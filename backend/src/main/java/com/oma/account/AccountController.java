package com.oma.account;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
class AccountController {

	private final AccountRepository accounts;

	private final SupabaseAuthAdminClient authAdmin;

	private final TransactionTemplate tx;

	AccountController(AccountRepository accounts, SupabaseAuthAdminClient authAdmin, TransactionTemplate tx) {
		this.accounts = accounts;
		this.authAdmin = authAdmin;
		this.tx = tx;
	}

	record ProfileResponse(String id, String email, String displayName) {
	}

	record UpdateProfileRequest(@NotBlank @Size(max = 80) String displayName) {
	}

	record DeletionResponse(boolean appDataDeleted, boolean authAccountDeleted) {
	}

	@GetMapping
	ProfileResponse get(CurrentUser user) {
		return new ProfileResponse(user.id().toString(), user.email(),
				accounts.findDisplayName(user.id()).orElse(null));
	}

	@PatchMapping
	ProfileResponse update(CurrentUser user, @Valid @RequestBody UpdateProfileRequest request) {
		accounts.updateDisplayName(user.id(), request.displayName().strip());
		return get(user);
	}

	/** Deletes all of the caller's data, then (if configured) their Supabase Auth user. */
	@DeleteMapping
	DeletionResponse delete(CurrentUser user) {
		tx.executeWithoutResult(status -> accounts.delete(user.id()));
		return new DeletionResponse(true, authAdmin.deleteUser(user.id()));
	}

}
