package com.heartcare.common;

import com.heartcare.common.response.ApiResponse;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ApiResponseTest {

    @Test
    void okWrapsDataWithSuccessTrue() {
        ApiResponse<String> resp = ApiResponse.ok("payload");

        assertThat(resp.success()).isTrue();
        assertThat(resp.data()).isEqualTo("payload");
        assertThat(resp.message()).isEqualTo("OK");
        assertThat(resp.timestamp()).isNotNull();
    }

    @Test
    void okWithMessageSetsMessage() {
        ApiResponse<String> resp = ApiResponse.ok("payload", "Created");

        assertThat(resp.message()).isEqualTo("Created");
        assertThat(resp.success()).isTrue();
        assertThat(resp.data()).isEqualTo("payload");
    }

    @Test
    void errorHasSuccessFalseAndNullData() {
        ApiResponse<Void> resp = ApiResponse.error("boom");

        assertThat(resp.success()).isFalse();
        assertThat(resp.data()).isNull();
        assertThat(resp.message()).isEqualTo("boom");
    }
}
