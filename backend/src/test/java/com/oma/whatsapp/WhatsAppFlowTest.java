package com.oma.whatsapp;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import com.oma.alert.AlertScheduler;
import com.oma.support.Api;
import com.oma.support.IntegrationTest;
import com.oma.whatsapp.WhatsAppApi.Kind;
import com.oma.whatsapp.WhatsAppApi.Outcome;
import com.oma.whatsapp.WhatsAppApi.SendResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Sending through the Cloud API, delivery webhooks, and the SMS alert they control. */
class WhatsAppFlowTest extends IntegrationTest {

	private static final String SECRET = "test-app-secret";

	@Autowired
	private AlertScheduler scheduler;

	private final UUID alice = UUID.randomUUID();

	private UUID anu;

	@BeforeEach
	void setUp() throws Exception {
		anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
	}

	@Test
	void firstMessageUsesTheTemplateAndSchedulesAnSmsAlert() throws Exception {
		send(UUID.randomUUID(), "Call me when free").andExpect(status().isCreated())
			.andExpect(jsonPath("$.status").value("ACCEPTED"))
			.andExpect(jsonPath("$.kind").value("TEMPLATE"))
			.andExpect(jsonPath("$.alert.state").value("SCHEDULED"));

		assertThat(whatsApp.sent).hasSize(1);
		var sent = whatsApp.sent.get(0);
		assertThat(sent.kind()).isEqualTo(Kind.TEMPLATE);
		assertThat(sent.toE164()).isEqualTo("+919876543210");
		assertThat(sent.templateName()).isEqualTo("missed_message");
		assertThat(sent.templateParams()).containsExactly("Someone", "Call me when free");
		assertThat(alertColumn("channel")).isEqualTo("RELAY_SMS");
		assertThat(alertColumn("trigger_source")).isEqualTo("DELIVERY_TIMEOUT");
	}

	@Test
	void retryWithTheSameRequestIdDoesNotSendTwice() throws Exception {
		UUID requestId = UUID.randomUUID();
		send(requestId, "Hello").andExpect(status().isCreated());
		send(requestId, "Hello").andExpect(status().isOk());

		assertThat(whatsApp.sent).hasSize(1);
		assertThat(count("app.wa_message")).isEqualTo(1);
		assertThat(count("app.alert")).isEqualTo(1);
	}

	@Test
	void deliveredInTimeCancelsTheAlert() throws Exception {
		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated());

		webhook(statusEvent("wamid.1", "sent")).andExpect(status().isOk());
		webhook(statusEvent("wamid.1", "delivered")).andExpect(status().isOk());

