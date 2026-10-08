package com.heartcare.auth;

import com.heartcare.common.exception.BadRequestException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SecurityAnswerNormalizerTest {

    @Test
    void ignoresCaseAndSurroundingSpace() {
        assertThat(SecurityAnswerNormalizer.normalize("  Bole School "))
                .isEqualTo(SecurityAnswerNormalizer.normalize("bole school"));
    }

    @Test
    void collapsesInnerWhitespace() {
        assertThat(SecurityAnswerNormalizer.normalize("Bole \t  School"))
                .isEqualTo("bole school");
    }

    @Test
    void doesNotApplyUnicodeCompatibilityFolding() {
        // The phone checks answers offline with the same rules and has no NFKC implementation,
        // so the server must not fold either, or the two checks would disagree.
        assertThat(SecurityAnswerNormalizer.normalize("ＢＯＬＥ")).isEqualTo("ｂｏｌｅ");
    }

    @Test
    void keepsAmharicText() {
        assertThat(SecurityAnswerNormalizer.normalize(" አዲስ  አበባ ")).isEqualTo("አዲስ አበባ");
    }

    @Test
    void rejectsAnswersShorterThanTwoCharacters() {
        assertThatThrownBy(() -> SecurityAnswerNormalizer.normalize(" a "))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void rejectsAnswersLongerThanOneHundredCharacters() {
        assertThatThrownBy(() -> SecurityAnswerNormalizer.normalize("x".repeat(101)))
                .isInstanceOf(BadRequestException.class);
    }
}
