package com.oma.sms;

/**
 * Provider-independent SMS sending. Implementations must map outcomes conservatively: if the request
 * may have reached the provider (e.g. a timeout after sending), return {@link SmsSendResult.Outcome#UNKNOWN},
 * never a retryable failure, so the caller does not send a duplicate.
 */
public interface SmsGateway {

	String providerName();

	SmsSendResult send(SmsMessage message);

}
