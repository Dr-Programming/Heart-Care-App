package com.heartcare.common.exception;

import java.io.Serial;

/**
 * 403 with a machine-readable code alongside the human message, for cases a client must react
 * to specifically (e.g. PASSWORD_CHANGE_REQUIRED routes a researcher to the change screen).
 */
public class ForbiddenException extends RuntimeException {

    @Serial
    private static final long serialVersionUID = 1L;

    private final String code;

    public ForbiddenException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
