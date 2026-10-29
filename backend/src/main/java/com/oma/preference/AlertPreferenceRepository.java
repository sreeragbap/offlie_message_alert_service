package com.oma.preference;

import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class AlertPreferenceRepository {

	private final JdbcClient jdbc;

	AlertPreferenceRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	/** Returns the user's saved preferences, or the defaults if they never changed them. */
	public AlertPreference get(UUID userId) {
		return jdbc.sql("""
				select default_delay_minutes, max_alerts_per_recipient_per_day, max_alerts_per_day, message_template
				from app.alert_preference where user_id = :userId
				""")
			.param("userId", userId)
			.query((rs, n) -> new AlertPreference(rs.getInt(1), rs.getInt(2), rs.getInt(3), rs.getString(4)))
			.optional()
			.orElse(AlertPreference.DEFAULTS);
	}

	void save(UUID userId, AlertPreference p) {
		jdbc.sql("""
				insert into app.alert_preference
				    (user_id, default_delay_minutes, max_alerts_per_recipient_per_day, max_alerts_per_day, message_template)
				values (:userId, :delay, :perRecipient, :perDay, :template)
				on conflict (user_id) do update set
				    default_delay_minutes = excluded.default_delay_minutes,
				    max_alerts_per_recipient_per_day = excluded.max_alerts_per_recipient_per_day,
				    max_alerts_per_day = excluded.max_alerts_per_day,
				    message_template = excluded.message_template,
				    updated_at = now()
				""")
			.param("userId", userId)
			.param("delay", p.defaultDelayMinutes())
			.param("perRecipient", p.maxAlertsPerRecipientPerDay())
			.param("perDay", p.maxAlertsPerDay())
			.param("template", p.messageTemplate())
			.update();
	}

}
