package com.heartcare.admin;

import com.heartcare.admin.model.AdminUser;
import com.heartcare.admin.repository.AdminUserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Creates the admin account named by ADMIN_USERNAME / ADMIN_PASSWORD on startup, if it does not
 * exist yet. This is the only way an admin row is ever created; there is no sign-up endpoint.
 *
 * <p>An existing account is left untouched, so changing ADMIN_PASSWORD later does not silently
 * reset it. Delete the row (or pick a new username) to rotate.
 */
@Component
public class AdminBootstrap implements ApplicationRunner {

    static final int MIN_PASSWORD_LENGTH = 12;

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrap.class);

    private final AdminUserRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final String username;
    private final String password;

    public AdminBootstrap(AdminUserRepository repository,
                          PasswordEncoder passwordEncoder,
                          @Value("${app.admin.username:}") String username,
                          @Value("${app.admin.password:}") String password) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.username = username == null ? "" : username.trim();
        this.password = password == null ? "" : password;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (username.isEmpty() || password.isEmpty()) {
            log.info("ADMIN_USERNAME/ADMIN_PASSWORD not set; no admin account bootstrapped");
            return;
        }
        if (password.length() < MIN_PASSWORD_LENGTH) {
            // Fail loudly: an admin panel over health data behind a short password is worse
            // than no admin panel.
            throw new IllegalStateException(
                    "ADMIN_PASSWORD must be at least " + MIN_PASSWORD_LENGTH + " characters");
        }
        if (repository.existsByUsername(username)) {
            return;
        }
        repository.save(new AdminUser(username, passwordEncoder.encode(password)));
        log.info("Bootstrapped admin account '{}'", username);
    }
}
