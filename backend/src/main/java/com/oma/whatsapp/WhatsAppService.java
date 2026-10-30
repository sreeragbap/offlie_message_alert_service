package com.oma.whatsapp;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.oma.account.AccountRepository;
import com.oma.alert.AlertService;
import com.oma.common.ApiException;
import com.oma.config.OmaProperties;
import com.oma.preference.AlertPreferenceRepository;
import com.oma.recipient.Recipient;
import com.oma.recipient.RecipientRepository;
import com.oma.whatsapp.WhatsAppMessage.Kind;
import com.oma.whatsapp.WhatsAppMessage.Status;

/**
 * Sends a WhatsApp message and schedules the SMS alert that fires if WhatsApp does not report it
 * delivered in time. The message row is saved before calling WhatsApp, so a retried request with
 * the same {@code clientRequestId} never sends twice.
 */
@Service
public class WhatsAppService {

	static final int MAX_TEXT_LENGTH = 1000;

	/** WhatsApp allows free-form messages this long after the recipient's last message. */
	static final Duration SERVICE_WINDOW = Duration.ofHours(24);

	private final WhatsAppApi api;

	private final WhatsAppMessageRepository messages;

	private final WhatsAppStatusHandler statusHandler;

	private final RecipientRepository recipients;

	private final AccountRepository accounts;

	private final AlertPreferenceRepository preferences;

	private final AlertService alerts;

	private final OmaProperties.Whatsapp config;

	private final TransactionTemplate tx;

	private final Clock clock;

	WhatsAppService(WhatsAppApi api, WhatsAppMessageRepository messages, WhatsAppStatusHandler statusHandler,
			RecipientRepository recipients, AccountRepository accounts, AlertPreferenceRepository preferences,
			AlertService alerts, OmaProperties properties, TransactionTemplate tx, Clock clock) {
		this.api = api;
		this.messages = messages;
		this.statusHandler = statusHandler;
		this.recipients = recipients;
		this.accounts = accounts;
		this.preferences = preferences;
		this.alerts = alerts;
		this.config = properties.whatsapp();
		this.tx = tx;
		this.clock = clock;
	}

	/**
	 * @param alertAfterMinutes send the SMS if WhatsApp has not reported delivery after this long;
	 * null uses the user's default delay; ignored when {@code smsAlert} is false
	 */
	public record SendCommand(UUID clientRequestId, UUID recipientId, String text, boolean smsAlert,
			Integer alertAfterMinutes) {
	}

	public record Sent(WhatsAppMessage message, boolean replayed) {
	}

	private record Prepared(UUID messageId, boolean replayed, Recipient recipient, Kind kind) {
	}

	public boolean configured() {
		return config.configured();
	}

	public String templateName() {
		return config.templateName();
	}

