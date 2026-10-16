package com.heartcare.common.monitoring;

import org.springframework.boot.actuate.endpoint.annotation.Endpoint;
import org.springframework.boot.actuate.endpoint.annotation.ReadOperation;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * {@code /actuator/scc-activity}: the recent activity timeline, read by the Monitoring API.
 * Served on the management port only, like every other actuator endpoint.
 */
@Component
@Endpoint(id = "scc-activity")
public class ActivityEndpoint {

    private final ActivityRecorder recorder;

    public ActivityEndpoint(ActivityRecorder recorder) {
        this.recorder = recorder;
    }

    @ReadOperation
    public Timeline timeline() {
        return new Timeline(ActivityRecorder.CAPACITY, recorder.recent(ActivityRecorder.CAPACITY));
    }

    public record Timeline(int capacity, List<ActivityEvent> events) {
    }
}
