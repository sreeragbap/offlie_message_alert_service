package com.oma.alert;

import java.time.Instant;
import java.util.UUID;

public record AlertResponse(UUID id, RecipientSummary recipient, Platform platform, AlertChannel channel,
		AlertState state, TriggerSource triggerSource, String messageText, Instant dueAt, Instant createdAt,
		Instant completedAt, boolean deliveryConfirmed, String note) {

	/** Null when the recipient has since been removed. */
	public record RecipientSummary(UUID id, String displayName, String phoneE164) {
	}

	public static AlertResponse of(AlertView view) {
		Alert a = view.alert();
		RecipientSummary recipient = a.recipientId() == null ? null
				: new RecipientSummary(a.recipientId(), view.recipientName(), view.recipientPhoneE164());
		return new AlertResponse(a.id(), recipient, a.platform(), a.channel(), a.state(), a.triggerSource(),
				a.messageText(), a.dueAt(), a.createdAt(), a.completedAt(), a.state() == AlertState.SMS_DELIVERED,
				a.lastError());
	}

}
