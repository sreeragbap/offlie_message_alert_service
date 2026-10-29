package com.oma.alert;

/** An alert with the recipient details needed to display or send it (recipient may have been removed). */
public record AlertView(Alert alert, String recipientName, String recipientPhoneE164) {
}
