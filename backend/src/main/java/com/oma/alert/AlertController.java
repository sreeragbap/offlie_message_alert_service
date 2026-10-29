package com.oma.alert;

import java.net.URI;
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
import com.oma.common.PageResponse;

@RestController
@RequestMapping("/api/v1/alerts")
class AlertController {

	private final AlertService service;

	AlertController(AlertService service) {
		this.service = service;
	}

	record CreateAlertRequest(@NotNull UUID clientRequestId, @NotNull UUID recipientId, @NotNull Platform platform,
			@Min(0) @Max(1440) Integer delayMinutes, AlertChannel channel) {
	}

	/** 201 for a new alert, 200 when the same {@code clientRequestId} was already used. */
	@PostMapping
	ResponseEntity<AlertResponse> create(CurrentUser user, @Valid @RequestBody CreateAlertRequest request) {
		AlertService.Created created = service.create(user.id(), new AlertService.CreateAlert(request.clientRequestId(),
				request.recipientId(), request.platform(), request.delayMinutes(), request.channel()));
		AlertResponse body = AlertResponse.of(created.alert());
		return created.replayed() ? ResponseEntity.ok(body)
				: ResponseEntity.created(URI.create("/api/v1/alerts/" + body.id())).body(body);
	}

	@GetMapping
	PageResponse<AlertResponse> list(CurrentUser user, @RequestParam(defaultValue = "false") boolean openOnly,
			@RequestParam(defaultValue = "0") @Min(0) int page,
			@RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
		PageResponse<AlertView> result = service.list(user.id(), openOnly, page, size);
		return new PageResponse<>(result.items().stream().map(AlertResponse::of).toList(), result.page(),
				result.size(), result.totalItems());
	}

	@GetMapping("/{id}")
	AlertResponse get(CurrentUser user, @PathVariable UUID id) {
		return AlertResponse.of(service.get(user.id(), id));
	}

	@PostMapping("/{id}/cancel")
	AlertResponse cancel(CurrentUser user, @PathVariable UUID id) {
		return AlertResponse.of(service.cancel(user.id(), id));
	}

	@PostMapping("/{id}/sent-from-device")
	AlertResponse sentFromDevice(CurrentUser user, @PathVariable UUID id) {
		return AlertResponse.of(service.markSentFromDevice(user.id(), id));
	}

}
