package com.oma.preference;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.http.HttpStatus;

import com.oma.common.ApiException;

/**
 * Per-user alert settings. The message template supports {@code {name}} (recipient's name as
 * saved by the user) and {@code {platform}} (e.g. "WhatsApp"). It never includes message content.
 */
public record AlertPreference(int defaultDelayMinutes, int maxAlertsPerRecipientPerDay, int maxAlertsPerDay,
		String messageTemplate) {

	public static final String DEFAULT_TEMPLATE = "Hi {name}, I've sent you a message on {platform}. Please check it when you can.";

	public static final AlertPreference DEFAULTS = new AlertPreference(30, 3, 20, DEFAULT_TEMPLATE);

	private static final Pattern PLACEHOLDER = Pattern.compile("\\{([a-zA-Z]+)}");

	public String render(String recipientName, String platformName) {
		return messageTemplate.replace("{name}", recipientName).replace("{platform}", platformName);
	}

	static void validateTemplate(String template) {
		Matcher matcher = PLACEHOLDER.matcher(template);
		while (matcher.find()) {
			String key = matcher.group(1);
			if (!key.equals("name") && !key.equals("platform")) {
				throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_TEMPLATE",
						"Unknown placeholder {" + key + "}. Use {name} or {platform}.");
			}
		}
	}

}
