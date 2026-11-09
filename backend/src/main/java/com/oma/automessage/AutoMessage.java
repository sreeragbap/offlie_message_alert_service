package com.oma.automessage;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.EnumSet;
import java.util.Set;
import java.util.UUID;

/**
 * A WhatsApp message the backend sends to one recipient by itself: repeatedly at {@code sendTime} on
 * {@code repeatDays}, or once a minute after saving when {@code sendTime} is null.
 *
 * @param repeatDays bit 0 = Monday ... bit 6 = Sunday
 */
public record AutoMessage(UUID recipientId, UUID userId, boolean enabled, String messageText, LocalTime sendTime,
		int repeatDays, ZoneId timeZone, int smsAfterMinutes, Instant nextRunAt, Instant lastRunAt,
		UUID lastMessageId, String lastError) {

	public static final String DEFAULT_TEXT = "Hi {name}, this is an automatic message from {sender}.";

	public static final ZoneId DEFAULT_ZONE = ZoneId.of("Asia/Kolkata");

	public static final int ALL_DAYS = 0b111_1111;

	public static final int DEFAULT_SMS_AFTER_MINUTES = 1;

	/** Settings shown for a recipient that has none saved yet. */
	static AutoMessage none(UUID userId, UUID recipientId) {
		return new AutoMessage(recipientId, userId, false, null, null, ALL_DAYS, DEFAULT_ZONE,
				DEFAULT_SMS_AFTER_MINUTES, null, null, null, null);
	}

	public boolean repeating() {
		return sendTime != null;
	}

	public String text() {
		return messageText != null ? messageText : DEFAULT_TEXT;
	}

	public String render(String recipientName, String senderName) {
		return text().replace("{name}", recipientName).replace("{sender}", senderName);
	}

	public Set<DayOfWeek> days() {
		return days(repeatDays);
	}

	static Set<DayOfWeek> days(int mask) {
		Set<DayOfWeek> days = EnumSet.noneOf(DayOfWeek.class);
		for (DayOfWeek day : DayOfWeek.values()) {
			if ((mask & bit(day)) != 0) {
				days.add(day);
			}
		}
		return days;
	}

	static int mask(Set<DayOfWeek> days) {
		return days.stream().mapToInt(AutoMessage::bit).reduce(0, (a, b) -> a | b);
	}

	private static int bit(DayOfWeek day) {
		return 1 << (day.getValue() - 1);
	}

	/** First {@code sendTime} on one of {@code repeatDays} strictly after {@code after}, in {@code zone}. */
	static Instant nextRun(LocalTime sendTime, int repeatDays, ZoneId zone, Instant after) {
		LocalDate today = after.atZone(zone).toLocalDate();
		for (int i = 0; i <= 7; i++) {
			LocalDate date = today.plusDays(i);
			if ((repeatDays & bit(date.getDayOfWeek())) == 0) {
				continue;
			}
			Instant candidate = ZonedDateTime.of(date, sendTime, zone).toInstant();
			if (candidate.isAfter(after)) {
				return candidate;
			}
		}
		throw new IllegalArgumentException("No day selected");
	}

}
