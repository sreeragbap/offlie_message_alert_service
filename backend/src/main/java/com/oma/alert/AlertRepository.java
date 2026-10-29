package com.oma.alert;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * SQL for alerts. State changes are conditional updates ({@code where state in (...)}), so a
 * transition only happens once even with concurrent requests or several backend instances.
 */
@Repository
public class AlertRepository {

	private static final String VIEW_SELECT = """
			select a.*, r.display_name as recipient_name, r.phone_e164 as recipient_phone
			from app.alert a left join app.recipient r on r.id = a.recipient_id
			""";

	private static final RowMapper<Alert> ALERT = AlertRepository::mapAlert;

	private static final RowMapper<AlertView> VIEW = (rs, n) -> new AlertView(mapAlert(rs, n),
			rs.getString("recipient_name"), rs.getString("recipient_phone"));

	private final JdbcClient jdbc;

	AlertRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	record NewAlert(UUID userId, UUID recipientId, UUID clientRequestId, TriggerSource triggerSource,
			Platform platform, AlertChannel channel, AlertState state, String messageText, Instant dueAt,
			Instant createdAt) {
	}

	UUID insert(NewAlert a) {
		return jdbc.sql("""
				insert into app.alert (user_id, recipient_id, client_request_id, trigger_source, platform, channel,
				                       state, message_text, due_at, created_at, updated_at)
				values (:userId, :recipientId, :clientRequestId, :triggerSource, :platform, :channel,
				        :state, :messageText, :dueAt, :createdAt, :createdAt)
				returning id
				""")
			.param("userId", a.userId())
			.param("recipientId", a.recipientId())
			.param("clientRequestId", a.clientRequestId())
			.param("triggerSource", a.triggerSource().name())
			.param("platform", a.platform().name())
			.param("channel", a.channel().name())
			.param("state", a.state().name())
			.param("messageText", a.messageText())
			.param("dueAt", ts(a.dueAt()))
			.param("createdAt", ts(a.createdAt()))
			.query(UUID.class)
			.single();
	}

	Optional<AlertView> find(UUID userId, UUID id) {
		return jdbc.sql(VIEW_SELECT + " where a.user_id = :userId and a.id = :id")
			.param("userId", userId)
			.param("id", id)
			.query(VIEW)
			.optional();
	}

	Optional<UUID> findIdByClientRequestId(UUID userId, UUID clientRequestId) {
		return jdbc.sql("select id from app.alert where user_id = :userId and client_request_id = :crid")
			.param("userId", userId)
			.param("crid", clientRequestId)
			.query(UUID.class)
			.optional();
	}

	public List<AlertView> page(UUID userId, boolean openOnly, int page, int size) {
		return jdbc.sql(VIEW_SELECT + " where a.user_id = :userId" + (openOnly ? " and a.state in ('SCHEDULED', 'DUE')" : "")
				+ " order by a.created_at desc, a.id limit :limit offset :offset")
			.param("userId", userId)
			.param("limit", size)
			.param("offset", (long) page * size)
			.query(VIEW)
			.list();
	}

	public long count(UUID userId, boolean openOnly) {
		return jdbc.sql("select count(*) from app.alert where user_id = :userId"
				+ (openOnly ? " and state in ('SCHEDULED', 'DUE')" : ""))
			.param("userId", userId)
			.query(Long.class)
			.single();
	}

	long countSentOrPendingForRecipientSince(UUID recipientId, Instant since) {
		return jdbc.sql("""
				select count(*) from app.alert
				where recipient_id = :recipientId and created_at >= :since
				  and state not in ('CANCELLED', 'SKIPPED', 'EXPIRED')
				""")
			.param("recipientId", recipientId)
			.param("since", ts(since))
			.query(Long.class)
			.single();
	}

	long countSentOrPendingForUserSince(UUID userId, Instant since) {
		return jdbc.sql("""
				select count(*) from app.alert
				where user_id = :userId and created_at >= :since
				  and state not in ('CANCELLED', 'SKIPPED', 'EXPIRED')
				""")
			.param("userId", userId)
			.param("since", ts(since))
			.query(Long.class)
			.single();
	}

	/** Moves a user's alert from one of {@code from} to {@code to}; returns false if it was in another state. */
	boolean transition(UUID userId, UUID id, Collection<AlertState> from, AlertState to, String note, boolean completes) {
		return jdbc.sql("""
				update app.alert
				set state = :to, last_error = coalesce(:note, last_error), updated_at = now(),
				    completed_at = case when :completes then now() else completed_at end
				where user_id = :userId and id = :id and state in (:from)
				""")
			.param("userId", userId)
			.param("id", id)
			.param("from", from.stream().map(Enum::name).toList())
			.param("to", to.name())
			.param("note", note)
			.param("completes", completes)
			.update() == 1;
	}

