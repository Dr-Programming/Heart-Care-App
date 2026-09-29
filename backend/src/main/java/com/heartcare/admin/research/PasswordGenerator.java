package com.heartcare.admin.research;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;

/** Random passwords for admin-issued researcher credentials. */
@Component
public class PasswordGenerator {

    /** No 0/O/o, 1/l/I: these are read aloud or retyped from a message. */
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
    static final int LENGTH = 16;

    private final SecureRandom random = new SecureRandom();

    public String generate() {
        StringBuilder sb = new StringBuilder(LENGTH + 3);
        for (int i = 0; i < LENGTH; i++) {
            if (i > 0 && i % 4 == 0) {
                sb.append('-');
            }
            sb.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }
}
