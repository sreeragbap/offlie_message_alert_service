package com.oma.common;

import org.springframework.http.HttpStatus;

/**
 * A client-facing error with a stable machine-readable {@code code}. The message is safe to show to users.
 */
public class ApiException extends RuntimeException {

	private final HttpStatus status;

	private final String code;

	public ApiException(HttpStatus status, String code, String message) {
		super(message);
		this.status = status;
		this.code = code;
	}

	public static ApiException notFound(String what) {
		return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", what + " not found");
	}

	public HttpStatus status() {
		return status;
	}

	public String code() {
		return code;
	}

}
