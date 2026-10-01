package com.heartcare.medication.dto;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * The number of {@code scheduleTimes} must fit the {@code frequency} (see
 * {@link com.heartcare.medication.model.Frequency}), and no time may appear twice.
 *
 * <p>Declared on the DTO rather than checked in MedicationService so that it fires on both write
 * paths: Spring's {@code @Valid} on the REST controller, and SyncPayloadMapper's explicit
 * validator call on the sync path.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ScheduleMatchesFrequencyValidator.class)
public @interface ScheduleMatchesFrequency {

    String message() default "scheduleTimes do not match frequency";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
