package com.oma.account;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class AccountRepository {

	private final JdbcClient jdbc;

	AccountRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	public void ensureExists(UUID id) {
		jdbc.sql("insert into app.user_account (id) values (:id) on conflict (id) do nothing")
			.param("id", id)
			.update();
	}

	public Optional<String> findDisplayName(UUID id) {
		return jdbc.sql("select display_name from app.user_account where id = :id")
			.param("id", id)
			.query(String.class)
			.optional();
	}

	void updateDisplayName(UUID id, String displayName) {
		jdbc.sql("update app.user_account set display_name = :name, updated_at = now() where id = :id")
			.param("id", id)
			.param("name", displayName)
			.update();
	}

	/** Deletes the account; recipients, preferences and alerts cascade. */
	public void markRelaySeen(UUID id, Instant at) {
		jdbc.sql("update app.user_account set relay_last_seen_at = :at where id = :id")
			.param("id", id)
			.param("at", Timestamp.from(at))
			.update();
	}

	public Optional<Instant> findRelayLastSeen(UUID id) {
		return jdbc.sql("select relay_last_seen_at from app.user_account where id = :id")
			.param("id", id)
			.query(Timestamp.class)
			.list()
			.stream()
			.filter(Objects::nonNull)
			.findFirst()
			.map(Timestamp::toInstant);
	}

	void delete(UUID id) {
		jdbc.sql("delete from app.user_account where id = :id").param("id", id).update();
	}

}
