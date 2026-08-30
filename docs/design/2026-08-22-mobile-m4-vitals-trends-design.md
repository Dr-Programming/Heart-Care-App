# Mobile Design — M4 (Vitals & Trend Charts)

**Date:** 2026-08-22
**Branch:** `feature/mobile/vitals`
**Base:** `mobile`
**Status:** Approved for planning
**Depends on:** M0 (merged). Reads `PatientProfiles` for height and goals; degrades safely without them.

---

## 0. How to use this spec

This is a design document, not a plan. Your first task is to turn it into one.

1. `/superpowers:brainstorming` — settle what is left open below.
2. `/superpowers:writing-plans` → `docs/plans/2026-XX-XX-mobile-m4-vitals.md`.
3. `/superpowers:subagent-driven-development` — execute task by task.
4. `/superpowers:requesting-code-review`, then
   `/superpowers:finishing-a-development-branch` — PR into `mobile`.

Read `mobile/CONTRIBUTING.md` first. Build bottom-up:
domain → data → presentation.

---

## 1. Context & goal

Vitals are where the app earns a patient's trust: they enter a blood pressure
and immediately learn whether it is in range and how it compares with last
week. This slice owns capture, history and the trend charts.

Five metric types share one endpoint with a polymorphic `values` object, so
the interesting design work is modelling that variation without five parallel
copies of everything.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md` §9, §10, §11)

FR-VIT-001 (BP), 002 (glucose), 003 (heart rate), 004 (weight + BMI), 005
(timestamp), 006 (full history), 007 (local first, synced when online), 008
(flag readings past clinical thresholds on entry), 009 (cholesterol).

FR-GRAPH-001 to 004 (7- and 30-day trends for BP, weight, glucose), 007
(charts render offline), 008 (reference lines at the patient's targets).

FR-DASH-002 (latest BP, colour-coded), 003 (weight and BMI), 004 (glucose),
005 (cholesterol) — delivered as your Home card.

### Deferred / out of scope (and where it lands)

- **FR-GRAPH-005, activity trend** — activity data belongs to **M5**. If both
  slices land early, the chart widget you build is the natural home for it;
  agree that with M5 rather than reaching into their tables speculatively.
- **FR-GRAPH-006, adherence trend** — **M3** computes the percentages.
- **FR-DASH-007, today's adherence** — M3's Home card.
- **FR-DASH-008, goal progress feedback** — you compare readings against the
  goals M2 stores and can show "target met" on your own card; the broader
  goal-progress card is M2's.

---

## 2. Design decisions

### Decision 1 — One entity with a typed `values` map, not five entities

`VitalType` drives everything: which fields the form shows, which keys the
`values` object must contain, which units are displayed, which thresholds
apply. Five separate entities would duplicate the repository, the datasource
and the history list four times over.

Model it as one `VitalReading` carrying a type and a values map, with a
per-type descriptor (required keys, ranges, units, labels) as the single seam.
Adding a sixth metric should be a new descriptor, not a new layer.

The server is strict: `values` must contain **exactly** the required keys for
the type — no extras, none missing.

| Type | Keys | Range | Unit |
|---|---|---|---|
| `BLOOD_PRESSURE` | `systolic`, `diastolic` | 40–300, systolic > diastolic | mmHg |
| `GLUCOSE` | `glucose` | 0–50 | mmol/L |
| `HEART_RATE` | `heartRate` | 20–300 | bpm |
| `WEIGHT` | `weight` | 0–500 | kg (response adds `bmi`) |
| `CHOLESTEROL` | `ldl`, `hdl`, `total` | 0–30 each | mmol/L |

### Decision 2 — The server owns `flagged`; the client computes it anyway

`flagged` and `bmi` are computed server-side and are authoritative once a
reading has synced. But a reading entered offline has no server answer, and
showing nothing — or worse, showing "normal" by default — for a systolic of
190 would be a clinical failure.

So compute locally with `isVitalFlagged` and `severityForVital` from
`core/clinical/alert_evaluator.dart`, which **mirror the backend exactly**.
Store the server's value when it arrives. Because the two agree by
construction, the status never changes under the patient after a sync.

Do not write your own thresholds. If you think one is wrong, that is a
conversation with the maintainer and the backend, not a local edit — the whole
point is that the two sides cannot drift.

### Decision 3 — BMI is computed locally for display and replaced by the server's snapshot

The server computes BMI on a `WEIGHT` reading when profile height is known,
and stores it as a snapshot on that reading — deliberately, so a later height
correction does not silently rewrite past readings.

Locally, read `heightCm` from `PatientProfiles` (M2's table, in `core/`, no
import needed) and compute `kg / m²` for immediate display. When the reading
syncs, keep the server's `bmi`. With no height stored, show the weight alone
and prompt the patient to add their height — do not guess one.

### Decision 4 — Readings are immutable

Append-only, like every log table. No edit, no delete. A mistyped reading is
corrected by adding the right one; the wrong one stays in history because
clinical history with silent edits and no audit trail is worse than clinical
history with a visible mistake.

This is also why the sync engine treats `CONFLICT` as terminal: the stored
record always wins.

### Decision 5 — Charts read Drift and never the network

`fl_chart`, already in `pubspec.yaml`. Every series comes from a local query
over `VitalsLogs` in the window, so charts render with the radio off
(FR-GRAPH-007) with no loading state at all.

Build one chart widget parameterised by series, not one per metric. Blood
pressure is the awkward case — two series on one axis — so design for that
first and the others fall out.

**Resolved shape (settled 2026-08-30):** `build_series` produces a pure-Dart
`VitalSeries { key, List<VitalPoint>(date, value), double? targetValue, min,
max, avg }` per line — one for glucose/weight, two (`systolic`, `diastolic`)
for blood pressure, sharing one x/y axis. Presentation maps each
`VitalSeries` to a `ChartSeries` (adds a `Color`) and hands the list to one
`TrendChart(List<ChartSeries>)` widget; the widget knows nothing about vital
types, only lines. `targetValue` comes from `PatientProfiles.goalsJson`
(`bpSystolic`, `bpDiastolic`, `targetWeightKg`); glucose has no goal field in
the schema, so its series never carries one — that's correct, not a gap. The
min/max/avg for the screen's summary row is computed once inside
`build_series` alongside the points, not as a separate pass. This is the
widget M5 can hand an activity series later (§1), unchanged.

Reference lines come from the goals in `PatientProfiles` (FR-GRAPH-008). No
goal set means no line, not a default line: an invented target on a clinical
chart is a made-up clinical claim.

### Decision 6 — A chart with too little data says so

Two points over thirty days is not a trend, and drawing it as one is
misleading. Below a threshold you choose and state, show the readings as a
list with an explanation rather than a line.

**Resolved (settled 2026-08-30): the threshold is 3 readings in the selected
window.** Two points is just a line between two dots with no shape; three is
the minimum that can show a direction. Below it, the trend screen shows the
readings as a list (`reading_row.dart`) with an explanation instead of
`TrendChart`.

### Decision 7 — Entry is fast, and forgiving about time

Most readings are entered right after they are taken, so default `measuredAt`
to now and let it be changed. Numeric keypads, sensible step sizes, the last
value as a hint. A patient recording a BP twice a day will do this ~700 times
a year; every extra tap is 700 taps.

Send `measuredAt` as UTC ISO-8601 (`DateFormatter.toApiDateTime`) so a
patient's history does not reorder itself if they change timezone.

---

## 3. Screens

| Screen | Route | Source | Contents | States |
|---|---|---|---|---|
| **Vitals (tab root)** | `AppRoutes.vitals` | Figma Vitals | Latest reading per type as `MetricTile` + `StatusChip`; sparkline or trend entry point per type; log button | loading · empty · loaded · offline |
| **Log a reading** | `vitalsLog` | — | Type selector, then the fields for that type; measured-at; optional note; immediate in-range/out-of-range feedback on save | idle · validating · saving · flagged result |
| **History** | `vitalsHistory` | — | Reverse-chronological, filterable by type and date range, with status chips and per-row sync state | loading · empty · loaded |
| **Trend** | `vitalsTrend` (`:type`) | — | 7-day / 30-day toggle, target reference line, min–max–average summary | loading · insufficient data · loaded |
| **Home card** | — | — | Latest BP, weight + BMI, glucose; order 200 | empty · loaded |

When a saved reading is out of range, say so on the spot with the recommended
action from `actionKeyFor(severity)` (FR-VIT-008, FR-DEC-009) — inline, not as
a separate Alerts screen (programme decision D4).

Copy goes in the `vitals.*` namespace. Units are not translated; labels are.

---

## 4. API contract

From `backend/docs/API.md` §4. **Success is always `200`.** Envelope as usual.

### `POST /api/v1/vitals`

```jsonc
{ "type": "BLOOD_PRESSURE",
  "values": { "systolic": 128, "diastolic": 82 },
  "measuredAt": "2026-08-22T06:30:00Z",   // optional, defaults to now
  "note": "before breakfast",             // optional, <= 500
  "clientRecordId": "..." }               // optional but always send one
