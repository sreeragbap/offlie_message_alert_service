package com.oma.automessage;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Automatic WhatsApp messages: set up once per recipient, sent by the backend, SMS alert when undelivered. */
class AutoMessageTest extends IntegrationTest {

	/** Monday 9 November 2026, 08:30 in India. */
	private static final Instant MONDAY_0830_IST = Instant.parse("2026-11-09T03:00:00Z");

	@Autowired
	private AutoMessageScheduler scheduler;

	private final UUID alice = UUID.randomUUID();

	private UUID anu;

	@BeforeEach
	void setUp() throws Exception {
		anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
	}

	@Test
	void recipientWithoutOneIsOff() throws Exception {
		mvc.perform(get(url(anu)).with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.enabled").value(false))
			.andExpect(jsonPath("$.preview").value("Hi Anu, this is an automatic message from Someone."))
			.andExpect(jsonPath("$.smsAfterMinutes").value(1));
	}

	@Test
	void withoutAScheduleItGoesOnceAMinuteAfterSavingWithAnSmsAlertAfterOneMinute() throws Exception {
		save(anu, "{\"enabled\":true}").andExpect(status().isOk())
			.andExpect(jsonPath("$.nextRunAt").value(clock.instant().plus(Duration.ofMinutes(1)).toString()));

		scheduler.runOnce();
		assertThat(whatsApp.sent).isEmpty();

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();
		assertThat(whatsApp.sent).hasSize(1);
		assertThat(whatsApp.sent.get(0).toE164()).isEqualTo("+919876543210");
		assertThat(whatsApp.sent.get(0).templateParams())
			.containsExactly("Someone", "Hi Anu, this is an automatic message from Someone.");
		assertThat(jdbc.sql("select due_at from app.alert").query(java.sql.Timestamp.class).single().toInstant())
			.isEqualTo(clock.instant().plus(Duration.ofMinutes(1)));

		clock.advance(Duration.ofHours(1));
		scheduler.runOnce();
		assertThat(whatsApp.sent).hasSize(1);
		mvc.perform(get(url(anu)).with(as(alice)))
			.andExpect(jsonPath("$.nextRunAt").isEmpty())
			.andExpect(jsonPath("$.lastMessageId").isNotEmpty())
			.andExpect(jsonPath("$.lastError").isEmpty());
	}

	@Test
	void repeatsAtTheTimeOnTheChosenDays() throws Exception {
		clock.set(MONDAY_0830_IST);
		save(anu, "{\"enabled\":true,\"sendTime\":\"09:00\",\"days\":[\"MONDAY\",\"WEDNESDAY\"],\"smsAfterMinutes\":5}")
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.sendTime").value("09:00"))
			.andExpect(jsonPath("$.days[0]").value("MONDAY"))
			.andExpect(jsonPath("$.timeZone").value("Asia/Kolkata"))
			.andExpect(jsonPath("$.nextRunAt").value("2026-11-09T03:30:00Z"));

		clock.advance(Duration.ofMinutes(30));
		scheduler.runOnce();
		assertThat(whatsApp.sent).hasSize(1);
		mvc.perform(get(url(anu)).with(as(alice))).andExpect(jsonPath("$.nextRunAt").value("2026-11-11T03:30:00Z"));

		clock.set(Instant.parse("2026-11-11T03:30:00Z"));
		scheduler.runOnce();
		assertThat(whatsApp.sent).hasSize(2);
	}

	@Test
	void customTextUsesPlaceholders() throws Exception {
		save(anu, "{\"enabled\":true,\"text\":\"Good morning {name}! {sender} here.\"}").andExpect(status().isOk())
			.andExpect(jsonPath("$.preview").value("Good morning Anu! Someone here."));
		save(anu, "{\"enabled\":true,\"text\":\"Hi {phone}\"}").andExpect(status().isUnprocessableContent())
			.andExpect(jsonPath("$.code").value("INVALID_TEXT"));

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();
		assertThat(whatsApp.sent.get(0).templateParams()).containsExactly("Someone", "Good morning Anu! Someone here.");
	}

	@Test
	void turnedOffItNeverSends() throws Exception {
		save(anu, "{\"enabled\":true}").andExpect(status().isOk());
		save(anu, "{\"enabled\":false}").andExpect(status().isOk()).andExpect(jsonPath("$.nextRunAt").isEmpty());

		clock.advance(Duration.ofMinutes(5));
		scheduler.runOnce();
		assertThat(whatsApp.sent).isEmpty();
	}

	@Test
	void aRepeatingRunMissedWhileTheServerWasOffIsSkippedNotSentLate() throws Exception {
		clock.set(MONDAY_0830_IST);
		save(anu, "{\"enabled\":true,\"sendTime\":\"09:00\"}").andExpect(status().isOk());

		clock.advance(Duration.ofHours(3));
		scheduler.runOnce();
		assertThat(whatsApp.sent).isEmpty();
		mvc.perform(get(url(anu)).with(as(alice)))
			.andExpect(jsonPath("$.lastError").value("Skipped a run: the server was offline at the scheduled time."))
			.andExpect(jsonPath("$.nextRunAt").value("2026-11-10T03:30:00Z"));
	}

	@Test
	void notSentToSomeoneWhoOptedOut() throws Exception {
		save(anu, "{\"enabled\":true}").andExpect(status().isOk());
		mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch("/api/v1/recipients/" + anu)
			.with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"optedOut\":true}")).andExpect(status().isOk());

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();
		assertThat(whatsApp.sent).isEmpty();
	}

	@Test
	void anotherUserCannotSeeOrChangeIt() throws Exception {
		UUID bob = UUID.randomUUID();
		mvc.perform(get(url(anu)).with(as(bob))).andExpect(status().isNotFound());
		mvc.perform(put(url(anu)).with(as(bob)).contentType(MediaType.APPLICATION_JSON).content("{\"enabled\":true}"))
			.andExpect(status().isNotFound());
	}

	@Test
	void nextRunSkipsDaysThatAreNotSelected() {
		ZoneId india = AutoMessage.DEFAULT_ZONE;
		int fridayOnly = 1 << 4;
		assertThat(AutoMessage.nextRun(LocalTime.of(9, 0), fridayOnly, india, MONDAY_0830_IST))
			.isEqualTo(Instant.parse("2026-11-13T03:30:00Z"));
		// Already past 09:00 on the only selected day: a week later.
		int mondayOnly = 1;
		assertThat(AutoMessage.nextRun(LocalTime.of(8, 0), mondayOnly, india, MONDAY_0830_IST))
			.isEqualTo(Instant.parse("2026-11-16T02:30:00Z"));
	}

	private ResultActions save(UUID recipientId, String json) throws Exception {
		return mvc.perform(put(url(recipientId)).with(as(alice)).contentType(MediaType.APPLICATION_JSON).content(json));
	}

	private static String url(UUID recipientId) {
		return "/api/v1/recipients/" + recipientId + "/auto-message";
	}

}
