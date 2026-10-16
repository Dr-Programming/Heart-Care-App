package com.heartcare.monitoring.prometheus;

/** Prometheus could not be reached or rejected a query. */
public class PrometheusException extends RuntimeException {
    public PrometheusException(String message, Throwable cause) {
        super(message, cause);
    }
}
