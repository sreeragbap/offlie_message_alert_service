package com.oma.platform;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.oma.whatsapp.WhatsAppService;

@RestController
class PlatformController {

	private final WhatsAppService whatsApp;

	PlatformController(WhatsAppService whatsApp) {
		this.whatsApp = whatsApp;
	}

	@GetMapping("/api/v1/platforms")
	List<PlatformCatalog.PlatformInfo> list() {
		return PlatformCatalog.all(whatsApp.configured());
	}

}
