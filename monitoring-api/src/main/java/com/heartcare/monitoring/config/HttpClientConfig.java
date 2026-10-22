// Author: Prince Jiteshbhai Khakhariya
// Last updated by: Prince Jiteshbhai Khakhariya

package com.heartcare.monitoring.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.net.http.HttpClient;
import java.time.Duration;

@Configuration
public class HttpClientConfig {

    /**
     * Short timeouts throughout: a slow or missing metrics source must degrade one card on the
     * dashboard, not stall every request behind it.
     */
    @Bean
    public RestClient.Builder monitoringRestClientBuilder() {
        HttpClient http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(2))
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(5));
        return RestClient.builder().requestFactory(factory);
    }
}
