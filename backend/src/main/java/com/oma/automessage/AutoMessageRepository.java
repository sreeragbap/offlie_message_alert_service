package com.oma.automessage;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** All user-facing queries are scoped by {@code user_id}. */
@Repository
class AutoMessageRepository {

	private static final String COLUMNS = "recipient_id, user_id, enabled, message_text, send_time, repeat_days, "
			+ "time_zone, sms_after_minutes, next_run_at, last_run_at, last_message_id, last_error";

	private static final RowMapper<AutoMessage> MAPPER = AutoMessageRepository::map;

	private final JdbcClient jdbc;

	AutoMessageRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	Optional<AutoMessage> find(UUID userId, UUID recipientId) {
		return jdbc.sql("select " + COLUMNS + " from app.auto_message where user_id = :userId and recipient_id = :recipientId")
			.param("userId", userId)
			.param("recipientId", recipientId)
			.query(MAPPER)
			.optional();
	}

	AutoMessage save(AutoMessage m) {
		return jdbc.sql("""
				insert into app.auto_message (recipient_id, user_id, enabled, message_text, send_time, repeat_days,
				                              time_zone, sms_after_minutes, next_run_at)
				values (:recipientId, :userId, :enabled, :text, :sendTime, :repeatDays, :zone, :smsAfter, :nextRunAt)
				on conflict (recipient_id) do update
				set enabled = excluded.enabled, message_text = excluded.message_text, send_time = excluded.send_time,
				    repeat_days = excluded.repeat_days, time_zone = excluded.time_zone,
				    sms_after_minutes = excluded.sms_after_minutes, next_run_at = excluded.next_run_at,
				    last_error = null, updated_at = now()
				where app.auto_message.user_id = excluded.user_id
				returning """ + " " + COLUMNS)
			.param("recipientId", m.recipientId())
			.param("userId", m.userId())
			.param("enabled", m.enabled())
			.param("text", m.messageText())
			.param("sendTime", m.sendTime() == null ? null : Time.valueOf(m.sendTime()))
			.param("repeatDays", m.repeatDays())
			.param("zone", m.timeZone().getId())
			.param("smsAfter", m.smsAfterMinutes())
			.param("nextRunAt", timestamp(m.nextRunAt()))
			.query(MAPPER)
			.single();
	}

	/** Locks due rows for the rest of the transaction; other instances skip them. */
	List<AutoMessage> lockDue(Instant now, int limit) {
		return jdbc.sql("select " + COLUMNS + """
				 from app.auto_message
				where enabled and next_run_at <= :now
				order by next_run_at
				limit :limit
				for update skip locked
				""")
			.param("now", Timestamp.from(now))
			.param("limit", limit)
			.query(MAPPER)
			.list();
	}

	/** Moves past the run that is about to be sent, so it is never claimed twice. */
	void advance(UUID recipientId, Instant ranAt, Instant nextRunAt) {
		jdbc.sql("""
				update app.auto_message
				set last_run_at = :ranAt, next_run_at = :nextRunAt, updated_at = now()
				where recipient_id = :recipientId
				""")
			.param("recipientId", recipientId)
			.param("ranAt", Timestamp.from(ranAt))
			.param("nextRunAt", timestamp(nextRunAt))
			.update();
	}

	void recordResult(UUID recipientId, UUID messageId, String error) {
		jdbc.sql("""
				update app.auto_message
				set last_message_id = :messageId, last_error = :error, updated_at = now()
				where recipient_id = :recipientId
				""")
			.param("recipientId", recipientId)
			.param("messageId", messageId)
			.param("error", error)
			.update();
	}

	private static Timestamp timestamp(Instant instant) {
		return instant == null ? null : Timestamp.from(instant);
	}

	private static Instant instant(ResultSet rs, String column) throws SQLException {
		Timestamp value = rs.getTimestamp(column);
		return value == null ? null : value.toInstant();
	}

	private static AutoMessage map(ResultSet rs, int rowNum) throws SQLException {
		Time sendTime = rs.getTime("send_time");
		return new AutoMessage(rs.getObject("recipient_id", UUID.class), rs.getObject("user_id", UUID.class),
				rs.getBoolean("enabled"), rs.getString("message_text"),
				sendTime == null ? null : sendTime.toLocalTime(), rs.getInt("repeat_days"),
				ZoneId.of(rs.getString("time_zone")), rs.getInt("sms_after_minutes"), instant(rs, "next_run_at"),
				instant(rs, "last_run_at"), rs.getObject("last_message_id", UUID.class), rs.getString("last_error"));
	}

}
