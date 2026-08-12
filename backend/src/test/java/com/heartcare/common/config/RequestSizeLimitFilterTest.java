package com.heartcare.common.config;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import tools.jackson.databind.ObjectMapper;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

class RequestSizeLimitFilterTest {

    private static final long MAX_BYTES = 64;

    private final RequestSizeLimitFilter filter =
            new RequestSizeLimitFilter(MAX_BYTES, new ObjectMapper());

    private MockHttpServletRequest jsonRequest(String body, boolean declareLength) {
        // MockHttpServletRequest always derives a Content-Length from the content it holds, so a
        // chunked request has to be simulated by overriding the accessors to report "unknown".
        // Without this the declared-length branch would short-circuit and the counting stream
        // wrapper below would never actually be exercised by this test.
        MockHttpServletRequest request = declareLength
                ? new MockHttpServletRequest("POST", "/api/v1/sync")
                : new MockHttpServletRequest("POST", "/api/v1/sync") {
                    @Override
                    public int getContentLength() {
                        return -1;
                    }

                    @Override
                    public long getContentLengthLong() {
                        return -1;
                    }
                };
        request.setContentType("application/json");
        request.setContent(body.getBytes(StandardCharsets.UTF_8));
        if (!declareLength) {
            request.addHeader("Transfer-Encoding", "chunked");
        }
        return request;
    }

    @Test
    void passesRequestUnderTheLimitThrough() throws Exception {
        MockHttpServletRequest request = jsonRequest("{\"records\":[]}", true);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(200);
        verify(chain).doFilter(any(), any());
    }

    @Test
    void rejectsOversizedBodyByDeclaredContentLength() throws Exception {
        MockHttpServletRequest request = jsonRequest("x".repeat((int) MAX_BYTES + 1), true);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(413);
        assertThat(response.getContentAsString()).contains("maximum allowed size");
        // The point of the filter: the body is never handed downstream to be deserialized.
        verify(chain, never()).doFilter(any(), any());
    }

    /**
     * A chunked request declares no Content-Length, so the cheap header check cannot catch it —
     * the counting stream wrapper must. Without it this cap would be trivially bypassable.
     */
    @Test
    void rejectsOversizedBodyWhenContentLengthIsAbsent() throws Exception {
        MockHttpServletRequest request = jsonRequest("x".repeat((int) MAX_BYTES + 1), false);
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);
        // Stand in for Jackson: read the body, as the message converter would.
        org.mockito.Mockito.doAnswer(inv -> {
            ((jakarta.servlet.http.HttpServletRequest) inv.getArgument(0))
                    .getInputStream().readAllBytes();
            return null;
        }).when(chain).doFilter(any(), any());

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(413);
    }
}
