package com.oma.recipient;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** All queries are scoped by {@code user_id}, so one user can never see another user's recipients. */
@Repository
public class RecipientRepository {

	private static final String COLUMNS = "id, user_id, display_name, phone_e164, alerts_enabled, opted_out, created_at, updated_at";

	private static final RowMapper<Recipient> MAPPER = RecipientRepository::map;

	private final JdbcClient jdbc;

	RecipientRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	List<Recipient> findAll(UUID userId) {
		return jdbc.sql("select " + COLUMNS + " from app.recipient where user_id = :userId order by lower(display_name), id")
			.param("userId", userId)
			.query(MAPPER)
			.list();
	}

	public Optional<Recipient> find(UUID userId, UUID id) {
		return jdbc.sql("select " + COLUMNS + " from app.recipient where user_id = :userId and id = :id")
			.param("userId", userId)
			.param("id", id)
			.query(MAPPER)
			.optional();
	}

	/** Locks the row for the rest of the transaction; serialises concurrent alerts to one recipient. */
	public Optional<Recipient> findForUpdate(UUID userId, UUID id) {
		return jdbc.sql("select " + COLUMNS + " from app.recipient where user_id = :userId and id = :id for update")
			.param("userId", userId)
			.param("id", id)
			.query(MAPPER)
			.optional();
	}

	Recipient insert(UUID userId, String displayName, String phoneE164, boolean alertsEnabled) {
		return jdbc.sql("""
				insert into app.recipient (user_id, display_name, phone_e164, alerts_enabled)
				values (:userId, :displayName, :phone, :alertsEnabled)
				returning """ + " " + COLUMNS)
			.param("userId", userId)
			.param("displayName", displayName)
			.param("phone", phoneE164)
			.param("alertsEnabled", alertsEnabled)
			.query(MAPPER)
			.single();
	}

	Recipient update(Recipient recipient) {
		return jdbc.sql("""
				update app.recipient
				set display_name = :displayName, phone_e164 = :phone, alerts_enabled = :alertsEnabled,
				    opted_out = :optedOut, updated_at = now()
				where user_id = :userId and id = :id
				returning """ + " " + COLUMNS)
			.param("userId", recipient.userId())
			.param("id", recipient.id())
			.param("displayName", recipient.displayName())
			.param("phone", recipient.phoneE164())
			.param("alertsEnabled", recipient.alertsEnabled())
			.param("optedOut", recipient.optedOut())
			.query(MAPPER)
			.single();
	}

	boolean delete(UUID userId, UUID id) {
		return jdbc.sql("delete from app.recipient where user_id = :userId and id = :id")
			.param("userId", userId)
			.param("id", id)
			.update() > 0;
	}

	/** Stops alerts that have not gone out yet, e.g. when the recipient is disabled or removed. */
	int cancelOpenAlerts(UUID userId, UUID recipientId, String reason) {
		return jdbc.sql("""
				update app.alert
				set state = 'CANCELLED', last_error = :reason, completed_at = now(), updated_at = now()
				where user_id = :userId and recipient_id = :recipientId and state in ('SCHEDULED', 'DUE')
				""")
			.param("userId", userId)
			.param("recipientId", recipientId)
			.param("reason", reason)
			.update();
	}

	public long countAll(UUID userId) {
		return jdbc.sql("select count(*) from app.recipient where user_id = :userId")
			.param("userId", userId)
			.query(Long.class)
			.single();
	}

	public long countAlertable(UUID userId) {
		return jdbc.sql("select count(*) from app.recipient where user_id = :userId and alerts_enabled and not opted_out")
			.param("userId", userId)
			.query(Long.class)
			.single();
	}

	private static Recipient map(ResultSet rs, int rowNum) throws SQLException {
		return new Recipient(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
				rs.getString("display_name"), rs.getString("phone_e164"), rs.getBoolean("alerts_enabled"),
				rs.getBoolean("opted_out"), rs.getTimestamp("created_at").toInstant(),
				rs.getTimestamp("updated_at").toInstant());
	}

}
