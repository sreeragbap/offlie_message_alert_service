package com.oma.alert;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.oma.common.ApiException;
import com.oma.common.PageResponse;
import com.oma.config.OmaProperties;
import com.oma.preference.AlertPreference;
import com.oma.preference.AlertPreferenceRepository;
import com.oma.recipient.Recipient;
import com.oma.recipient.RecipientRepository;

@Service
public class AlertService {

	static final int MAX_MESSAGE_LENGTH = 320;

	private static final Duration RATE_WINDOW = Duration.ofHours(24);

	private final AlertRepository alerts;

	private final RecipientRepository recipients;

	private final AlertPreferenceRepository preferences;

	private final OmaProperties properties;

	private final Clock clock;

	AlertService(AlertRepository alerts, RecipientRepository recipients, AlertPreferenceRepository preferences,
			OmaProperties properties, Clock clock) {
		this.alerts = alerts;
		this.recipients = recipients;
		this.preferences = preferences;
		this.properties = properties;
		this.clock = clock;
	}

	public record CreateAlert(UUID clientRequestId, UUID recipientId, Platform platform, Integer delayMinutes,
			AlertChannel channel) {
	}

	public record Created(AlertView alert, boolean replayed) {
	}

	/**
	 * Creates a user-triggered alert. Repeating a request with the same {@code clientRequestId}
	 * returns the original alert instead of creating a second one.
	 */
	@Transactional
	public Created create(UUID userId, CreateAlert command) {
		AlertChannel channel = command.channel() == null ? AlertChannel.DEVICE_SMS : command.channel();
		if (channel == AlertChannel.SERVER_SMS && !properties.sms().serverChannelEnabled()) {
			throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "CHANNEL_UNAVAILABLE",
					"Sending SMS from the server is not available yet. Send the alert from your phone instead.");
		}
		// Lock the recipient first: serialises concurrent requests for the same recipient so the
		// idempotency check and the rate limit below cannot be raced.
		Recipient recipient = recipients.findForUpdate(userId, command.recipientId())
			.orElseThrow(() -> ApiException.notFound("Recipient"));

		var existing = alerts.findIdByClientRequestId(userId, command.clientRequestId());
		if (existing.isPresent()) {
			return new Created(get(userId, existing.get()), true);
		}
		if (recipient.optedOut()) {
			throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "RECIPIENT_OPTED_OUT",
					recipient.displayName() + " asked not to receive alerts.");
		}
		if (!recipient.alertsEnabled()) {
			throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "RECIPIENT_ALERTS_DISABLED",
					"Alerts are turned off for " + recipient.displayName() + ".");
		}

		AlertPreference preference = preferences.get(userId);
		Instant now = clock.instant();
		Instant windowStart = now.minus(RATE_WINDOW);
		if (alerts.countSentOrPendingForRecipientSince(recipient.id(), windowStart) >= preference
			.maxAlertsPerRecipientPerDay()) {
			throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RECIPIENT_RATE_LIMITED",
					"You've reached the daily alert limit for " + recipient.displayName() + ".");
		}
		if (alerts.countSentOrPendingForUserSince(userId, windowStart) >= preference.maxAlertsPerDay()) {
			throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "DAILY_RATE_LIMITED",
					"You've reached your daily alert limit.");
		}

		int delay = command.delayMinutes() != null ? command.delayMinutes() : preference.defaultDelayMinutes();
		String message = preference.render(recipient.displayName(), command.platform().displayName());
		if (message.length() > MAX_MESSAGE_LENGTH) {
			throw new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, "MESSAGE_TOO_LONG",
					"The alert message is too long. Shorten your message template.");
		}
		AlertState initial = (delay == 0 && channel == AlertChannel.DEVICE_SMS) ? AlertState.DUE : AlertState.SCHEDULED;

		UUID id;
		try {
			id = alerts.insert(new AlertRepository.NewAlert(userId, recipient.id(), command.clientRequestId(),
					TriggerSource.USER_TRIGGERED, command.platform(), channel, initial, message,
					now.plus(Duration.ofMinutes(delay)), now));
		}
		catch (DuplicateKeyException ex) {
			// Defensive: the recipient lock makes this unreachable for the same recipient.
			throw new ApiException(HttpStatus.CONFLICT, "DUPLICATE_REQUEST", "This alert was already requested.");
		}
		return new Created(get(userId, id), false);
	}

	public AlertView get(UUID userId, UUID id) {
		return alerts.find(userId, id).orElseThrow(() -> ApiException.notFound("Alert"));
	}

	public PageResponse<AlertView> list(UUID userId, boolean openOnly, int page, int size) {
		List<AlertView> items = alerts.page(userId, openOnly, page, size);
		return new PageResponse<>(items, page, size, alerts.count(userId, openOnly));
	}

	@Transactional
	public AlertView cancel(UUID userId, UUID id) {
		if (!alerts.transition(userId, id, AlertState.OPEN, AlertState.CANCELLED, "Cancelled by you", true)) {
			throw invalidState(userId, id, "Only alerts that have not been sent can be cancelled.");
		}
		return get(userId, id);
	}

	/**
	 * The user sent the SMS from their own phone (allowed early, before the delay ends). Android does
	 * not report whether the SMS was actually sent, so this records the user's confirmation only.
	 */
	@Transactional
	public AlertView markSentFromDevice(UUID userId, UUID id) {
		AlertView current = get(userId, id);
		if (current.alert().channel() != AlertChannel.DEVICE_SMS) {
			throw new ApiException(HttpStatus.CONFLICT, "INVALID_STATE", "This alert is sent by the server.");
		}
		if (current.alert().state() == AlertState.SENT_FROM_DEVICE) {
			return current;
		}
		if (current.recipientPhoneE164() == null) {
			throw new ApiException(HttpStatus.CONFLICT, "RECIPIENT_REMOVED", "This recipient was removed.");
		}
		if (!alerts.transition(userId, id, EnumSet.of(AlertState.SCHEDULED, AlertState.DUE),
				AlertState.SENT_FROM_DEVICE, null, true)) {
			throw invalidState(userId, id, "This alert can no longer be sent.");
		}
		return get(userId, id);
	}

	private ApiException invalidState(UUID userId, UUID id, String message) {
		get(userId, id); // 404 if it is not the caller's alert
		return new ApiException(HttpStatus.CONFLICT, "INVALID_STATE", message);
	}

}
