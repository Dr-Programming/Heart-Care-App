// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.service;

import com.heartcare.monitoring.prometheus.PromQueries;
import org.springframework.stereotype.Component;

/**
 * Host CPU and memory. windows_exporter is the real host; if it is not installed, CPU falls back
 * to the Docker VM as seen by the backend JVM, labelled as such so nobody mistakes one for the other.
 */
@Component
public class HostReader {

    public static final String WINDOWS_HOST = "windows-host";
    public static final String DOCKER_VM = "docker-vm";

    public record Reading(Double cpuPercent, String cpuSource, Double memoryPercent, boolean hostAvailable) {
    }

    private final Metrics metrics;

    public HostReader(Metrics metrics) {
        this.metrics = metrics;
    }

    public boolean hostAvailable() {
        return metrics.isUp(PromQueries.HOST_UP);
    }

    public Reading read() {
        if (hostAvailable()) {
            return new Reading(metrics.value(PromQueries.HOST_CPU_PERCENT), WINDOWS_HOST,
                    metrics.value(PromQueries.HOST_MEMORY_PERCENT), true);
        }
        return new Reading(metrics.value(PromQueries.VM_CPU_PERCENT), DOCKER_VM, null, false);
    }

    /** The CPU expression matching what {@link #read()} would report right now. */
    public String cpuExpression(boolean hostAvailable) {
        return hostAvailable ? PromQueries.HOST_CPU_PERCENT : PromQueries.VM_CPU_PERCENT;
    }
}
