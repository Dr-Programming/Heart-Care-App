# Slice ownership

Who owns what. **This file is the single source of truth for assignment** —
if it disagrees with anything else, this wins.

One slice, one owner, end to end: domain, data, presentation, tests. Six
slices for six developers. Fill in the Owner column when the maintainer
assigns, and open a PR for the change like any other.

---

## Assignments

| Slice | Owner | Branch | Spec | Status |
|---|---|---|---|---|
| **M0** Foundation & app shell | *maintainer* | `mobile` | [programme](../docs/design/2026-08-22-mobile-frontend-program.md) | ✅ **Done** — 112 tests green |
| **M1** Auth & session | | `feature/mobile/auth` | [spec](../docs/design/2026-08-22-mobile-m1-auth-design.md) | Not started |
| **M2** Profile, onboarding & settings | | `feature/mobile/profile` | [spec](../docs/design/2026-08-22-mobile-m2-profile-onboarding-design.md) | Not started |
| **M3** Medications, dose logs & reminders | | `feature/mobile/medications` | [spec](../docs/design/2026-08-22-mobile-m3-medications-reminders-design.md) | In review |
| **M4** Vitals & trend charts | | `feature/mobile/vitals` | [spec](../docs/design/2026-08-22-mobile-m4-vitals-trends-design.md) | Not started |
| **M5** Symptoms, activity & guidance | | `feature/mobile/symptoms-activity` | [spec](../docs/design/2026-08-22-mobile-m5-symptoms-activity-guidance-design.md) | Not started |

M0 is the maintainer's slice and is already built — the Drift schema for every
feature, the sync engine, the offline clinical evaluator, the router, the
five-tab shell, the shared widget kit and the test helpers. It is the thing the
other five plug into, which is why it had to be finished first.

---

## What each slice is like

Read this before assigning. The slices are deliberately comparable in size,
but not in character.

**M1 — Auth & session.** Six screens and a full vertical rebuild, plus the
router's auth gate. Give it to whoever is fastest and **start it first**: it is
the critical path for manual end-to-end testing, because nothing else can reach
a real token until login exists. It does *not* block anyone's development —
every other slice's local path and tests are buildable without a session.

**M2 — Profile, onboarding & settings.** A three-step wizard plus profile,
settings and the language toggle. The slice with the sharpest trap in it:
`PUT /patients/me` is a full replace, so a one-field edit that sends one field
silently erases the rest of the patient's profile. Also owns the app-wide
accessibility pass.

**M3 — Medications, dose logs & reminders.** The largest team slice. Medication
CRUD, schedule maths, dose logging, adherence percentages, **and** local
notifications. Two skills in one. If someone has less time than the others,
this is not their slice.

**M4 — Vitals & trend charts.** Five metric types behind one polymorphic
endpoint, plus `fl_chart` trends. The most data-modelling of the five: done
well it is one entity with a typed values map; done badly it is the same code
five times.

**M5 — Symptoms, activity & guidance.** Two logging verticals plus all the
bundled education and diet content in English and Amharic. **No Figma screens
exist for any of it** — the most actual design work, and the most writing. Good
for someone who wants scope to make decisions rather than match a mockup.

---

## Rules

- **One owner per slice.** Two people in one feature folder is the merge
  conflict this whole layout exists to prevent.
- **Branch from `mobile`, PR into `mobile`.** Never `dev`, never `main`.
- **Everyone needs write access** to the repository before they can clone —
  it is private.
- Slices are genuinely parallel. M4 wants profile height for BMI and M3's
  cross-signal wants symptom data, but both read Drift tables that already
  exist and both degrade to "—" when the other slice has written nothing yet.
  **Build for the empty case**; do not wait on each other.

---

## Getting started

Read [CONTRIBUTING.md](CONTRIBUTING.md) first — setup, the architectural
rules, the shared files nobody may edit, and the starter prompt for your first
session. Then your spec, linked above.

Keep the Status column current: `Not started` → `In progress` → `In review` →
`Merged`. It is the fastest way for the maintainer to see where the programme
actually is.
