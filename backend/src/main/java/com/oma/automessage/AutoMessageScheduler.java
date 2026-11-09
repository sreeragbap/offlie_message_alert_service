package com.oma.automessage;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import com.oma.common.ApiException;
import com.oma.recipient.Recipient;
import com.oma.recipient.RecipientRepository;
import com.oma.whatsapp.WhatsAppService;

/**
 * Sends automatic WhatsApp messages when they are due, through the same path as a message sent from
 * the app, so the SMS alert follows when WhatsApp does not report delivery in time.
 *
 * <p>A run is moved past (committed) before the message is sent, and each run uses a fixed request
 * id, so a crash or a second instance can skip a run but never sends it twice.
 */
@Component
public class AutoMessageScheduler {

	private static final Logger log = LoggerFactory.getLogger(AutoMessageScheduler.class);

	static final int BATCH_SIZE = 20;

	/** A repeating message this late (e.g. the server was off) is skipped rather than sent late. */
	static final Duration STALE_AFTER = Duration.ofMinutes(30);

	private final AutoMessageRepository autoMessages;

	private final AutoMessageService service;

	private final RecipientRepository recipients;

	private final WhatsAppService whatsApp;

	private final TransactionTemplate tx;

	private final Clock clock;

	AutoMessageScheduler(AutoMessageRepository autoMessages, AutoMessageService service,
			RecipientRepository recipients, WhatsAppService whatsApp, TransactionTemplate tx, Clock clock) {
		this.autoMessages = autoMessages;
		this.service = service;
		this.recipients = recipients;
		this.whatsApp = whatsApp;
		this.tx = tx;
		this.clock = clock;
	}

	private record Run(AutoMessage autoMessage, Instant slot) {
	}

	@Scheduled(fixedDelayString = "${oma.scheduler.poll-interval}",
			initialDelayString = "${oma.scheduler.initial-delay:PT10S}")
	public void runOnce() {
		Instant now = clock.instant();
		List<Run> claimed;
		do {
			claimed = claim(now);
			claimed.forEach(run -> send(run, now));
		}
		while (claimed.size() == BATCH_SIZE);
	}

	private List<Run> claim(Instant now) {
		return tx.execute(status -> {
			List<Run> runs = new ArrayList<>();
			for (AutoMessage m : autoMessages.lockDue(now, BATCH_SIZE)) {
				Instant next = m.repeating() ? AutoMessage.nextRun(m.sendTime(), m.repeatDays(), m.timeZone(), now)
						: null;
				autoMessages.advance(m.recipientId(), m.nextRunAt(), next);
				runs.add(new Run(m, m.nextRunAt()));
			}
			return runs;
		});
	}

	private void send(Run run, Instant now) {
		AutoMessage m = run.autoMessage();
		if (m.repeating() && run.slot().isBefore(now.minus(STALE_AFTER))) {
			autoMessages.recordResult(m.recipientId(), null,
					"Skipped a run: the server was offline at the scheduled time.");
			return;
		}
		Recipient recipient = recipients.find(m.userId(), m.recipientId()).orElse(null);
		if (recipient == null) {
			return;
		}
		if (recipient.optedOut()) {
			autoMessages.recordResult(m.recipientId(), null, "Not sent: they asked not to be alerted.");
			return;
		}
		String text = m.render(recipient.displayName(), service.senderName(m.userId()));
		try {
			WhatsAppService.Sent sent = whatsApp.send(m.userId(), new WhatsAppService.SendCommand(
					requestId(m.recipientId(), run.slot()), m.recipientId(), text, true, m.smsAfterMinutes()));
			autoMessages.recordResult(m.recipientId(), sent.messageId(), sent.error());
		}
		catch (ApiException ex) {
			autoMessages.recordResult(m.recipientId(), null, ex.getMessage());
		}
		catch (RuntimeException ex) {
			log.error("Automatic message to recipient {} failed: {}", m.recipientId(), ex.getClass().getSimpleName());
			autoMessages.recordResult(m.recipientId(), null, "Could not send. It will go at the next scheduled time.");
		}
	}

	/** Same slot, same id: WhatsAppService treats a repeat as a replay instead of sending again. */
	static UUID requestId(UUID recipientId, Instant slot) {
		return UUID.nameUUIDFromBytes(
				("auto-message:" + recipientId + ":" + slot.toEpochMilli()).getBytes(StandardCharsets.UTF_8));
	}

}
