package com.oma.config;

import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.Test;

import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;

import static org.assertj.core.api.Assertions.assertThat;

class SecurityConfigTest {

	private static final String URL = "https://abc.supabase.co";

	private final OAuth2TokenValidator<Jwt> validator = SecurityConfig
		.tokenValidator(new OmaProperties.Supabase(URL, null));

	@Test
	void acceptsSupabaseAccessToken() {
		assertThat(validator.validate(token(URL + "/auth/v1", List.of("authenticated"), 300)).hasErrors()).isFalse();
	}

	@Test
	void rejectsTokenFromAnotherProject() {
		assertThat(validator.validate(token("https://evil.supabase.co/auth/v1", List.of("authenticated"), 300))
			.hasErrors()).isTrue();
	}

	@Test
	void rejectsWrongAudience() {
		assertThat(validator.validate(token(URL + "/auth/v1", List.of("anon"), 300)).hasErrors()).isTrue();
	}

	@Test
	void rejectsExpiredToken() {
		assertThat(validator.validate(token(URL + "/auth/v1", List.of("authenticated"), -600)).hasErrors()).isTrue();
	}

	private static Jwt token(String issuer, List<String> audience, long expiresInSeconds) {
		Instant now = Instant.now();
		return Jwt.withTokenValue("t")
			.header("alg", "ES256")
			.issuer(issuer)
			.audience(audience)
			.subject("4b1c1a7e-0000-4000-8000-000000000001")
			.issuedAt(now.minusSeconds(Math.abs(expiresInSeconds) + 60))
			.expiresAt(now.plusSeconds(expiresInSeconds))
			.build();
	}

}
