package com.oma.alert;

import java.time.Duration;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.http.MediaType;

import com.oma.support.Api;
import com.oma.support.IntegrationTest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AlertApiTest extends IntegrationTest {

	private final UUID alice = UUID.randomUUID();

	private final UUID bob = UUID.randomUUID();

	private UUID anu;

	@BeforeEach
	void setUp() throws Exception {
		anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
	}

	@Test
	void createsScheduledDeviceAlertWithRenderedMessage() throws Exception {
		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 15, null)))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.state").value("SCHEDULED"))
			.andExpect(jsonPath("$.channel").value("DEVICE_SMS"))
			.andExpect(jsonPath("$.triggerSource").value("USER_TRIGGERED"))
			.andExpect(jsonPath("$.recipient.phoneE164").value("+919876543210"))
			.andExpect(jsonPath("$.messageText")
				.value("Hi Anu, I've sent you a message on WhatsApp. Please check it when you can."))
			.andExpect(jsonPath("$.dueAt").value(clock.instant().plus(Duration.ofMinutes(15)).toString()))
			.andExpect(jsonPath("$.deliveryConfirmed").value(false));
	}

	@Test
	void zeroDelayIsImmediatelyDue() throws Exception {
		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 0, null)))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.state").value("DUE"));
	}

	@Test
	void usesDefaultDelayFromPreferences() throws Exception {
		mvc.perform(put("/api/v1/alert-preferences").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("""
					{"defaultDelayMinutes":45,"maxAlertsPerRecipientPerDay":3,"maxAlertsPerDay":20,
					 "messageTemplate":"{name}, please check {platform}"}
					"""))
			.andExpect(status().isOk());

		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, null, null)))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.dueAt").value(clock.instant().plus(Duration.ofMinutes(45)).toString()))
			.andExpect(jsonPath("$.messageText").value("Anu, please check WhatsApp"));
	}

	/** Brief test 3: the same request arriving twice must not create a second alert. */
	@Test
	void repeatedRequestIsIdempotent() throws Exception {
		UUID requestId = UUID.randomUUID();
		String body = Api.alertJson(requestId, anu, 10, null);
		String first = mvc.perform(post("/api/v1/alerts").with(as(alice)).contentType(MediaType.APPLICATION_JSON).content(body))
			.andExpect(status().isCreated())
			.andReturn().getResponse().getContentAsString();
		String second = mvc.perform(post("/api/v1/alerts").with(as(alice)).contentType(MediaType.APPLICATION_JSON).content(body))
			.andExpect(status().isOk())
			.andReturn().getResponse().getContentAsString();

		assertThat(second).isEqualTo(first);
		assertThat(alertCount()).isEqualTo(1);
	}

	/** Brief test 6: a recipient with alerts disabled gets no new alert. */
	@Test
	void refusesAlertWhenRecipientDisabled() throws Exception {
		mvc.perform(patch("/api/v1/recipients/" + anu).with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"alertsEnabled\":false}")).andExpect(status().isOk());

		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 10, null)))
			.andExpect(status().isUnprocessableContent())
			.andExpect(jsonPath("$.code").value("RECIPIENT_ALERTS_DISABLED"));
		assertThat(alertCount()).isZero();
	}

	@Test
	void refusesAlertWhenRecipientOptedOut() throws Exception {
		mvc.perform(patch("/api/v1/recipients/" + anu).with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"optedOut\":true}")).andExpect(status().isOk());

		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 10, null)))
			.andExpect(status().isUnprocessableContent())
			.andExpect(jsonPath("$.code").value("RECIPIENT_OPTED_OUT"));
	}

	@Test
	void disablingRecipientCancelsPendingAlerts() throws Exception {
		UUID alert = Api.createAlert(mvc, alice, anu, 30, null);
		mvc.perform(patch("/api/v1/recipients/" + anu).with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"alertsEnabled\":false}")).andExpect(status().isOk());

		mvc.perform(get("/api/v1/alerts/" + alert).with(as(alice)))
			.andExpect(jsonPath("$.state").value("CANCELLED"))
			.andExpect(jsonPath("$.note").value("Alerts disabled for recipient"));
	}

	@Test
	void enforcesPerRecipientDailyLimit() throws Exception {
		for (int i = 0; i < 3; i++) {
			Api.createAlert(mvc, alice, anu, 0, null);
		}
		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 0, null)))
			.andExpect(status().isTooManyRequests())
			.andExpect(jsonPath("$.code").value("RECIPIENT_RATE_LIMITED"));

		clock.advance(Duration.ofHours(24).plusMinutes(1));
		Api.createAlert(mvc, alice, anu, 0, null);
	}

	@Test
	void cancelledAlertsDoNotCountTowardsLimit() throws Exception {
		for (int i = 0; i < 3; i++) {
			UUID id = Api.createAlert(mvc, alice, anu, 30, null);
			mvc.perform(post("/api/v1/alerts/" + id + "/cancel").with(as(alice))).andExpect(status().isOk());
		}
		Api.createAlert(mvc, alice, anu, 30, null);
	}

	@Test
	void cancelOnlyWorksOnce() throws Exception {
		UUID alert = Api.createAlert(mvc, alice, anu, 30, null);
		mvc.perform(post("/api/v1/alerts/" + alert + "/cancel").with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.state").value("CANCELLED"));
		mvc.perform(post("/api/v1/alerts/" + alert + "/cancel").with(as(alice)))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("INVALID_STATE"));
	}

	@Test
	void recordsSendFromDeviceAndIsIdempotent() throws Exception {
		UUID alert = Api.createAlert(mvc, alice, anu, 30, null);
		mvc.perform(post("/api/v1/alerts/" + alert + "/sent-from-device").with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.state").value("SENT_FROM_DEVICE"))
			.andExpect(jsonPath("$.deliveryConfirmed").value(false));
		mvc.perform(post("/api/v1/alerts/" + alert + "/sent-from-device").with(as(alice)))
			.andExpect(status().isOk());
		mvc.perform(post("/api/v1/alerts/" + alert + "/cancel").with(as(alice))).andExpect(status().isConflict());
	}

	/** Brief test 9: another user's data is not accessible. */
	@Test
	void otherUsersCannotUseOrSeeAlerts() throws Exception {
		UUID alert = Api.createAlert(mvc, alice, anu, 30, null);

		mvc.perform(post("/api/v1/alerts").with(as(bob))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 0, null)))
			.andExpect(status().isNotFound());
		mvc.perform(get("/api/v1/alerts/" + alert).with(as(bob))).andExpect(status().isNotFound());
		mvc.perform(post("/api/v1/alerts/" + alert + "/cancel").with(as(bob))).andExpect(status().isNotFound());
		mvc.perform(post("/api/v1/alerts/" + alert + "/sent-from-device").with(as(bob))).andExpect(status().isNotFound());
		mvc.perform(get("/api/v1/alerts").with(as(bob))).andExpect(jsonPath("$.totalItems").value(0));
	}

	@Test
	void serverChannelIsUnavailableByDefault() throws Exception {
		mvc.perform(post("/api/v1/alerts").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content(Api.alertJson(UUID.randomUUID(), anu, 0, "SERVER_SMS")))
			.andExpect(status().isUnprocessableContent())
			.andExpect(jsonPath("$.code").value("CHANNEL_UNAVAILABLE"));
	}

	@Test
	void listsHistoryNewestFirstWithPaging() throws Exception {
		UUID first = Api.createAlert(mvc, alice, anu, 30, null);
		clock.advance(Duration.ofSeconds(1));
		UUID second = Api.createAlert(mvc, alice, anu, 30, null);
		mvc.perform(post("/api/v1/alerts/" + first + "/cancel").with(as(alice))).andExpect(status().isOk());

		mvc.perform(get("/api/v1/alerts?size=1").with(as(alice)))
			.andExpect(jsonPath("$.totalItems").value(2))
			.andExpect(jsonPath("$.items[0].id").value(second.toString()));
		mvc.perform(get("/api/v1/alerts?openOnly=true").with(as(alice)))
			.andExpect(jsonPath("$.totalItems").value(1));
		mvc.perform(get("/api/v1/alerts?size=500").with(as(alice))).andExpect(status().isBadRequest());
	}

	@Test
	void historyKeepsAlertsOfRemovedRecipients() throws Exception {
		UUID alert = Api.createAlert(mvc, alice, anu, 30, null);
		mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/v1/recipients/" + anu)
			.with(as(alice))).andExpect(status().isNoContent());

		mvc.perform(get("/api/v1/alerts/" + alert).with(as(alice)))
			.andExpect(jsonPath("$.state").value("CANCELLED"))
			.andExpect(jsonPath("$.recipient").doesNotExist());
	}

	private long alertCount() {
		return jdbc.sql("select count(*) from app.alert").query(Long.class).single();
	}

}
