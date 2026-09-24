package com.heartcare.common.health;

import com.heartcare.common.response.ApiResponse;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Unauthenticated liveness probe.
 *
 * <p>The mobile client calls this before it lets a patient fill in the sign-up form: registration
 * is the one flow that cannot be queued offline, so the app has to know the server is actually
 * answering — not merely that the phone has a radio signal — before it accepts any input. It is
 * deliberately free of database or security work so that "the server answered" means exactly that
 * and nothing slower.
 */
@RestController
@RequestMapping("/api/v1/health")
public class HealthController {

    @GetMapping
    public ApiResponse<Map<String, String>> health() {
        return ApiResponse.ok(Map.of("status", "UP"));
    }
}
