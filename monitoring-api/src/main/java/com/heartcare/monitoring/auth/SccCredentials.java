package com.heartcare.monitoring.auth;

import com.heartcare.monitoring.config.SccProperties;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * The single SCC administrator account, configured through SCC_ADMIN_USERNAME / SCC_ADMIN_PASSWORD.
 * The password is hashed once at startup so the plaintext is not kept in a field afterwards, and
 * every check runs bcrypt, so timing does not reveal whether the username was right.
 */
@Component
public class SccCredentials {

    static final int MIN_PASSWORD_LENGTH = 12;

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final byte[] username;
    private final String passwordHash;

    public SccCredentials(SccProperties properties) {
        String user = properties.admin().username();
        String password = properties.admin().password();
        if (user == null || user.isBlank()) {
            throw new IllegalStateException("SCC_ADMIN_USERNAME must be set (see .env.example)");
        }
        if (password == null || password.length() < MIN_PASSWORD_LENGTH) {
            throw new IllegalStateException(
                    "SCC_ADMIN_PASSWORD must be at least " + MIN_PASSWORD_LENGTH + " characters");
        }
        this.username = user.getBytes(StandardCharsets.UTF_8);
        this.passwordHash = encoder.encode(password);
    }

    public boolean matches(String user, String password) {
        boolean passwordOk = password != null && encoder.matches(password, passwordHash);
        boolean userOk = user != null && MessageDigest.isEqual(username, user.getBytes(StandardCharsets.UTF_8));
        return userOk && passwordOk;
    }
}
