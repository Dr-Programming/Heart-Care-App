package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.ActivityResponse;
import com.heartcare.monitoring.dto.Common.SourceStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import tools.jackson.databind.JsonNode;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * The activity timeline, read from the backend's {@code /actuator/scc-activity} on its internal
 * management port. The backend anonymises events before they leave it; this service only relays.
 */
@Service
public class ActivityService {

    static final int MAX_EVENTS = 100;

    private final RestClient http;
    private final String endpoint;
    private final TtlCache cache;

    public ActivityService(RestClient.Builder builder, SccProperties properties, TtlCache cache) {
        this.http = builder.build();
        this.endpoint = properties.backendManagementUrl() + "/actuator/scc-activity";
        this.cache = cache;
    }

    public ActivityResponse activity() {
        return cache.get("activity", this::compute);
    }

    private ActivityResponse compute() {
        JsonNode body;
        try {
            body = http.get().uri(endpoint).retrieve().body(JsonNode.class);
        } catch (RestClientException ex) {
            return new ActivityResponse(SourceStatus.UNAVAILABLE, List.of(), Map.of(), Instant.now());
        }
        List<ActivityResponse.Event> events = new ArrayList<>();
        Map<String, Long> recent = new TreeMap<>();
        Instant cutoff = Instant.now().minus(Duration.ofMinutes(5));
        if (body != null) {
            for (JsonNode e : body.path("events")) {
                Instant at = Instant.parse(e.path("at").asString());
                ActivityResponse.Event event = new ActivityResponse.Event(at,
                        e.path("client").asString(), e.path("category").asString(), e.path("label").asString(),
                        e.path("outcome").asString(), e.path("durationMs").asLong());
                if (events.size() < MAX_EVENTS) {
                    events.add(event);
                }
                if (at.isAfter(cutoff)) {
                    recent.merge(event.client(), 1L, Long::sum);
                }
            }
        }
        return new ActivityResponse(SourceStatus.OK, events, recent, Instant.now());
    }
}
