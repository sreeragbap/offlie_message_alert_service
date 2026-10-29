package com.oma.sms;

public record SmsSendResult(Outcome outcome, String providerMessageId, String errorCode) {

	public enum Outcome {

		/** The provider accepted the request. Says nothing about delivery to the phone. */
		ACCEPTED,
		/** Definitely not accepted, and safe to try again (e.g. connection refused, 429). */
		RETRYABLE_FAILURE,
		/** Definitely not accepted, and retrying will not help (e.g. invalid number). */
		PERMANENT_FAILURE,
		/** It is unknown whether the provider accepted the request. */
		UNKNOWN

	}

	public static SmsSendResult accepted(String providerMessageId) {
		return new SmsSendResult(Outcome.ACCEPTED, providerMessageId, null);
	}

	public static SmsSendResult retryable(String errorCode) {
		return new SmsSendResult(Outcome.RETRYABLE_FAILURE, null, errorCode);
	}

	public static SmsSendResult permanent(String errorCode) {
		return new SmsSendResult(Outcome.PERMANENT_FAILURE, null, errorCode);
	}

	public static SmsSendResult unknown(String errorCode) {
		return new SmsSendResult(Outcome.UNKNOWN, null, errorCode);
	}

}
