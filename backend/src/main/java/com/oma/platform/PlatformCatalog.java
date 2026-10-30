package com.oma.platform;

import java.util.List;
import java.util.stream.Stream;

import com.oma.alert.Platform;

/**
 * What each messaging platform actually supports, based on the Phase 0 feasibility study
 * (docs/01-feasibility-and-architecture.md). The app shows this instead of implying monitoring works.
 */
public final class PlatformCatalog {

	public enum AutomaticDetection {

		/** The platform offers no way for another app to learn delivery status. */
		NOT_AVAILABLE,
		/** Possible only for messages a business sends through the platform's business API. */
		BUSINESS_ACCOUNTS_ONLY

	}

	public record PlatformInfo(Platform id, String name, boolean manualAlerts, AutomaticDetection automaticDetection,
			boolean automaticDetectionConnected, String explanation) {
	}

	/** @param whatsappConnected whether this deployment has a WhatsApp Business number configured */
	public static List<PlatformInfo> all(boolean whatsappConnected) {
		PlatformInfo whatsapp = whatsappConnected
				? new PlatformInfo(Platform.WHATSAPP, "WhatsApp", true, AutomaticDetection.BUSINESS_ACCOUNTS_ONLY, true,
						"Messages you send from the WhatsApp tab go out from your business number and are tracked: "
								+ "if one isn't delivered in time, your relay phone texts the person. Chats in your "
								+ "personal WhatsApp still can't be monitored; send a manual alert for those.")
				: new PlatformInfo(Platform.WHATSAPP, "WhatsApp", true, AutomaticDetection.BUSINESS_ACCOUNTS_ONLY, false,
						"WhatsApp shares delivery status only for messages a business sends through the WhatsApp "
								+ "Business Platform. Personal chats can't be monitored by any app, so send a manual alert.");
		return Stream.concat(Stream.of(whatsapp), OTHERS.stream()).toList();
	}

	private static final List<PlatformInfo> OTHERS = List.of(
			new PlatformInfo(Platform.TELEGRAM, "Telegram", true, AutomaticDetection.NOT_AVAILABLE, false,
					"Telegram does not share delivery status with other apps. Send a manual alert."),
			new PlatformInfo(Platform.MESSENGER, "Messenger", true, AutomaticDetection.BUSINESS_ACCOUNTS_ONLY, false,
					"Only Facebook Pages receive delivery receipts. Personal chats can't be monitored."),
			new PlatformInfo(Platform.INSTAGRAM, "Instagram", true, AutomaticDetection.NOT_AVAILABLE, false,
					"Instagram does not share delivery status with other apps."),
			new PlatformInfo(Platform.SIGNAL, "Signal", true, AutomaticDetection.NOT_AVAILABLE, false,
					"Signal has no public API for other apps."),
			new PlatformInfo(Platform.OTHER, "Other app", true, AutomaticDetection.NOT_AVAILABLE, false,
					"Send a manual alert for any other messaging app."));

	private PlatformCatalog() {
	}

}
