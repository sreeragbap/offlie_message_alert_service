package com.oma.whatsapp;

import java.net.URI;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.CurrentUser;

@RestController
@RequestMapping("/api/v1/whatsapp")
class WhatsAppController {

	private final WhatsAppService service;

	WhatsAppController(WhatsAppService service) {
		this.service = service;
	}

	record StatusResponse(boolean connected, String templateName) {
	}

	record SendRequest(@NotNull UUID clientRequestId, @NotNull UUID recipientId, @NotNull String text,
			Boolean smsAlert, @Min(1) @Max(1440) Integer alertAfterMinutes) {
	}

	record AlertSummary(UUID id, String state, Instant dueAt, String note) {
	}

	record MessageResponse(UUID id, UUID recipientId, String recipientName, WhatsAppMessage.Direction direction,
			WhatsAppMessage.Kind kind, String text, WhatsAppMessage.Status status, String error, Instant createdAt,
			Instant sentAt, Instant deliveredAt, Instant readAt, AlertSummary alert, String alertSkipped) {

		static MessageResponse of(WhatsAppMessage m) {
			AlertSummary alert = m.alertId() == null ? null
					: new AlertSummary(m.alertId(), m.alertState(), m.alertDueAt(), m.alertNote());
			return new MessageResponse(m.id(), m.recipientId(), m.recipientName(), m.direction(), m.kind(), m.body(),
					m.status(), m.errorMessage(), m.createdAt(), m.sentAt(), m.deliveredAt(), m.readAt(), alert,
					m.alertSkipped());
		}

	}

	@GetMapping("/status")
	StatusResponse status() {
		return new StatusResponse(service.configured(), service.configured() ? service.templateName() : null);
	}

	/** 201 for a new message, 200 when the same {@code clientRequestId} was already used. */
	@PostMapping("/messages")
	ResponseEntity<MessageResponse> send(CurrentUser user, @Valid @RequestBody SendRequest request) {
		WhatsAppService.Sent sent = service.send(user.id(),
				new WhatsAppService.SendCommand(request.clientRequestId(), request.recipientId(), request.text(),
						request.smsAlert() == null || request.smsAlert(), request.alertAfterMinutes()));
		MessageResponse body = MessageResponse.of(sent.message());
		return sent.replayed() ? ResponseEntity.ok(body)
				: ResponseEntity.created(URI.create("/api/v1/whatsapp/messages/" + body.id())).body(body);
	}

	@GetMapping("/messages")
	List<MessageResponse> recent(CurrentUser user, @RequestParam(required = false) UUID recipientId,
			@RequestParam(defaultValue = "50") @Min(1) @Max(200) int limit) {
		return service.recent(user.id(), recipientId, limit).stream().map(MessageResponse::of).toList();
	}

	@GetMapping("/messages/{id}")
	MessageResponse get(CurrentUser user, @PathVariable UUID id) {
		return MessageResponse.of(service.get(user.id(), id));
	}

}
