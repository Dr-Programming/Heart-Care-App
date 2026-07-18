# Heart-Care App — Functional Requirements

**Project:** Heart-Care App (UOW Capstone — Project 29)  
**Client:** Tesema Etefa Birhanu  
**Supervisors:** Dr Elena Vlahu-Gjorgievska, Prof. Khin Than Win  
**Document Owner:** Developing Team  
**Last Updated:** 14 April 2026

---

## How to Use This Document

Each requirement has a unique ID, priority tier, and a checkbox for tracking completion.

**ID Format:** `FR-[MODULE]-[NUMBER]`

**Priority Tiers:**

| Tier | Label | Meaning |
|---|---|---|
| 🔴 | **P1 — Must Have** | Core MVP. App cannot ship without this. |
| 🟡 | **P2 — Should Have** | Important feature. Include if time allows before deadline. |
| 🟢 | **P3 — Nice to Have** | Enhances experience. Implement after P1 and P2 are complete. |
| 🔵 | **P4 — Stretch Goal** | Aspirational. Only if significantly ahead of schedule. |

**Status Checkboxes:** `- [ ]` = Not Started &nbsp;|&nbsp; `- [~]` = In Progress &nbsp;|&nbsp; `- [x]` = Completed

---

## Table of Contents

1. [Authentication & User Management](#1-authentication--user-management)
2. [Personal Patient Profile](#2-personal-patient-profile)
3. [CHD Education Modules](#3-chd-education-modules)
4. [Medication Management](#4-medication-management)
5. [Decision Support & Alerts](#5-decision-support--alerts)
6. [Symptom Monitoring](#6-symptom-monitoring)
7. [Physical Activity Guidance](#7-physical-activity-guidance)
8. [Diet & Nutrition Guide](#8-diet--nutrition-guide)
9. [Health Vitals Tracking](#9-health-vitals-tracking)
10. [Risk-Factor Dashboard](#10-risk-factor-dashboard)
11. [Trend Graphs & Progress Visualisation](#11-trend-graphs--progress-visualisation)
12. [Patient–Clinician Communication](#12-patientclinician-communication)
13. [Follow-Up & Appointment Support](#13-follow-up--appointment-support)
14. [Offline Functionality](#14-offline-functionality)
15. [Notifications & Reminders](#15-notifications--reminders)
16. [Localisation & Accessibility](#16-localisation--accessibility)
17. [Non-Functional Requirements](#17-non-functional-requirements)

---

ONLY FOR SELF PATIENT

## 1. Authentication & User Management

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-AUTH-001 | The system shall allow a new user to register with their name, email address, and password. | 🔴 P1 | - [ only patient] |
| FR-AUTH-002 | The system shall allow registered users to log in using their email and password. | 🔴 P1 | - [ ] |
| FR-AUTH-003 | The system shall support two distinct user roles: **Patient** and **Clinician**, with separate access scopes. | 🔴 P1 | - [ ] |
| FR-AUTH-004 | The system shall issue a JWT token upon successful login, valid for 7 days. | 🔴 P1 | - [ ] |
| FR-AUTH-005 | The system shall store the JWT token in encrypted device storage (Android Keystore / iOS Keychain). | 🔴 P1 | - [ ] |
| FR-AUTH-006 | The system shall automatically log the user in on app relaunch if a valid token exists. | 🔴 P1 | - [ ] |
| FR-AUTH-007 | The system shall allow a user to log out, clearing the stored token from the device. | 🔴 P1 | - [ ] |
| FR-AUTH-008 | The system shall allow a user to reset their password via a link sent to their registered email. | 🟡 P2 | - [ ] |
| FR-AUTH-009 | The system shall prevent a Patient from accessing any other patient's data. | 🔴 P1 | - [ ] |
| FR-AUTH-010 | The system shall allow a Clinician to access only their assigned patients' data. | 🔴 P1 | - [ to be droped] |
| FR-AUTH-011 | The system shall support an **Admin** role for user and content management. | 🔵 P4 | - [ ] |

---

## 2. Personal Patient Profile

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-PROF-001 | The system shall allow a patient to create and save their personal profile, including full name, date of birth, and preferred language. | 🔴 P1 | - [ONLY YEAR ] |
| FR-PROF-002 | The system shall allow a patient to record their disease history and CHD diagnosis stage. | 🔴 P1 | - [ ] |
| FR-PROF-003 | The system shall allow a patient to record comorbidities (e.g., diabetes, hypertension, kidney disease). | 🔴 P1 | - [ ] |
| FR-PROF-004 | The system shall allow a patient to store relevant lab results (e.g., cholesterol, HbA1c). | 🟡 P2 | - [ ] |
| FR-PROF-005 | The system shall allow a patient to record current management plan and medications. | 🔴 P1 | - [ ] |
| FR-PROF-006 | The system shall allow a patient to set personalised goals for BP, cholesterol, steps per day, weight, and diet. | 🟡 P2 | - [ ] |
| FR-PROF-007 | The system shall allow a patient to update their profile at any time. | 🔴 P1 | - [ ] |
| FR-PROF-008 | The system shall store the full patient profile locally on the device for offline access. | 🔴 P1 | - [ ] |
| FR-PROF-009 | The system shall allow a patient to optionally add a family member or caregiver contact. | 🟢 P3 | - [ ] |

---

## 3. CHD Education Modules

ONLY REFERENCE LINKS,  NO VIDEO EMBEDDING. 
Ask user to select which to download

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-EDU-001 | The system shall provide an education module explaining what Coronary Heart Disease (CHD) is. | 🔴 P1 | - [ ] |
| FR-EDU-002 | The system shall provide content explaining the symptoms of CHD and how to recognise them. | 🔴 P1 | - [ ] |
| FR-EDU-003 | The system shall provide an explanation of what a heart attack is, its warning signs, and what to do. | 🔴 P1 | - [ ] |
| FR-EDU-004 | The system shall provide an education module on heart-healthy diet practices. | 🔴 P1 | - [ ] |
| FR-EDU-005 | The system shall provide an education module on psychosocial wellbeing and stress management. | 🟡 P2 | - [ p1] |
| FR-EDU-006 | The system shall provide an education module on safe physical exercise for CHD patients. | 🔴 P1 | - [ ] |
| FR-EDU-007 | The system shall provide an education module on medication adherence and why it matters. | 🔴 P1 | - [ ] |
| FR-EDU-008 | The system shall include a knowledge quiz (Quiz 1) after the CHD facts section to reinforce learning. | 🟡 P2 | - [ ] |
| FR-EDU-009 | All education content shall be available fully offline (bundled into the app at build time). | 🔴 P1 | - [ ] |
| FR-EDU-010 | All education content shall be available in both English and Amharic. | 🔴 P1 | - [ ] |
| FR-EDU-011 | The system shall use simple language and visual aids suitable for users with low digital literacy. | 🔴 P1 | - [ ] |
| FR-EDU-012 | The system shall allow the client/admin to update education content via the backend without a new app release. | 🔵 P4 | - [ voided] |

---

## 4. Medication Management

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-MED-001 | The system shall allow a patient to add a medication with its name, dose (mg), and frequency (Once daily, BID, TID, or Custom). | 🔴 P1 | - [ ] |
| FR-MED-002 | The system shall allow a patient to set one or more scheduled times per day for each medication. | 🔴 P1 | - [ ] |
| FR-MED-003 | The system shall allow a patient to log each individual dose as **Taken**, **Missed**, or **Skipped**. | 🔴 P1 | - [ p3] |
| FR-MED-004 | The system shall display the full medication list with current dose status for the day. | 🔴 P1 | - [ ] |
| FR-MED-005 | The system shall allow a patient to edit or deactivate a medication. | 🔴 P1 | - [ ] |
| FR-MED-006 | The system shall maintain a complete history of dose logs, including timestamps. | 🔴 P1 | - [p3 ] |
| FR-MED-007 | The system shall calculate and display a medication adherence percentage for the past 7 and 30 days. | 🟡 P2 | - [ ] |
| FR-MED-008 | The system shall support adding optional notes to each dose log (e.g., "took with food", "felt nauseous"). | 🟢 P3 | - [ ] |
| FR-MED-009 | The system shall allow a patient to optionally designate a family member or caregiver to receive missed-dose notifications. | 🟢 P3 | - [ voided] |
| FR-MED-010 | All medication data and dose logs shall be stored locally for offline access and logging. | 🔴 P1 | - [ ] |

---

## 5. Decision Support & Alerts

Further discussion

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-DEC-001 | The system shall send a reminder notification if a dose has not been logged within 1 hour of its scheduled time. | 🔴 P1 | - [ ] |
| FR-DEC-002 | The system shall trigger an **adherence alert** if a patient misses 2 or more consecutive doses of the same medication. | 🔴 P1 | - [ ] |
| FR-DEC-003 | The system shall trigger a **critical warning** if a patient reports missing doses AND reports chest pain or shortness of breath in the same day. | 🔴 P1 | - [ ] |
| FR-DEC-004 | The system shall trigger a **critical BP alert** if systolic BP > 180 mmHg or diastolic BP > 110 mmHg is recorded. | 🔴 P1 | - [ ] |
| FR-DEC-005 | The system shall trigger a **warning BP alert** if systolic BP > 140 mmHg or diastolic BP > 90 mmHg is recorded. | 🔴 P1 | - [ ] |
| FR-DEC-006 | The system shall trigger a **heart rate alert** if resting HR > 120 bpm or < 50 bpm is recorded. | 🔴 P1 | - [ ] |
| FR-DEC-007 | The system shall trigger a **glucose alert** if blood glucose < 3.9 mmol/L or > 15.0 mmol/L is recorded. | 🔴 P1 | - [ ] |
| FR-DEC-008 | The system shall trigger an **emergency alert** if a patient reports severe chest pain. | 🔴 P1 | - [ ] |
| FR-DEC-009 | For each alert, the system shall display a recommended action to the patient (e.g., "Call emergency contact", "Self-care management tips", "Monitor"). | 🔴 P1 | - [ ] |
| FR-DEC-010 | Critical alerts shall be forwarded in real-time to the assigned clinician via WebSocket notification when the device is online. | 🟡 P2 | - [ ] |
| FR-DEC-011 | All decision support logic shall function entirely offline, using locally stored data. | 🔴 P1 | - [ ] |

---

## 6. Symptom Monitoring

further discussion and approval waiting

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-SYM-001 | The system shall allow a patient to complete a daily symptom check-in. | 🔴 P1 | - [ ] |
| FR-SYM-002 | The daily check-in shall capture chest pain (Yes/No + severity). | 🔴 P1 | - [ ] |
| FR-SYM-003 | The daily check-in shall capture shortness of breath (None / Mild / Severe). | 🔴 P1 | - [ ] |
| FR-SYM-004 | The daily check-in shall capture resting heart rate (bpm). | 🔴 P1 | - [ ] |
| FR-SYM-005 | The daily check-in shall capture blood pressure (systolic / diastolic). | 🔴 P1 | - [ ] |
| FR-SYM-006 | The daily check-in shall capture presence of leg/ankle swelling (Yes/No). | 🔴 P1 | - [ ] |
| FR-SYM-007 | The daily check-in shall capture energy/activity level on a scale of 0–10. | 🔴 P1 | - [ ] |
| FR-SYM-008 | The system shall ask "Worse than yesterday?" for each symptom to capture deterioration trends. | 🟡 P2 | - [ ] |
| FR-SYM-009 | The system shall store symptom check-in history and allow a patient to review past entries. | 🔴 P1 | - [ ] |
| FR-SYM-010 | The system shall provide a clinical interpretation and recommended action for each symptom severity level (e.g., "Severe chest pain → Emergency: call emergency contact"). | 🔴 P1 | - [ ] |
| FR-SYM-011 | All symptom logs shall be stored locally and synced to the server when connectivity is available. | 🔴 P1 | - [ ] |

---

## 7. Physical Activity Guidance
further discussion and approval waiting

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-ACT-001 | The system shall provide evidence-based physical activity guidelines appropriate for CHD patients. | 🔴 P1 | - [ ] |
| FR-ACT-002 | The system shall display a clear list of **indications to terminate activity** (e.g., chest pain, dizziness, BP > threshold, blood glucose < 6 mmol/L or > 15 mmol/L). | 🔴 P1 | - [ ] |
| FR-ACT-003 | The system shall allow a patient to log daily physical activity (type, duration, intensity). | 🟡 P2 | - [ ] |
| FR-ACT-004 | The system shall provide culturally relevant activity suggestions appropriate for the Ethiopian context. | 🟡 P2 | - [ ] |
| FR-ACT-005 | The system shall display activity guidance content fully offline. | 🔴 P1 | - [ ] |
| FR-ACT-006 | The system shall display the patient's activity log history. | 🟡 P2 | - [ ] |
| FR-ACT-007 | The system shall track progress toward the patient's personalised daily steps goal. | 🟢 P3 | - [ ] |

---

## 8. Diet & Nutrition Guide
further discussion and approval waiting

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-DIET-001 | The system shall provide a heart-healthy eating guide tailored to Ethiopian foods and cultural practices. | 🔴 P1 | - [ ] |
| FR-DIET-002 | The guide shall include recommended whole grains (e.g., injera from whole teff, barley, sorghum, oats, brown rice). | 🔴 P1 | - [ ] |
| FR-DIET-003 | The guide shall include recommended legumes (e.g., shiro/chickpea, misir/lentils, kik/split peas, beans). | 🔴 P1 | - [ ] |
| FR-DIET-004 | The guide shall include recommended vegetables (e.g., gomen, cabbage, carrots, tomatoes, spinach) and fruits (orange, papaya, mango, guava, banana). | 🔴 P1 | - [ ] |
| FR-DIET-005 | The guide shall include foods to limit or avoid (saturated fats, excess salt, processed foods). | 🟡 P2 | - [ ] |
| FR-DIET-006 | The system shall allow a patient to log daily meals or diet adherence. | 🟢 P3 | - [ ] |
| FR-DIET-007 | All diet guide content shall be available offline. | 🔴 P1 | - [ ] |
| FR-DIET-008 | Diet content shall be available in both English and Amharic. | 🔴 P1 | - [ ] |

---

## 9. Health Vitals Tracking
further discussion and approval waiting

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-VIT-001 | The system shall allow a patient to log their blood pressure (systolic and diastolic in mmHg). | 🔴 P1 | - [ ] |
| FR-VIT-002 | The system shall allow a patient to log their blood glucose level (mmol/L). | 🔴 P1 | - [ ] |
| FR-VIT-003 | The system shall allow a patient to log their resting heart rate (bpm). | 🔴 P1 | - [ ] |
| FR-VIT-004 | The system shall allow a patient to log their weight (kg) and automatically calculate BMI if height is stored in profile. | 🔴 P1 | - [ ] |
| FR-VIT-005 | Each vital log entry shall record the timestamp of when the reading was taken. | 🔴 P1 | - [ ] |
| FR-VIT-006 | The system shall allow a patient to view their full vitals history. | 🔴 P1 | - [ ] |
| FR-VIT-007 | All vitals entries shall be stored locally first and synced to the server when online. | 🔴 P1 | - [ ] |
| FR-VIT-008 | The system shall flag any vitals reading that exceeds clinical alert thresholds immediately upon entry. | 🔴 P1 | - [ ] |
| FR-VIT-009 | The system shall allow a patient to log cholesterol levels (LDL, HDL, total) when available. | 🟡 P2 | - [ ] |

---

## 10. Risk-Factor Dashboard

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-DASH-001 | The system shall display a summary dashboard showing the patient's key health metrics at a glance. | 🔴 P1 | - [ ] |
| FR-DASH-002 | The dashboard shall display the most recent BP reading with a colour-coded status (normal / warning / critical). | 🔴 P1 | - [ ] |
| FR-DASH-003 | The dashboard shall display the most recent weight and BMI. | 🔴 P1 | - [ ] |
| FR-DASH-004 | The dashboard shall display the most recent blood glucose reading. | 🔴 P1 | - [ ] |
| FR-DASH-005 | The dashboard shall display the most recent cholesterol reading (when available). | 🟡 P2 | - [ ] |
| FR-DASH-006 | The dashboard shall display today's physical activity summary. | 🟡 P2 | - [ ] |
| FR-DASH-007 | The dashboard shall display today's medication adherence status (doses taken vs. due). | 🔴 P1 | - [ ] |
| FR-DASH-008 | The dashboard shall provide feedback on progress toward personalised goals (e.g., "BP target achieved this week"). | 🟡 P2 | - [ ] |
| FR-DASH-009 | The dashboard shall be fully viewable offline using the most recently synced or locally stored data. | 🔴 P1 | - [ ] |

---

## 11. Trend Graphs & Progress Visualisation

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-GRAPH-001 | The system shall display a 7-day trend graph for blood pressure (systolic and diastolic). | 🔴 P1 | - [ ] |
| FR-GRAPH-002 | The system shall display a 30-day trend graph for blood pressure. | 🟡 P2 | - [ ] |
| FR-GRAPH-003 | The system shall display a 7-day and 30-day trend graph for weight. | 🔴 P1 | - [ ] |
| FR-GRAPH-004 | The system shall display a 7-day and 30-day trend graph for blood glucose. | 🔴 P1 | - [ ] |
| FR-GRAPH-005 | The system shall display a 7-day and 30-day trend graph for physical activity. | 🟡 P2 | - [ ] |
| FR-GRAPH-006 | The system shall display a medication adherence trend over 7 and 30 days. | 🟡 P2 | - [ ] |
| FR-GRAPH-007 | Trend graphs shall render fully offline using locally stored data. | 🔴 P1 | - [ ] |
| FR-GRAPH-008 | Graphs shall include reference lines for the patient's personalised target values (e.g., target BP). | 🟢 P3 | - [ ] |

---

## 12. Patient–Clinician Communication
TO BE DROPPED

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-COM-001 | The system shall allow a clinician to view their assigned patients' health data (vitals, symptoms, medication logs). | 🔴 P1 | - [ ] |
| FR-COM-002 | The system shall allow a patient to share a health summary report with their clinician before a visit. | 🟡 P2 | - [ ] |
| FR-COM-003 | The system shall allow a clinician to receive real-time alerts when a patient records a critical reading (via WebSocket). | 🟡 P2 | - [ ] |
| FR-COM-004 | The system shall allow a clinician to review vitals and logs remotely between appointments. | 🟡 P2 | - [ ] |
| FR-COM-005 | The system shall allow a clinician to update a shared care plan that the patient can view in-app. | 🟢 P3 | - [ ] |
| FR-COM-006 | The system shall generate a visit preparation summary for the patient before a scheduled appointment, showing recent vitals and symptoms. | 🟢 P3 | - [ ] |
| FR-COM-007 | The system shall allow a clinician to add notes or comments on a patient's data entry. | 🔵 P4 | - [ ] |
| FR-COM-008 | The system shall support in-app messaging between patient and clinician. | 🔵 P4 | - [ ] |

---

## 13. Follow-Up & Appointment Support
TO BE DROPPED

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-APT-001 | The system shall allow a patient to record upcoming follow-up appointments (date, time, location, type). | 🔴 P1 | - [ ] |
| FR-APT-002 | The system shall send a local reminder notification to the patient 24 hours before a scheduled appointment. | 🔴 P1 | - [ ] |
| FR-APT-003 | The system shall send a local reminder notification 1 hour before a scheduled appointment. | 🟡 P2 | - [ ] |
| FR-APT-004 | The system shall allow a clinician to schedule follow-up appointments for patients via the clinician view. | 🟡 P2 | - [ ] |
| FR-APT-005 | The system shall allow a patient to mark an appointment as completed or missed. | 🔴 P1 | - [ ] |
| FR-APT-006 | The system shall allow a clinician to flag abnormal readings that require an earlier follow-up. | 🟢 P3 | - [ ] |
| FR-APT-007 | Appointment data shall be stored locally and accessible offline. | 🔴 P1 | - [ ] |

---

## 14. Offline Functionality

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-OFF-001 | The system shall allow a patient to log vitals, symptoms, medications, and activity with no internet connection. | 🔴 P1 | - [ ] |
| FR-OFF-002 | The system shall store all user-generated records in a local SQLite database on the device. | 🔴 P1 | - [ ] |
| FR-OFF-003 | The system shall maintain a sync queue of all records created while offline, marked as PENDING. | 🔴 P1 | - [ ] |
| FR-OFF-004 | The system shall automatically trigger a background sync when internet connectivity is detected. | 🔴 P1 | - [ ] |
| FR-OFF-005 | The sync process shall submit pending records to the server in a single batched API call to minimise data usage. | 🔴 P1 | - [ ] |
| FR-OFF-006 | Each offline record shall carry a client-generated UUID (`client_record_id`) to prevent duplicate entries on re-submission. | 🔴 P1 | - [ ] |
| FR-OFF-007 | The system shall handle sync conflicts using a last-recorded-timestamp-wins strategy per record. | 🔴 P1 | - [ ] |
| ⚠️ FR-OFF-007 — **implemented as an approved deviation (owner sign-off 2026-07-19).** The Slice 7 sync engine detects and *reports* conflicts (per-record `CONFLICT` status) but does **not** overwrite: the first-stored record always wins, because all log tables are append-only/immutable and the phone is the sole writer, so a divergent payload under an existing `client_record_id` signals a client bug rather than a legitimate edit. Overwriting would mutate clinical history with no audit trail. See `docs/design/2026-07-17-sync-design.md`, Decision 3. | | |
| FR-OFF-008 | The system shall notify the user if a sync fails, and retain records in the queue for retry. | 🟡 P2 | - [ ] |
| FR-OFF-009 | All education content shall be bundled into the app and available offline without a server request. | 🔴 P1 | - [ ] |
| FR-OFF-010 | Medication reminders and appointment notifications shall fire locally without any server dependency. | 🔴 P1 | - [ ] |
| FR-OFF-011 | The dashboard and trend graphs shall render using locally stored data when offline. | 🔴 P1 | - [ ] |

---

## 15. Notifications & Reminders

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-NOT-001 | The system shall send a local push notification at each scheduled medication time. | 🔴 P1 | - [ ] |
| FR-NOT-002 | The system shall send a follow-up reminder 1 hour after a missed scheduled dose. | 🔴 P1 | - [ ] |
| FR-NOT-003 | The system shall send an adherence alert notification if 2 or more consecutive doses are missed. | 🔴 P1 | - [ ] |
| FR-NOT-004 | The system shall send a reminder notification for scheduled follow-up appointments. | 🔴 P1 | - [ ] |
| FR-NOT-005 | The system shall send a daily prompt to complete the symptom check-in (configurable time). | 🟡 P2 | - [ ] |
| FR-NOT-006 | The system shall send an in-app alert when a recorded vital exceeds a clinical threshold. | 🔴 P1 | - [ ] |
| FR-NOT-007 | All notification text shall be available in both English and Amharic. | 🔴 P1 | - [ ] |
| FR-NOT-008 | The system shall allow a patient to configure their preferred notification times. | 🟡 P2 | - [ ] |
| FR-NOT-009 | The system shall allow a patient to mute non-critical notifications for a defined period. | 🟢 P3 | - [ ] |
| FR-NOT-010 | The system shall allow a caregiver/family member to optionally receive missed-dose notifications. | 🟢 P3 | - [ ] |

---

## 16. Localisation & Accessibility

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-LOC-001 | The system shall support English as the default language. | 🔴 P1 | - [ ] |
| FR-LOC-002 | The system shall support Amharic as a full alternative language for all screens, labels, and content. | 🔴 P1 | - [ ] |
| FR-LOC-003 | The system shall allow a patient to select their preferred language during onboarding, with the option to change it later. | 🔴 P1 | - [ ] |
| FR-LOC-004 | The system shall use simple, plain language across all user-facing text to accommodate low digital literacy. | 🔴 P1 | - [ ] |
| FR-LOC-005 | The system shall use visual icons and illustrations alongside text labels to aid comprehension. | 🟡 P2 | - [ ] |
| FR-LOC-006 | The system shall use large touch targets (minimum 44×44 dp) to aid users with low device familiarity. | 🟡 P2 | - [ ] |
| FR-LOC-007 | The system shall support screen reader accessibility (TalkBack on Android, VoiceOver on iOS). | 🟢 P3 | - [ ] |
| FR-LOC-008 | The system shall use high-contrast colour schemes to ensure readability in bright outdoor environments. | 🟡 P2 | - [ ] |

---

## 17. Non-Functional Requirements

These are system-quality constraints rather than discrete features, but they are equally required for the app to function appropriately in the Ethiopian low-resource context.

| ID | Requirement | Priority |
|---|---|---|
| NFR-001 | The app shall function on Android devices running Android 8.0 (API 26) or later. | 🔴 P1 |
| NFR-002 | The app shall function on iOS devices running iOS 13 or later. | 🔴 P1 |
| NFR-003 | The app shall load the home screen within 2 seconds on a mid-range Android device (e.g., 2 GB RAM). | 🟡 P2 |
| NFR-004 | All locally stored health data shall be encrypted at rest using AES-256 (via SQLCipher or equivalent). | 🔴 P1 |
| NFR-005 | All API communication shall use HTTPS with TLS 1.2 or higher. | 🔴 P1 |
| NFR-006 | The Spring Boot API shall respond to standard requests within 500ms under normal load. | 🟡 P2 |
| NFR-007 | The app's installed size shall not exceed 50 MB to accommodate devices with limited storage. | 🟡 P2 |
| NFR-008 | The sync process shall minimise data transfer volume to reduce costs for users on metered mobile data. | 🔴 P1 |
| NFR-009 | The app shall handle loss of network connectivity gracefully, with no crashes or data loss. | 🔴 P1 |
| NFR-010 | Patient health data shall not be shared with any third-party analytics or advertising service. | 🔴 P1 |

---

## Requirements Summary

| Priority | Count |
|---|---|
| 🔴 P1 — Must Have | 82 |
| 🟡 P2 — Should Have | 33 |
| 🟢 P3 — Nice to Have | 13 |
| 🔵 P4 — Stretch Goal | 4 |
| **Total** | **132** |

---

*This document is a living reference. Requirements should be checked off as they are implemented and verified. Any scope changes agreed with the client (Tesema Etefa Birhanu) or supervisors must be reflected here and communicated to the subject coordinator.*
