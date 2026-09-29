package com.heartcare.research.auth;

import com.heartcare.research.model.Researcher;
import com.heartcare.research.model.ResearcherGrant;

/**
 * The verified researcher, their current grant and the suppression threshold, resolved fresh
 * from the database for every request by {@link ResearchAccessGuard}. Controllers take it as a
 * request attribute rather than trusting anything in the token beyond the researcher id.
 */
public record ResearchContext(Researcher researcher, ResearcherGrant grant, int minGroupSize) {

    public static final String ATTR = "com.heartcare.research.context";
}
