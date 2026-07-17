package com.heartcare.common.sync;

import com.heartcare.common.exception.BadRequestException;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import org.springframework.stereotype.Component;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import java.util.Set;
import java.util.stream.Collectors;

/**
 * Turns a sync payload into a feature request DTO, applying the Jakarta constraints that DTO
 * declares.
 *
 * <p>This is not redundant with the controllers: those constraints fire because the controller
 * parameter is annotated {@code @Valid}, which Spring honours on the MVC path only. Deserializing
 * a JsonNode here bypasses that entirely, so the validator must be invoked by hand or a
 * medication with a blank name would reach the database. See design §4.
 */
@Component
public class SyncPayloadMapper {

    private final ObjectMapper objectMapper;
    private final Validator validator;

    public SyncPayloadMapper(ObjectMapper objectMapper, Validator validator) {
        this.objectMapper = objectMapper;
        this.validator = validator;
    }

    /**
     * @throws BadRequestException if the payload is absent, malformed, carries an unknown enum
     *                             value, or violates the DTO's constraints
     */
    public <T> T toRequest(JsonNode payload, Class<T> type) {
        if (payload == null || payload.isNull()) {
            throw new BadRequestException("payload is required");
        }

        T dto;
        try {
            dto = objectMapper.treeToValue(payload, type);
        } catch (JacksonException | IllegalArgumentException e) {
            // Covers unknown enum values (InvalidFormatException) and structural mismatches.
            // JacksonException is unchecked in Jackson 3 (tools.jackson), unlike the checked
            // JsonProcessingException in classic (com.fasterxml) Jackson 2 — still caught
            // explicitly here so a malformed payload never reaches the DB layer unconverted.
            throw new BadRequestException("malformed payload: " + concise(e));
        }

        Set<ConstraintViolation<T>> violations = validator.validate(dto);
        if (!violations.isEmpty()) {
            // Same "field: message; field: message" shape GlobalExceptionHandler produces for
            // MethodArgumentNotValidException, so sync and direct-POST errors read alike.
            throw new BadRequestException(violations.stream()
                    .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                    .sorted()
                    .collect(Collectors.joining("; ")));
        }
        return dto;
    }

    private String concise(Exception e) {
        return e instanceof JacksonException je ? je.getOriginalMessage() : e.getMessage();
    }
}
