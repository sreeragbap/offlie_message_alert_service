package com.oma.platform;

import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.oma.support.Api;
import com.oma.support.IntegrationTest;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlatformAndDashboardApiTest extends IntegrationTest {

	private final UUID alice = UUID.randomUUID();

	/** Brief test 10: platforms without delivery events are reported as such, never as connected. */
	@Test
	void platformsReportRealCapabilities() throws Exception {
		mvc.perform(get("/api/v1/platforms").with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$[?(@.id == 'WHATSAPP')].automaticDetection").value("BUSINESS_ACCOUNTS_ONLY"))
			.andExpect(jsonPath("$[?(@.id == 'TELEGRAM')].automaticDetection").value("NOT_AVAILABLE"))
			.andExpect(jsonPath("$[?(@.automaticDetectionConnected == true)]").isEmpty());
	}

	@Test
	void dashboardShowsSetupStateAndLimitations() throws Exception {
		mvc.perform(get("/api/v1/dashboard").with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.serviceActive").value(false))
			.andExpect(jsonPath("$.automaticMonitoringConnected").value(false))
			.andExpect(jsonPath("$.setupIssues[0]").value("Add a recipient to start sending alerts."));

		UUID anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
		Api.createAlert(mvc, alice, anu, 30, null);

		mvc.perform(get("/api/v1/dashboard").with(as(alice)))
			.andExpect(jsonPath("$.serviceActive").value(true))
			.andExpect(jsonPath("$.recipientCount").value(1))
			.andExpect(jsonPath("$.openAlertCount").value(1))
			.andExpect(jsonPath("$.recentAlerts[0].recipient.displayName").value("Anu"));
	}

	@Test
	void deletingAccountRemovesAllData() throws Exception {
		UUID anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
		Api.createAlert(mvc, alice, anu, 30, null);

		mvc.perform(delete("/api/v1/me").with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.appDataDeleted").value(true))
			.andExpect(jsonPath("$.authAccountDeleted").value(false)); // no service-role key in tests

		org.assertj.core.api.Assertions
			.assertThat(jdbc.sql("select count(*) from app.alert").query(Long.class).single())
			.isZero();
	}

	@Test
	void healthIsPublicButEverythingElseIsNot() throws Exception {
		mvc.perform(get("/actuator/health")).andExpect(status().isOk());
		mvc.perform(get("/api/v1/dashboard")).andExpect(status().isUnauthorized());
		mvc.perform(get("/actuator/env")).andExpect(status().isUnauthorized());
	}

}
