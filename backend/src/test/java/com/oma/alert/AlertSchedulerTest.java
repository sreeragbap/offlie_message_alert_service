package com.oma.alert;

import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;

import com.oma.sms.SmsSendResult;
import com.oma.support.Api;
import com.oma.support.IntegrationTest;

import static org.assertj.core.api.Assertions.assertThat;

/** Server-side processing. Uses the server SMS channel (enabled here) with a fake gateway. */
@TestPropertySource(properties = "oma.sms.server-channel-enabled=true")
class AlertSchedulerTest extends IntegrationTest {

	@Autowired
	private AlertScheduler scheduler;

	private final UUID alice = UUID.randomUUID();

	private UUID anu;

	@BeforeEach
	void setUp() throws Exception {
		anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
	}

	@Test
	void deviceAlertBecomesDueAfterDelayThenExpires() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 10, "DEVICE_SMS");

		clock.advance(Duration.ofMinutes(9));
		scheduler.runOnce();
		assertThat(state(id)).isEqualTo("SCHEDULED");

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();
		assertThat(state(id)).isEqualTo("DUE");

		clock.advance(Duration.ofHours(24));
		scheduler.runOnce();
		assertThat(state(id)).isEqualTo("EXPIRED");
		assertThat(sms.sent).isEmpty();
	}

	/** Brief test 5: provider acceptance is recorded, not reported as delivery. */
	@Test
	void serverAlertIsSentOnceWhenDueAndMarkedAcceptedNotDelivered() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 5, "SERVER_SMS");

		scheduler.runOnce();
		assertThat(sms.sent).isEmpty();

		clock.advance(Duration.ofMinutes(5));
		scheduler.runOnce();
		scheduler.runOnce();

		assertThat(sms.sent).hasSize(1);
		assertThat(sms.sent.get(0).toE164()).isEqualTo("+919876543210");
		assertThat(sms.sent.get(0).clientReference()).isEqualTo(id.toString());
		assertThat(state(id)).isEqualTo("SMS_ACCEPTED");
		assertThat(jdbc.sql("select provider_message_id from app.alert where id = :id").param("id", id)
			.query(String.class).single()).isEqualTo("fake-1");
	}

	/** Brief test 4: transient provider failures are retried with backoff, then given up. */
	@Test
	void retriesTransientFailuresWithBackoffThenGivesUp() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "SERVER_SMS");
		sms.thenReturn(() -> SmsSendResult.retryable("HTTP_503"));
		sms.thenReturn(() -> SmsSendResult.retryable("HTTP_503"));
		sms.thenReturn(() -> SmsSendResult.retryable("HTTP_503"));

		scheduler.runOnce(); // attempt 1 -> retry in 1 min
		assertThat(state(id)).isEqualTo("SCHEDULED");
		scheduler.runOnce();
		assertThat(sms.sent).hasSize(1); // not due yet

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce(); // attempt 2 -> retry in 2 min
		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();
		assertThat(sms.sent).hasSize(2);

		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce(); // attempt 3 = max -> failed
		assertThat(sms.sent).hasSize(3);
		assertThat(state(id)).isEqualTo("SMS_FAILED");
	}

	@Test
	void retrySucceedsAfterTransientFailure() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "SERVER_SMS");
		sms.thenReturn(() -> SmsSendResult.retryable("TIMEOUT_BEFORE_SEND"));

		scheduler.runOnce();
		clock.advance(Duration.ofMinutes(1));
		scheduler.runOnce();

		assertThat(sms.sent).hasSize(2);
		assertThat(state(id)).isEqualTo("SMS_ACCEPTED");
	}

	@Test
	void permanentFailureIsNotRetried() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "SERVER_SMS");
		sms.thenReturn(() -> SmsSendResult.permanent("INVALID_NUMBER"));

		scheduler.runOnce();
		clock.advance(Duration.ofHours(1));
		scheduler.runOnce();

		assertThat(sms.sent).hasSize(1);
		assertThat(state(id)).isEqualTo("SMS_FAILED");
	}

	@Test
	void unknownOutcomeIsNeverRetriedToAvoidDuplicates() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "SERVER_SMS");
		sms.thenReturn(() -> {
			throw new IllegalStateException("read timeout");
		});

		scheduler.runOnce();
		clock.advance(Duration.ofHours(1));
		scheduler.runOnce();

		assertThat(sms.sent).hasSize(1);
		assertThat(state(id)).isEqualTo("SMS_UNKNOWN");
	}

	/** Brief test 11: a send interrupted by a crash/restart is not lost silently and not duplicated. */
	@Test
	void interruptedSendIsMarkedUnknownAfterLease() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 0, "SERVER_SMS");
		// Simulate a worker that claimed the alert and then died before recording the result.
		jdbc.sql("update app.alert set state = 'SENDING', attempts = 1, locked_until = :until where id = :id")
			.param("until", java.sql.Timestamp.from(clock.instant().plus(Duration.ofMinutes(2))))
			.param("id", id)
			.update();

		scheduler.runOnce();
		assertThat(state(id)).isEqualTo("SENDING");

		clock.advance(Duration.ofMinutes(3));
		scheduler.runOnce();
		assertThat(state(id)).isEqualTo("SMS_UNKNOWN");
		assertThat(sms.sent).isEmpty();
	}

	@Test
	void skipsWhenRecipientOptedOutAfterScheduling() throws Exception {
		UUID id = Api.createAlert(mvc, alice, anu, 5, "SERVER_SMS");
		jdbc.sql("update app.recipient set opted_out = true where id = :id").param("id", anu).update();

		clock.advance(Duration.ofMinutes(5));
		scheduler.runOnce();

		assertThat(state(id)).isEqualTo("SKIPPED");
		assertThat(sms.sent).isEmpty();
	}

	@Test
	void concurrentWorkersSendEachAlertOnce() throws Exception {
		for (int i = 0; i < 3; i++) {
			Api.createAlert(mvc, alice, anu, 0, "SERVER_SMS");
		}
		ExecutorService pool = Executors.newFixedThreadPool(4);
		CountDownLatch start = new CountDownLatch(1);
		for (int i = 0; i < 4; i++) {
			pool.submit(() -> {
				start.await();
				scheduler.runOnce();
				return null;
			});
		}
		start.countDown();
		pool.shutdown();
		assertThat(pool.awaitTermination(30, TimeUnit.SECONDS)).isTrue();

		assertThat(sms.sent).hasSize(3);
		assertThat(sms.sent.stream().map(m -> m.clientReference()).distinct()).hasSize(3);
	}

	private String state(UUID id) {
		return jdbc.sql("select state from app.alert where id = :id").param("id", id).query(String.class).single();
	}

}
