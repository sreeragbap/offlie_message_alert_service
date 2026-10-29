package com.oma.alert;

public enum AlertChannel {

	/** The user's own phone sends the SMS through the system composer after the user confirms. */
	DEVICE_SMS,

	/** The backend sends the SMS through an {@link com.oma.sms.SmsGateway}. Off in the MVP. */
	SERVER_SMS

}
