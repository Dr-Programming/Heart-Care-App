package com.heartcare.common.config;

import com.heartcare.common.response.ApiResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;

/**
 * Caps request body size.
 *
 * <p>SyncService rejects batches over app.sync.max-batch-size, but only after Spring has
 * deserialized the whole body into JsonNode payloads — so an oversized request exhausts heap
 * before that check ever runs. Tomcat's own maxPostSize does not help: it applies to form
 * encodings, not application/json.
 *
 * <p>Runs first in the chain, ahead of authentication, so the cost of an oversized body is
 * bounded for unauthenticated callers too.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestSizeLimitFilter extends OncePerRequestFilter {

    private final long maxBytes;
    private final ObjectMapper objectMapper;

    public RequestSizeLimitFilter(@Value("${app.sync.max-body-bytes}") long maxBytes,
                                  ObjectMapper objectMapper) {
        this.maxBytes = maxBytes;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        if (request.getContentLengthLong() > maxBytes) {
            reject(response);
            return;
        }
        // Content-Length is absent on a chunked request, so the declared length cannot be the only
        // guard — count the bytes actually read and fail once the cap is passed.
        try {
            filterChain.doFilter(new LimitedRequest(request, maxBytes), response);
        } catch (BodyTooLargeException ex) {
            if (!response.isCommitted()) {
                reject(response);
            }
        }
    }

    private void reject(HttpServletResponse response) throws IOException {
        response.setStatus(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(),
                ApiResponse.error("Request body exceeds the maximum allowed size"));
    }

    /** Unchecked so it can escape the read() call deep inside Jackson without a wrapper contract. */
    private static class BodyTooLargeException extends RuntimeException {
    }

    private static class LimitedRequest extends HttpServletRequestWrapper {

        private final long maxBytes;

        LimitedRequest(HttpServletRequest request, long maxBytes) {
            super(request);
            this.maxBytes = maxBytes;
        }

        @Override
        public ServletInputStream getInputStream() throws IOException {
            ServletInputStream delegate = super.getInputStream();
            return new ServletInputStream() {

                private long read;

                private int count(int bytes) {
                    if (bytes > 0 && (read += bytes) > maxBytes) {
                        throw new BodyTooLargeException();
                    }
                    return bytes;
                }

                @Override
                public int read() throws IOException {
                    int b = delegate.read();
                    count(b == -1 ? -1 : 1);
                    return b;
                }

                @Override
                public int read(byte[] buffer, int off, int len) throws IOException {
                    return count(delegate.read(buffer, off, len));
                }

                @Override
                public boolean isFinished() {
                    return delegate.isFinished();
                }

                @Override
                public boolean isReady() {
                    return delegate.isReady();
                }

                @Override
                public void setReadListener(ReadListener listener) {
                    delegate.setReadListener(listener);
                }
            };
        }
    }
}
