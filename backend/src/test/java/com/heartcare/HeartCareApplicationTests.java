package com.heartcare;

import org.junit.jupiter.api.Test;

class HeartCareApplicationTests extends AbstractIntegrationTest {

    @Test
    void contextLoads() {
        // Verifies the Spring context starts and connects to a real PostgreSQL
        // (via Testcontainers + @ServiceConnection) with Flyway enabled.
    }
}
