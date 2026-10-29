package com.oma.alert;

public enum TriggerSource {

	/** The user asked for the alert in the app. */
	USER_TRIGGERED,

	/** A platform integration reported no delivery within the configured time (future: WhatsApp Business). */
	DELIVERY_TIMEOUT

}
