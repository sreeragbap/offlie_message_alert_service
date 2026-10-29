package com.oma.alert;

import java.util.EnumSet;
import java.util.Set;

/**
 * Lifecycle of an alert. States describe only what this system knows: e.g. {@link #SMS_ACCEPTED}
 * means the provider accepted the request, not that the phone received it.
 */
public enum AlertState {

	/** Waiting for its delay to pass. */
	SCHEDULED,
	/** Device channel: ready for the user to send from their phone. */
	DUE,
	/** Device channel: the user confirmed sending from their phone. The OS does not confirm delivery. */
	SENT_FROM_DEVICE,
	/** Server channel: claimed by a worker and being submitted to the SMS provider. */
	SENDING,
	/** Server channel: provider accepted the request. Delivery not confirmed. */
	SMS_ACCEPTED,
	/** Server channel: provider reported delivery to the handset. */
	SMS_DELIVERED,
	/** Server channel: provider rejected or failed delivery. */
	SMS_FAILED,
	/** Server channel: the outcome of a submission is unknown; never retried automatically to avoid duplicates. */
	SMS_UNKNOWN,
	/** Cancelled by the user, or because the recipient was disabled, opted out or removed. */
	CANCELLED,
	/** Not sent because a rule blocked it when it became due. */
	SKIPPED,
	/** Device channel: due but not acted on in time. */
	EXPIRED;

	/** Alerts that are still waiting to go out. */
	public static final Set<AlertState> OPEN = EnumSet.of(SCHEDULED, DUE);

	/** Alerts that did not and will not go out; they do not count towards rate limits. */
	public static final Set<AlertState> NOT_SENT = EnumSet.of(CANCELLED, SKIPPED, EXPIRED);

}
