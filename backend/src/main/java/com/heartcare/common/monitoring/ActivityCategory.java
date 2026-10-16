package com.heartcare.common.monitoring;

import java.util.List;

/**
 * Turns a matched route into a human-readable activity for the System Control Centre timeline.
 * Categories are a fixed set (they are also a metric tag), and labels never include ids, query
 * parameters or anything from the request body.
 */
public record ActivityCategory(String key, String label) {

    private record Rule(String method, String prefix, ActivityCategory category) {
        boolean matches(String m, String pattern) {
            return (method == null || method.equals(m)) && pattern.startsWith(prefix);
        }
    }

    private static ActivityCategory of(String key, String label) {
        return new ActivityCategory(key, label);
    }

    // First match wins, so more specific prefixes come first.
    private static final List<Rule> RULES = List.of(
            new Rule("POST", "/api/v1/admin/auth/login", of("admin_login", "Admin signed in")),
            new Rule(null, "/api/v1/admin/auth", of("admin_session", "Admin session check")),
            new Rule(null, "/api/v1/admin/users", of("admin_users", "Admin accessed user management")),
            new Rule(null, "/api/v1/admin/researchers", of("admin_researchers", "Admin managed researcher accounts")),
            new Rule(null, "/api/v1/admin/research-activity", of("admin_audit", "Admin reviewed research audit log")),
            new Rule(null, "/api/v1/admin/research-settings", of("admin_settings", "Admin accessed research settings")),
            new Rule(null, "/api/v1/admin/stats", of("admin_dashboard", "Admin viewed dashboard")),
            new Rule(null, "/api/v1/admin/", of("admin_clinical", "Admin viewed clinical overview")),

            new Rule("POST", "/api/v1/research/auth/login", of("research_login", "Researcher signed in")),
            new Rule(null, "/api/v1/research/auth", of("research_session", "Researcher account action")),
            new Rule(null, "/api/v1/research/catalog", of("research_catalog", "Researcher browsed data catalogue")),
            new Rule(null, "/api/v1/research/cohorts", of("research_cohorts", "Researcher worked with cohorts")),
            new Rule(null, "/api/v1/research/analytics", of("research_analysis", "Researcher ran an analysis")),
            new Rule(null, "/api/v1/research/records", of("research_records", "Researcher searched records")),

            new Rule("POST", "/api/v1/auth/login", of("mobile_login", "Mobile user signed in")),
            new Rule("POST", "/api/v1/auth/register", of("mobile_register", "Mobile user registered")),
            new Rule("POST", "/api/v1/auth/refresh", of("mobile_refresh", "Mobile user refreshed session")),
            new Rule(null, "/api/v1/auth", of("mobile_account", "Mobile user account action")),
            new Rule(null, "/api/v1/sync", of("mobile_sync", "Mobile user synchronised data")),
            new Rule("POST", "/api/v1/vitals", of("mobile_vitals", "Mobile user recorded vitals")),
            new Rule("POST", "/api/v1/symptoms", of("mobile_symptoms", "Mobile user recorded symptoms")),
            new Rule("POST", "/api/v1/activities", of("mobile_activity", "Mobile user logged activity")),
            new Rule("POST", "/api/v1/medications/{medicationId}/doses", of("mobile_dose", "Mobile user logged a dose")),
            new Rule(null, "/api/v1/medications", of("mobile_medications", "Mobile user managed medications")),
            new Rule(null, "/api/v1/patients", of("mobile_profile", "Mobile user accessed profile")),
            new Rule(null, "/api/v1/health", of("health_check", "Health check")),
            new Rule(null, "/api/v1/", of("mobile_view", "Mobile user viewed records")));

    private static final ActivityCategory OTHER = of("other", "Other request");

    /**
     * @param pattern the matched route template (e.g. {@code /api/v1/admin/users/{id}}), never the
     *                raw URI, so ids cannot leak into the label
     */
    public static ActivityCategory classify(String method, String pattern) {
        if (pattern == null) {
            return OTHER;
        }
        for (Rule rule : RULES) {
            if (rule.matches(method, pattern)) {
                return rule.category();
            }
        }
        return OTHER;
    }
}
