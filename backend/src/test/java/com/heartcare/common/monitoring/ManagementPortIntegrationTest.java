package com.heartcare.common.monitoring;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Actuator must answer on the management port (scraped by Prometheus) and never on the API port,
 * which ngrok exposes to the internet.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "management.server.port=0")
class ManagementPortIntegrationTest {

    @ServiceConnection
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer(DockerImageName.parse("postgres:16-alpine"));

    static {
        POSTGRES.start();
    }

    @Value("${local.server.port}")
    int apiPort;

    @Value("${local.management.port}")
    int managementPort;

    private final HttpClient http = HttpClient.newHttpClient();

    @Test
    void prometheusIsServedOnManagementPortWithClientTag() throws Exception {
        get(apiPort, "/api/v1/health");

        HttpResponse<String> response = get(managementPort, "/actuator/prometheus");

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("http_server_requests_seconds_bucket");
        assertThat(response.body()).contains("client=\"public\"");
        assertThat(response.body()).contains("heartcare_active_users");
    }

    @Test
    void activityTimelineIsServedOnManagementPort() throws Exception {
        get(apiPort, "/api/v1/health");

        HttpResponse<String> response = get(managementPort, "/actuator/scc-activity");

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("\"category\":\"health_check\"");
    }

    @Test
    void actuatorIsNotReachableOnApiPort() throws Exception {
        assertThat(get(apiPort, "/actuator/prometheus").statusCode()).isIn(401, 403, 404);
        assertThat(get(apiPort, "/actuator/scc-activity").statusCode()).isIn(401, 403, 404);
    }

    private HttpResponse<String> get(int port, String path) throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).build(),
                HttpResponse.BodyHandlers.ofString());
    }
}
