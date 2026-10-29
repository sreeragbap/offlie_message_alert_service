package com.oma.preference;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.CurrentUser;

@RestController
@RequestMapping("/api/v1/alert-preferences")
class AlertPreferenceController {

	private final AlertPreferenceRepository preferences;

	AlertPreferenceController(AlertPreferenceRepository preferences) {
		this.preferences = preferences;
	}

	record PreferenceBody(@NotNull @Min(0) @Max(1440) Integer defaultDelayMinutes,
			@NotNull @Min(1) @Max(10) Integer maxAlertsPerRecipientPerDay,
			@NotNull @Min(1) @Max(50) Integer maxAlertsPerDay,
			@NotBlank @Size(min = 10, max = 300) String messageTemplate) {

		static PreferenceBody of(AlertPreference p) {
			return new PreferenceBody(p.defaultDelayMinutes(), p.maxAlertsPerRecipientPerDay(), p.maxAlertsPerDay(),
					p.messageTemplate());
		}

	}

	@GetMapping
	PreferenceBody get(CurrentUser user) {
		return PreferenceBody.of(preferences.get(user.id()));
	}

	@PutMapping
	PreferenceBody put(CurrentUser user, @Valid @RequestBody PreferenceBody body) {
		String template = body.messageTemplate().strip();
		AlertPreference.validateTemplate(template);
		preferences.save(user.id(), new AlertPreference(body.defaultDelayMinutes(), body.maxAlertsPerRecipientPerDay(),
				body.maxAlertsPerDay(), template));
		return get(user);
	}

}
