package com.heartcare.monitoring.service;

import com.heartcare.monitoring.common.TtlCache;
import com.heartcare.monitoring.config.SccProperties;
import com.heartcare.monitoring.dto.Common.ChartSeries;
import com.heartcare.monitoring.dto.Common.SourceStatus;
import com.heartcare.monitoring.dto.InfrastructureResponse;
import com.heartcare.monitoring.dto.InfrastructureResponse.Container;
import com.heartcare.monitoring.prometheus.PromQueries;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class InfrastructureService {

    static final Duration CHART_RANGE = Duration.ofMinutes(15);

    /**
     * The containers shown on the Infrastructure page, and how each one's status is known when
     * cAdvisor has nothing: a Prometheus `up`-style query, an HTTP probe, or "self".
     */
    record Spec(String name, String displayName, String upQuery) {
    }

    static final List<Spec> CONTAINERS = List.of(
            new Spec("heartcare-backend", "Backend API", PromQueries.BACKEND_UP),
            new Spec("heartcare-postgres", "PostgreSQL", PromQueries.PG_UP),
            new Spec("heartcare-admin-web", "Admin Frontend", null),
            new Spec("heartcare-research-web", "Researcher Frontend", null),
            new Spec("heartcare-scc-web", "System Control Centre", null),
            new Spec("heartcare-monitoring-api", "Monitoring API", null),
            new Spec("heartcare-prometheus", "Prometheus", "up{job=\"prometheus\"}"),
            new Spec("heartcare-postgres-exporter", "PostgreSQL Exporter", "up{job=\"postgresql\"}"),
            new Spec("heartcare-cadvisor", "cAdvisor", PromQueries.CADVISOR_UP));

    private final Metrics metrics;
    private final HostReader host;
    private final TtlCache cache;
    private final RestClient probeClient;
    private final Map<String, String> probes;

    public InfrastructureService(Metrics metrics, HostReader host, TtlCache cache,
                                 RestClient.Builder builder, SccProperties properties) {
        this.metrics = metrics;
        this.host = host;
        this.cache = cache;
        this.probeClient = builder.build();
        this.probes = properties.probes();
    }

    public InfrastructureResponse infrastructure() {
        return cache.get("infrastructure", this::compute);
    }

    private InfrastructureResponse compute() {
        HostReader.Reading reading = host.read();
        boolean hostUp = reading.hostAvailable();
        InfrastructureResponse.Host hostDto = hostUp
                ? new InfrastructureResponse.Host(SourceStatus.OK, reading.cpuSource(), reading.cpuPercent(),
                        reading.memoryPercent(),
                        used(metrics.value(PromQueries.HOST_MEMORY_TOTAL_BYTES), metrics.value(PromQueries.HOST_MEMORY_FREE_BYTES)),
                        metrics.value(PromQueries.HOST_MEMORY_TOTAL_BYTES),
                        metrics.value(PromQueries.HOST_DISK_PERCENT),
                        metrics.value(PromQueries.HOST_DISK_FREE_BYTES),
                        metrics.value(PromQueries.HOST_DISK_TOTAL_BYTES),
                        metrics.value(PromQueries.HOST_NET_RX_BPS),
                        metrics.value(PromQueries.HOST_NET_TX_BPS))
                : new InfrastructureResponse.Host(SourceStatus.UNAVAILABLE, reading.cpuSource(), reading.cpuPercent(),
                        null, null, null, null, null, null, null, null);

        Map<String, Double> cpu = metrics.byLabel(PromQueries.CONTAINER_CPU_PERCENT, "name");
        Map<String, Double> memory = metrics.byLabel(PromQueries.CONTAINER_MEMORY_BYTES, "name");
        boolean cadvisor = metrics.isUp(PromQueries.CADVISOR_UP) && !memory.isEmpty();

        List<Container> containers = new ArrayList<>();
        for (Spec spec : CONTAINERS) {
            // cAdvisor is opt-in: its scrape target always exists, so leave it off the list unless
            // it is actually up, rather than reporting an intentionally absent service as down.
            if (spec.upQuery() == PromQueries.CADVISOR_UP && !metrics.isUp(PromQueries.CADVISOR_UP)) {
                continue;
            }
            containers.add(status(spec, cpu.get(spec.name()), memory.get(spec.name())));
        }

        List<ChartSeries> cpuChart = new ArrayList<>();
        cpuChart.add(metrics.series(hostUp ? "host CPU %" : "Docker VM CPU %", host.cpuExpression(hostUp), CHART_RANGE));
        List<ChartSeries> memoryChart = hostUp
                ? List.of(metrics.series("host memory %", PromQueries.HOST_MEMORY_PERCENT, CHART_RANGE))
                : List.of();
        if (cadvisor) {
            cpuChart.addAll(metrics.seriesByLabel(PromQueries.CONTAINER_CPU_PERCENT, "name", CHART_RANGE));
        }
        List<ChartSeries> network = hostUp
                ? List.of(metrics.series("received B/s", PromQueries.HOST_NET_RX_BPS, CHART_RANGE),
                        metrics.series("sent B/s", PromQueries.HOST_NET_TX_BPS, CHART_RANGE))
                : List.of();

        return new InfrastructureResponse(hostDto, cadvisor ? SourceStatus.OK : SourceStatus.UNAVAILABLE,
                containers, cpuChart, memoryChart, network, Instant.now());
    }

    private Container status(Spec spec, Double cpuPercent, Double memoryBytes) {
        if (spec.name().equals("heartcare-monitoring-api")) {
            return new Container(spec.name(), spec.displayName(), "RUNNING", "self", cpuPercent, memoryBytes);
        }
        if (spec.upQuery() != null) {
            Double up = HealthService.safe(() -> metrics.value(spec.upQuery()));
            if (up != null) {
                return new Container(spec.name(), spec.displayName(), up == 1.0 ? "RUNNING" : "DOWN",
                        "prometheus", cpuPercent, memoryBytes);
            }
        }
        String probe = probes.get(spec.name());
        if (probe != null) {
            return new Container(spec.name(), spec.displayName(), probe(probe) ? "RUNNING" : "DOWN",
                    "probe", cpuPercent, memoryBytes);
        }
        if (memoryBytes != null) {
            return new Container(spec.name(), spec.displayName(), "RUNNING", "cadvisor", cpuPercent, memoryBytes);
        }
        return new Container(spec.name(), spec.displayName(), "UNKNOWN", "none", null, null);
    }

    private boolean probe(String url) {
        try {
            probeClient.get().uri(url).retrieve().toBodilessEntity();
            return true;
        } catch (RestClientException ex) {
            return false;
        }
    }

    private static Double used(Double total, Double free) {
        return total == null || free == null ? null : total - free;
    }
}
