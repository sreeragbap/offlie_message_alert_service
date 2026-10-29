package com.oma.recipient;

import java.util.UUID;

import org.junit.jupiter.api.Test;

import org.springframework.http.MediaType;

import com.oma.support.Api;
import com.oma.support.IntegrationTest;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class RecipientApiTest extends IntegrationTest {

	private final UUID alice = UUID.randomUUID();

	private final UUID bob = UUID.randomUUID();

	@Test
	void requiresAuthentication() throws Exception {
		mvc.perform(get("/api/v1/recipients")).andExpect(status().isUnauthorized());
	}

	@Test
	void createsRecipientWithNormalisedNumber() throws Exception {
		mvc.perform(post("/api/v1/recipients").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"displayName\":\" Anu \",\"phone\":\"98765 43210\"}"))
			.andExpect(status().isCreated())
			.andExpect(jsonPath("$.displayName").value("Anu"))
			.andExpect(jsonPath("$.phoneE164").value("+919876543210"))
			.andExpect(jsonPath("$.alertsEnabled").value(true))
			.andExpect(jsonPath("$.canReceiveAlerts").value(true));
	}

	@Test
	void rejectsInvalidInputWithProblemDetails() throws Exception {
		mvc.perform(post("/api/v1/recipients").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"displayName\":\"\",\"phone\":\"98765 43210\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
			.andExpect(jsonPath("$.errors[0].field").value("displayName"));

		mvc.perform(post("/api/v1/recipients").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"displayName\":\"Anu\",\"phone\":\"12345\"}"))
			.andExpect(status().isBadRequest())
			.andExpect(jsonPath("$.code").value("INVALID_PHONE"));
	}

	@Test
	void rejectsDuplicateNumberForSameUser() throws Exception {
		Api.createRecipient(mvc, alice, "Anu", "9876543210");
		mvc.perform(post("/api/v1/recipients").with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"displayName\":\"Anu again\",\"phone\":\"+91 98765 43210\"}"))
			.andExpect(status().isConflict())
			.andExpect(jsonPath("$.code").value("DUPLICATE_RECIPIENT"));
	}

	@Test
	void usersCannotSeeOrChangeEachOthersRecipients() throws Exception {
		UUID anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");

		mvc.perform(get("/api/v1/recipients").with(as(bob))).andExpect(status().isOk()).andExpect(jsonPath("$", hasSize(0)));
		mvc.perform(get("/api/v1/recipients/" + anu).with(as(bob))).andExpect(status().isNotFound());
		mvc.perform(patch("/api/v1/recipients/" + anu).with(as(bob))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"alertsEnabled\":false}")).andExpect(status().isNotFound());
		mvc.perform(delete("/api/v1/recipients/" + anu).with(as(bob))).andExpect(status().isNotFound());

		mvc.perform(get("/api/v1/recipients/" + anu).with(as(alice)))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.alertsEnabled").value(true));
	}

	@Test
	void updatesAndDeletesRecipient() throws Exception {
		UUID anu = Api.createRecipient(mvc, alice, "Anu", "9876543210");
		mvc.perform(patch("/api/v1/recipients/" + anu).with(as(alice))
			.contentType(MediaType.APPLICATION_JSON)
			.content("{\"optedOut\":true}"))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.optedOut").value(true))
			.andExpect(jsonPath("$.canReceiveAlerts").value(false));

		mvc.perform(delete("/api/v1/recipients/" + anu).with(as(alice))).andExpect(status().isNoContent());
		mvc.perform(get("/api/v1/recipients/" + anu).with(as(alice))).andExpect(status().isNotFound());
	}

}
