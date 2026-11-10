package com.oma.automessage;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.oma.account.AccountRepository;
import com.oma.common.ApiException;
import com.oma.recipient.Recipient;
import com.oma.recipient.RecipientRepository;

@Service
class AutoMessageService {

	/** A one-off goes this long after it is saved. */
	static final Duration ONE_OFF_DELAY = Duration.ofMinutes(1);

	static final int MAX_TEXT_LENGTH = 1000;

	private static final Pattern PLACEHOLDER = Pattern.compile("\\{([a-zA-Z]+)}");

	private final AutoMessageRepository autoMessages;

	private final RecipientRepository recipients;

	private final AccountRepository accounts;

	private final Clock clock;

	AutoMessageService(AutoMessageRepository autoMessages, RecipientRepository recipients, AccountRepository accounts,
			Clock clock) {
		this.autoMessages = autoMessages;
		this.recipients = recipients;
		this.accounts = accounts;
		this.clock = clock;
	}

	/**
	 * @param text null or blank for the default text
	 * @param sendTime null to send once, a minute after saving
	 * @param days days to send on with {@code sendTime}; null or empty for every day
	 */
	record Settings(boolean enabled, String text, LocalTime sendTime, Set<DayOfWeek> days, String timeZone,
			Integer smsAfterMinutes) {
	}

	/** The settings plus the text as the recipient will see it. */
	record View(AutoMessage autoMessage, String preview) {
	}

	View get(UUID userId, UUID recipientId) {
		Recipient recipient = recipient(userId, recipientId);
		return view(autoMessages.find(userId, recipientId).orElseGet(() -> AutoMessage.none(userId, recipientId)),
				recipient);
	}

	@Transactional
	View save(UUID userId, UUID recipientId, Settings settings) {
		Recipient recipient = recipients.findForUpdate(userId, recipientId)
			.orElseThrow(() -> ApiException.notFound("Recipient"));
		String text = settings.text() == null || settings.text().isBlank() ? null : settings.text().strip();
		if (text != null) {
			validateText(text);
		}
		LocalTime sendTime = settings.sendTime() == null ? null : settings.sendTime().truncatedTo(ChronoUnit.MINUTES);
		int days = settings.days() == null || settings.days().isEmpty() ? AutoMessage.ALL_DAYS
				: AutoMessage.mask(settings.days());
		ZoneId zone = zone(settings.timeZone());
		int smsAfter = settings.smsAfterMinutes() != null ? settings.smsAfterMinutes()
				: AutoMessage.DEFAULT_SMS_AFTER_MINUTES;

		Instant now = clock.instant();
		Instant nextRunAt = !settings.enabled() ? null
				: sendTime == null ? now.plus(ONE_OFF_DELAY) : AutoMessage.nextRun(sendTime, days, zone, now);
		AutoMessage saved = autoMessages.save(new AutoMessage(recipientId, userId, settings.enabled(), text, sendTime,
				days, zone, smsAfter, nextRunAt, null, null, null));
		return view(saved, recipient);
	}

	private View view(AutoMessage autoMessage, Recipient recipient) {
		return new View(autoMessage, autoMessage.render(recipient.displayName(), senderName(recipient.userId())));
	}

	private String senderName(UUID userId) {
		return accounts.findDisplayName(userId).filter(name -> !name.isBlank()).orElse("Someone");
	}

	private Recipient recipient(UUID userId, UUID recipientId) {
		return recipients.find(userId, recipientId).orElseThrow(() -> ApiException.notFound("Recipient"));
	}

	private static void validateText(String text) {
		if (text.length() > MAX_TEXT_LENGTH) {
			throw invalid("INVALID_TEXT", "Write a message of up to " + MAX_TEXT_LENGTH + " characters.");
		}
		Matcher matcher = PLACEHOLDER.matcher(text);
		while (matcher.find()) {
			String key = matcher.group(1);
			if (!key.equals("name") && !key.equals("sender")) {
				throw invalid("INVALID_TEXT", "Unknown placeholder {" + key + "}. Use {name} or {sender}.");
			}
		}
	}

	private static ZoneId zone(String id) {
		if (id == null || id.isBlank()) {
			return AutoMessage.DEFAULT_ZONE;
		}
		try {
			return ZoneId.of(id);
		}
		catch (DateTimeException ex) {
			throw invalid("INVALID_TIME_ZONE", "Unknown time zone " + id + ".");
		}
	}

	private static ApiException invalid(String code, String message) {
		return new ApiException(HttpStatus.UNPROCESSABLE_CONTENT, code, message);
	}

}
