package com.heartcare.common.exception;

/**
 * Login refused because the account is inside its lockout window. Distinct from
 * {@link UnauthorizedException} so the client can say "try again in N minutes" instead of
 * "wrong PIN" — the user's PIN may well be right.
 */
public class AccountLockedException extends RuntimeException {

    public AccountLockedException(String message) {
        super(message);
    }
}
