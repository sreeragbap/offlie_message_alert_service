package com.oma.recipient;

import java.net.URI;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.CurrentUser;

@RestController
@RequestMapping("/api/v1/recipients")
class RecipientController {

	private final RecipientService service;

	RecipientController(RecipientService service) {
		this.service = service;
	}

	record CreateRecipientRequest(@NotBlank @Size(max = 80) String displayName,
			@NotBlank @Size(max = 32) String phone, Boolean alertsEnabled) {
	}

	record UpdateRecipientRequest(@Size(min = 1, max = 80) String displayName, @Size(min = 3, max = 32) String phone,
			Boolean alertsEnabled, Boolean optedOut) {
	}

	record RecipientResponse(UUID id, String displayName, String phoneE164, boolean alertsEnabled, boolean optedOut,
			boolean canReceiveAlerts) {

		static RecipientResponse of(Recipient r) {
			return new RecipientResponse(r.id(), r.displayName(), r.phoneE164(), r.alertsEnabled(), r.optedOut(),
					r.canReceiveAlerts());
		}

	}

	@GetMapping
	List<RecipientResponse> list(CurrentUser user) {
		return service.list(user.id()).stream().map(RecipientResponse::of).toList();
	}

	@GetMapping("/{id}")
	RecipientResponse get(CurrentUser user, @PathVariable UUID id) {
		return RecipientResponse.of(service.get(user.id(), id));
	}

	@PostMapping
	ResponseEntity<RecipientResponse> create(CurrentUser user, @Valid @RequestBody CreateRecipientRequest request) {
		Recipient created = service.create(user.id(), request.displayName(), request.phone(),
				request.alertsEnabled() == null || request.alertsEnabled());
		return ResponseEntity.created(URI.create("/api/v1/recipients/" + created.id()))
			.body(RecipientResponse.of(created));
	}

	@PatchMapping("/{id}")
	RecipientResponse update(CurrentUser user, @PathVariable UUID id,
			@Valid @RequestBody UpdateRecipientRequest request) {
		return RecipientResponse.of(service.update(user.id(), id, new RecipientService.Changes(request.displayName(),
				request.phone(), request.alertsEnabled(), request.optedOut())));
	}

	@DeleteMapping("/{id}")
	ResponseEntity<Void> delete(CurrentUser user, @PathVariable UUID id) {
		service.delete(user.id(), id);
		return ResponseEntity.noContent().build();
	}

}
