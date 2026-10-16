package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.dto.Common.SourceStatus;
import com.heartcare.monitoring.dto.NetworkResponse;
import com.heartcare.monitoring.prometheus.PromQueries;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import tools.jackson.databind.JsonNode;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Local web traffic versus mobile traffic. "Mobile" is the backend's `client` tag, derived from the
 * role-guarded route rather than from any header a caller could set.
 */
@Service
public class NetworkService {

    static final Duration CHART_RANGE = Duration.ofMinutes(15);

    private final Metrics metrics;
    private final HostReader host;
    private final TtlCache cache;
    private final RestClient http;
    private final String ngrokApiUrl;

    public NetworkService(Metrics metrics, HostReader host, TtlCache cache,
                          RestClient.Builder builder, SccProperties properties) {
        this.metrics = metrics;
        this.host = host;
        this.cache = cache;
        this.http = builder.build();
        this.ngrokApiUrl = properties.ngrokApiUrl();
    }

    public NetworkResponse network() {
        return cache.get("network", this::compute);
    }

    private NetworkResponse compute() {
        Map<String, Double> rps = metrics.byLabel(PromQueries.RPS_BY_CLIENT, "client");
        Map<String, Double> totals = metrics.byLabel(PromQueries.REQUESTS_BY_CLIENT, "client");
        Map<String, Double> serverErrors = metrics.byLabel(PromQueries.SERVER_ERRORS_BY_CLIENT, "client");
        Map<String, Double> clientErrors = metrics.byLabel(PromQueries.CLIENT_ERRORS_BY_CLIENT, "client");
        boolean hostUp = host.hostAvailable();

        List<ChartSeries> hostTraffic = hostUp
                ? List.of(metrics.series("received B/s", PromQueries.HOST_NET_RX_BPS, CHART_RANGE),
                        metrics.series("sent B/s", PromQueries.HOST_NET_TX_BPS, CHART_RANGE))
                : List.of();

        return new NetworkResponse(
                ngrok(),
                rps.getOrDefault("admin", 0.0) + rps.getOrDefault("researcher", 0.0),
                rps.getOrDefault("mobile", 0.0),
                Math.round(totals.getOrDefault("mobile", 0.0)),
                Math.round(serverErrors.getOrDefault("mobile", 0.0)),
                Math.round(clientErrors.getOrDefault("mobile", 0.0)),
                Math.round(serverErrors.getOrDefault("admin", 0.0) + serverErrors.getOrDefault("researcher", 0.0)),
                hostUp ? SourceStatus.OK : SourceStatus.UNAVAILABLE,
                hostUp ? metrics.value(PromQueries.HOST_NET_RX_BPS) : null,
                hostUp ? metrics.value(PromQueries.HOST_NET_TX_BPS) : null,
                metrics.breakdown(PromQueries.REQUESTS_BY_CLIENT, "client"),
                metrics.seriesByLabel(PromQueries.RPS_BY_CLIENT, "client", CHART_RANGE),
                hostTraffic,
                Instant.now());
    }

    /** Reads the local ngrok agent's API (http://127.0.0.1:4040/api/tunnels on the host). */
    public NetworkResponse.Ngrok ngrok() {
        return cache.get("ngrok", this::readNgrok);
    }

    private NetworkResponse.Ngrok readNgrok() {
        JsonNode body;
        try {
            body = http.get().uri(ngrokApiUrl).retrieve().body(JsonNode.class);
        } catch (RestClientException ex) {
            return new NetworkResponse.Ngrok("UNREACHABLE", null, null,
                    "ngrok agent API not reachable at " + ngrokApiUrl);
        }
        if (body == null || body.path("tunnels").isEmpty()) {
            return new NetworkResponse.Ngrok("OFFLINE", null, null, "ngrok is running but has no open tunnel");
        }
        String url = null;
        long requests = 0;
        for (JsonNode tunnel : body.path("tunnels")) {
            String publicUrl = tunnel.path("public_url").asString();
            if (url == null || publicUrl.startsWith("https")) {
                url = publicUrl;
            }
            requests += tunnel.path("metrics").path("http").path("count").asLong(0);
        }
        return new NetworkResponse.Ngrok("ONLINE", url, requests, "Tunnel open");
    }
}
