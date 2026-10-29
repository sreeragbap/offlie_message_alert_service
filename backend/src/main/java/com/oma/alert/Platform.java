package com.oma.alert;

/** The messaging platform the user says their unanswered message was sent on. A label only. */
public enum Platform {

	WHATSAPP("WhatsApp"), TELEGRAM("Telegram"), MESSENGER("Messenger"), INSTAGRAM("Instagram"), SIGNAL("Signal"),
	SMS("SMS"), OTHER("another messaging app");

	private final String displayName;

	Platform(String displayName) {
		this.displayName = displayName;
	}

	public String displayName() {
		return displayName;
	}

}
