package com.oma.whatsapp;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.oma.whatsapp.WhatsAppMessage.Direction;
import com.oma.whatsapp.WhatsAppMessage.Kind;
import com.oma.whatsapp.WhatsAppMessage.Status;

@Repository
class WhatsAppMessageRepository {

	private static final String VIEW_SELECT = """
			select m.*, r.display_name as recipient_name, a.state as alert_state, a.due_at as alert_due_at,
			       a.last_error as alert_note
			from app.wa_message m
			left join app.recipient r on r.id = m.recipient_id
			left join app.alert a on a.id = m.alert_id
			""";

	private static final RowMapper<WhatsAppMessage> VIEW = WhatsAppMessageRepository::map;

	/** Order of outgoing statuses; a webhook never moves a message backwards. */
	private static final String RANK = """
			case %s when 'ACCEPTED' then 0 when 'SENT' then 1 when 'DELIVERED' then 2 when 'READ' then 3
			        when 'FAILED' then 4 else -1 end
			""";

	private final JdbcClient jdbc;

	WhatsAppMessageRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	UUID insertPending(UUID userId, UUID recipientId, UUID clientRequestId, Kind kind, String body, Instant now) {
		return jdbc.sql("""
				insert into app.wa_message (user_id, recipient_id, direction, client_request_id, kind, body, status,
				                            created_at, updated_at)
				values (:userId, :recipientId, 'OUT', :crid, :kind, :body, 'PENDING', :now, :now)
				returning id
				""")
			.param("now", Timestamp.from(now))
			.param("userId", userId)
			.param("recipientId", recipientId)
			.param("crid", clientRequestId)
			.param("kind", kind.name())
			.param("body", body)
			.query(UUID.class)
			.single();
	}

	Optional<UUID> findIdByClientRequestId(UUID userId, UUID clientRequestId) {
		return jdbc.sql("select id from app.wa_message where user_id = :userId and client_request_id = :crid")
			.param("userId", userId)
			.param("crid", clientRequestId)
			.query(UUID.class)
			.optional();
	}

	Optional<WhatsAppMessage> find(UUID userId, UUID id) {
		return jdbc.sql(VIEW_SELECT + " where m.user_id = :userId and m.id = :id")
			.param("userId", userId)
			.param("id", id)
			.query(VIEW)
			.optional();
	}

	List<WhatsAppMessage> recent(UUID userId, UUID recipientId, int limit) {
		return jdbc.sql(VIEW_SELECT + " where m.user_id = :userId"
				+ (recipientId != null ? " and m.recipient_id = :recipientId" : "")
				+ " order by m.created_at desc, m.id limit :limit")
			.param("userId", userId)
			.param("recipientId", recipientId)
			.param("limit", limit)
			.query(VIEW)
			.list();
	}

	void markAccepted(UUID id, String wamid) {
		jdbc.sql("update app.wa_message set status = 'ACCEPTED', wamid = :wamid, updated_at = now() where id = :id")
			.param("id", id)
			.param("wamid", wamid)
			.update();
	}

	void markFinished(UUID id, Status status, String errorCode, String errorMessage) {
		jdbc.sql("""
				update app.wa_message set status = :status, error_code = :code, error_message = :message, updated_at = now()
				where id = :id
				""")
			.param("id", id)
			.param("status", status.name())
			.param("code", errorCode)
			.param("message", truncate(errorMessage, 300))
			.update();
	}

	void linkAlert(UUID id, UUID alertId, String skippedReason) {
		jdbc.sql("update app.wa_message set alert_id = :alertId, alert_skipped = :skipped, updated_at = now() where id = :id")
			.param("id", id)
			.param("alertId", alertId)
			.param("skipped", skippedReason)
			.update();
	}

	/**
	 * Serialises work on one wamid within the current transaction: the send flow storing the wamid and
	 * a webhook reporting its status must not interleave, or an early status could be missed.
	 */
	void lockWamid(String wamid) {
		jdbc.sql("select pg_advisory_xact_lock(hashtext(:wamid))").param("wamid", wamid).query(Object.class).list();
	}

	void insertStatusEvent(String wamid, Status status, Instant occurredAt, String errorCode, String errorTitle) {
		jdbc.sql("""
				insert into app.wa_status_event (wamid, status, occurred_at, error_code, error_title)
				values (:wamid, :status, :at, :code, :title)
				""")
			.param("wamid", wamid)
			.param("status", status.name())
			.param("at", Timestamp.from(occurredAt))
			.param("code", errorCode)
			.param("title", truncate(errorTitle, 300))
			.update();
	}

	record StatusEvent(Status status, Instant occurredAt, String errorCode, String errorTitle) {
	}

	List<StatusEvent> statusEvents(String wamid) {
		return jdbc.sql("""
				select status, occurred_at, error_code, error_title from app.wa_status_event
				where wamid = :wamid order by occurred_at, id
				""")
			.param("wamid", wamid)
			.query((rs, n) -> new StatusEvent(Status.valueOf(rs.getString("status")),
					rs.getTimestamp("occurred_at").toInstant(), rs.getString("error_code"), rs.getString("error_title")))
			.list();
	}

