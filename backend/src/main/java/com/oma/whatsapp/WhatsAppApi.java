package com.oma.whatsapp;

import java.util.List;

/** Sends messages through the WhatsApp Business Platform (Cloud API). */
public interface WhatsAppApi {

	SendResult send(OutgoingMessage message);

	enum Kind {

		/** Free-form text; allowed only within 24 hours of the recipient's last message to us. */
		TEXT,
		/** An approved message template; required to start a conversation. */
		TEMPLATE

	}

	/**
	 * @param toE164 recipient in E.164 format
	 * @param text body for {@link Kind#TEXT}
	 * @param templateParams values for the template's body variables, in order
	 */
	record OutgoingMessage(String toE164, Kind kind, String text, String templateName, String templateLanguage,
			List<String> templateParams) {
	}

	enum Outcome {

		/** WhatsApp accepted the message and returned its id. Not yet delivered. */
		ACCEPTED,
		/** WhatsApp refused the request; nothing was sent. */
		REJECTED,
		/** No answer (timeout, server error): the message may or may not have been sent. */
		UNKNOWN

	}

	record SendResult(Outcome outcome, String wamid, String errorCode, String errorMessage) {

		static SendResult accepted(String wamid) {
			return new SendResult(Outcome.ACCEPTED, wamid, null, null);
		}

		static SendResult rejected(String code, String message) {
			return new SendResult(Outcome.REJECTED, null, code, message);
		}

		static SendResult unknown(String code) {
			return new SendResult(Outcome.UNKNOWN, null, code, null);
		}

	}

}
