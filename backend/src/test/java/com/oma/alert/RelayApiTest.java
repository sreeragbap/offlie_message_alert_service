package com.oma.alert;

import java.time.Duration;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import com.oma.support.Api;
import com.oma.support.IntegrationTest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The relay phone's work queue: claim due SMS, report the outcome, never send twice. */
class RelayApiTest extends IntegrationTest {

	@Autowired
	private AlertScheduler scheduler;

	private final UUID alice = UUID.randomUUID();

	private UUID anu;

	@BeforeEach
	void setUp() throws Exception {
		anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
	}

	@Test
	void dueAlertIsHandedOutOnceAndRecordedAsSent() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 5, "RELAY_SMS");

		claim(alice).andExpect(jsonPath("$").isEmpty());
		clock.advance(Duration.ofMinutes(5));
		scheduler.runOnce();

		claim(alice).andExpect(jsonPath("$.length()").value(1))
			.andExpect(jsonPath("$[0].alertId").value(id.toString()))
			.andExpect(jsonPath("$[0].toE164").value("+919876543210"))
			.andExpect(jsonPath("$[0].text").value(org.hamcrest.Matchers.startsWith("Hi Anu")));
		claim(alice).andExpect(jsonPath("$").isEmpty());

		report(alice, id, "SENT").andExpect(status().isOk()).andExpect(jsonPath("$.state").value("SMS_ACCEPTED"));
		report(alice, id, "DELIVERED").andExpect(jsonPath("$.state").value("SMS_DELIVERED"))
			.andExpect(jsonPath("$.deliveryConfirmed").value(true));
	}

	@Test
	void otherUsersCannotClaimOrReport() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "RELAY_SMS");
		scheduler.runOnce();
		UUID mallory = UUID.randomUUID();

		claim(mallory).andExpect(jsonPath("$").isEmpty());
		claim(alice).andExpect(jsonPath("$.length()").value(1));
		report(mallory, id, "SENT").andExpect(status().isNotFound());
	}

	@Test
	void unreportedClaimBecomesUnknownAndIsNotSentAgain() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "RELAY_SMS");
		scheduler.runOnce();
		claim(alice).andExpect(jsonPath("$.length()").value(1));

		clock.advance(Duration.ofMinutes(3));
		scheduler.runOnce();

		assertThat(state(id)).isEqualTo("SMS_UNKNOWN");
		claim(alice).andExpect(jsonPath("$").isEmpty());
		// A late report does not overwrite what was recorded.
		report(alice, id, "SENT").andExpect(jsonPath("$.state").value("SMS_UNKNOWN"));
	}

	@Test
	void noSignalIsRetriedWithBackoffThenGivenUp() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "RELAY_SMS");
		for (int attempt = 1; attempt <= 3; attempt++) {
			clock.advance(Duration.ofMinutes(5));
			scheduler.runOnce();
			claim(alice).andExpect(jsonPath("$.length()").value(1));
			report(alice, id, "RETRYABLE_FAILURE");
		}
		assertThat(state(id)).isEqualTo("SMS_FAILED");
	}

	@Test
	void recipientWhoOptedOutAfterSchedulingIsSkipped() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "RELAY_SMS");
		scheduler.runOnce();
		jdbc.sql("update app.recipient set opted_out = true").update();

		claim(alice).andExpect(jsonPath("$").isEmpty());
		assertThat(state(id)).isEqualTo("SKIPPED");
	}

	@Test
	void alertExpiresIfTheRelayPhoneStaysOffline() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "RELAY_SMS");
		scheduler.runOnce();
		clock.advance(Duration.ofHours(25));
		scheduler.runOnce();

		assertThat(state(id)).isEqualTo("EXPIRED");
	}

	@Test
	void claimingMarksTheRelayPhoneOnline() throws Exception {
		mvc.perform(get("/api/v1/dashboard").with(as(alice))).andExpect(jsonPath("$.relayOnline").value(false));
		claim(alice);
		mvc.perform(get("/api/v1/dashboard").with(as(alice))).andExpect(jsonPath("$.relayOnline").value(true));
		clock.advance(Duration.ofMinutes(3));
		mvc.perform(get("/api/v1/dashboard").with(as(alice))).andExpect(jsonPath("$.relayOnline").value(false));
	}

	@Test
	void reportBeforeClaimIsRejected() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 30, "RELAY_SMS");
		report(alice, id, "SENT").andExpect(status().isConflict());
	}

	private ResultActions claim(UUID user) throws Exception {
		return mvc.perform(post("/api/v1/relay/claim").with(as(user))).andExpect(status().isOk());
	}

	private ResultActions report(UUID user, UUID id, String outcome) throws Exception {
		return mvc.perform(post("/api/v1/relay/alerts/" + id + "/result").with(as(user))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"outcome\":\"" + outcome + "\"}"));
	}

	private String state(UUID id) {
		return jdbc.sql("select state from app.alert where id = :id").param("id", id).query(String.class).single();
	}

}
