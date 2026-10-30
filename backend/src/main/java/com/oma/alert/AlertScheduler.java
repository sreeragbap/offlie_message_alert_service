package com.oma.alert;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.oma.config.OmaProperties;
import com.oma.recipient.Recipient;
import com.oma.recipient.RecipientRepository;
import com.oma.sms.SmsGateway;
import com.oma.sms.SmsMessage;
import com.oma.sms.SmsSendResult;

/**
 * Background processing, independent of the mobile app. Every step is a conditional SQL update or a
 * {@code SKIP LOCKED} claim, so it is safe to run on several instances and after restarts.
 */
@Component
public class AlertScheduler {

	private static final Logger log = LoggerFactory.getLogger(AlertScheduler.class);

	static final int BATCH_SIZE = 20;

	private final AlertRepository alerts;

	private final RecipientRepository recipients;

	private final SmsGateway smsGateway;

	private final OmaProperties properties;

	private final Clock clock;

	AlertScheduler(AlertRepository alerts, RecipientRepository recipients, SmsGateway smsGateway,
			OmaProperties properties, Clock clock) {
		this.alerts = alerts;
		this.recipients = recipients;
		this.smsGateway = smsGateway;
		this.properties = properties;
		this.clock = clock;
	}

	@Scheduled(fixedDelayString = "${oma.scheduler.poll-interval}",
			initialDelayString = "${oma.scheduler.initial-delay:PT10S}")
	public void runOnce() {
		Instant now = clock.instant();
		int recovered = alerts.markStuckSendsUnknown(now);
		if (recovered > 0) {
			log.warn("{} alert(s) were interrupted while sending and are marked SMS_UNKNOWN", recovered);
		}
		alerts.promoteDueDeviceAndRelayAlerts(now);
		alerts.expireDeviceAndRelayAlerts(now.minus(properties.alerts().deviceDueExpiry()));
		dispatchServerAlerts(now);
	}

	@Scheduled(cron = "${oma.scheduler.retention-cron:0 30 3 * * *}")
	public void purgeOldAlerts() {
		int deleted = alerts.deleteCreatedBefore(clock.instant().minus(properties.alerts().retention()));
		if (deleted > 0) {
			log.info("Retention: deleted {} old alert(s)", deleted);
		}
	}

	private void dispatchServerAlerts(Instant now) {
		List<Alert> claimed;
		do {
			claimed = alerts.claimDueServerAlerts(now, now.plus(properties.alerts().sendLease()), BATCH_SIZE);
			claimed.forEach(this::send);
		}
		while (claimed.size() == BATCH_SIZE);
	}

	private void send(Alert alert) {
		if (!properties.sms().serverChannelEnabled()) {
			alerts.finishSending(alert.id(), AlertState.SKIPPED, null, "Server SMS channel is disabled");
			return;
		}
		Recipient recipient = alert.recipientId() == null ? null
				: recipients.find(alert.userId(), alert.recipientId()).orElse(null);
		if (recipient == null || !recipient.canReceiveAlerts()) {
			alerts.finishSending(alert.id(), AlertState.SKIPPED, null, "Recipient can no longer receive alerts");
			return;
		}

		SmsSendResult result;
		try {
			result = smsGateway.send(new SmsMessage(recipient.phoneE164(), alert.messageText(), alert.id().toString()));
		}
		catch (RuntimeException ex) {
			// We cannot tell whether the provider received it; do not risk a duplicate SMS.
			log.error("SMS gateway threw for alert {}: {}", alert.id(), ex.getClass().getSimpleName());
			result = SmsSendResult.unknown("GATEWAY_EXCEPTION");
		}

		String provider = smsGateway.providerName();
		switch (result.outcome()) {
			case ACCEPTED -> alerts.markAccepted(alert.id(), provider, result.providerMessageId());
			case UNKNOWN -> alerts.finishSending(alert.id(), AlertState.SMS_UNKNOWN, provider,
					"Outcome unknown: " + result.errorCode());
			case PERMANENT_FAILURE -> alerts.finishSending(alert.id(), AlertState.SMS_FAILED, provider,
					"Rejected: " + result.errorCode());
			case RETRYABLE_FAILURE -> {
				if (alert.attempts() >= properties.alerts().serverMaxAttempts()) {
					alerts.finishSending(alert.id(), AlertState.SMS_FAILED, provider,
							"Gave up after " + alert.attempts() + " attempts: " + result.errorCode());
				}
				else {
					alerts.reschedule(alert.id(), clock.instant().plus(backoff(alert.attempts())),
							"Retrying after: " + result.errorCode());
				}
			}
		}
	}

	/** Exponential backoff: base, 2x base, 4x base, ... */
	Duration backoff(int attemptsSoFar) {
		return properties.alerts().serverRetryBaseDelay().multipliedBy(1L << Math.max(0, attemptsSoFar - 1));
	}

}