	public Sent send(UUID userId, SendCommand command) {
		if (!config.configured()) {
			throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "WHATSAPP_NOT_CONFIGURED",
					"WhatsApp Business isn't connected yet. See the setup guide.");
		}
		String text = command.text() == null ? "" : command.text().strip();
		if (text.isEmpty() || text.length() > MAX_TEXT_LENGTH) {
			throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "INVALID_TEXT",
					"Write a message of up to " + MAX_TEXT_LENGTH + " characters.");
		}

		Prepared prepared = tx.execute(status -> {
			Recipient recipient = recipients.findForUpdate(userId, command.recipientId())
				.orElseThrow(() -> ApiException.notFound("Recipient"));
			var existing = messages.findIdByClientRequestId(userId, command.clientRequestId());
			if (existing.isPresent()) {
				return new Prepared(existing.get(), true, recipient, null);
			}
			Instant now = clock.instant();
			Instant lastInbound = messages.recipientLastInbound(recipient.id()).orElse(null);
			boolean windowOpen = lastInbound != null && lastInbound.isAfter(now.minus(SERVICE_WINDOW));
			Kind kind = windowOpen ? Kind.TEXT : Kind.TEMPLATE;
			return new Prepared(
					messages.insertPending(userId, recipient.id(), command.clientRequestId(), kind, text, now), false,
					recipient, kind);
		});
		if (prepared.replayed()) {
			return new Sent(get(userId, prepared.messageId()), true);
		}

		WhatsAppApi.SendResult result = api.send(outgoing(userId, prepared.recipient(), prepared.kind(), text));

		tx.executeWithoutResult(status -> {
			switch (result.outcome()) {
				case REJECTED -> messages.markFinished(prepared.messageId(), Status.FAILED, result.errorCode(),
						friendlyError(result.errorCode(), result.errorMessage()));
				case UNKNOWN -> messages.markFinished(prepared.messageId(), Status.UNKNOWN, result.errorCode(),
						"WhatsApp did not answer. Check the recipient's chat before sending again.");
				case ACCEPTED -> accepted(userId, prepared, result.wamid(), command);
			}
		});
		return new Sent(get(userId, prepared.messageId()), false);
	}

	private void accepted(UUID userId, Prepared prepared, String wamid, SendCommand command) {
		messages.lockWamid(wamid);
		messages.markAccepted(prepared.messageId(), wamid);
		// Statuses that arrived before the wamid was stored.
		for (var event : messages.statusEvents(wamid)) {
			statusHandler.apply(wamid, event.status(), event.occurredAt(), event.errorCode(), event.errorTitle());
		}
		if (!command.smsAlert()) {
			return;
		}
		WhatsAppMessage current = get(userId, prepared.messageId());
		if (current.status() == Status.DELIVERED || current.status() == Status.READ) {
			return;
		}
		Recipient recipient = recipients.findForUpdate(userId, prepared.recipient().id()).orElse(null);
		if (recipient == null) {
			return;
		}
		int delay = command.alertAfterMinutes() != null ? command.alertAfterMinutes()
				: Math.max(1, preferences.get(userId).defaultDelayMinutes());
		AlertService.DeliveryAlert alert = alerts.scheduleDeliveryTimeoutAlert(userId, recipient,
				command.clientRequestId(), delay);
		messages.linkAlert(prepared.messageId(), alert.alertId(),
				alert.skippedBecause() == null ? null : alert.skippedBecause().name());
		if (alert.alertId() != null && current.status() == Status.FAILED) {
			alerts.sendNowBecauseWhatsAppFailed(alert.alertId());
		}
	}

	private WhatsAppApi.OutgoingMessage outgoing(UUID userId, Recipient recipient, Kind kind, String text) {
		if (kind == Kind.TEXT) {
			return new WhatsAppApi.OutgoingMessage(recipient.phoneE164(), WhatsAppApi.Kind.TEXT, text, null, null,
					List.of());
		}
		String sender = accounts.findDisplayName(userId).filter(name -> !name.isBlank()).orElse("Someone");
		List<String> params = config.templateParamsOrEmpty().stream().map(String::strip).map(param -> switch (param) {
			case "sender" -> sender;
			case "name" -> recipient.displayName();
			case "text" -> text;
			default -> param;
		}).map(WhatsAppService::templateSafe).toList();
		return new WhatsAppApi.OutgoingMessage(recipient.phoneE164(), WhatsAppApi.Kind.TEMPLATE, null,
				config.templateName(), config.templateLanguage(), params);
	}

	/** Template variables may not contain new lines, tabs or more than four spaces in a row. */
	static String templateSafe(String value) {
		return value.replaceAll("[\\t\\r\\n]+", " ").replaceAll(" {4,}", "   ").strip();
	}

	static String friendlyError(String code, String detail) {
		return switch (code == null ? "" : code) {
			case "131030" -> "This number isn't on your WhatsApp test number's allowed list. Add it in the Meta app.";
			case "131047" -> "More than 24 hours since they last wrote to you. Try again: a template will be used.";
			case "131026" -> "WhatsApp can't deliver to this number (no WhatsApp, or an old app version).";
			case "132000", "132001" -> "The WhatsApp template isn't approved or its variables don't match. "
					+ "Check WHATSAPP_TEMPLATE_* settings.";
			case "190" -> "The WhatsApp access token has expired. Create a new one in the Meta app.";
			case "130429", "131056" -> "Too many messages right now. Try again in a minute.";
			default -> detail == null || detail.isBlank() ? "WhatsApp rejected the message (" + code + ")." : detail;
		};
	}

	public WhatsAppMessage get(UUID userId, UUID id) {
		return messages.find(userId, id).orElseThrow(() -> ApiException.notFound("Message"));
	}

	public List<WhatsAppMessage> recent(UUID userId, UUID recipientId, int limit) {
		return messages.recent(userId, recipientId, limit);
	}

}
