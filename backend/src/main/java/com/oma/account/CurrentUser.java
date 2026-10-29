package com.oma.account;

import java.util.UUID;

/** The authenticated caller, resolved from the Supabase access token's {@code sub} claim. */
public record CurrentUser(UUID id, String email) {
}
