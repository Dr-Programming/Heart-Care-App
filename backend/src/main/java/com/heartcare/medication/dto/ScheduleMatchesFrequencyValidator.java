package com.heartcare.medication.dto;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.util.HashSet;
import java.util.List;

public class ScheduleMatchesFrequencyValidator
        implements ConstraintValidator<ScheduleMatchesFrequency, MedicationRequest> {

    @Override
    public boolean isValid(MedicationRequest request, ConstraintValidatorContext context) {
        if (request == null || request.frequency() == null) {
            return true; // @NotNull on frequency reports the missing value
        }
        List<String> times = request.scheduleTimes() == null ? List.of() : request.scheduleTimes();

        if (!request.frequency().allowsTimeCount(times.size())) {
            return fail(context, request.frequency().timeCountRule() + ", got " + times.size());
        }
        if (new HashSet<>(times).size() != times.size()) {
            return fail(context, "scheduleTimes must not contain duplicates");
        }
        return true;
    }

    /**
     * Reported against the scheduleTimes property, not the object: GlobalExceptionHandler builds
     * its message from field errors only, so an object-level error would surface as a blank 400.
     */
    private boolean fail(ConstraintValidatorContext context, String message) {
        context.disableDefaultConstraintViolation();
        context.buildConstraintViolationWithTemplate(message)
                .addPropertyNode("scheduleTimes")
                .addConstraintViolation();
        return false;
    }
}
