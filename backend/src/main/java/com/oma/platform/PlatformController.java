package com.oma.platform;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class PlatformController {

	@GetMapping("/api/v1/platforms")
	List<PlatformCatalog.PlatformInfo> list() {
		return PlatformCatalog.ALL;
	}

}
