package com.heartcare.monitoring.prometheus;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.queryParam;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;
import static org.hamcrest.Matchers.startsWith;

class PrometheusClientTest {

    private MockRestServiceServer server;
    private PrometheusClient client;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        client = new PrometheusClient(builder.build(), "http://prometheus:9090/");
    }

    @Test
    void parsesVectorSamplesWithLabels() {
        server.expect(requestTo(startsWith("http://prometheus:9090/api/v1/query?")))
                .andExpect(queryParam("query", "sum+by+%28status%29+%28x%29"))
                .andRespond(withSuccess("""
                        {"status":"success","data":{"resultType":"vector","result":[
                          {"metric":{"status":"200"},"value":[1760000000.5,"42"]},
                          {"metric":{"status":"500"},"value":[1760000000.5,"3"]}]}}
                        """, MediaType.APPLICATION_JSON));

        List<PrometheusClient.Sample> samples = client.query("sum by (status) (x)");

        assertThat(samples).hasSize(2);
        assertThat(samples.getFirst().label("status")).isEqualTo("200");
        assertThat(samples.getFirst().value()).isEqualTo(42.0);
        server.verify();
    }

    /** Braces must not be read as URI template variables, and '+' must not decode as a space. */
    @Test
    void encodesLabelMatchersAndPlusSignsLosslessly() {
        String promql = "rate(a{job=\"x\",uri!~\"/actuator.*\"}[1m]) + rate(b[1m])";
        server.expect(request -> assertThat(java.net.URLDecoder.decode(
                        request.getURI().getRawQuery().substring("query=".length()),
                        java.nio.charset.StandardCharsets.UTF_8)).isEqualTo(promql))
                .andRespond(withSuccess("""
                        {"status":"success","data":{"resultType":"vector","result":[]}}
                        """, MediaType.APPLICATION_JSON));

        assertThat(client.query(promql)).isEmpty();
        server.verify();
    }

    @Test
    void scalarTreatsNaNAndEmptyResultsAsNoData() {
        server.expect(requestTo(startsWith("http://prometheus:9090/api/v1/query?")))
                .andRespond(withSuccess("""
                        {"status":"success","data":{"resultType":"vector","result":[
                          {"metric":{},"value":[1760000000,"NaN"]}]}}
                        """, MediaType.APPLICATION_JSON));
        server.expect(requestTo(startsWith("http://prometheus:9090/api/v1/query?")))
                .andRespond(withSuccess("""
                        {"status":"success","data":{"resultType":"vector","result":[]}}
                        """, MediaType.APPLICATION_JSON));

        assertThat(client.scalar("a / b")).isNull();
        assertThat(client.scalar("missing_metric")).isNull();
    }

    @Test
    void parsesScalarResultType() {
        server.expect(requestTo(startsWith("http://prometheus:9090/api/v1/query?")))
                .andRespond(withSuccess("""
                        {"status":"success","data":{"resultType":"scalar","result":[1760000000,"1"]}}
                        """, MediaType.APPLICATION_JSON));

        assertThat(client.scalar("vector(1)")).isEqualTo(1.0);
    }

    @Test
    void parsesRangeMatrixIntoMillisecondPoints() {
        server.expect(requestTo(startsWith("http://prometheus:9090/api/v1/query_range?")))
                .andExpect(queryParam("step", "10s"))
                .andRespond(withSuccess("""
                        {"status":"success","data":{"resultType":"matrix","result":[
                          {"metric":{"client":"mobile"},"values":[[1760000000,"1.5"],[1760000010,"+Inf"]]}]}}
                        """, MediaType.APPLICATION_JSON));

        Instant end = Instant.ofEpochSecond(1760000010);
        List<PrometheusClient.Series> series = client.queryRange("q", end.minusSeconds(60), end, Duration.ofSeconds(10));

        assertThat(series).hasSize(1);
        assertThat(series.getFirst().labels()).containsEntry("client", "mobile");
        assertThat(series.getFirst().points()).containsExactly(
                new PrometheusClient.Point(1760000000000L, 1.5),
                new PrometheusClient.Point(1760000010000L, null));
    }

    @Test
    void failedQueryRaisesPrometheusException() {
        server.expect(requestTo(startsWith("http://prometheus:9090/api/v1/query?")))
                .andRespond(withStatus(HttpStatus.BAD_REQUEST).contentType(MediaType.APPLICATION_JSON)
                        .body("{\"status\":\"error\",\"errorType\":\"bad_data\",\"error\":\"parse error\"}"));

        assertThatThrownBy(() -> client.query("sum(")).isInstanceOf(PrometheusException.class);
    }
}
