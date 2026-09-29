package com.heartcare.research.anon;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.UUID;

/**
 * Stable, researcher-specific stand-ins for patient ids: {@code P-} + 8 base32 characters of
 * HMAC-SHA256(secret, researcherId:userId).
 *
 * <p>Keyed per researcher so two researchers' exports cannot be joined on the pseudonym, and
 * keyed by a server secret so a pseudonym cannot be reversed by hashing candidate user ids.
 * 40 bits is ample against collisions at this app's scale (birthday bound ~1M patients).
 */
@Component
public class Pseudonymizer {

    private static final int MIN_SECRET_BYTES = 32;
    private static final char[] BASE32 = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();

    private final SecretKeySpec key;

    public Pseudonymizer(@Value("${app.research.pseudonym-secret}") String secret) {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("app.research.pseudonym-secret (RESEARCH_PSEUDONYM_SECRET) must be at least "
                    + MIN_SECRET_BYTES + " bytes; generate one with: openssl rand -base64 48");
        }
        this.key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    public String of(UUID researcherId, UUID userId) {
        byte[] digest;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(key);
            digest = mac.doFinal((researcherId + ":" + userId).getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HmacSHA256 unavailable", e);
        }
        // 8 symbols x 5 bits = the first 40 bits of the digest.
        long bits = 0;
        for (int i = 0; i < 5; i++) {
            bits = (bits << 8) | (digest[i] & 0xFF);
        }
        char[] out = new char[8];
        for (int i = 7; i >= 0; i--) {
            out[i] = BASE32[(int) (bits & 31)];
            bits >>>= 5;
        }
        return "P-" + new String(out);
    }
}
