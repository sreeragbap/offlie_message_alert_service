package com.oma.alert;

public enum TriggerSource {

	/** The user asked for the alert in the app. */
	USER_TRIGGERED,

	/** WhatsApp did not report delivery of a message sent through the WhatsApp Business Platform in time. */
	DELIVERY_TIMEOUT

}
