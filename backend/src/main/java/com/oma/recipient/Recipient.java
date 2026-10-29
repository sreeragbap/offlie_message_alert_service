package com.oma.recipient;

import java.time.Instant;
import java.util.UUID;

public record Recipient(UUID id, UUID userId, String displayName, String phoneE164, boolean alertsEnabled,
		boolean optedOut, Instant createdAt, Instant updatedAt) {

	/** Alerts are allowed only when the user enabled them and the recipient has not opted out. */
	public boolean canReceiveAlerts() {
		return alertsEnabled && !optedOut;
	}

}
