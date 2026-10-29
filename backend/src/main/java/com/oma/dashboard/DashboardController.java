package com.oma.dashboard;

import java.util.ArrayList;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oma.account.CurrentUser;
import com.oma.alert.AlertRepository;
import com.oma.alert.AlertResponse;
import com.oma.recipient.RecipientRepository;

@RestController
class DashboardController {

	static final int RECENT_ALERTS = 5;

	private final RecipientRepository recipients;

	private final AlertRepository alerts;

	DashboardController(RecipientRepository recipients, AlertRepository alerts) {
		this.recipients = recipients;
		this.alerts = alerts;
	}

	record Dashboard(boolean serviceActive, long recipientCount, long alertableRecipientCount, long openAlertCount,
			List<AlertResponse> recentAlerts, boolean automaticMonitoringConnected, List<String> setupIssues) {
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
		issues.add("Automatic delivery monitoring is not connected. Personal chats can't be monitored, "
				+ "so alerts are sent manually from your phone.");
		return new Dashboard(alertable > 0, recipientCount, alertable, alerts.count(user.id(), true),
				alerts.page(user.id(), false, 0, RECENT_ALERTS).stream().map(AlertResponse::of).toList(), false,
				issues);
	}

}
