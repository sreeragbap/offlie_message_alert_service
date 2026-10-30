package com.oma.config;

import java.time.Duration;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "oma")
public record OmaProperties(@Valid @NotNull Supabase supabase, @Valid @NotNull Sms sms, @Valid @NotNull Alerts alerts,
		@Valid @NotNull Whatsapp whatsapp) {

	public record Supabase(@NotBlank String url, String serviceRoleKey) {

		public String issuer() {
			return stripTrailingSlash(url) + "/auth/v1";
		}

		public String jwksUri() {
			return issuer() + "/.well-known/jwks.json";
		}

		public boolean hasServiceRoleKey() {
			return serviceRoleKey != null && !serviceRoleKey.isBlank();
		}

		private static String stripTrailingSlash(String value) {
			return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
		}

	}

	/** Server-side SMS is off by default: in the MVP alerts are sent from the user's own phone. */
	public record Sms(boolean serverChannelEnabled) {
	}

	public record Alerts(@NotNull Duration deviceDueExpiry, @Min(1) int serverMaxAttempts,
			@NotNull Duration serverRetryBaseDelay, @NotNull Duration sendLease, @NotNull Duration retention) {
	}

	/**
	 * WhatsApp Business Platform (Cloud API). Off until a phone number id, access token and app secret
	 * are configured.
	 *
	 * @param templateParams values for the template's body variables {{1}}, {{2}}, ... in order; each
	 * is {@code sender} (the user's display name), {@code name} (the recipient's name) or {@code text}
	 * (the message typed in the app)
	 */
	public record Whatsapp(@NotBlank String graphUrl, @NotBlank String apiVersion, String phoneNumberId,
			String accessToken, String appSecret, String verifyToken, @NotBlank String templateName,
			@NotBlank String templateLanguage, List<String> templateParams, @NotNull Duration requestTimeout) {

		public boolean configured() {
			return notBlank(phoneNumberId) && notBlank(accessToken) && notBlank(appSecret);
		}

		public List<String> templateParamsOrEmpty() {
			return templateParams == null ? List.of() : templateParams;
		}

		private static boolean notBlank(String value) {
			return value != null && !value.isBlank();
		}

	}

}
