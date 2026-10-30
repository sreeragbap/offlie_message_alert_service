package com.oma.dashboard;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.AccountRepository;
import com.oma.account.CurrentUser;
import com.oma.alert.AlertRepository;
import com.oma.alert.AlertResponse;
import com.oma.recipient.RecipientRepository;
import com.oma.whatsapp.WhatsAppService;

@RestController
class DashboardController {

	static final int RECENT_ALERTS = 5;

	/** The relay phone asks for work every few seconds; longer silence means it is not running. */
	static final Duration RELAY_ONLINE_WITHIN = Duration.ofMinutes(2);

	private final RecipientRepository recipients;

	private final AlertRepository alerts;

	private final AccountRepository accounts;

	private final WhatsAppService whatsApp;

	private final Clock clock;

	DashboardController(RecipientRepository recipients, AlertRepository alerts, AccountRepository accounts,
			WhatsAppService whatsApp, Clock clock) {
		this.recipients = recipients;
		this.alerts = alerts;
		this.accounts = accounts;
		this.whatsApp = whatsApp;
		this.clock = clock;
	}

	record Dashboard(boolean serviceActive, long recipientCount, long alertableRecipientCount, long openAlertCount,
			List<AlertResponse> recentAlerts, boolean automaticMonitoringConnected, Instant relayLastSeenAt,
			boolean relayOnline, List<String> setupIssues) {
	}

	@GetMapping("/api/v1/dashboard")
	Dashboard get(CurrentUser user) {
		long recipientCount = recipients.countAll(user.id());
		long alertable = recipients.countAlertable(user.id());
		List<String> issues = new ArrayList<>();
		if (recipientCount == 0) {
			issues.add("Add a recipient to start sending alerts.");
		}
		else if (alertable == 0) {
			issues.add("Alerts are turned off for all your recipients.");
		}
		boolean monitoring = whatsApp.configured();
		Instant relaySeen = accounts.findRelayLastSeen(user.id()).orElse(null);
		boolean relayOnline = relaySeen != null && relaySeen.isAfter(clock.instant().minus(RELAY_ONLINE_WITHIN));
		if (!monitoring) {
			issues.add("Automatic delivery monitoring is not connected. Personal chats can't be monitored, "
					+ "so alerts are sent manually from your phone.");
		}
		else if (!relayOnline) {
			issues.add("Your relay phone is offline. Automatic SMS alerts wait until it is running again.");
		}
		return new Dashboard(alertable > 0, recipientCount, alertable, alerts.count(user.id(), true),
				alerts.page(user.id(), false, 0, RECENT_ALERTS).stream().map(AlertResponse::of).toList(), monitoring,
				relaySeen, relayOnline, issues);
	}

}
