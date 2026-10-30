package com.oma.whatsapp;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.oma.config.OmaProperties;

/**
 * Public endpoint Meta calls. Not behind sign-in: requests are trusted only when signed with the
 * app secret, and verification only answers with the configured verify token.
 */
@RestController
class WhatsAppWebhookController {

	static final String PATH = "/webhooks/whatsapp";

	private static final Logger log = LoggerFactory.getLogger(WhatsAppWebhookController.class);

	private final OmaProperties.Whatsapp config;

	private final WhatsAppWebhookService service;

	private final JsonMapper json;

	WhatsAppWebhookController(OmaProperties properties, WhatsAppWebhookService service, JsonMapper json) {
		this.config = properties.whatsapp();
		this.service = service;
		this.json = json;
	}

	/** Meta's one-time check when the webhook URL is saved in the app dashboard. */
	@GetMapping(path = PATH, produces = MediaType.TEXT_PLAIN_VALUE)
	ResponseEntity<String> verify(@RequestParam(name = "hub.mode", required = false) String mode,
			@RequestParam(name = "hub.verify_token", required = false) String token,
			@RequestParam(name = "hub.challenge", required = false) String challenge) {
		String expected = config.verifyToken();
		if ("subscribe".equals(mode) && expected != null && !expected.isBlank() && expected.equals(token)
				&& challenge != null) {
			return ResponseEntity.ok(challenge);
		}
		return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
	}

	@PostMapping(PATH)
	ResponseEntity<Void> receive(@RequestHeader(name = "X-Hub-Signature-256", required = false) String signature,
			@RequestBody byte[] body) {
		if (!WebhookSignature.valid(config.appSecret(), body, signature)) {
			log.warn("Rejected a WhatsApp webhook with a missing or invalid signature");
			return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
		}
		try {
			service.handle(json.readTree(body));
		}
		catch (JacksonException ex) {
			return ResponseEntity.badRequest().build();
		}
		// Any other exception gives a 500, and Meta retries the delivery later.
		return ResponseEntity.ok().build();
	}

}
