package com.oma.recipient;

import com.google.i18n.phonenumbers.NumberParseException;
import com.google.i18n.phonenumbers.PhoneNumberUtil;
import com.google.i18n.phonenumbers.PhoneNumberUtil.PhoneNumberFormat;
import com.google.i18n.phonenumbers.PhoneNumberUtil.PhoneNumberType;
import com.google.i18n.phonenumbers.Phonenumber.PhoneNumber;

import org.springframework.http.HttpStatus;

import com.oma.common.ApiException;

/** Parses user-entered numbers into E.164. Numbers without a country code are treated as Indian. */
public final class PhoneNumbers {

	static final String DEFAULT_REGION = "IN";

	private static final PhoneNumberUtil UTIL = PhoneNumberUtil.getInstance();

	private PhoneNumbers() {
	}

	public static String toE164(String raw) {
		if (raw == null || raw.isBlank()) {
			throw invalid();
		}
		PhoneNumber number;
		try {
			number = UTIL.parse(raw.strip(), DEFAULT_REGION);
		}
		catch (NumberParseException ex) {
			throw invalid();
		}
		if (!UTIL.isValidNumber(number)) {
			throw invalid();
		}
		PhoneNumberType type = UTIL.getNumberType(number);
		if (type != PhoneNumberType.MOBILE && type != PhoneNumberType.FIXED_LINE_OR_MOBILE) {
			throw new ApiException(HttpStatus.BAD_REQUEST, "PHONE_NOT_MOBILE",
					"This number cannot receive SMS. Please enter a mobile number.");
		}
		return UTIL.format(number, PhoneNumberFormat.E164);
	}

	private static ApiException invalid() {
		return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PHONE", "Please enter a valid mobile number");
	}

}
