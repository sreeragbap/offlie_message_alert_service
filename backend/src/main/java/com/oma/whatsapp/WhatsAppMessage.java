package com.oma.whatsapp;

import java.time.Instant;
import java.util.UUID;

/** A WhatsApp message sent through the app ({@code OUT}) or a reply to the business number ({@code IN}). */
record WhatsAppMessage(UUID id, UUID userId, UUID recipientId, String recipientName, Direction direction,
		Kind kind, String body, String wamid, Status status, String errorCode, String errorMessage, UUID alertId,
		String alertState, Instant alertDueAt, String alertNote, String alertSkipped, Instant createdAt,
		Instant sentAt, Instant deliveredAt, Instant readAt) {

	enum Direction {

		OUT, IN

	}

	enum Kind {

		TEXT, TEMPLATE, OTHER

	}

	enum Status {

		/** Saved, being handed to WhatsApp. */
		PENDING,
		/** WhatsApp accepted it (has a wamid). */
		ACCEPTED,
		/** WhatsApp sent it (one tick). */
		SENT,
		/** It reached the recipient's phone (two ticks). */
		DELIVERED,
		/** The recipient opened it (blue ticks; only if they allow read receipts). */
		READ,
		/** WhatsApp could not send or deliver it. */
		FAILED,
		/** No answer from WhatsApp; it may or may not have been sent. */
		UNKNOWN,
		/** Incoming message. */
		RECEIVED

	}

}
