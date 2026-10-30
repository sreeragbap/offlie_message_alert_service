package com.oma.alert;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.oma.account.AccountRepository;
import com.oma.common.ApiException;
import com.oma.config.OmaProperties;
import com.oma.recipient.Recipient;
import com.oma.recipient.RecipientRepository;

/**
 * Work queue for the user's relay phone. The phone claims due {@link AlertChannel#RELAY_SMS} alerts,
 * sends each SMS from its SIM and reports the outcome. A claim is a lease: if the phone never reports,
 * the scheduler marks the alert {@link AlertState#SMS_UNKNOWN} instead of handing it out again, so a
 * recipient never gets a duplicate SMS.
 */
@Service
public class RelayService {

	static final int MAX_CLAIM = 10;

	static final String PROVIDER = "relay-phone";

	private final AlertRepository alerts;

	private final RecipientRepository recipients;

	private final AccountRepository accounts;

	private final OmaProperties properties;

	private final Clock clock;

	RelayService(AlertRepository alerts, RecipientRepository recipients, AccountRepository accounts,
			OmaProperties properties, Clock clock) {
		this.alerts = alerts;
		this.recipients = recipients;
		this.accounts = accounts;
		this.properties = properties;
		this.clock = clock;
	}

	/** An SMS the relay phone must send now. */
	public record RelayJob(UUID alertId, String toE164, String text) {
	}

	@Transactional
	public List<RelayJob> claim(UUID userId, int limit) {
		Instant now = clock.instant();
		accounts.markRelaySeen(userId, now);
		List<RelayJob> jobs = new ArrayList<>();
		for (Alert alert : alerts.claimDueRelayAlerts(userId, now.plus(properties.alerts().sendLease()),
				Math.max(1, Math.min(limit, MAX_CLAIM)))) {
			Recipient recipient = alert.recipientId() == null ? null
					: recipients.find(userId, alert.recipientId()).orElse(null);
			if (recipient == null || !recipient.canReceiveAlerts()) {
				alerts.finishSending(alert.id(), AlertState.SKIPPED, null, "Recipient can no longer receive alerts");
				continue;
			}
			jobs.add(new RelayJob(alert.id(), recipient.phoneE164(), alert.messageText()));
		}
		return jobs;
	}

	public enum ReportedOutcome {

		/** Android reported the SMS as sent by the SIM (RESULT_OK). Not a delivery confirmation. */
		SENT,
		/** The network's delivery report arrived for an SMS already reported as sent. */
		DELIVERED,
		/** Definitely not sent, worth trying again (no signal, airplane mode). */
		RETRYABLE_FAILURE,
		/** Not sent and retrying will not help. */
		FAILED,
		/** The phone could not tell whether it was sent. */
		UNKNOWN

	}

	@Transactional
	public AlertView report(UUID userId, UUID alertId, ReportedOutcome outcome, String error) {
		Alert alert = alerts.findForUser(userId, alertId)
			.filter(a -> a.channel() == AlertChannel.RELAY_SMS)
			.orElseThrow(() -> ApiException.notFound("Alert"));
		String reason = error == null || error.isBlank() ? outcome.name() : error.strip();
		switch (outcome) {
			case DELIVERED -> alerts.markDelivered(userId, alertId);
			case SENT -> requireSending(alert, () -> alerts.markAccepted(alertId, PROVIDER, null));
			case UNKNOWN -> requireSending(alert,
					() -> alerts.finishSending(alertId, AlertState.SMS_UNKNOWN, PROVIDER, "Outcome unknown: " + reason));
			case FAILED -> requireSending(alert,
					() -> alerts.finishSending(alertId, AlertState.SMS_FAILED, PROVIDER, "Not sent: " + reason));
			case RETRYABLE_FAILURE -> requireSending(alert, () -> {
				if (alert.attempts() >= properties.alerts().serverMaxAttempts()) {
					alerts.finishSending(alertId, AlertState.SMS_FAILED, PROVIDER,
							"Gave up after " + alert.attempts() + " attempts: " + reason);
				}
				else {
					alerts.reschedule(alertId, clock.instant().plus(properties.alerts().serverRetryBaseDelay()
						.multipliedBy(1L << Math.max(0, alert.attempts() - 1))), "Retrying after: " + reason);
				}
			});
		}
		return alerts.find(userId, alertId).orElseThrow();
	}

	private static void requireSending(Alert alert, Runnable action) {
		if (AlertState.OPEN.contains(alert.state())) {
			throw new ApiException(HttpStatus.CONFLICT, "INVALID_STATE", "This alert has not been claimed.");
		}
		// A repeated or late report (e.g. after the lease expired) keeps the outcome already recorded.
		if (alert.state() == AlertState.SENDING) {
			action.run();
		}
	}

}
