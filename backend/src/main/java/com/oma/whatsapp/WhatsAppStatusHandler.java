package com.oma.whatsapp;

import java.time.Instant;

import org.springframework.stereotype.Component;

import com.oma.alert.AlertService;
import com.oma.whatsapp.WhatsAppMessage.Status;

/** Applies a WhatsApp delivery status to the message and to the SMS alert waiting on it. */
@Component
class WhatsAppStatusHandler {

	private final WhatsAppMessageRepository messages;

	private final AlertService alerts;

	WhatsAppStatusHandler(WhatsAppMessageRepository messages, AlertService alerts) {
		this.messages = messages;
		this.alerts = alerts;
	}

	/** Call within a transaction holding {@link WhatsAppMessageRepository#lockWamid}. */
	void apply(String wamid, Status status, Instant at, String errorCode, String errorTitle) {
		for (var advanced : messages.advanceStatus(wamid, status, at, errorCode, errorTitle)) {
			if (advanced.alertId() == null) {
				continue;
			}
			switch (status) {
				case DELIVERED, READ -> alerts.cancelBecauseDelivered(advanced.alertId());
				case FAILED -> alerts.sendNowBecauseWhatsAppFailed(advanced.alertId());
				default -> {
				}
			}
		}
	}

}
