package com.oma.sms;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Development stand-in used until a DLT-registered provider is configured. Logs a masked number and
 * the message length only, never the full number or text.
 */
public class LoggingSmsGateway implements SmsGateway {

	private static final Logger log = LoggerFactory.getLogger(LoggingSmsGateway.class);

	@Override
	public String providerName() {
		return "log";
	}

	@Override
	public SmsSendResult send(SmsMessage message) {
		String id = "log-" + UUID.randomUUID();
		log.info("[dev SMS] to={} chars={} ref={} id={}", mask(message.toE164()), message.text().length(),
				message.clientReference(), id);
		return SmsSendResult.accepted(id);
	}

	static String mask(String e164) {
		if (e164 == null || e164.length() < 6) {
			return "***";
		}
		return e164.substring(0, 3) + "*".repeat(e164.length() - 7) + e164.substring(e164.length() - 4);
	}

}
