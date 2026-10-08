package com.heartcare.auth.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

/** One hashed answer to one recovery question. See V15__security_answers.sql. */
@Entity
@Table(name = "user_security_answers")
public class SecurityAnswer {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "question_id", nullable = false, length = 40)
    private SecurityQuestion question;

    /** BCrypt of the normalised answer; the answer itself is never stored. */
    @Column(name = "answer_hash", nullable = false)
    private String answerHash;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected SecurityAnswer() {
        // for JPA
    }

    public SecurityAnswer(UUID userId, SecurityQuestion question, String answerHash) {
        this.userId = userId;
        this.question = question;
        this.answerHash = answerHash;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }

    public SecurityQuestion getQuestion() {
        return question;
    }

    public String getAnswerHash() {
        return answerHash;
    }
}
