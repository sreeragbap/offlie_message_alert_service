package com.oma.sms;

/**
 * @param toE164 recipient in E.164 format
 * @param text message body
 * @param clientReference our alert id, passed to providers that support a client reference
 */
public record SmsMessage(String toE164, String text, String clientReference) {
}
