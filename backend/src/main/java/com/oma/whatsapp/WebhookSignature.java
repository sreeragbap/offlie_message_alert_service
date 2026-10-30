package com.oma.whatsapp;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.HexFormat;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/** Meta signs each webhook body with the app secret: {@code X-Hub-Signature-256: sha256=<hex HMAC>}. */
final class WebhookSignature {

	private static final String PREFIX = "sha256=";

	private WebhookSignature() {
	}

	static boolean valid(String appSecret, byte[] body, String header) {
		if (appSecret == null || appSecret.isBlank() || header == null || !header.startsWith(PREFIX)) {
			return false;
		}
		byte[] expected = hmac(appSecret, body);
		byte[] given;
		try {
			given = HexFormat.of().parseHex(header.substring(PREFIX.length()));
		}
		catch (IllegalArgumentException ex) {
			return false;
		}
		return MessageDigest.isEqual(expected, given);
	}

	static String sign(String appSecret, byte[] body) {
		return PREFIX + HexFormat.of().formatHex(hmac(appSecret, body));
	}

	private static byte[] hmac(String secret, byte[] body) {
		try {
			Mac mac = Mac.getInstance("HmacSHA256");
			mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
			return mac.doFinal(body);
		}
		catch (GeneralSecurityException ex) {
			throw new IllegalStateException(ex);
		}
	}

}
