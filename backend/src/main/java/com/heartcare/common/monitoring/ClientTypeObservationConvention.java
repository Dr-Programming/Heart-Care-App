// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.common.monitoring;

import io.micrometer.common.KeyValues;
import org.springframework.http.server.observation.DefaultServerRequestObservationConvention;
import org.springframework.http.server.observation.ServerRequestObservationContext;
import org.springframework.stereotype.Component;

/**
 * Adds a {@code client} tag (admin / researcher / mobile / public / other) to
 * {@code http_server_requests_seconds}, so the System Control Centre can split web traffic from
 * mobile traffic arriving through ngrok. The tag comes from the route, never from a header.
 */
@Component
public class ClientTypeObservationConvention extends DefaultServerRequestObservationConvention {

    @Override
    public KeyValues getLowCardinalityKeyValues(ServerRequestObservationContext context) {
        return super.getLowCardinalityKeyValues(context)
                .and("client", ClientType.fromPath(context.getCarrier().getRequestURI()).tag());
    }
}
