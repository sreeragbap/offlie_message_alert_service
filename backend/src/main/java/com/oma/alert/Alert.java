package com.oma.alert;

import java.time.Instant;
import java.util.UUID;

public record Alert(UUID id, UUID userId, UUID recipientId, UUID clientRequestId, TriggerSource triggerSource,
		Platform platform, AlertChannel channel, AlertState state, String messageText, Instant dueAt, int attempts,
		Instant lockedUntil, String provider, String providerMessageId, String lastError, Instant createdAt,
		Instant updatedAt, Instant completedAt) {
}
