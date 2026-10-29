package com.oma.support;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.UUID;

import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import org.junit.jupiter.api.BeforeEach;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

/**
 * Full application against a real PostgreSQL 17 (in-process, no Docker), with Flyway migrations applied.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(IntegrationTest.TestBeans.class)
public abstract class IntegrationTest {

	private static final EmbeddedPostgres POSTGRES = start();

	@Autowired
	protected MockMvc mvc;

	@Autowired
	protected JdbcClient jdbc;

	@Autowired
	protected MutableClock clock;

	@Autowired
	protected FakeSmsGateway sms;

	@DynamicPropertySource
	static void datasource(DynamicPropertyRegistry registry) {
		registry.add("spring.datasource.url", () -> POSTGRES.getJdbcUrl("postgres", "postgres"));
		registry.add("spring.datasource.username", () -> "postgres");
		registry.add("spring.datasource.password", () -> "postgres");
	}

	@BeforeEach
	void resetState() {
		jdbc.sql("truncate app.alert, app.recipient, app.alert_preference, app.user_account cascade").update();
		clock.reset();
		sms.reset();
	}

	/** Authenticates the request as the given Supabase user. */
	protected static RequestPostProcessor as(UUID userId) {
		return jwt().jwt(token -> token.subject(userId.toString()).claim("email", userId + "@example.test"));
	}

	private static EmbeddedPostgres start() {
		try {
			return EmbeddedPostgres.start();
		}
		catch (IOException ex) {
			throw new UncheckedIOException(ex);
		}
	}

	@TestConfiguration(proxyBeanMethods = false)
	static class TestBeans {

		@Bean
		@Primary
		MutableClock testClock() {
			return new MutableClock();
		}

		@Bean
		@Primary
		FakeSmsGateway fakeSmsGateway() {
			return new FakeSmsGateway();
		}

	}

}
