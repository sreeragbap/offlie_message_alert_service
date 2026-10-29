package com.oma.recipient;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import com.oma.common.ApiException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PhoneNumbersTest {

	@ParameterizedTest
	@ValueSource(strings = { "9876543210", "98765 43210", "+91 98765-43210", "09876543210", "+919876543210" })
	void normalisesIndianMobileFormatsToE164(String input) {
		assertThat(PhoneNumbers.toE164(input)).isEqualTo("+919876543210");
	}

	@Test
	void keepsExplicitForeignCountryCode() {
		assertThat(PhoneNumbers.toE164("+44 7400 123456")).isEqualTo("+447400123456");
	}

	@ParameterizedTest
	@ValueSource(strings = { "", "12345", "abcdefghij", "+91 98765" })
	void rejectsInvalidNumbers(String input) {
		assertThatThrownBy(() -> PhoneNumbers.toE164(input)).isInstanceOf(ApiException.class)
			.extracting("code")
			.isEqualTo("INVALID_PHONE");
	}

	@Test
	void rejectsLandlinesBecauseTheyCannotReceiveSms() {
		assertThatThrownBy(() -> PhoneNumbers.toE164("+91 11 2345 6789")).isInstanceOf(ApiException.class)
			.extracting("code")
			.isEqualTo("PHONE_NOT_MOBILE");
	}

}