// 200 -> the stored reading, with server-computed `flagged` and, for WEIGHT, `bmi`
```

Message: `"Vital logged"`. `400` if `values` does not contain exactly the
required keys for the type, or a value is out of range.

### `GET /api/v1/vitals`

Newest first. `?type=&from=&to=`, dates `yyyy-MM-dd`.

### Sync

```jsonc
{ "clientRecordId": "...", "entityType": "VITAL", "payload": { /* the POST body */ } }
```

Any `clientRecordId` inside the payload is ignored — the envelope's is the
idempotency key.

### Flag thresholds (the server's, mirrored in `core/clinical`)

Flagged when a value is **at or beyond** a bound: systolic 90/180 · diastolic
60/120 · glucose 4.0/11.1 · heartRate 40/120 · bmi 18.5/30 · ldl —/4.9 ·
total —/7.5 · hdl 1.0/—.

Documented defaults, **pending clinical sign-off**. Not approved clinical
guidance.

---

## 5. Local state & offline behaviour

**Table:** `VitalsLogs` — `clientRecordId` (PK), `serverId`, `type`,
`valuesJson`, `flagged`, `bmi`, `measuredAt`, `note`. Append-only.

**Write:** mint `newClientRecordId()`, compute `flagged` locally, write to
Drift, then `syncEnqueuerProvider.enqueue(..., SyncEntityType.vital, ...)`.
Never await the network.

**Read:** Drift only. History, charts and the Home card must all render with
the radio off.

**Cross-slice reads:** `PatientProfiles.heightCm` for BMI and
`PatientProfiles.goalsJson` for reference lines. Read the table directly —
both live in `core/db`, so this is not a cross-feature import. Handle a
missing profile gracefully; M2 may not have landed yet.

**Per-row sync state:** `SyncQueueDao.statusFor(clientRecordId)`.

---

## 6. Feature layout

```
lib/features/vitals/
  vitals_providers.dart
  domain/
    entities/{vital_reading,vital_type,vital_series}.dart
    vital_descriptors.dart      per-type keys, ranges, units, labels
    repositories/vitals_repository.dart
    usecases/{log_vital,watch_history,build_series,latest_by_type}.dart
    bmi.dart
    validators.dart
  data/
    models/vital_model.dart
    datasources/vitals_remote_datasource.dart
    datasources/vitals_local_datasource.dart
    repositories/vitals_repository_impl.dart
  presentation/
    controllers/{vitals_list,vital_form,vitals_trend}_controller.dart
    screens/{vitals,vital_form,vitals_history,vitals_trend}_screen.dart
    widgets/{vital_form_fields,reading_row,trend_chart,sparkline,range_toggle}.dart
    home/latest_vitals_card.dart          order 200
