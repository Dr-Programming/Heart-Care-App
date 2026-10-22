// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.common.monitoring;

/**
 * Which app a request came from, derived from the route rather than a client-supplied header.
 * The prefixes are role-partitioned in SecurityConfig: admin routes need an ADMIN token, research
 * routes a RESEARCHER token, and every other /api/v1 route a PATIENT token, which only the mobile
 * app holds. Used as a low-cardinality metric tag, so the set of values must stay fixed.
 */
public enum ClientType {
    ADMIN("admin"),
    RESEARCHER("researcher"),
    MOBILE("mobile"),
    PUBLIC("public"),
    OTHER("other");

    private final String tag;

    ClientType(String tag) {
        this.tag = tag;
    }

    public String tag() {
        return tag;
    }

    public static ClientType fromPath(String path) {
        if (path == null || !path.startsWith("/api/v1/")) {
            return OTHER;
        }
        if (path.startsWith("/api/v1/admin/")) {
            return ADMIN;
        }
        if (path.startsWith("/api/v1/research/")) {
            return RESEARCHER;
        }
        if (path.equals("/api/v1/health") || path.startsWith("/api/v1/health/")) {
            return PUBLIC;
        }
        return MOBILE;
    }

    /** Maps the JWT role claim to the app that holds such tokens. */
    public static ClientType fromRole(String role) {
        if (role == null) {
            return OTHER;
        }
        return switch (role) {
            case "ADMIN" -> ADMIN;
            case "RESEARCHER" -> RESEARCHER;
            case "PATIENT" -> MOBILE;
            default -> OTHER;
        };
    }
}
