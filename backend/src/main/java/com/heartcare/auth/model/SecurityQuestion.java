package com.heartcare.auth.model;

/**
 * The fixed list of recovery questions. The server only knows these IDs; the question text, in
 * English and Amharic, lives in the mobile app's translation files.
 *
 * <p>Questions whose answers close family are likely to know (mother's name, birthplace) are left
 * out on purpose: family members are the people most likely to have the patient's phone.
 *
 * <p>Never rename or remove a value: stored answers reference these names.
 */
public enum SecurityQuestion {
    FIRST_SCHOOL,
    CHILDHOOD_FRIEND,
    FAVORITE_TEACHER,
    CHILDHOOD_STREET,
    FIRST_JOB_PLACE,
    FAVORITE_CHILDHOOD_FOOD,
    FIRST_PHONE_BRAND,
    CHILDHOOD_HERO
}
