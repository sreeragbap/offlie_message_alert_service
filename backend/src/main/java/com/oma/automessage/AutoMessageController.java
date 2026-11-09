package com.oma.automessage;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.CurrentUser;

/** The automatic WhatsApp message for one recipient. A recipient without one gets {@code enabled: false}. */
@RestController
@RequestMapping("/api/v1/recipients/{recipientId}/auto-message")
class AutoMessageController {

	private final AutoMessageService service;

	AutoMessageController(AutoMessageService service) {
		this.service = service;
	}

	/**
	 * @param sendTime "HH:mm" to repeat at that time on {@code days}; omit to send once, a minute after saving
	 * @param days e.g. ["MONDAY", "FRIDAY"]; omit for every day
	 * @param text omit for the default text; may use {name} and {sender}
	 */
	record AutoMessageRequest(@NotNull Boolean enabled, @Size(max = 1000) String text,
			@Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$", message = "use HH:mm") String sendTime,
			List<DayOfWeek> days, @Size(max = 64) String timeZone, @Min(1) @Max(1440) Integer smsAfterMinutes) {
	}

	record AutoMessageResponse(boolean enabled, String text, String defaultText, String preview, String sendTime,
			List<DayOfWeek> days, String timeZone, int smsAfterMinutes, Instant nextRunAt, Instant lastRunAt,
			UUID lastMessageId, String lastError) {

		static AutoMessageResponse of(AutoMessageService.View view) {
			AutoMessage m = view.autoMessage();
			return new AutoMessageResponse(m.enabled(), m.messageText(), AutoMessage.DEFAULT_TEXT, view.preview(),
					m.sendTime() == null ? null : m.sendTime().toString(), List.copyOf(m.days()), m.timeZone().getId(),
					m.smsAfterMinutes(), m.nextRunAt(), m.lastRunAt(), m.lastMessageId(), m.lastError());
		}

	}

	@GetMapping
	AutoMessageResponse get(CurrentUser user, @PathVariable UUID recipientId) {
		return AutoMessageResponse.of(service.get(user.id(), recipientId));
	}

	@PutMapping
	AutoMessageResponse save(CurrentUser user, @PathVariable UUID recipientId,
			@Valid @RequestBody AutoMessageRequest request) {
		return AutoMessageResponse.of(service.save(user.id(), recipientId,
				new AutoMessageService.Settings(request.enabled(), request.text(),
						request.sendTime() == null ? null : LocalTime.parse(request.sendTime()),
						request.days() == null ? null : Set.copyOf(request.days()),
						request.timeZone(), request.smsAfterMinutes())));
	}

}
