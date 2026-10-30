package com.oma.whatsapp;

import java.time.Clock;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.oma.config.OmaProperties;

/** Deletes WhatsApp messages and status events older than the alert retention period. */
@Component
class WhatsAppRetention {

	private static final Logger log = LoggerFactory.getLogger(WhatsAppRetention.class);

	private final WhatsAppMessageRepository messages;

	private final OmaProperties properties;

	private final Clock clock;

	WhatsAppRetention(WhatsAppMessageRepository messages, OmaProperties properties, Clock clock) {
		this.messages = messages;
		this.properties = properties;
		this.clock = clock;
	}

	@Scheduled(cron = "${oma.scheduler.retention-cron:0 30 3 * * *}")
	void purge() {
		int deleted = messages.deleteCreatedBefore(clock.instant().minus(properties.alerts().retention()));
		if (deleted > 0) {
			log.info("Retention: deleted {} old WhatsApp message(s)", deleted);
		}
	}

}
