# Heart-Care-App

**Project Started:** 2026-04-17

A cross-platform mobile application for managing coronary heart disease (CHD) patients in Ethiopia, developed as a UOW Capstone Project (Project 29).

## About

Heart-Care-App helps patients track and manage their CHD treatment plans. It supports offline-first usage for areas with limited connectivity and provides bilingual support in English and Amharic.

The current scope is **patient-only**. A clinician role, real-time alerting, and appointment scheduling are not part of this build.

**Supervised by:** Dr. Elena Vlahu-Gjorgievska & Prof. Khin Than Win
**Client:** Tesema Etefa Birhanu

## Tech Stack

- **Mobile:** Flutter (Dart) — iOS & Android
- **Backend:** Spring Boot (Java) — REST API
- **Database:** PostgreSQL (hosted on Railway)

## Key Features

- Medication tracking with dose reminders
- Vitals logging (blood pressure, glucose, heart rate, weight)
- Symptom check-ins and activity logs
- On-device alerts for abnormal vitals and symptoms (evaluated offline)
- Offline-first sync — works without internet connectivity
- Bilingual UI (English & Amharic)

## Status

Early development.

- **Backend:** all 7 slices (auth, patient profile, medications & dose logs, vitals, symptoms, activity, offline sync) are implemented and tested. See [`backend/README.md`](./backend/README.md) for build/run instructions and slice-by-slice progress.
- **Mobile:** not yet built, but the first slice — **Foundation & Auth** — is designed and approved (`docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md`). Stack decided: Flutter · Riverpod · go_router · Drift · Dio. Auth moves to phone + 4-digit PIN (see [`docs/frontend-decisions.md`](./docs/frontend-decisions.md)).
