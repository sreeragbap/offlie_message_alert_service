package com.oma.support;

import java.util.UUID;

import com.jayway.jsonpath.JsonPath;

import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Small helpers for setting up data through the public API. */
public final class Api {

	private Api() {
	}

	public static UUID createRecipient(MockMvc mvc, UUID user, String name, String phone) throws Exception {
		MvcResult result = mvc.perform(post("/api/v1/recipients").with(IntegrationTest.as(user))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"displayName\":\"%s\",\"phone\":\"%s\"}".formatted(name, phone)))
			.andExpect(status().isCreated())
			.andReturn();
		return UUID.fromString(JsonPath.read(result.getResponse().getContentAsString(), "$.id"));
	}

	public static String alertJson(UUID clientRequestId, UUID recipientId, Integer delayMinutes, String channel) {
		return """
				{"clientRequestId":"%s","recipientId":"%s","platform":"WHATSAPP"%s%s}
				""".formatted(clientRequestId, recipientId,
				delayMinutes == null ? "" : ",\"delayMinutes\":" + delayMinutes,
				channel == null ? "" : ",\"channel\":\"" + channel + "\"");
	}

	public static UUID createAlert(MockMvc mvc, UUID user, UUID recipientId, Integer delayMinutes, String channel)
			throws Exception {
		MvcResult result = mvc.perform(post("/api/v1/alerts").with(IntegrationTest.as(user))
			.contentType(MediaType.APPLICATION_JSON)
			.content(alertJson(UUID.randomUUID(), recipientId, delayMinutes, channel)))
			.andExpect(status().isCreated())
			.andReturn();
		return UUID.fromString(JsonPath.read(result.getResponse().getContentAsString(), "$.id"));
	}

}
