package com.oma.account;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.oma.config.OmaProperties;

/**
 * Deletes users from Supabase Auth using the server-only service-role key. If the key is not
 * configured, auth deletion is reported as not done rather than silently pretending.
 */
@Component
class SupabaseAuthAdminClient {

	private static final Logger log = LoggerFactory.getLogger(SupabaseAuthAdminClient.class);

	private final OmaProperties.Supabase supabase;

	private final RestClient restClient;

	SupabaseAuthAdminClient(OmaProperties properties) {
		this.supabase = properties.supabase();
		this.restClient = RestClient.builder().baseUrl(supabase.issuer()).build();
	}

	boolean deleteUser(UUID userId) {
		if (!supabase.hasServiceRoleKey()) {
			log.warn("SUPABASE_SERVICE_ROLE_KEY not set; auth user {} was not deleted", userId);
			return false;
		}
		try {
			restClient.delete()
				.uri("/admin/users/{id}", userId)
				.header("apikey", supabase.serviceRoleKey())
				.header("Authorization", "Bearer " + supabase.serviceRoleKey())
				.retrieve()
				.toBodilessEntity();
			return true;
		}
		catch (RestClientException ex) {
			log.error("Failed to delete auth user {}: {}", userId, ex.getClass().getSimpleName());
			return false;
		}
	}

}