	// ---- Scheduler operations (all users) ----

	int promoteDueDeviceAlerts(Instant now) {
		return jdbc.sql("""
				update app.alert set state = 'DUE', updated_at = now()
				where channel = 'DEVICE_SMS' and state = 'SCHEDULED' and due_at <= :now
				""")
			.param("now", ts(now))
			.update();
	}

	int expireDeviceAlerts(Instant dueBefore) {
		return jdbc.sql("""
				update app.alert
				set state = 'EXPIRED', last_error = 'Not sent from the phone in time', completed_at = now(), updated_at = now()
				where channel = 'DEVICE_SMS' and state = 'DUE' and due_at <= :dueBefore
				""")
			.param("dueBefore", ts(dueBefore))
			.update();
	}

	/**
	 * A worker died (or the backend restarted) while submitting. We cannot know whether the provider
	 * received the request, so the alert becomes UNKNOWN instead of being retried and possibly duplicated.
	 */
	int markStuckSendsUnknown(Instant now) {
		return jdbc.sql("""
				update app.alert
				set state = 'SMS_UNKNOWN', last_error = 'Interrupted while sending; outcome unknown',
				    locked_until = null, completed_at = now(), updated_at = now()
				where state = 'SENDING' and locked_until < :now
				""")
			.param("now", ts(now))
			.update();
	}

	/** Atomically claims due server-channel alerts; concurrent workers skip rows another worker holds. */
	List<Alert> claimDueServerAlerts(Instant now, Instant lockedUntil, int limit) {
		return jdbc.sql("""
				update app.alert set state = 'SENDING', attempts = attempts + 1, locked_until = :lockedUntil,
				                     updated_at = now()
				where id in (
				    select id from app.alert
				    where channel = 'SERVER_SMS' and state = 'SCHEDULED' and due_at <= :now
				    order by due_at
				    limit :limit
				    for update skip locked)
				returning *
				""")
			.param("now", ts(now))
			.param("lockedUntil", ts(lockedUntil))
			.param("limit", limit)
			.query(ALERT)
			.list();
	}

	void markAccepted(UUID id, String provider, String providerMessageId) {
		jdbc.sql("""
				update app.alert
				set state = 'SMS_ACCEPTED', provider = :provider, provider_message_id = :pmid, locked_until = null,
				    last_error = null, completed_at = now(), updated_at = now()
				where id = :id and state = 'SENDING'
				""")
			.param("id", id)
			.param("provider", provider)
			.param("pmid", providerMessageId)
			.update();
	}

	void reschedule(UUID id, Instant dueAt, String error) {
		jdbc.sql("""
				update app.alert
				set state = 'SCHEDULED', due_at = :dueAt, locked_until = null, last_error = :error, updated_at = now()
				where id = :id and state = 'SENDING'
				""")
			.param("id", id)
			.param("dueAt", ts(dueAt))
			.param("error", error)
			.update();
	}

	void finishSending(UUID id, AlertState state, String provider, String error) {
		jdbc.sql("""
				update app.alert
				set state = :state, provider = coalesce(:provider, provider), locked_until = null, last_error = :error,
				    completed_at = now(), updated_at = now()
				where id = :id and state = 'SENDING'
				""")
			.param("id", id)
			.param("state", state.name())
			.param("provider", provider)
			.param("error", error)
			.update();
	}

	int deleteCreatedBefore(Instant cutoff) {
		return jdbc.sql("delete from app.alert where created_at < :cutoff and state not in ('SCHEDULED', 'DUE', 'SENDING')")
			.param("cutoff", ts(cutoff))
			.update();
	}

	private static Timestamp ts(Instant instant) {
		return instant == null ? null : Timestamp.from(instant);
	}

	private static Instant instant(ResultSet rs, String column) throws SQLException {
		Timestamp value = rs.getTimestamp(column);
		return value == null ? null : value.toInstant();
	}

	private static Alert mapAlert(ResultSet rs, int rowNum) throws SQLException {
		return new Alert(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
				rs.getObject("recipient_id", UUID.class), rs.getObject("client_request_id", UUID.class),
				TriggerSource.valueOf(rs.getString("trigger_source")), Platform.valueOf(rs.getString("platform")),
				AlertChannel.valueOf(rs.getString("channel")), AlertState.valueOf(rs.getString("state")),
				rs.getString("message_text"), instant(rs, "due_at"), rs.getInt("attempts"),
				instant(rs, "locked_until"), rs.getString("provider"), rs.getString("provider_message_id"),
				rs.getString("last_error"), instant(rs, "created_at"), instant(rs, "updated_at"),
				instant(rs, "completed_at"));
	}

}
