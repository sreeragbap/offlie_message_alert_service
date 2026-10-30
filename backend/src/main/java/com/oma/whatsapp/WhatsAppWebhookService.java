package com.oma.whatsapp;

import java.time.Instant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.databind.JsonNode;

import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.oma.alert.AlertService;
import com.oma.whatsapp.WhatsAppMessage.Kind;
import com.oma.whatsapp.WhatsAppMessage.Status;

/**
 * Processes WhatsApp webhooks: delivery statuses of our messages and messages people send to the
 * business number. Safe to receive twice (Meta retries): statuses only move forward and inbound
 * messages are stored once per wamid.
 */
@Service
class WhatsAppWebhookService {

	private static final Logger log = LoggerFactory.getLogger(WhatsAppWebhookService.class);

	private final WhatsAppMessageRepository messages;

	private final WhatsAppStatusHandler statusHandler;

	private final AlertService alerts;

	private final TransactionTemplate tx;

	WhatsAppWebhookService(WhatsAppMessageRepository messages, WhatsAppStatusHandler statusHandler,
			AlertService alerts, TransactionTemplate tx) {
		this.messages = messages;
		this.statusHandler = statusHandler;
		this.alerts = alerts;
		this.tx = tx;
	}

	void handle(JsonNode payload) {
		for (JsonNode entry : payload.path("entry")) {
			for (JsonNode change : entry.path("changes")) {
				if (!"messages".equals(change.path("field").asString(""))) {
					continue;
				}
				JsonNode value = change.path("value");
				value.path("statuses").forEach(this::status);
				value.path("messages").forEach(this::inbound);
			}
		}
	}

	private void status(JsonNode node) {
		String wamid = node.path("id").asString(null);
		Status status = switch (node.path("status").asString("")) {
			case "sent" -> Status.SENT;
			case "delivered" -> Status.DELIVERED;
			case "read" -> Status.READ;
			case "failed" -> Status.FAILED;
			default -> null;
		};
		if (wamid == null || status == null) {
			return;
		}
		Instant at = epoch(node.path("timestamp"));
		JsonNode error = node.path("errors").path(0);
		String code = error.isMissingNode() ? null : error.path("code").asString(null);
		String title = error.isMissingNode() ? null
				: error.path("error_data").path("details").asString(error.path("title").asString(null));
		tx.executeWithoutResult(s -> {
			messages.lockWamid(wamid);
			messages.insertStatusEvent(wamid, status, at, code, title);
			statusHandler.apply(wamid, status, at, code, title);
		});
		if (status == Status.FAILED) {
			log.info("WhatsApp reported a message failed: {}", code);
		}
	}

	private void inbound(JsonNode node) {
		String from = node.path("from").asString(null);
		String wamid = node.path("id").asString(null);
		if (from == null || wamid == null || !from.chars().allMatch(Character::isDigit)) {
			return;
		}
		String type = node.path("type").asString("unknown");
		boolean text = "text".equals(type);
		String body = text ? node.path("text").path("body").asString("") : "[" + type + "]";
		Instant at = epoch(node.path("timestamp"));
		tx.executeWithoutResult(s -> {
			for (var ref : messages.touchRecipientsByPhone("+" + from, at)) {
				messages.insertInbound(ref, wamid, text ? Kind.TEXT : Kind.OTHER, body, at);
				alerts.cancelBecauseRecipientReplied(ref.recipientId());
			}
		});
	}

	private static Instant epoch(JsonNode timestamp) {
		try {
			return Instant.ofEpochSecond(Long.parseLong(timestamp.asString("")));
		}
		catch (NumberFormatException ex) {
			return Instant.now();
		}
	}

}
