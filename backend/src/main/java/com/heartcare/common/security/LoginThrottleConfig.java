package com.heartcare.common.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;
import java.time.Duration;

/** One throttle per sign-in realm, all on the patient lockout policy (app.auth.lockout.*). */
@Configuration
public class LoginThrottleConfig {

    private final int maxAttempts;
    private final Duration lockout;

    public LoginThrottleConfig(@Value("${app.auth.lockout.max-attempts}") int maxAttempts,
                               @Value("${app.auth.lockout.duration-minutes}") int lockoutMinutes) {
        this.maxAttempts = maxAttempts;
        this.lockout = Duration.ofMinutes(lockoutMinutes);
    }

    @Bean
    public LoginThrottle adminLoginThrottle() {
        return new LoginThrottle(maxAttempts, lockout, Clock.systemUTC());
    }

    @Bean
    public LoginThrottle researchLoginThrottle() {
        return new LoginThrottle(maxAttempts, lockout, Clock.systemUTC());
    }
}
