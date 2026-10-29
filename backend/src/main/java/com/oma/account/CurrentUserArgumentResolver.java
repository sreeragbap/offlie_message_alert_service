package com.oma.account;

import java.util.UUID;

import org.springframework.core.MethodParameter;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import com.oma.common.ApiException;

/**
 * Injects {@link CurrentUser} into controller methods and makes sure the matching
 * {@code app.user_account} row exists (first request after sign-up creates it).
 */
@Component
class CurrentUserArgumentResolver implements HandlerMethodArgumentResolver {

	private final AccountRepository accounts;

	CurrentUserArgumentResolver(AccountRepository accounts) {
		this.accounts = accounts;
	}

	@Override
	public boolean supportsParameter(MethodParameter parameter) {
		return parameter.getParameterType().equals(CurrentUser.class);
	}

	@Override
	public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer,
			NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
		Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
		if (authentication == null || !(authentication.getPrincipal() instanceof Jwt jwt)) {
			throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Sign in required");
		}
		UUID id;
		try {
			id = UUID.fromString(jwt.getSubject());
		}
		catch (IllegalArgumentException | NullPointerException ex) {
			throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_TOKEN", "Invalid access token");
		}
		accounts.ensureExists(id);
		return new CurrentUser(id, jwt.getClaimAsString("email"));
	}

}
