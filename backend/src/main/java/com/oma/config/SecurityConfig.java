package com.oma.config;

import java.util.Collection;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Stateless API secured by Supabase Auth access tokens. Tokens are verified against the
 * project's JWKS (asymmetric keys), issuer and the "authenticated" audience.
 */
@Configuration(proxyBeanMethods = false)
class SecurityConfig {

	static final String SUPABASE_AUDIENCE = "authenticated";

	@Bean
	SecurityFilterChain apiSecurity(HttpSecurity http) throws Exception {
		http.csrf(csrf -> csrf.disable())
			.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
			.authorizeHttpRequests(auth -> auth
				.requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
				// Only served when OMA_API_DOCS_ENABLED=true.
				.requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
				.requestMatchers("/api/**").authenticated()
				.anyRequest().denyAll())
			.oauth2ResourceServer(oauth -> oauth.jwt(Customizer.withDefaults()));
		return http.build();
	}

	@Bean
	JwtDecoder jwtDecoder(OmaProperties properties) {
		NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(properties.supabase().jwksUri())
			.jwsAlgorithm(SignatureAlgorithm.ES256)
			.jwsAlgorithm(SignatureAlgorithm.RS256)
			.build();
		decoder.setJwtValidator(tokenValidator(properties.supabase()));
		return decoder;
	}

	/** Expiry/not-before, issuer = this Supabase project, audience = "authenticated". */
	static OAuth2TokenValidator<Jwt> tokenValidator(OmaProperties.Supabase supabase) {
		JwtClaimValidator<Collection<String>> audience = new JwtClaimValidator<>(JwtClaimNames.AUD,
				aud -> aud != null && aud.contains(SUPABASE_AUDIENCE));
		return new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefaultWithIssuer(supabase.issuer()),
				audience);
	}

}
