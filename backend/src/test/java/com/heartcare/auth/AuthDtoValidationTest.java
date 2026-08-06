package com.heartcare.auth;

import com.heartcare.auth.dto.LoginRequest;
import com.heartcare.auth.dto.RegisterRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The phone and PIN patterns are the whole input contract for auth, so they are pinned here
 * as fast unit assertions rather than only through the (slow) integration test.
 */
class AuthDtoValidationTest {

    static final ValidatorFactory FACTORY = Validation.buildDefaultValidatorFactory();
    static final Validator VALIDATOR = FACTORY.getValidator();

    private RegisterRequest register(String phone, String pin, String name, String lang) {
        return new RegisterRequest(phone, pin, name, lang);
    }

    @Test
    void acceptsAWellFormedRegistration() {
        assertThat(VALIDATOR.validate(register("+251911234567", "1234", "Abebe", "am"))).isEmpty();
    }

    @Test
    void rejectsPhoneWithoutTheEthiopianPrefix() {
        assertThat(VALIDATOR.validate(register("0911234567", "1234", "Abebe", "en"))).isNotEmpty();
    }

    @Test
    void rejectsPhoneWithTheWrongNumberOfDigits() {
        assertThat(VALIDATOR.validate(register("+25191123456", "1234", "Abebe", "en"))).isNotEmpty();
        assertThat(VALIDATOR.validate(register("+2519112345678", "1234", "Abebe", "en"))).isNotEmpty();
    }

    @Test
    void rejectsPinThatIsNotExactlyFourDigits() {
        assertThat(VALIDATOR.validate(register("+251911234567", "123", "Abebe", "en"))).isNotEmpty();
        assertThat(VALIDATOR.validate(register("+251911234567", "12345", "Abebe", "en"))).isNotEmpty();
        assertThat(VALIDATOR.validate(register("+251911234567", "12a4", "Abebe", "en"))).isNotEmpty();
    }

    @Test
    void rejectsBlankName() {
        assertThat(VALIDATOR.validate(register("+251911234567", "1234", "  ", "en"))).isNotEmpty();
    }

    @Test
    void rejectsUnsupportedLanguage() {
        assertThat(VALIDATOR.validate(register("+251911234567", "1234", "Abebe", "fr"))).isNotEmpty();
    }

    @Test
    void loginRequestEnforcesTheSamePhoneAndPinRules() {
        assertThat(VALIDATOR.validate(new LoginRequest("+251911234567", "1234"))).isEmpty();
        assertThat(VALIDATOR.validate(new LoginRequest("0911234567", "1234"))).isNotEmpty();
        assertThat(VALIDATOR.validate(new LoginRequest("+251911234567", "abcd"))).isNotEmpty();
    }
}
