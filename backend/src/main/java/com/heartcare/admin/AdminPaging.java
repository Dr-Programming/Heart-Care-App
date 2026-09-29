package com.heartcare.admin;

import com.heartcare.common.exception.BadRequestException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.util.Set;

/**
 * Builds a Pageable from raw query parameters. The sort field is checked against a whitelist:
 * handing an arbitrary client string to Spring Data surfaces as a 500 (PropertyReferenceException)
 * instead of the 400 it deserves.
 */
final class AdminPaging {

    static final int MAX_SIZE = 100;

    private AdminPaging() {
    }

    /** {@code sort} is {@code "field"} or {@code "field,asc|desc"}; null uses the default. */
    static Pageable of(int page, int size, String sort, Set<String> allowedFields, Sort defaultSort) {
        if (page < 0) {
            throw new BadRequestException("page must not be negative");
        }
        if (size < 1 || size > MAX_SIZE) {
            throw new BadRequestException("size must be between 1 and " + MAX_SIZE);
        }
        return PageRequest.of(page, size, parseSort(sort, allowedFields, defaultSort));
    }

    private static Sort parseSort(String sort, Set<String> allowedFields, Sort defaultSort) {
        if (sort == null || sort.isBlank()) {
            return defaultSort;
        }
        String[] parts = sort.split(",", 2);
        String field = parts[0].trim();
        if (!allowedFields.contains(field)) {
            throw new BadRequestException("sort must be one of " + allowedFields);
        }
        Sort.Direction direction = Sort.Direction.DESC;
        if (parts.length == 2) {
            direction = Sort.Direction.fromOptionalString(parts[1].trim())
                    .orElseThrow(() -> new BadRequestException("sort direction must be asc or desc"));
        }
        return Sort.by(direction, field).and(Sort.by(Sort.Direction.DESC, "id"));
    }
}
