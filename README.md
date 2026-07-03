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

- **Backend:** the authentication foundation (Spring Boot 4.1 · PostgreSQL · Flyway · JWT — patient register/login/`me`) is implemented and tested. See [`backend/README.md`](./backend/README.md) for build/run instructions and slice-by-slice progress.
- **Mobile:** the Flutter app has not been started yet.
