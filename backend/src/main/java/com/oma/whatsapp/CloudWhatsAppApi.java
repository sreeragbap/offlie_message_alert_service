package com.oma.whatsapp;

import java.net.ConnectException;
import java.net.UnknownHostException;
import java.net.http.HttpClient;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import com.oma.config.OmaProperties;

/** Graph API client for {@code POST /{phone-number-id}/messages}. */
@Component
class CloudWhatsAppApi implements WhatsAppApi {

	private static final Logger log = LoggerFactory.getLogger(CloudWhatsAppApi.class);

	private final OmaProperties.Whatsapp config;

	private final RestClient http;

	private final JsonMapper json;

	CloudWhatsAppApi(OmaProperties properties, JsonMapper json) {
		this.config = properties.whatsapp();
		this.json = json;
		JdkClientHttpRequestFactory requests = new JdkClientHttpRequestFactory(
				HttpClient.newBuilder().connectTimeout(config.requestTimeout()).build());
		requests.setReadTimeout(config.requestTimeout());
		this.http = RestClient.builder()
			.baseUrl(config.graphUrl() + "/" + config.apiVersion())
			.requestFactory(requests)
			.build();
	}

	@Override
	public SendResult send(OutgoingMessage message) {
		try {
			JsonNode response = http.post()
				.uri("/{phoneNumberId}/messages", config.phoneNumberId())
				.header(HttpHeaders.AUTHORIZATION, "Bearer " + config.accessToken())
				.contentType(MediaType.APPLICATION_JSON)
				.body(json.writeValueAsString(body(message)))
				.retrieve()
				.body(JsonNode.class);
			String wamid = response == null ? null : response.path("messages").path(0).path("id").asString(null);
			return wamid != null ? SendResult.accepted(wamid) : SendResult.unknown("NO_MESSAGE_ID");
		}
		catch (HttpStatusCodeException ex) {
			JsonNode error = readError(ex.getResponseBodyAsString());
			String code = error.path("code").asString("HTTP_" + ex.getStatusCode().value());
			String detail = error.path("error_data").path("details").asString(error.path("message").asString(""));
			if (ex.getStatusCode().is5xxServerError()) {
				log.warn("WhatsApp send: server error {} ({})", ex.getStatusCode().value(), code);
				return SendResult.unknown(code);
			}
			log.info("WhatsApp send rejected: {} {}", code, detail);
			return SendResult.rejected(code, detail);
		}
		catch (ResourceAccessException ex) {
			// Could not connect at all: nothing was sent. Anything else (e.g. read timeout) is ambiguous.
			if (ex.getCause() instanceof ConnectException || ex.getCause() instanceof UnknownHostException) {
				return SendResult.rejected("CONNECT_FAILED", "Could not reach WhatsApp. Try again.");
			}
			log.warn("WhatsApp send: no response ({})", ex.getClass().getSimpleName());
			return SendResult.unknown("NO_RESPONSE");
		}
	}

	static Map<String, Object> body(OutgoingMessage message) {
		Map<String, Object> body = new LinkedHashMap<>();
		body.put("messaging_product", "whatsapp");
		body.put("recipient_type", "individual");
		body.put("to", message.toE164().substring(1));
		if (message.kind() == Kind.TEXT) {
			body.put("type", "text");
			body.put("text", Map.of("body", message.text(), "preview_url", false));
			return body;
		}
		Map<String, Object> template = new LinkedHashMap<>();
		template.put("name", message.templateName());
		template.put("language", Map.of("code", message.templateLanguage()));
		if (!message.templateParams().isEmpty()) {
			List<Map<String, String>> parameters = message.templateParams()
				.stream()
				.map(value -> Map.of("type", "text", "text", value))
				.toList();
			template.put("components", List.of(Map.of("type", "body", "parameters", parameters)));
		}
		body.put("type", "template");
		body.put("template", template);
		return body;
	}

	private JsonNode readError(String responseBody) {
		try {
			return json.readTree(responseBody).path("error");
		}
		catch (RuntimeException ex) {
			return json.missingNode();
		}
	}

}
