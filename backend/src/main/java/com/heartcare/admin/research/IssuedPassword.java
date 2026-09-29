package com.heartcare.admin.research;

/**
 * Returned exactly once, from create and reset. The plaintext is never stored and no endpoint can
 * show it again; the admin passes it to the researcher out of band.
 */
public record IssuedPassword(ResearcherView researcher, String password) {
}
