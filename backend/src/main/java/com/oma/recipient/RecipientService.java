package com.oma.recipient;

import java.util.List;
import java.util.UUID;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.oma.common.ApiException;

@Service
class RecipientService {

	private final RecipientRepository recipients;

	RecipientService(RecipientRepository recipients) {
		this.recipients = recipients;
	}

	record Changes(String displayName, String phone, Boolean alertsEnabled, Boolean optedOut) {
	}

	List<Recipient> list(UUID userId) {
		return recipients.findAll(userId);
	}

	Recipient get(UUID userId, UUID id) {
		return recipients.find(userId, id).orElseThrow(() -> ApiException.notFound("Recipient"));
	}

	@Transactional
	Recipient create(UUID userId, String displayName, String phone, boolean alertsEnabled) {
		String e164 = PhoneNumbers.toE164(phone);
		try {
			return recipients.insert(userId, displayName.strip(), e164, alertsEnabled);
		}
		catch (DuplicateKeyException ex) {
			throw duplicate();
		}
	}

	@Transactional
	Recipient update(UUID userId, UUID id, Changes changes) {
		Recipient current = recipients.findForUpdate(userId, id).orElseThrow(() -> ApiException.notFound("Recipient"));
		Recipient updated = new Recipient(current.id(), current.userId(),
				changes.displayName() != null ? changes.displayName().strip() : current.displayName(),
				changes.phone() != null ? PhoneNumbers.toE164(changes.phone()) : current.phoneE164(),
				changes.alertsEnabled() != null ? changes.alertsEnabled() : current.alertsEnabled(),
				changes.optedOut() != null ? changes.optedOut() : current.optedOut(), current.createdAt(),
				current.updatedAt());
		try {
			updated = recipients.update(updated);
		}
		catch (DuplicateKeyException ex) {
			throw duplicate();
		}
		if (!updated.canReceiveAlerts()) {
			recipients.cancelOpenAlerts(userId, id,
					updated.optedOut() ? "Recipient opted out" : "Alerts disabled for recipient");
		}
		else if (!updated.phoneE164().equals(current.phoneE164())) {
			recipients.cancelOpenAlerts(userId, id, "Recipient phone number changed");
		}
		return updated;
	}

	@Transactional
	void delete(UUID userId, UUID id) {
		recipients.cancelOpenAlerts(userId, id, "Recipient removed");
		if (!recipients.delete(userId, id)) {
			throw ApiException.notFound("Recipient");
		}
	}

	private static ApiException duplicate() {
		return new ApiException(HttpStatus.CONFLICT, "DUPLICATE_RECIPIENT", "You already added this phone number");
	}

}
