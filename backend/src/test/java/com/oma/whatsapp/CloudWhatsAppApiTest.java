package com.oma.whatsapp;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

import com.oma.config.OmaProperties;
import com.oma.whatsapp.WhatsAppApi.Kind;
import com.oma.whatsapp.WhatsAppApi.OutgoingMessage;
import com.oma.whatsapp.WhatsAppApi.Outcome;

import static org.assertj.core.api.Assertions.assertThat;

/** The real Graph API client against a local stand-in server. */
class CloudWhatsAppApiTest {

	private HttpServer server;

	private final AtomicReference<String> requestBody = new AtomicReference<>();

	private final AtomicReference<String> authorization = new AtomicReference<>();

	private volatile int responseStatus = 200;

	private volatile String responseBody = "{\"messages\":[{\"id\":\"wamid.ABC\"}]}";

	private volatile long delayMillis;

	@BeforeEach
	void start() throws IOException {
		server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
		server.createContext("/v24.0/PHONE_ID/messages", exchange -> {
			requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
			authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
			try {
				Thread.sleep(delayMillis);
			}
			catch (InterruptedException ex) {
				Thread.currentThread().interrupt();
			}
			byte[] bytes = responseBody.getBytes(StandardCharsets.UTF_8);
			exchange.getResponseHeaders().add("Content-Type", "application/json");
			exchange.sendResponseHeaders(responseStatus, bytes.length);
			exchange.getResponseBody().write(bytes);
			exchange.close();
		});
		server.start();
	}

	@AfterEach
	void stop() {
		server.stop(0);
	}

	@Test
	void sendsTemplateWithBodyParametersAndBearerToken() {
		var result = api().send(new OutgoingMessage("+919876543210", Kind.TEMPLATE, null, "missed_message", "en",
				List.of("Sreerag", "Call me")));

		assertThat(result.outcome()).isEqualTo(Outcome.ACCEPTED);
		assertThat(result.wamid()).isEqualTo("wamid.ABC");
		assertThat(authorization.get()).isEqualTo("Bearer TOKEN");
		assertThat(requestBody.get()).contains("\"to\":\"919876543210\"")
			.contains("\"type\":\"template\"")
			.contains("\"name\":\"missed_message\"")
			.contains("\"language\":{\"code\":\"en\"}")
			.contains("{\"type\":\"text\",\"text\":\"Sreerag\"}");
	}

	@Test
	void sendsFreeText() {
		api().send(new OutgoingMessage("+919876543210", Kind.TEXT, "Hello", null, null, List.of()));

		assertThat(requestBody.get()).contains("\"type\":\"text\"").contains("\"body\":\"Hello\"");
	}

	@Test
	void clientErrorIsARejectionWithTheMetaErrorCode() {
		responseStatus = 400;
		responseBody = """
				{"error":{"message":"(#131030) Recipient phone number not in allowed list","type":"OAuthException",
				  "code":131030,"error_data":{"details":"Recipient phone number not in allowed list"}}}
				""";

		var result = api().send(new OutgoingMessage("+919876543210", Kind.TEXT, "Hello", null, null, List.of()));

		assertThat(result.outcome()).isEqualTo(Outcome.REJECTED);
		assertThat(result.errorCode()).isEqualTo("131030");
		assertThat(result.errorMessage()).isEqualTo("Recipient phone number not in allowed list");
	}

	@Test
	void serverErrorAndTimeoutAreUnknownNotRetried() {
		responseStatus = 500;
		responseBody = "{\"error\":{\"code\":1,\"message\":\"An unknown error occurred\"}}";
		assertThat(api().send(text()).outcome()).isEqualTo(Outcome.UNKNOWN);

		responseStatus = 200;
		delayMillis = 1500;
		assertThat(api().send(text()).outcome()).isEqualTo(Outcome.UNKNOWN);
	}

	@Test
	void unreachableServerIsARejectionSoTheUserCanRetry() {
		server.stop(0);
		assertThat(api().send(text()).outcome()).isEqualTo(Outcome.REJECTED);
	}

	private static OutgoingMessage text() {
		return new OutgoingMessage("+919876543210", Kind.TEXT, "Hello", null, null, List.of());
	}

	private CloudWhatsAppApi api() {
		var whatsapp = new OmaProperties.Whatsapp("http://127.0.0.1:" + server.getAddress().getPort(), "v24.0",
				"PHONE_ID", "TOKEN", "SECRET", "VERIFY", "hello_world", "en_US", List.of(), Duration.ofSeconds(1));
		var properties = new OmaProperties(new OmaProperties.Supabase("http://localhost", null),
				new OmaProperties.Sms(false), null, whatsapp);
		return new CloudWhatsAppApi(properties, JsonMapper.builder().build());
	}

}
