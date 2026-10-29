package com.oma.support;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

public class MutableClock extends Clock {

	private volatile Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);

	public void advance(Duration duration) {
		now = now.plus(duration);
	}

	public void reset() {
		now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
	}

	@Override
	public Instant instant() {
		return now;
	}

	@Override
	public ZoneId getZone() {
		return ZoneOffset.UTC;
	}

	@Override
	public Clock withZone(ZoneId zone) {
		return this;
	}

}