		assertThat(alertColumn("state")).isEqualTo("CANCELLED");
		assertThat(alertColumn("last_error")).isEqualTo("Delivered on WhatsApp");
		clock.advance(Duration.ofMinutes(20));
		scheduler.runOnce();
		assertThat(alertColumn("state")).isEqualTo("CANCELLED");
	}

	@Test
	void notDeliveredInTimeMakesTheAlertDueForTheRelayPhone() throws Exception {
		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated());
		webhook(statusEvent("wamid.1", "sent")).andExpect(status().isOk());

		clock.advance(Duration.ofMinutes(14));
		scheduler.runOnce();
		assertThat(alertColumn("state")).isEqualTo("SCHEDULED");

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();
		assertThat(alertColumn("state")).isEqualTo("DUE");

		// Delivered before the relay phone picked it up: the SMS is no longer needed.
		webhook(statusEvent("wamid.1", "delivered")).andExpect(status().isOk());
		assertThat(alertColumn("state")).isEqualTo("CANCELLED");
	}

	@Test
	void statusesNeverMoveBackwards() throws Exception {
		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated());
		webhook(statusEvent("wamid.1", "read")).andExpect(status().isOk());
		webhook(statusEvent("wamid.1", "delivered")).andExpect(status().isOk());
		webhook(failed("wamid.1")).andExpect(status().isOk());

		mvc.perform(get("/api/v1/whatsapp/messages").with(as(alice)))
			.andExpect(jsonPath("$[0].status").value("READ"))
			.andExpect(jsonPath("$[0].deliveredAt").isNotEmpty());
	}

	@Test
	void whatsAppFailureSendsTheSmsRightAway() throws Exception {
		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated());
		webhook(failed("wamid.1")).andExpect(status().isOk());

		scheduler.runOnce();
		assertThat(alertColumn("state")).isEqualTo("DUE");
	}

	@Test
	void statusThatArrivesBeforeTheWamidIsStoredStillCounts() throws Exception {
		// Meta can call the webhook before our send request has finished saving the wamid.
		webhook(statusEvent("wamid.1", "delivered")).andExpect(status().isOk());

		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated())
			.andExpect(jsonPath("$.status").value("DELIVERED"))
			.andExpect(jsonPath("$.alert").doesNotExist());
		assertThat(count("app.alert")).isZero();
	}

	@Test
	void replyOpensTheFreeTextWindowAndCancelsPendingAlerts() throws Exception {
		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated());
		clock.advance(Duration.ofMinutes(5));
		webhook(inbound("919876543210", "wamid.in1", "Sorry, was offline")).andExpect(status().isOk());

		assertThat(alertColumn("state")).isEqualTo("CANCELLED");
		mvc.perform(get("/api/v1/whatsapp/messages").with(as(alice)))
			.andExpect(jsonPath("$[0].direction").value("IN"))
			.andExpect(jsonPath("$[0].text").value("Sorry, was offline"));

		send(UUID.randomUUID(), "No problem").andExpect(jsonPath("$.kind").value("TEXT"));
		assertThat(whatsApp.sent.get(1).kind()).isEqualTo(Kind.TEXT);
		assertThat(whatsApp.sent.get(1).text()).isEqualTo("No problem");

		clock.advance(Duration.ofHours(25));
		send(UUID.randomUUID(), "Again").andExpect(jsonPath("$.kind").value("TEMPLATE"));
	}

	@Test
	void replyIsNotShownToUsersWhoNeverMessagedThatNumber() throws Exception {
		UUID bob = UUID.randomUUID();
		Api.createRecipient(mvc, bob, "Anu", "9876543210");
		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated());

		webhook(inbound("919876543210", "wamid.in1", "Hi")).andExpect(status().isOk());

		assertThat(jdbc.sql("select count(*) from app.wa_message where user_id = :bob")
			.param("bob", bob)
			.query(Long.class)
			.single()).isZero();
	}

	@Test
	void rejectedMessageIsReportedAndNoAlertIsScheduled() throws Exception {
		whatsApp.thenReturn(() -> new SendResult(Outcome.REJECTED, null, "131030", "Recipient not in allowed list"));

		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated())
			.andExpect(jsonPath("$.status").value("FAILED"))
			.andExpect(jsonPath("$.error").value(containsString("allowed list")));
		assertThat(count("app.alert")).isZero();
	}

	@Test
	void unknownOutcomeIsNotRetriedAutomatically() throws Exception {
		whatsApp.thenReturn(() -> new SendResult(Outcome.UNKNOWN, null, "NO_RESPONSE", null));
		UUID requestId = UUID.randomUUID();

		send(requestId, "Hello").andExpect(jsonPath("$.status").value("UNKNOWN"));
		send(requestId, "Hello").andExpect(status().isOk());

		assertThat(whatsApp.sent).hasSize(1);
	}

	@Test
	void optedOutRecipientGetsTheWhatsAppButNoSms() throws Exception {
		mvc.perform(patch("/api/v1/recipients/" + anu).with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"optedOut\":true}")).andExpect(status().isOk());

		send(UUID.randomUUID(), "Hello").andExpect(status().isCreated())
			.andExpect(jsonPath("$.alert").doesNotExist())
			.andExpect(jsonPath("$.alertSkipped").value("RECIPIENT_OPTED_OUT"));
	}

	@Test
	void webhookRequiresAValidSignature() throws Exception {
		byte[] body = statusEvent("wamid.1", "delivered").getBytes(StandardCharsets.UTF_8);
		mvc.perform(post("/webhooks/whatsapp").contentType(MediaType.APPLICATION_JSON).content(body))
			.andExpect(status().isUnauthorized());
		mvc.perform(post("/webhooks/whatsapp").contentType(MediaType.APPLICATION_JSON)
			.header("X-Hub-Signature-256", WebhookSignature.sign("wrong-secret", body))
			.content(body)).andExpect(status().isUnauthorized());
		assertThat(count("app.wa_status_event")).isZero();
	}

	@Test
	void webhookVerificationEchoesTheChallengeOnlyForTheRightToken() throws Exception {
		mvc.perform(get("/webhooks/whatsapp").param("hub.mode", "subscribe")
			.param("hub.verify_token", "test-verify-token")
			.param("hub.challenge", "12345")).andExpect(status().isOk()).andExpect(content().string("12345"));
		mvc.perform(get("/webhooks/whatsapp").param("hub.mode", "subscribe")
			.param("hub.verify_token", "nope")
			.param("hub.challenge", "12345")).andExpect(status().isForbidden());
	}

	@Test
	void cannotSeeAnotherUsersMessages() throws Exception {
		String id = JsonPath.read(send(UUID.randomUUID(), "Hello").andReturn().getResponse().getContentAsString(),
				"$.id");
		mvc.perform(get("/api/v1/whatsapp/messages/" + id).with(as(UUID.randomUUID())))
			.andExpect(status().isNotFound());
	}

	private ResultActions send(UUID requestId, String text) throws Exception {
		return mvc.perform(post("/api/v1/whatsapp/messages").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("""
					{"clientRequestId":"%s","recipientId":"%s","text":"%s","alertAfterMinutes":15}
					""".formatted(requestId, anu, text)));
	}

	private ResultActions webhook(String json) throws Exception {
		byte[] body = json.getBytes(StandardCharsets.UTF_8);
		return mvc.perform(post("/webhooks/whatsapp").contentType(MediaType.APPLICATION_JSON)
			.header("X-Hub-Signature-256", WebhookSignature.sign(SECRET, body))
			.content(body));
	}

	private String statusEvent(String wamid, String status) {
		return envelope("""
				"statuses":[{"id":"%s","status":"%s","timestamp":"%d","recipient_id":"919876543210"}]
				""".formatted(wamid, status, clock.instant().getEpochSecond()));
	}

	private String failed(String wamid) {
		return envelope("""
				"statuses":[{"id":"%s","status":"failed","timestamp":"%d","recipient_id":"919876543210",
				  "errors":[{"code":131026,"title":"Message undeliverable"}]}]
				""".formatted(wamid, clock.instant().getEpochSecond()));
	}

	private String inbound(String from, String wamid, String text) {
		return envelope("""
				"contacts":[{"wa_id":"%s","profile":{"name":"Anu"}}],
				"messages":[{"from":"%s","id":"%s","timestamp":"%d","type":"text","text":{"body":"%s"}}]
				""".formatted(from, from, wamid, clock.instant().getEpochSecond(), text));
	}

	private static String envelope(String value) {
		return """
				{"object":"whatsapp_business_account","entry":[{"id":"waba","changes":[{"field":"messages",
				  "value":{"messaging_product":"whatsapp","metadata":{"phone_number_id":"test-phone-id"},%s}}]}]}
				""".formatted(value);
	}

	private String alertColumn(String column) {
		return jdbc.sql("select " + column + " from app.alert").query(String.class).single();
	}

	private long count(String table) {
		return jdbc.sql("select count(*) from " + table).query(Long.class).single();
	}

}