	/** An outgoing message whose status just moved forward, with the alert that depends on it. */
	record Advanced(UUID messageId, UUID alertId) {
	}

	/** Moves outgoing messages with this wamid forward to {@code status}; FAILED never overrides delivery. */
	List<Advanced> advanceStatus(String wamid, Status status, Instant at, String errorCode, String errorTitle) {
		return jdbc.sql("""
				update app.wa_message set status = :status,
				    sent_at = case when :status in ('SENT', 'DELIVERED', 'READ') then coalesce(sent_at, :at) else sent_at end,
				    delivered_at = case when :status in ('DELIVERED', 'READ') then coalesce(delivered_at, :at) else delivered_at end,
				    read_at = case when :status = 'READ' then coalesce(read_at, :at) else read_at end,
				    error_code = case when :status = 'FAILED' then :code else error_code end,
				    error_message = case when :status = 'FAILED' then :title else error_message end,
				    updated_at = now()
				where direction = 'OUT' and wamid = :wamid
				  and %s < %s
				  and not (:status = 'FAILED' and status in ('DELIVERED', 'READ'))
				returning id, alert_id
				""".formatted(RANK.formatted("status"), RANK.formatted(":status")))
			.param("wamid", wamid)
			.param("status", status.name())
			.param("at", Timestamp.from(at))
			.param("code", errorCode)
			.param("title", truncate(errorTitle, 300))
			.query((rs, n) -> new Advanced(rs.getObject("id", UUID.class), rs.getObject("alert_id", UUID.class)))
			.list();
	}

	Optional<Instant> recipientLastInbound(UUID recipientId) {
		return jdbc.sql("select wa_last_inbound_at from app.recipient where id = :id")
			.param("id", recipientId)
			.query((rs, n) -> Optional.ofNullable(rs.getTimestamp(1)).map(Timestamp::toInstant))
			.optional()
			.flatMap(value -> value);
	}

	/** A recipient (of any user) with this phone number. */
	record RecipientRef(UUID userId, UUID recipientId) {
	}

	/**
	 * Records a message from this number to the business number. The business number is shared by the
	 * deployment, so it is attributed only to users who have messaged this recipient through the app.
	 */
	List<RecipientRef> touchRecipientsByPhone(String phoneE164, Instant at) {
		return jdbc.sql("""
				update app.recipient r set wa_last_inbound_at = greatest(r.wa_last_inbound_at, :at)
				where r.phone_e164 = :phone
				  and exists (select 1 from app.wa_message m where m.recipient_id = r.id and m.direction = 'OUT')
				returning r.user_id, r.id
				""")
			.param("phone", phoneE164)
			.param("at", Timestamp.from(at))
			.query((rs, n) -> new RecipientRef(rs.getObject("user_id", UUID.class), rs.getObject("id", UUID.class)))
			.list();
	}

	void insertInbound(RecipientRef ref, String wamid, Kind kind, String body, Instant at) {
		jdbc.sql("""
				insert into app.wa_message (user_id, recipient_id, direction, kind, body, wamid, status, created_at, updated_at)
				values (:userId, :recipientId, 'IN', :kind, :body, :wamid, 'RECEIVED', :at, :at)
				on conflict (user_id, wamid) where wamid is not null do nothing
				""")
			.param("userId", ref.userId())
			.param("recipientId", ref.recipientId())
			.param("kind", kind.name())
			.param("body", truncate(body, 4096))
			.param("wamid", wamid)
			.param("at", Timestamp.from(at))
			.update();
	}

	int deleteCreatedBefore(Instant cutoff) {
		int messages = jdbc.sql("delete from app.wa_message where created_at < :cutoff")
			.param("cutoff", Timestamp.from(cutoff))
			.update();
		jdbc.sql("delete from app.wa_status_event where received_at < :cutoff")
			.param("cutoff", Timestamp.from(cutoff))
			.update();
		return messages;
	}

	private static String truncate(String value, int max) {
		return value == null || value.length() <= max ? value : value.substring(0, max);
	}

	private static Instant instant(ResultSet rs, String column) throws SQLException {
		Timestamp value = rs.getTimestamp(column);
		return value == null ? null : value.toInstant();
	}

	private static WhatsAppMessage map(ResultSet rs, int rowNum) throws SQLException {
		return new WhatsAppMessage(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
				rs.getObject("recipient_id", UUID.class), rs.getString("recipient_name"),
				Direction.valueOf(rs.getString("direction")), Kind.valueOf(rs.getString("kind")), rs.getString("body"),
				rs.getString("wamid"), Status.valueOf(rs.getString("status")), rs.getString("error_code"),
				rs.getString("error_message"), rs.getObject("alert_id", UUID.class), rs.getString("alert_state"),
				instant(rs, "alert_due_at"), rs.getString("alert_note"), rs.getString("alert_skipped"),
				instant(rs, "created_at"), instant(rs, "sent_at"), instant(rs, "delivered_at"), instant(rs, "read_at"));
	}

}
