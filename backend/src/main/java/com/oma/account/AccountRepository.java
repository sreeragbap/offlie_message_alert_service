package com.oma.account;

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

	Optional<String> findDisplayName(UUID id) {
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
	void delete(UUID id) {
		jdbc.sql("delete from app.user_account where id = :id").param("id", id).update();
	}

}
