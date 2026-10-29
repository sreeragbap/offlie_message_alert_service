package com.oma.preference;

import org.junit.jupiter.api.Test;

import com.oma.common.ApiException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThatNoException;

class AlertPreferenceTest {

	@Test
	void rendersNameAndPlatform() {
		assertThat(AlertPreference.DEFAULTS.render("Anu", "WhatsApp"))
			.isEqualTo("Hi Anu, I've sent you a message on WhatsApp. Please check it when you can.");
	}

	@Test
	void acceptsKnownPlaceholders() {
		assertThatNoException().isThrownBy(() -> AlertPreference.validateTemplate("Hey {name}, check {platform}"));
	}

	@Test
	void rejectsUnknownPlaceholders() {
		assertThatThrownBy(() -> AlertPreference.validateTemplate("Hi {name}, {message}"))
			.isInstanceOf(ApiException.class)
			.hasMessageContaining("{message}");
	}

}
