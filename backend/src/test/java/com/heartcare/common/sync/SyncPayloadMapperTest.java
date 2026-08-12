package com.heartcare.common.sync;

import com.heartcare.common.exception.BadRequestException;
import com.heartcare.medication.dto.MedicationRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SyncPayloadMapperTest {

    // Jackson 3 (tools.jackson) bundles JSR-310 (OffsetDateTime/LocalDate) support directly in
    // jackson-databind, so unlike classic Jackson 2 no separate JavaTimeModule registration
    // (findAndRegisterModules(), which doesn't exist on this ObjectMapper) is needed.
    private final ObjectMapper objectMapper = new ObjectMapper();
    private Validator validator;
    private SyncPayloadMapper mapper;

    @BeforeEach
    void setUp() {
        validator = Validation.buildDefaultValidatorFactory().getValidator();
        mapper = new SyncPayloadMapper(objectMapper, validator);
    }

    private JsonNode json(String raw) throws Exception {
        return objectMapper.readTree(raw);
    }

    @Test
    void deserializesValidPayload() throws Exception {
        JsonNode payload = json("""
                {"name":"Atorvastatin","doseMg":20,"frequency":"ONCE_DAILY","scheduleTimes":["08:00"]}""");

        MedicationRequest request = mapper.toRequest(payload, MedicationRequest.class);

        assertThat(request.name()).isEqualTo("Atorvastatin");
        assertThat(request.frequency().name()).isEqualTo("ONCE_DAILY");
    }

    /**
     * The gap this class exists to close: the DTO's Jakarta constraints do not fire on their own
     * outside the @Valid controller path, so a blank name would otherwise reach the database.
     */
    @Test
    void rejectsPayloadViolatingBeanValidation() throws Exception {
        JsonNode payload = json("""
                {"name":"","doseMg":20,"frequency":"ONCE_DAILY"}""");

        assertThatThrownBy(() -> mapper.toRequest(payload, MedicationRequest.class))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("name");
    }

    @Test
    void rejectsPayloadWithNonPositiveDose() throws Exception {
        JsonNode payload = json("""
                {"name":"Atorvastatin","doseMg":-5,"frequency":"ONCE_DAILY"}""");

        assertThatThrownBy(() -> mapper.toRequest(payload, MedicationRequest.class))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("doseMg");
    }

    @Test
    void rejectsUnknownEnumValue() throws Exception {
        JsonNode payload = json("""
                {"name":"Atorvastatin","doseMg":20,"frequency":"HOURLY_ISH"}""");

        assertThatThrownBy(() -> mapper.toRequest(payload, MedicationRequest.class))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("malformed payload");
    }

    @Test
    void rejectsNullPayload() {
        assertThatThrownBy(() -> mapper.toRequest(null, MedicationRequest.class))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("payload is required");
    }
}
