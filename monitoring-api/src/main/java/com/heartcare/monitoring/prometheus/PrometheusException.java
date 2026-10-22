// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.prometheus;

/** Prometheus could not be reached or rejected a query. */
public class PrometheusException extends RuntimeException {
    public PrometheusException(String message, Throwable cause) {
        super(message, cause);
    }
}
