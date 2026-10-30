package com.oma.alert;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.CurrentUser;

/** Called by the user's relay phone (the app in relay mode), signed in as the same user. */
@RestController
@RequestMapping("/api/v1/relay")
class RelayController {

	private final RelayService service;

	RelayController(RelayService service) {
		this.service = service;
	}

	record ReportRequest(@NotNull RelayService.ReportedOutcome outcome, @Size(max = 200) String error) {
	}

	/** Hands out due SMS jobs; also records that the relay phone is online. */
	@PostMapping("/claim")
	List<RelayService.RelayJob> claim(CurrentUser user,
			@RequestParam(defaultValue = "" + RelayService.MAX_CLAIM) int limit) {
		return service.claim(user.id(), limit);
	}

	@PostMapping("/alerts/{id}/result")
	AlertResponse report(CurrentUser user, @PathVariable UUID id, @Valid @RequestBody ReportRequest request) {
		return AlertResponse.of(service.report(user.id(), id, request.outcome(), request.error()));
	}

}
