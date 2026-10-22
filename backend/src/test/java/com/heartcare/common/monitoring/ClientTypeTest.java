// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.common.monitoring;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ClientTypeTest {

    @Test
    void classifiesByRolePartitionedPrefix() {
        assertThat(ClientType.fromPath("/api/v1/admin/users/abc")).isEqualTo(ClientType.ADMIN);
        assertThat(ClientType.fromPath("/api/v1/admin/auth/login")).isEqualTo(ClientType.ADMIN);
        assertThat(ClientType.fromPath("/api/v1/research/analytics/trend")).isEqualTo(ClientType.RESEARCHER);
        assertThat(ClientType.fromPath("/api/v1/sync")).isEqualTo(ClientType.MOBILE);
        assertThat(ClientType.fromPath("/api/v1/auth/login")).isEqualTo(ClientType.MOBILE);
        assertThat(ClientType.fromPath("/api/v1/health")).isEqualTo(ClientType.PUBLIC);
    }

    @Test
    void lookalikePrefixesAreNotMisattributed() {
        assertThat(ClientType.fromPath("/api/v1/administrator")).isEqualTo(ClientType.MOBILE);
        assertThat(ClientType.fromPath("/api/v1/healthz")).isEqualTo(ClientType.MOBILE);
        assertThat(ClientType.fromPath("/actuator/prometheus")).isEqualTo(ClientType.OTHER);
        assertThat(ClientType.fromPath(null)).isEqualTo(ClientType.OTHER);
    }

    @Test
    void mapsRolesToApps() {
        assertThat(ClientType.fromRole("PATIENT")).isEqualTo(ClientType.MOBILE);
        assertThat(ClientType.fromRole("ADMIN")).isEqualTo(ClientType.ADMIN);
        assertThat(ClientType.fromRole("RESEARCHER")).isEqualTo(ClientType.RESEARCHER);
        assertThat(ClientType.fromRole("???")).isEqualTo(ClientType.OTHER);
    }
}