```

Register in `lib/app/app_wiring.dart`, `M4 vitals` region: the tab root and
sub-routes, plus your Home card.

---

## 7. Files this slice may NOT touch

`backend/**` and `database/**` are **read-only and frozen at `v1.0.0`** — reading the Java is encouraged (this spec asks you to), changing it is not, and CI blocks it.

`lib/core/**` · `lib/main.dart` · `pubspec.yaml` · `tables.dart` ·
`api_endpoints.dart`. `VitalsLogs`, `ApiEndpoints.vitals`, `fl_chart` and the
whole clinical evaluator already exist.

**Especially do not edit `core/clinical/alert_evaluator.dart`.** Its thresholds
mirror the backend; changing one here makes the client and server disagree.

Allowed, in your marked region only: `lib/app/app_wiring.dart`, and the
`vitals.*` namespace in `assets/translations/*.json`.

---

## 8. Testing strategy (TDD)

**`vital_descriptors_test`** — every type declares exactly the keys the API
requires; ranges match the documented bounds; a BP with systolic ≤ diastolic
is rejected; an extra key is rejected; a missing key is rejected.

**`bmi_test`** — 70 kg at 175 cm is 22.9; null height yields null, not zero or
an exception; a zero or negative height does not divide by zero.

**`vitals_local_datasource_test`** (`testDatabase()`) — round-trips each of the
five types with its own `values` shape; history is newest-first; the type
filter works; the date-window query has the right inclusive bounds; latest-by-
type returns nothing for a type never recorded.

**`vitals_remote_datasource_test`** (`FakeDio`) — the posted body carries
exactly the required keys; `measuredAt` is UTC ISO-8601; unwraps a **200**;
a `400` surfaces the server's field list.

**`vitals_repository_impl_test`** — logging offline writes to Drift, enqueues
a `VITAL` record and makes **no request**; the locally computed `flagged`
matches what the server would have returned for the same reading (this is the
test that protects the offline/online agreement); the server's `bmi` replaces
the locally computed one once synced.

**`build_series_test`** — a 7-day window includes today and excludes day 8;
BP produces two series from one set of readings; an empty window is
"insufficient data", not an empty chart; readings are ordered oldest-to-newest
for plotting even though history is newest-first.

**Widget tests** (`pumpApp`) — the form shows two fields for BP and three for
cholesterol; an out-of-range value is blocked before submit; saving a systolic
of 190 shows an urgent status and its recommended action; the history list
filters by type; a trend with two points shows the insufficient-data state;
the Home card shows "—" for a type with no readings rather than hiding it;
at least one screen asserted in Amharic.

---

## 9. "Done" criteria

- A patient records all five vital types, each with the right fields and
  units, and sees an immediate in-range or out-of-range verdict with a
  recommended action.
- Weight shows a BMI when a height is stored, and prompts for one when not.
- History is browsable and filterable by type and date.
- 7-day and 30-day trends render for BP, weight and glucose, with the
  patient's target as a reference line when one is set, and say so plainly
  when there is not enough data.
- Everything above works **with the radio off**, including the charts.
- A reading logged offline shows the same status before and after it syncs.
- Everything created offline reaches the server after reconnecting, with no
  duplicates.
- `flutter analyze` clean; whole suite green; CI passing.

---

## 10. Handover checklist

- [ ] Plan committed to `docs/plans/`
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Ran the app against a local backend; specifically verified that a
      reading's status is identical before and after sync
- [ ] Stated the minimum-points threshold for drawing a trend
- [ ] No edits to `core/clinical/`, or to any shared file outside the marked
      regions
- [ ] Screenshots in the PR, English and Amharic, including a chart
- [ ] No AI co-author trailer on any commit
- [ ] PR into `mobile`, title `feat(mobile): M4 — Vitals & trend charts`
- [ ] Told M5 whether the chart widget can take an activity series
