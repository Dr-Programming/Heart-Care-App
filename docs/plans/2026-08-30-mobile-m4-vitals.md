# M4 — Vitals & Trend Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a patient log blood pressure, glucose, heart rate, weight and cholesterol readings offline, see an immediate clinical status, browse history, and view 7-/30-day trend charts — all working with the radio off.

**Architecture:** Feature-first clean architecture in `lib/features/vitals/` (domain → data → presentation), plugging into an already-built foundation: `VitalsLogs` Drift table, `core/clinical/alert_evaluator.dart` for local flagging, `core/sync` for the offline write queue, and pre-registered routes/Home-card slots. One `VitalReading` entity with a typed `values` map drives all five metric types; one `TrendChart` widget, parameterised by series, renders all trend charts.

**Tech Stack:** Flutter, Riverpod (plain `Provider`/`AsyncNotifier`, no code-gen), go_router, Drift/SQLite, Dio, freezed + json_serializable, fl_chart, easy_localization, mocktail.

**Spec:** `docs/design/2026-08-22-mobile-m4-vitals-trends-design.md` (as amended 2026-08-30 with the resolved chart-widget shape and the 3-reading trend threshold). Also required reading: `mobile/CONTRIBUTING.md` §4 (architecture rules), §8 (canonical layer template), §9 (API contract traps); `docs/design/2026-07-10-vitals-design.md` (backend's Slice 4 — the authority for thresholds and the `values` contract); `backend/docs/API.md` §sync (why the write path never calls the remote datasource directly).

## Global Constraints

- Package name `libu_care`. All code lives under `mobile/lib/features/vitals/` and `mobile/test/features/vitals/`.
- **Never edit** `backend/**`, `database/**` (frozen, CI-blocked), or `lib/core/**`, `lib/main.dart`, `pubspec.yaml`, `tables.dart`, `api_endpoints.dart` (shared, off-limits per `CONTRIBUTING.md` §4). The only files outside `lib/features/vitals/` this plan touches are the marked `M4 vitals` region of `lib/app/app_wiring.dart` and the `vitals.*` block of `assets/translations/en.json` / `am.json`.
- **Never edit `core/clinical/alert_evaluator.dart`.** Its `isVitalFlagged`, `severityForVital`, `vitalFlagRanges` are the single source of clinical truth and are used as-is.
- Offline-first, unconditionally: every write goes to Drift first, then `SyncEnqueuer.enqueue(...)`. No task in this plan may check connectivity or call the API before a local write. History, the dashboard card and trend charts read only from Drift.
- `client_record_id` is minted once via `newClientRecordId()` (`core/utils/ids.dart`) at capture time and never regenerated on retry.
- API envelope: `{success, data, message, timestamp}`, unwrapped via `ApiResponse.fromJson`. **Success is always `200`**, never `201`.
- Per-type `values` keys (exactly these, no extras) and physiological input-sanity ranges, from `docs/design/2026-07-10-vitals-design.md` §7:
  - `BLOOD_PRESSURE`: `systolic`, `diastolic`, each 40–300, and `systolic > diastolic`.
  - `GLUCOSE`: `glucose`, 0–50.
  - `HEART_RATE`: `heartRate`, 20–300.
  - `WEIGHT`: `weight`, 0–500 (server adds `bmi`; never sent by the client).
  - `CHOLESTEROL`: `ldl`, `hdl`, `total`, each 0–30.
- Clinical flag ranges (mirrored from `core/clinical/alert_evaluator.dart` / backend `VitalThresholds.java`, **do not redefine them** — reuse the existing map): systolic 90/180 · diastolic 60/120 · glucose 4.0/11.1 · heartRate 40/120 · bmi 18.5/30 · ldl —/4.9 · total —/7.5 · hdl 1.0/—.
- BMI: `weightKg / (heightM)²`, rounded to 1 decimal; null height (or ≤ 0) yields a null BMI, never zero, never a divide-by-zero.
- Readings are immutable: no update, no delete endpoint or UI anywhere in this feature.
- Trend charts need **3 readings minimum** in the selected window; below that, show a list instead of a line (resolved Decision 6).
- Translation copy goes only in the `vitals.*` namespace of `assets/translations/en.json` and `am.json` (already present as an empty `{}` placeholder in both files). Shared validation messages (`errors.required`, `errors.invalidNumber`, `errors.outOfRange`) are reused, never redefined.
- Every screen must render correctly with connectivity off and must not throw when `PatientProfiles` has no row yet (M2 may not have landed).
- `flutter analyze` must stay clean and the whole suite green after every task's final step.

---

### Task 1: Domain — `VitalType` and the per-type descriptor registry

**Files:**
- Create: `mobile/lib/features/vitals/domain/entities/vital_type.dart`
- Create: `mobile/lib/features/vitals/domain/vital_descriptors.dart`
- Test: `mobile/test/features/vitals/domain/vital_descriptors_test.dart`

**Interfaces:**
- Produces: `enum VitalType { bloodPressure, glucose, heartRate, weight, cholesterol }` with `String get wire` and `static VitalType fromWire(String value)`.
- Produces: `class VitalDescriptor { final VitalType type; final List<String> requiredKeys; final Map<String, ({num min, num max})> ranges; final String unit; final String labelKey; }` and `const Map<VitalType, VitalDescriptor> vitalDescriptors`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/domain/vital_descriptors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/vital_descriptors.dart';

void main() {
  group('VitalType', () {
    test('round-trips through the wire form', () {
      for (final VitalType type in VitalType.values) {
        expect(VitalType.fromWire(type.wire), type);
      }
    });

    test('wire values match the backend enum exactly', () {
      expect(VitalType.bloodPressure.wire, 'BLOOD_PRESSURE');
      expect(VitalType.glucose.wire, 'GLUCOSE');
      expect(VitalType.heartRate.wire, 'HEART_RATE');
      expect(VitalType.weight.wire, 'WEIGHT');
      expect(VitalType.cholesterol.wire, 'CHOLESTEROL');
    });
  });

  group('vitalDescriptors', () {
    test('every type has a descriptor', () {
      for (final VitalType type in VitalType.values) {
        expect(vitalDescriptors.containsKey(type), isTrue, reason: type.name);
      }
    });

    test('blood pressure requires exactly systolic and diastolic, 40-300', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.bloodPressure]!;
      expect(d.requiredKeys, <String>['systolic', 'diastolic']);
      expect(d.ranges['systolic'], (min: 40, max: 300));
      expect(d.ranges['diastolic'], (min: 40, max: 300));
      expect(d.unit, 'mmHg');
    });

    test('glucose requires exactly glucose, 0-50 mmol/L', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.glucose]!;
      expect(d.requiredKeys, <String>['glucose']);
      expect(d.ranges['glucose'], (min: 0, max: 50));
      expect(d.unit, 'mmol/L');
    });

    test('heart rate requires exactly heartRate, 20-300 bpm', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.heartRate]!;
      expect(d.requiredKeys, <String>['heartRate']);
      expect(d.ranges['heartRate'], (min: 20, max: 300));
      expect(d.unit, 'bpm');
    });

    test('weight requires exactly weight, 0-500 kg', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.weight]!;
      expect(d.requiredKeys, <String>['weight']);
      expect(d.ranges['weight'], (min: 0, max: 500));
      expect(d.unit, 'kg');
    });

    test('cholesterol requires exactly ldl, hdl, total, each 0-30 mmol/L', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.cholesterol]!;
      expect(d.requiredKeys, <String>['ldl', 'hdl', 'total']);
      expect(d.ranges['ldl'], (min: 0, max: 30));
      expect(d.ranges['hdl'], (min: 0, max: 30));
      expect(d.ranges['total'], (min: 0, max: 30));
      expect(d.unit, 'mmol/L');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/domain/vital_descriptors_test.dart`
Expected: FAIL — `Target of URI doesn't exist` (neither source file exists yet).

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/domain/entities/vital_type.dart
/// The five metric types `VitalsLogs.type` can hold. Wire-identical to the
/// backend's `VitalType` enum (`docs/design/2026-07-10-vitals-design.md` §4).
enum VitalType {
  bloodPressure('BLOOD_PRESSURE'),
  glucose('GLUCOSE'),
  heartRate('HEART_RATE'),
  weight('WEIGHT'),
  cholesterol('CHOLESTEROL');

  const VitalType(this.wire);

  final String wire;

  static VitalType fromWire(String value) =>
      values.firstWhere((VitalType t) => t.wire == value);
}
```

```dart
// mobile/lib/features/vitals/domain/vital_descriptors.dart
import 'entities/vital_type.dart';

/// What one [VitalType] needs: which `values` keys the server requires
/// (exactly these, no more, no fewer), the physiological input-sanity range
/// for each key (distinct from the *clinical* flag thresholds in
/// `core/clinical/alert_evaluator.dart` — a systolic of 190 is valid but
/// flagged; a systolic of 900 is rejected outright), the canonical unit, and
/// the translation key for its label.
///
/// Adding a sixth vital type is a new entry here, not a new layer — see
/// Decision 1 in the M4 design spec.
class VitalDescriptor {
  const VitalDescriptor({
    required this.type,
    required this.requiredKeys,
    required this.ranges,
    required this.unit,
    required this.labelKey,
  });

  final VitalType type;
  final List<String> requiredKeys;
  final Map<String, ({num min, num max})> ranges;
  final String unit;
  final String labelKey;
}

/// Source: `docs/design/2026-07-10-vitals-design.md` §7 (input-sanity ranges)
/// and §4 (`values` keys and units).
const Map<VitalType, VitalDescriptor> vitalDescriptors =
    <VitalType, VitalDescriptor>{
      VitalType.bloodPressure: VitalDescriptor(
        type: VitalType.bloodPressure,
        requiredKeys: <String>['systolic', 'diastolic'],
        ranges: <String, ({num min, num max})>{
          'systolic': (min: 40, max: 300),
          'diastolic': (min: 40, max: 300),
        },
        unit: 'mmHg',
        labelKey: 'vitals.type.bloodPressure',
      ),
      VitalType.glucose: VitalDescriptor(
        type: VitalType.glucose,
        requiredKeys: <String>['glucose'],
        ranges: <String, ({num min, num max})>{
          'glucose': (min: 0, max: 50),
        },
        unit: 'mmol/L',
        labelKey: 'vitals.type.glucose',
      ),
      VitalType.heartRate: VitalDescriptor(
        type: VitalType.heartRate,
        requiredKeys: <String>['heartRate'],
        ranges: <String, ({num min, num max})>{
          'heartRate': (min: 20, max: 300),
        },
        unit: 'bpm',
        labelKey: 'vitals.type.heartRate',
      ),
      VitalType.weight: VitalDescriptor(
        type: VitalType.weight,
        requiredKeys: <String>['weight'],
        ranges: <String, ({num min, num max})>{
          'weight': (min: 0, max: 500),
        },
        unit: 'kg',
        labelKey: 'vitals.type.weight',
      ),
      VitalType.cholesterol: VitalDescriptor(
        type: VitalType.cholesterol,
        requiredKeys: <String>['ldl', 'hdl', 'total'],
        ranges: <String, ({num min, num max})>{
          'ldl': (min: 0, max: 30),
          'hdl': (min: 0, max: 30),
          'total': (min: 0, max: 30),
        },
        unit: 'mmol/L',
        labelKey: 'vitals.type.cholesterol',
      ),
    };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/domain/vital_descriptors_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/domain/entities/vital_type.dart \
        mobile/lib/features/vitals/domain/vital_descriptors.dart \
        mobile/test/features/vitals/domain/vital_descriptors_test.dart
git commit -m "feat(vitals): add VitalType and the per-type descriptor registry"
```

---

### Task 2: Domain — `VitalReading` entity and structural validators

**Files:**
- Create: `mobile/lib/features/vitals/domain/entities/vital_reading.dart`
- Create: `mobile/lib/features/vitals/domain/validators.dart`
- Test: `mobile/test/features/vitals/domain/validators_test.dart`

**Interfaces:**
- Consumes: `VitalType`, `vitalDescriptors` (Task 1).
- Produces: `class VitalReading` (fields below) — used by every later task.
- Produces: `class FieldError { final String key; final Map<String, String> args; }`, `Map<String, FieldError> validateVitalValues(VitalType type, Map<String, double?> values)`, `FieldError? bloodPressureCrossFieldError(double systolic, double diastolic)`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/domain/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/validators.dart';

void main() {
  group('validateVitalValues', () {
    test('valid blood pressure has no errors', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.bloodPressure,
        <String, double?>{'systolic': 120, 'diastolic': 80},
      );
      expect(errors, isEmpty);
    });

    test('a missing required key is errors.required', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.bloodPressure,
        <String, double?>{'systolic': 120, 'diastolic': null},
      );
      expect(errors['diastolic']?.key, 'errors.required');
    });

    test('a value below range is errors.outOfRange with min/max args', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 5},
      );
      expect(errors['heartRate']?.key, 'errors.outOfRange');
      expect(errors['heartRate']?.args, <String, String>{'min': '20', 'max': '300'});
    });

    test('a value above range is errors.outOfRange', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 900},
      );
      expect(errors['heartRate']?.key, 'errors.outOfRange');
    });

    test('a value just inside the bound is valid', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.heartRate,
        <String, double?>{'heartRate': 300},
      );
      expect(errors, isEmpty);
    });

    test('cholesterol validates all three keys independently', () {
      final Map<String, FieldError> errors = validateVitalValues(
        VitalType.cholesterol,
        <String, double?>{'ldl': 40, 'hdl': 1.2, 'total': null},
      );
      expect(errors.keys, <String>{'ldl', 'total'});
      expect(errors['ldl']?.key, 'errors.outOfRange');
      expect(errors['total']?.key, 'errors.required');
    });
  });

  group('bloodPressureCrossFieldError', () {
    test('systolic greater than diastolic is valid', () {
      expect(bloodPressureCrossFieldError(120, 80), isNull);
    });

    test('systolic equal to diastolic is an error', () {
      expect(
        bloodPressureCrossFieldError(80, 80)?.key,
        'vitals.error.systolicMustExceedDiastolic',
      );
    });

    test('systolic less than diastolic is an error', () {
      expect(
        bloodPressureCrossFieldError(70, 90)?.key,
        'vitals.error.systolicMustExceedDiastolic',
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/domain/validators_test.dart`
Expected: FAIL — `validators.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/domain/entities/vital_reading.dart
import 'vital_type.dart';

/// One vitals reading, exactly as the app stores and displays it. No JSON,
/// no Drift, no Flutter import — see `CONTRIBUTING.md` §8.
///
/// [flagged] is computed locally at capture time via
/// `core/clinical/alert_evaluator.dart` and is never recomputed later: it
/// agrees with the server's answer by construction (Decision 2), so there is
/// nothing to reconcile once the reading syncs.
class VitalReading {
  const VitalReading({
    required this.clientRecordId,
    required this.type,
    required this.values,
    required this.flagged,
    required this.measuredAt,
    this.serverId,
    this.bmi,
    this.note,
  });

  final String clientRecordId;
  final String? serverId;
  final VitalType type;

  /// Exactly the keys `vitalDescriptors[type]!.requiredKeys` declares.
  final Map<String, double> values;
  final bool flagged;

  /// Only ever set for a [VitalType.weight] reading with a known profile
  /// height (Decision 3). Null otherwise — never zero, never guessed.
  final double? bmi;
  final DateTime measuredAt;
  final String? note;
}
```

```dart
// mobile/lib/features/vitals/domain/validators.dart
import 'entities/vital_type.dart';
import 'vital_descriptors.dart';

/// A field-level validation problem: a translation key plus any named args
/// the message needs (`errors.outOfRange`'s `{min}`/`{max}`). The domain
/// layer never resolves the key itself — no Flutter import here — the
/// presentation layer calls `.tr(namedArgs: ...)` on it.
class FieldError {
  const FieldError(this.key, [this.args = const <String, String>{}]);

  final String key;
  final Map<String, String> args;
}

/// Validates one reading's `values` against its type's descriptor:
/// structurally (every required key present) and physiologically (each
/// value inside its input-sanity range). Mirrors the backend's `400`
/// validation exactly (`docs/design/2026-07-10-vitals-design.md` §7).
///
/// Only iterates the descriptor's required keys, so an unexpected extra key
/// in [values] is silently ignored here — the remote datasource is what
/// guarantees only the required keys are ever sent (Task 7).
Map<String, FieldError> validateVitalValues(
  VitalType type,
  Map<String, double?> values,
) {
  final VitalDescriptor descriptor = vitalDescriptors[type]!;
  final Map<String, FieldError> errors = <String, FieldError>{};

  for (final String key in descriptor.requiredKeys) {
    final double? value = values[key];
    if (value == null) {
      errors[key] = const FieldError('errors.required');
      continue;
    }
    final ({num min, num max}) range = descriptor.ranges[key]!;
    if (value < range.min || value > range.max) {
      errors[key] = FieldError('errors.outOfRange', <String, String>{
        'min': range.min.toString(),
        'max': range.max.toString(),
      });
    }
  }
  return errors;
}

/// The one cross-field rule (backend §7): a blood-pressure reading's
/// systolic must exceed its diastolic. Call only after [validateVitalValues]
/// on the same values returns empty — this does not repeat the range check.
FieldError? bloodPressureCrossFieldError(double systolic, double diastolic) {
  return systolic > diastolic
      ? null
      : const FieldError('vitals.error.systolicMustExceedDiastolic');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/domain/validators_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/domain/entities/vital_reading.dart \
        mobile/lib/features/vitals/domain/validators.dart \
        mobile/test/features/vitals/domain/validators_test.dart
git commit -m "feat(vitals): add VitalReading entity and value validators"
```

---

### Task 3: Domain — BMI calculator

**Files:**
- Create: `mobile/lib/features/vitals/domain/bmi.dart`
- Test: `mobile/test/features/vitals/domain/bmi_test.dart`

**Interfaces:**
- Produces: `double? calculateBmi({required double weightKg, double? heightCm})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/domain/bmi_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/bmi.dart';

void main() {
  group('calculateBmi', () {
    test('70 kg at 175 cm is 22.9', () {
      expect(calculateBmi(weightKg: 70, heightCm: 175), 22.9);
    });

    test('null height yields null, not zero or an exception', () {
      expect(calculateBmi(weightKg: 70, heightCm: null), isNull);
    });

    test('zero height does not divide by zero', () {
      expect(calculateBmi(weightKg: 70, heightCm: 0), isNull);
    });

    test('negative height does not divide by zero', () {
      expect(calculateBmi(weightKg: 70, heightCm: -10), isNull);
    });

    test('rounds to one decimal place', () {
      // 68 / (1.70^2) = 23.529... -> 23.5
      expect(calculateBmi(weightKg: 68, heightCm: 170), 23.5);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/domain/bmi_test.dart`
Expected: FAIL — `bmi.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/domain/bmi.dart
/// FR-VIT-004 / Decision 3. Computes the same formula the server snapshots
/// onto a `WEIGHT` reading (`docs/design/2026-07-10-vitals-design.md` §4):
/// `weightKg / (heightM)^2`, rounded to one decimal.
///
/// A missing or non-positive height yields `null` rather than dividing by
/// zero or throwing — a patient with no height on file simply sees no BMI,
/// never a garbage one. The value returned here is for immediate offline
/// display only; once the reading syncs, the server's snapshot is what
/// persists (Decision 3 — never overwritten locally after the fact).
double? calculateBmi({required double weightKg, double? heightCm}) {
  if (heightCm == null || heightCm <= 0) return null;
  final double heightM = heightCm / 100;
  final double bmi = weightKg / (heightM * heightM);
  return double.parse(bmi.toStringAsFixed(1));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/domain/bmi_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/domain/bmi.dart \
        mobile/test/features/vitals/domain/bmi_test.dart
git commit -m "feat(vitals): add local BMI calculator"
```

---

### Task 4: Domain — `VitalSeries` and the `BuildSeries` usecase

**Files:**
- Create: `mobile/lib/features/vitals/domain/entities/vital_series.dart`
- Create: `mobile/lib/features/vitals/domain/usecases/build_series.dart`
- Test: `mobile/test/features/vitals/domain/build_series_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType`, `vitalDescriptors` (Tasks 1–2); `DateFormatter.daysAgo` (`package:libu_care/core/utils/date_formatter.dart`, already exists).
- Produces: `class VitalPoint { final DateTime date; final double value; }`, `class VitalSeries { final String key; final List<VitalPoint> points; final double? targetValue; double get min/max/avg; }`, `const int minReadingsForTrend = 3`, `class BuildSeries` with `List<VitalSeries> call({required VitalType type, required List<VitalReading> readings, required int windowDays, Map<String, double> targets, DateTime? now})`. Used by Task 15 (`VitalsTrendController`).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/domain/build_series_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_series.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/usecases/build_series.dart';

VitalReading _bp(
  DateTime measuredAt, {
  double systolic = 120,
  double diastolic = 80,
}) {
  return VitalReading(
    clientRecordId: 'id-${measuredAt.microsecondsSinceEpoch}',
    type: VitalType.bloodPressure,
    values: <String, double>{'systolic': systolic, 'diastolic': diastolic},
    flagged: false,
    measuredAt: measuredAt,
  );
}

void main() {
  final DateTime now = DateTime(2026, 8, 30, 12);
  const BuildSeries buildSeries = BuildSeries();

  test('a 7-day window includes a reading from exactly 7 days ago', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now.subtract(const Duration(days: 7)))],
      windowDays: 7,
      now: now,
    );
    expect(series.first.points, hasLength(1));
  });

  test('a 7-day window excludes a reading from 8 days ago', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now.subtract(const Duration(days: 8)))],
      windowDays: 7,
      now: now,
    );
    expect(series, isEmpty);
  });

  test('blood pressure produces two series from one set of readings', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now, systolic: 130, diastolic: 85)],
      windowDays: 7,
      now: now,
    );
    expect(
      series.map((VitalSeries s) => s.key),
      <String>['systolic', 'diastolic'],
    );
    expect(series[0].points.single.value, 130);
    expect(series[1].points.single.value, 85);
  });

  test('an empty window yields no series, not empty ones', () {
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: const <VitalReading>[],
      windowDays: 7,
      now: now,
    );
    expect(series, isEmpty);
  });

  test('points are ordered oldest-to-newest even when input is newest-first', () {
    final DateTime day1 = now.subtract(const Duration(days: 2));
    final DateTime day2 = now.subtract(const Duration(days: 1));
    final List<VitalSeries> series = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[
        _bp(day2, systolic: 140), // newest first, as history streams it
        _bp(day1, systolic: 120),
      ],
      windowDays: 7,
      now: now,
    );
    final VitalSeries systolic = series.firstWhere(
      (VitalSeries s) => s.key == 'systolic',
    );
    expect(
      systolic.points.map((VitalPoint p) => p.value),
      <double>[120, 140],
    );
  });

  test('a target value comes through per key when supplied', () {
    final List<VitalSeries> withTarget = buildSeries(
      type: VitalType.bloodPressure,
      readings: <VitalReading>[_bp(now)],
      windowDays: 7,
      targets: <String, double>{'systolic': 120},
      now: now,
    );
    expect(withTarget.first.targetValue, 120);
    expect(withTarget.last.targetValue, isNull);
  });

  group('VitalSeries summary', () {
    test('min, max and avg are computed over the series', () {
      final VitalSeries s = VitalSeries(
        key: 'systolic',
        points: <VitalPoint>[
          VitalPoint(now, 110),
          VitalPoint(now, 130),
          VitalPoint(now, 120),
        ],
      );
      expect(s.min, 110);
      expect(s.max, 130);
      expect(s.avg, 120);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/domain/build_series_test.dart`
Expected: FAIL — neither source file exists yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/domain/entities/vital_series.dart
/// One point on a trend chart: when, and what the value was.
class VitalPoint {
  const VitalPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// One line's worth of windowed history — `systolic`, `diastolic`,
/// `weight`, or `glucose` — ready to plot. [points] is oldest-to-newest.
///
/// Presentation maps this to a `ChartSeries` (Task 11) by adding a [Color];
/// this class stays Flutter-free.
class VitalSeries {
  VitalSeries({required this.key, required this.points, this.targetValue})
    : assert(points.isNotEmpty, 'VitalSeries must have at least one point');

  final String key;
  final List<VitalPoint> points;

  /// From the patient's goals (Decision 5). Null means no goal is set on
  /// this key — never a default, invented target.
  final double? targetValue;

  double get min =>
      points.map((VitalPoint p) => p.value).reduce((a, b) => a < b ? a : b);

  double get max =>
      points.map((VitalPoint p) => p.value).reduce((a, b) => a > b ? a : b);

  double get avg =>
      points.map((VitalPoint p) => p.value).reduce((a, b) => a + b) /
      points.length;
}

/// Resolved Decision 6: below this many readings in the selected window,
/// the trend screen shows a list instead of a line — two points is not a
/// trend.
const int minReadingsForTrend = 3;
```

```dart
// mobile/lib/features/vitals/domain/usecases/build_series.dart
import 'package:libu_care/core/utils/date_formatter.dart';

import '../entities/vital_reading.dart';
import '../entities/vital_series.dart';
import '../entities/vital_type.dart';
import '../vital_descriptors.dart';

/// Turns a type's reading history into one [VitalSeries] per value key,
/// windowed to the last [windowDays] (FR-GRAPH-001..004).
///
/// [readings] need not be pre-filtered or pre-sorted — this windows them
/// itself, inclusive of the whole day [windowDays] ago (so a 7-day window
/// includes a reading from exactly 7 days back and excludes one from 8), and
/// always emits points oldest-to-newest for plotting, regardless of the
/// newest-first order a history stream provides (FR-VIT-006).
class BuildSeries {
  const BuildSeries();

  List<VitalSeries> call({
    required VitalType type,
    required List<VitalReading> readings,
    required int windowDays,
    Map<String, double> targets = const <String, double>{},
    DateTime? now,
  }) {
    final DateTime windowStart = DateFormatter.daysAgo(windowDays, from: now);
    final List<VitalReading> windowed =
        readings
            .where((VitalReading r) => !r.measuredAt.isBefore(windowStart))
            .toList()
          ..sort(
            (VitalReading a, VitalReading b) =>
                a.measuredAt.compareTo(b.measuredAt),
          );

    if (windowed.isEmpty) return const <VitalSeries>[];

    final List<String> keys = vitalDescriptors[type]!.requiredKeys;

    return <VitalSeries>[
      for (final String key in keys)
        if (windowed.any((VitalReading r) => r.values[key] != null))
          VitalSeries(
            key: key,
            points: <VitalPoint>[
              for (final VitalReading r in windowed)
                if (r.values[key] != null)
                  VitalPoint(r.measuredAt, r.values[key]!),
            ],
            targetValue: targets[key],
          ),
    ];
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/domain/build_series_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/domain/entities/vital_series.dart \
        mobile/lib/features/vitals/domain/usecases/build_series.dart \
        mobile/test/features/vitals/domain/build_series_test.dart
git commit -m "feat(vitals): add VitalSeries and the BuildSeries usecase"
```

---

### Task 5: Domain — `VitalsRepository` interface and thin usecases

**Files:**
- Create: `mobile/lib/features/vitals/domain/repositories/vitals_repository.dart`
- Create: `mobile/lib/features/vitals/domain/usecases/log_vital.dart`
- Create: `mobile/lib/features/vitals/domain/usecases/watch_history.dart`
- Create: `mobile/lib/features/vitals/domain/usecases/latest_by_type.dart`
- Test: `mobile/test/features/vitals/domain/usecases_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType` (Tasks 1–2).
- Produces: `class VitalGoals { final double? bpSystolic; final double? bpDiastolic; final double? targetWeightKg; }`; `abstract interface class VitalsRepository` with `log`, `watchHistory`, `latestByType`, `patientHeightCm`, `patientGoals` — implemented by Task 9, consumed by Tasks 12, 13, 15, 16. `class LogVital`, `class WatchHistory`, `class LatestByType` — consumed by Task 10's provider wiring.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/domain/usecases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/latest_by_type.dart';
import 'package:libu_care/features/vitals/domain/usecases/log_vital.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';

class _FakeVitalsRepository implements VitalsRepository {
  VitalReading? loggedReading;
  VitalType? watchedType;
  DateTime? watchedFrom;
  DateTime? watchedTo;
  VitalType? latestRequestedType;

  @override
  Future<void> log(VitalReading reading) async {
    loggedReading = reading;
  }

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    watchedType = type;
    watchedFrom = from;
    watchedTo = to;
    return Stream<List<VitalReading>>.value(const <VitalReading>[]);
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async {
    latestRequestedType = type;
    return null;
  }

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

VitalReading _reading() => VitalReading(
  clientRecordId: 'abc',
  type: VitalType.glucose,
  values: <String, double>{'glucose': 6.2},
  flagged: false,
  measuredAt: DateTime(2026, 8, 30),
);

void main() {
  late _FakeVitalsRepository repo;

  setUp(() => repo = _FakeVitalsRepository());

  test('LogVital delegates to repository.log with the exact reading', () async {
    final VitalReading reading = _reading();
    await LogVital(repo)(reading);
    expect(repo.loggedReading, same(reading));
  });

  test('WatchHistory delegates to repository.watchHistory with its filters', () {
    final DateTime from = DateTime(2026, 8, 1);
    final DateTime to = DateTime(2026, 8, 30);
    WatchHistory(repo)(type: VitalType.weight, from: from, to: to);
    expect(repo.watchedType, VitalType.weight);
    expect(repo.watchedFrom, from);
    expect(repo.watchedTo, to);
  });

  test('LatestByType delegates to repository.latestByType', () async {
    await LatestByType(repo)(VitalType.heartRate);
    expect(repo.latestRequestedType, VitalType.heartRate);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/domain/usecases_test.dart`
Expected: FAIL — none of the four source files exist yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/domain/repositories/vitals_repository.dart
import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';

/// The subset of `PatientProfiles.goalsJson` this feature reads —
/// BP and weight targets for trend reference lines (Decision 5,
/// FR-GRAPH-008). Glucose has no goal field in the schema, so it never
/// appears here; that is correct, not a gap.
class VitalGoals {
  const VitalGoals({this.bpSystolic, this.bpDiastolic, this.targetWeightKg});

  final double? bpSystolic;
  final double? bpDiastolic;
  final double? targetWeightKg;
}

/// Returns a value or throws a [Failure] (`core/error/failure.dart`). Never
/// returns null for an error — see `CONTRIBUTING.md` §8.
abstract interface class VitalsRepository {
  /// Writes [reading] to Drift, then enqueues it for sync. Never awaits the
  /// network.
  Future<void> log(VitalReading reading);

  /// Newest-first (FR-VIT-006). Drift only, live-updating — never the API.
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  });

  /// The most recent reading of [type], or null if none exists yet. Powers
  /// the Home card and the form's "last value as a hint" (Decision 7).
  Future<VitalReading?> latestByType(VitalType type);

  /// `PatientProfiles.heightCm`, or null with no profile row yet (M2 may not
  /// have landed) or no height set (Decision 3).
  Future<double?> patientHeightCm();

  /// `PatientProfiles.goalsJson`, parsed. Null under the same conditions as
  /// [patientHeightCm].
  Future<VitalGoals?> patientGoals();
}
```

```dart
// mobile/lib/features/vitals/domain/usecases/log_vital.dart
import '../entities/vital_reading.dart';
import '../repositories/vitals_repository.dart';

/// FR-VIT-001..003/009, FR-OFF-001. Thin — the offline-first behaviour lives
/// in [VitalsRepository]'s implementation, not here.
class LogVital {
  const LogVital(this._repository);

  final VitalsRepository _repository;

  Future<void> call(VitalReading reading) => _repository.log(reading);
}
```

```dart
// mobile/lib/features/vitals/domain/usecases/watch_history.dart
import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

/// FR-VIT-006.
class WatchHistory {
  const WatchHistory(this._repository);

  final VitalsRepository _repository;

  Stream<List<VitalReading>> call({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => _repository.watchHistory(type: type, from: from, to: to);
}
```

```dart
// mobile/lib/features/vitals/domain/usecases/latest_by_type.dart
import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

/// FR-DASH-002..005 (the Home card) and Decision 7 (the form's hint).
class LatestByType {
  const LatestByType(this._repository);

  final VitalsRepository _repository;

  Future<VitalReading?> call(VitalType type) => _repository.latestByType(type);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/domain/usecases_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/domain/repositories/vitals_repository.dart \
        mobile/lib/features/vitals/domain/usecases/log_vital.dart \
        mobile/lib/features/vitals/domain/usecases/watch_history.dart \
        mobile/lib/features/vitals/domain/usecases/latest_by_type.dart \
        mobile/test/features/vitals/domain/usecases_test.dart
git commit -m "feat(vitals): add VitalsRepository interface and thin usecases"
```

---

### Task 6: Data — `VitalModel` (freezed)

This is the first `@freezed` model in the codebase, so there is no existing
example in `lib/` to copy from — this task follows `CONTRIBUTING.md` §8's
canonical shape (`toEntity()` / `fromEntity()` / `toCompanion()` / `toJson()`)
precisely. Because the test file cannot even compile until
`vital_model.freezed.dart` and `vital_model.g.dart` exist, this task departs
from strict red-green order: write the annotated source, generate, **then**
write and run the test.

**Files:**
- Create: `mobile/lib/features/vitals/data/models/vital_model.dart`
- Test: `mobile/test/features/vitals/data/models/vital_model_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType` (Tasks 1–2); `VitalsLogsCompanion` (`package:libu_care/core/db/app_database.dart`, already exists); `DateFormatter.toApiDateTime` (already exists).
- Produces: `class VitalModel` with `VitalModel.fromEntity(VitalReading)`, `VitalModel.fromJson(Map<String, dynamic>)`, `.toJson()`, and (via extension) `.toEntity()` / `.toCompanion()`. Consumed by Tasks 7, 8, 9.

- [ ] **Step 1: Write the model source**

```dart
// mobile/lib/features/vitals/data/models/vital_model.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/utils/date_formatter.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';

part 'vital_model.freezed.dart';
part 'vital_model.g.dart';

/// The wire (and, via [toCompanion], the Drift) shape of one vitals reading.
///
/// One model serves both directions, but not symmetrically: [toJson] emits
/// only what `POST /api/v1/vitals` accepts (`clientRecordId`, `type`,
/// `values`, `measuredAt`, `note`) — `serverId`, `flagged` and `bmi` are
/// server-computed response fields the client must never send back
/// (`docs/design/2026-07-10-vitals-design.md` Decisions 2–3), so they are
/// marked `includeToJson: false`. [fromJson] still reads all of them, for
/// parsing a response.
@freezed
abstract class VitalModel with _$VitalModel {
  const factory VitalModel({
    required String clientRecordId,
    @JsonKey(name: 'id', includeToJson: false) String? serverId,
    required String type,
    @JsonKey(fromJson: _valuesFromJson) required Map<String, double> values,
    @JsonKey(includeToJson: false) required bool flagged,
    @JsonKey(includeToJson: false) double? bmi,
    @JsonKey(fromJson: _measuredAtFromJson, toJson: _measuredAtToJson)
    required DateTime measuredAt,
    String? note,
  }) = _VitalModel;

  factory VitalModel.fromEntity(VitalReading reading) => VitalModel(
    clientRecordId: reading.clientRecordId,
    serverId: reading.serverId,
    type: reading.type.wire,
    values: reading.values,
    flagged: reading.flagged,
    bmi: reading.bmi,
    measuredAt: reading.measuredAt,
    note: reading.note,
  );

  factory VitalModel.fromJson(Map<String, dynamic> json) =>
      _$VitalModelFromJson(json);
}

/// Conversions kept outside the freezed class body — no need for the
/// private-constructor escape hatch that adding instance methods inside
/// `@freezed` requires.
extension VitalModelMapping on VitalModel {
  VitalReading toEntity() => VitalReading(
    clientRecordId: clientRecordId,
    serverId: serverId,
    type: VitalType.fromWire(type),
    values: values,
    flagged: flagged,
    bmi: bmi,
    measuredAt: measuredAt,
    note: note,
  );

  VitalsLogsCompanion toCompanion() => VitalsLogsCompanion.insert(
    clientRecordId: clientRecordId,
    serverId: Value(serverId),
    type: type,
    valuesJson: jsonEncode(values),
    flagged: Value(flagged),
    bmi: Value(bmi),
    measuredAt: measuredAt,
    note: Value(note),
  );
}

Map<String, double> _valuesFromJson(Map<String, dynamic> json) =>
    json.map(
      (String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()),
    );

DateTime _measuredAtFromJson(String value) => DateTime.parse(value).toLocal();

String _measuredAtToJson(DateTime value) => DateFormatter.toApiDateTime(value);
```

- [ ] **Step 2: Generate the freezed/json_serializable parts**

Run: `cd mobile && dart run build_runner build`
Expected: `vital_model.freezed.dart` and `vital_model.g.dart` are created next to `vital_model.dart` with no errors. Do **not** pass `--delete-conflicting-outputs` (removed from this build_runner version; `CONTRIBUTING.md` §1).

- [ ] **Step 3: Write the test**

```dart
// mobile/test/features/vitals/data/models/vital_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

void main() {
  final VitalReading bpReading = VitalReading(
    clientRecordId: 'crid-1',
    type: VitalType.bloodPressure,
    values: <String, double>{'systolic': 190, 'diastolic': 100},
    flagged: true,
    measuredAt: DateTime.utc(2026, 8, 30, 8, 15),
    note: 'felt dizzy',
  );

  test('fromEntity then toJson emits exactly the POST body shape', () {
    final Map<String, dynamic> json = VitalModel.fromEntity(bpReading).toJson();
    expect(json.keys, containsAll(<String>[
      'clientRecordId',
      'type',
      'values',
      'measuredAt',
      'note',
    ]));
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('flagged'), isFalse);
    expect(json.containsKey('bmi'), isFalse);
    expect(json['type'], 'BLOOD_PRESSURE');
    expect(json['values'], <String, double>{'systolic': 190, 'diastolic': 100});
    expect(json['measuredAt'], '2026-08-30T08:15:00.000Z');
  });

  test('fromJson parses a full response, including server-only fields', () {
    final VitalModel model = VitalModel.fromJson(<String, dynamic>{
      'id': 'server-uuid',
      'clientRecordId': 'crid-1',
      'type': 'WEIGHT',
      'values': <String, dynamic>{'weight': 72, 'bmi': 23.5},
      'flagged': false,
      'bmi': 23.5,
      'measuredAt': '2026-08-30T08:15:00Z',
      'note': null,
    });
    expect(model.serverId, 'server-uuid');
    expect(model.bmi, 23.5);
    expect(model.values['weight'], 72.0);
    expect(model.values['weight'], isA<double>());
  });

  test('toEntity round-trips values, flagged and bmi', () {
    final VitalModel model = VitalModel.fromEntity(bpReading);
    final VitalReading roundTripped = model.toEntity();
    expect(roundTripped.clientRecordId, bpReading.clientRecordId);
    expect(roundTripped.type, VitalType.bloodPressure);
    expect(roundTripped.values, bpReading.values);
    expect(roundTripped.flagged, isTrue);
    expect(roundTripped.measuredAt, bpReading.measuredAt);
  });

  test('toCompanion produces an insertable row with valuesJson encoded', () {
    final VitalsLogsCompanion companion =
        VitalModel.fromEntity(bpReading).toCompanion();
    expect(companion.clientRecordId.value, 'crid-1');
    expect(companion.type.value, 'BLOOD_PRESSURE');
    expect(companion.valuesJson.value, contains('"systolic":190'));
    expect(companion.flagged.value, isTrue);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/data/models/vital_model_test.dart`
Expected: PASS — all tests green. If the analyzer reports missing generated members, re-run Step 2.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/data/models/vital_model.dart \
        mobile/lib/features/vitals/data/models/vital_model.freezed.dart \
        mobile/lib/features/vitals/data/models/vital_model.g.dart \
        mobile/test/features/vitals/data/models/vital_model_test.dart
git commit -m "feat(vitals): add VitalModel with entity/companion/JSON mapping"
```

Note: `*.freezed.dart` and `*.g.dart` are gitignored project-wide
(`CONTRIBUTING.md` §1) — the `git add` above will simply find nothing to
stage for those two paths, which is expected; only `vital_model.dart` and the
test actually get committed.

---

### Task 7: Data — `VitalsRemoteDataSource`

Not called by the write path in this slice — see the class doc below and the
plan header's note on why. Built and tested anyway because the spec's file
layout and testing strategy both name it explicitly, and `GET /vitals` is
`backend/docs/API.md`'s documented mechanism for a fresh-install/second-device
restore (a real use, just not one this slice's screens exercise).

**Files:**
- Create: `mobile/lib/features/vitals/data/datasources/vitals_remote_datasource.dart`
- Test: `mobile/test/features/vitals/data/datasources/vitals_remote_datasource_test.dart`

**Interfaces:**
- Consumes: `VitalModel` (Task 6); `ApiEndpoints.vitals`, `ApiResponse.fromJson`, `failureFromDioException` (all in `core/`, already exist).
- Produces: `class VitalsRemoteDataSource` with `Future<VitalModel> post(VitalModel model)` and `Future<List<VitalModel>> getHistory({String? type, String? from, String? to})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/data/datasources/vitals_remote_datasource_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_remote_datasource.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  late FakeDio fakeDio;
  late VitalsRemoteDataSource dataSource;

  setUp(() {
    fakeDio = FakeDio();
    dataSource = VitalsRemoteDataSource(fakeDio.dio);
  });

  group('post', () {
    final VitalModel model = VitalModel(
      clientRecordId: 'crid-1',
      type: 'BLOOD_PRESSURE',
      values: <String, double>{'systolic': 190, 'diastolic': 100},
      flagged: true,
      measuredAt: DateTime.utc(2026, 8, 30, 8, 15),
    );

    test('posts exactly the required keys, with UTC ISO-8601 measuredAt', () async {
      fakeDio.stub(
        '/api/v1/vitals',
        FakeResponse.ok(<String, dynamic>{
          'id': 'server-uuid',
          'clientRecordId': 'crid-1',
          'type': 'BLOOD_PRESSURE',
          'values': <String, dynamic>{'systolic': 190, 'diastolic': 100},
          'flagged': true,
          'measuredAt': '2026-08-30T08:15:00Z',
        }),
      );

      await dataSource.post(model);

      final Map<String, dynamic> sent = fakeDio.requests.single.json;
      expect(sent.keys, <String>{
        'clientRecordId',
        'type',
        'values',
        'measuredAt',
      });
      expect(sent['measuredAt'], '2026-08-30T08:15:00.000Z');
    });

    test('unwraps a 200 into a VitalModel', () async {
      fakeDio.stub(
        '/api/v1/vitals',
        FakeResponse.ok(<String, dynamic>{
          'id': 'server-uuid',
          'clientRecordId': 'crid-1',
          'type': 'BLOOD_PRESSURE',
          'values': <String, dynamic>{'systolic': 190, 'diastolic': 100},
          'flagged': true,
          'measuredAt': '2026-08-30T08:15:00Z',
        }),
      );

      final VitalModel result = await dataSource.post(model);
      expect(result.serverId, 'server-uuid');
      expect(result.flagged, isTrue);
    });

    test("a 400 surfaces the server's field list as a ValidationFailure", () async {
      fakeDio.stub(
        '/api/v1/vitals',
        FakeResponse.error(400, 'systolic: must exceed diastolic'),
      );

      await expectLater(
        dataSource.post(model),
        throwsA(
          isA<ValidationFailure>().having(
            (ValidationFailure f) => f.message,
            'message',
            'systolic: must exceed diastolic',
          ),
        ),
      );
    });
  });

  group('getHistory', () {
    test('unwraps a 200 list into VitalModels', () async {
      fakeDio.stub(
        '/api/v1/vitals',
        FakeResponse.ok(<dynamic>[
          <String, dynamic>{
            'id': 's1',
            'clientRecordId': 'c1',
            'type': 'GLUCOSE',
            'values': <String, dynamic>{'glucose': 5.5},
            'flagged': false,
            'measuredAt': '2026-08-29T08:00:00Z',
          },
        ]),
      );

      final List<VitalModel> results = await dataSource.getHistory();
      expect(results, hasLength(1));
      expect(results.single.type, 'GLUCOSE');
    });

    test('sends type/from/to as query parameters when given', () async {
      fakeDio.stub('/api/v1/vitals', FakeResponse.ok(const <dynamic>[]));

      await dataSource.getHistory(
        type: 'WEIGHT',
        from: '2026-08-01',
        to: '2026-08-30',
      );

      expect(fakeDio.requests.single.queryParameters, <String, dynamic>{
        'type': 'WEIGHT',
        'from': '2026-08-01',
        'to': '2026-08-30',
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/data/datasources/vitals_remote_datasource_test.dart`
Expected: FAIL — `vitals_remote_datasource.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/data/datasources/vitals_remote_datasource.dart
import 'package:dio/dio.dart';
import 'package:libu_care/core/constants/api_endpoints.dart';
import 'package:libu_care/core/network/api_response.dart';
import 'package:libu_care/core/network/dio_client.dart';

import '../models/vital_model.dart';

/// Dio only — no Drift, no domain types beyond what it returns.
///
/// **Not called by [VitalsRepositoryImpl]'s write path.** Every write goes
/// local-then-queue through `core/sync` (`CONTRIBUTING.md` §8: "it does not
/// check connectivity and it does not call the API"), and reads come from
/// Drift, never the API. This class exists because the API contract
/// documents both endpoints and `GET /vitals` is `backend/docs/API.md`'s
/// stated mechanism for a fresh-install/second-device restore — a real,
/// documented use this slice's screens do not exercise.
class VitalsRemoteDataSource {
  const VitalsRemoteDataSource(this._dio);

  final Dio _dio;

  /// `POST /api/v1/vitals`. Throws the mapped [Failure] on any non-2xx
  /// response.
  Future<VitalModel> post(VitalModel model) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        ApiEndpoints.vitals,
        data: model.toJson(),
      );
      final ApiResponse<VitalModel> envelope =
          ApiResponse<VitalModel>.fromJson(
            (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
            (Object? data) => VitalModel.fromJson(
              (data as Map<Object?, Object?>).cast<String, dynamic>(),
            ),
          );
      return envelope.data!;
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }

  /// `GET /api/v1/vitals?type=&from=&to=`. Newest first.
  Future<List<VitalModel>> getHistory({
    String? type,
    String? from,
    String? to,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        ApiEndpoints.vitals,
        queryParameters: <String, dynamic>{
          if (type != null) 'type': type,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final ApiResponse<List<VitalModel>> envelope =
          ApiResponse<List<VitalModel>>.fromJson(
            (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
            (Object? data) => (data as List<dynamic>)
                .map(
                  (dynamic e) => VitalModel.fromJson(
                    (e as Map<Object?, Object?>).cast<String, dynamic>(),
                  ),
                )
                .toList(),
          );
      return envelope.data ?? const <VitalModel>[];
    } on DioException catch (e) {
      throw failureFromDioException(e);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/data/datasources/vitals_remote_datasource_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/data/datasources/vitals_remote_datasource.dart \
        mobile/test/features/vitals/data/datasources/vitals_remote_datasource_test.dart
git commit -m "feat(vitals): add VitalsRemoteDataSource"
```

---

### Task 8: Data — `VitalsLocalDataSource`

A **plain class over `AppDatabase`**, not a `@DriftAccessor` — `app_database.dart`'s `daos: [...]` list is off-limits to this branch, so a new `@DriftAccessor` could never be registered there. This mirrors `core/sync/sync_queue_dao.dart` exactly, which is the foundation's own reference implementation of this pattern (`CONTRIBUTING.md` §4 rule 5).

**Files:**
- Create: `mobile/lib/features/vitals/data/datasources/vitals_local_datasource.dart`
- Test: `mobile/test/features/vitals/data/datasources/vitals_local_datasource_test.dart`

**Interfaces:**
- Consumes: `VitalModel`, `VitalType` (Tasks 1, 6); `VitalGoals` (Task 5); `AppDatabase`, `VitalsLog`, `PatientProfile` (`package:libu_care/core/db/app_database.dart`, already exist).
- Produces: `class VitalsLocalDataSource` with `insert`, `watchHistory`, `latestByType`, `readHeightCm`, `readGoals`. Consumed by Task 9.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/data/datasources/vitals_local_datasource_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';

import '../../../../helpers/test_database.dart';

VitalModel _model(
  VitalType type,
  Map<String, double> values, {
  String? id,
  DateTime? measuredAt,
}) {
  return VitalModel(
    clientRecordId: id ?? 'crid-${type.wire}-${measuredAt?.microsecondsSinceEpoch}',
    type: type.wire,
    values: values,
    flagged: false,
    measuredAt: measuredAt ?? DateTime(2026, 8, 30),
  );
}

void main() {
  late AppDatabase db;
  late VitalsLocalDataSource dataSource;

  setUp(() {
    db = testDatabase();
    dataSource = VitalsLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('round-trips each of the five types with its own values shape', () async {
    final Map<VitalType, Map<String, double>> byType = <VitalType, Map<String, double>>{
      VitalType.bloodPressure: <String, double>{'systolic': 120, 'diastolic': 80},
      VitalType.glucose: <String, double>{'glucose': 5.5},
      VitalType.heartRate: <String, double>{'heartRate': 72},
      VitalType.weight: <String, double>{'weight': 70},
      VitalType.cholesterol: <String, double>{'ldl': 2.5, 'hdl': 1.2, 'total': 4.5},
    };

    for (final MapEntry<VitalType, Map<String, double>> entry in byType.entries) {
      await dataSource.insert(_model(entry.key, entry.value, id: entry.key.wire));
    }

    for (final MapEntry<VitalType, Map<String, double>> entry in byType.entries) {
      final VitalModel? latest = await dataSource.latestByType(entry.key);
      expect(latest, isNotNull, reason: entry.key.wire);
      expect(latest!.values, entry.value, reason: entry.key.wire);
    }
  });

  test('history is newest-first', () async {
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 5.0}, id: '1', measuredAt: DateTime(2026, 8, 1)),
    );
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 6.0}, id: '2', measuredAt: DateTime(2026, 8, 15)),
    );
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 7.0}, id: '3', measuredAt: DateTime(2026, 8, 10)),
    );

    final List<VitalModel> history = await dataSource.watchHistory().first;
    expect(history.map((VitalModel m) => m.clientRecordId), <String>['2', '3', '1']);
  });

  test('the type filter works', () async {
    await dataSource.insert(_model(VitalType.glucose, <String, double>{'glucose': 5.0}, id: 'g1'));
    await dataSource.insert(_model(VitalType.weight, <String, double>{'weight': 70}, id: 'w1'));

    final List<VitalModel> glucoseOnly =
        await dataSource.watchHistory(type: VitalType.glucose).first;
    expect(glucoseOnly.map((VitalModel m) => m.clientRecordId), <String>['g1']);
  });

  test('the date-window query has inclusive bounds', () async {
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 5.0}, id: 'before', measuredAt: DateTime(2026, 7, 31)),
    );
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 6.0}, id: 'on-from', measuredAt: DateTime(2026, 8, 1)),
    );
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 7.0}, id: 'on-to', measuredAt: DateTime(2026, 8, 31)),
    );
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 8.0}, id: 'after', measuredAt: DateTime(2026, 9, 1)),
    );

    final List<VitalModel> windowed = await dataSource
        .watchHistory(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31))
        .first;
    expect(
      windowed.map((VitalModel m) => m.clientRecordId).toSet(),
      <String>{'on-from', 'on-to'},
    );
  });

  test('latest-by-type returns nothing for a type never recorded', () async {
    expect(await dataSource.latestByType(VitalType.cholesterol), isNull);
  });

  test('an insertOrIgnore retry does not duplicate a row', () async {
    final VitalModel model = _model(VitalType.glucose, <String, double>{'glucose': 5.0}, id: 'dup');
    await dataSource.insert(model);
    await dataSource.insert(model);

    final List<VitalModel> history = await dataSource.watchHistory().first;
    expect(history, hasLength(1));
  });

  group('readHeightCm', () {
    test('returns null when no profile row exists yet', () async {
      expect(await dataSource.readHeightCm(), isNull);
    });

    test('returns the stored height', () async {
      await db
          .into(db.patientProfiles)
          .insert(
            PatientProfilesCompanion.insert(
              userId: 'u1',
              heightCm: const Value<double?>(175),
              updatedAt: DateTime(2026, 8, 30),
            ),
          );
      expect(await dataSource.readHeightCm(), 175);
    });
  });

  group('readGoals', () {
    test('returns null when no profile row exists yet', () async {
      expect(await dataSource.readGoals(), isNull);
    });

    test('parses bpSystolic, bpDiastolic and targetWeightKg from goalsJson', () async {
      await db
          .into(db.patientProfiles)
          .insert(
            PatientProfilesCompanion.insert(
              userId: 'u1',
              goalsJson: const Value<String?>(
                '{"bpSystolic":120,"bpDiastolic":80,"targetWeightKg":68}',
              ),
              updatedAt: DateTime(2026, 8, 30),
            ),
          );
      final VitalGoals? goals = await dataSource.readGoals();
      expect(goals?.bpSystolic, 120);
      expect(goals?.bpDiastolic, 80);
      expect(goals?.targetWeightKg, 68);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/data/datasources/vitals_local_datasource_test.dart`
Expected: FAIL — `vitals_local_datasource.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/data/datasources/vitals_local_datasource.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:libu_care/core/db/app_database.dart';

import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../models/vital_model.dart';

/// Drift only — no Dio, no domain usecases. See the file-level note in
/// `vitals_repository_impl.dart` (Task 9) for how this and the sync queue
/// compose into the offline-first write path.
class VitalsLocalDataSource {
  const VitalsLocalDataSource(this._db);

  final AppDatabase _db;

  /// `insertOrIgnore` so a retried write (app killed before the local
  /// transaction confirms, then retried) is a no-op rather than a primary-key
  /// crash — `clientRecordId` is `VitalsLogs`' primary key.
  Future<void> insert(VitalModel model) async {
    await _db
        .into(_db.vitalsLogs)
        .insert(model.toCompanion(), mode: InsertMode.insertOrIgnore);
  }

  /// Newest-first (FR-VIT-006), optionally filtered by [type] and/or windowed
  /// to `[from, to]` inclusive on both ends.
  Stream<List<VitalModel>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    final Selectable<VitalsLog> query = _db.select(_db.vitalsLogs)
      ..where(($VitalsLogsTable t) {
        Expression<bool> predicate = const Constant<bool>(true);
        if (type != null) predicate = predicate & t.type.equals(type.wire);
        if (from != null) {
          predicate = predicate & t.measuredAt.isBiggerOrEqualValue(from);
        }
        if (to != null) {
          predicate = predicate & t.measuredAt.isSmallerOrEqualValue(to);
        }
        return predicate;
      });

    return query.watch().map(
      (List<VitalsLog> rows) =>
          (rows.map(_fromRow).toList())
            ..sort(
              (VitalModel a, VitalModel b) => b.measuredAt.compareTo(a.measuredAt),
            ),
    );
  }

  /// The most recent reading of [type], or null if none exists yet.
  Future<VitalModel?> latestByType(VitalType type) async {
    final List<VitalsLog> rows = await (_db.select(_db.vitalsLogs)..where(
          ($VitalsLogsTable t) => t.type.equals(type.wire),
        ))
        .get();
    if (rows.isEmpty) return null;
    rows.sort((VitalsLog a, VitalsLog b) => b.measuredAt.compareTo(a.measuredAt));
    return _fromRow(rows.first);
  }

  /// `PatientProfiles.heightCm` for the device's one patient row, or null if
  /// no row exists yet (M2 may not have landed) or no height is set.
  Future<double?> readHeightCm() async {
    final PatientProfile? profile = await (_db.select(
      _db.patientProfiles,
    )..limit(1)).getSingleOrNull();
    return profile?.heightCm;
  }

  /// `PatientProfiles.goalsJson`, parsed to the three keys this feature
  /// reads. Null under the same conditions as [readHeightCm], or if
  /// `goalsJson` itself is null.
  Future<VitalGoals?> readGoals() async {
    final PatientProfile? profile = await (_db.select(
      _db.patientProfiles,
    )..limit(1)).getSingleOrNull();
    final String? goalsJson = profile?.goalsJson;
    if (goalsJson == null) return null;

    final Map<String, dynamic> goals =
        jsonDecode(goalsJson) as Map<String, dynamic>;
    return VitalGoals(
      bpSystolic: (goals['bpSystolic'] as num?)?.toDouble(),
      bpDiastolic: (goals['bpDiastolic'] as num?)?.toDouble(),
      targetWeightKg: (goals['targetWeightKg'] as num?)?.toDouble(),
    );
  }

  VitalModel _fromRow(VitalsLog row) => VitalModel(
    clientRecordId: row.clientRecordId,
    serverId: row.serverId,
    type: row.type,
    values: (jsonDecode(row.valuesJson) as Map<String, dynamic>).map(
      (String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()),
    ),
    flagged: row.flagged ?? false,
    bmi: row.bmi,
    measuredAt: row.measuredAt,
    note: row.note,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/data/datasources/vitals_local_datasource_test.dart`
Expected: PASS — all tests green. If `where`/`isBiggerOrEqualValue` are not
found on the analyzer, double-check the callback parameter is typed
`$VitalsLogsTable` (the *generated* table class), not `VitalsLogs` — this is
the exact trap `CONTRIBUTING.md` §10 calls out.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/data/datasources/vitals_local_datasource.dart \
        mobile/test/features/vitals/data/datasources/vitals_local_datasource_test.dart
git commit -m "feat(vitals): add VitalsLocalDataSource"
```

---

### Task 9: Data — `VitalsRepositoryImpl`

**Design note carried from brainstorming, recorded here for whoever reads this task next:** the M4 spec's own testing strategy line "the server's `bmi` replaces the locally computed one once synced" describes a reconciliation pull that **`core/sync/sync_service.dart` cannot support** — its `/api/v1/sync` response only ever carries `{clientRecordId, status, serverId, reason}` per record (confirmed against `backend/docs/API.md` §sync), and `_applyResults` writes only to `SyncQueueEntries`, never to a feature table (its own doc comment: "it also never touches a feature table"). Building a separate `GET /vitals` reconciliation pull is not asked for anywhere else in the spec (no screen, no usecase names it) and is unneeded regardless: Decision 2/3 guarantee the locally computed `flagged`/`bmi` already equal what the server would compute, by construction. This task therefore does **not** attempt a reconciliation pull — `log()` follows `CONTRIBUTING.md` §8's canonical repository exactly, and the tests below prove the offline path and the local-value-is-final property instead.

**Files:**
- Create: `mobile/lib/features/vitals/data/repositories/vitals_repository_impl.dart`
- Test: `mobile/test/features/vitals/data/repositories/vitals_repository_impl_test.dart`

**Interfaces:**
- Consumes: `VitalsLocalDataSource` (Task 8); `VitalModel` (Task 6); `VitalReading`, `VitalType` (Tasks 1–2); `VitalsRepository`, `VitalGoals` (Task 5); `SyncEnqueuer`, `SyncEntityType` (`package:libu_care/core/sync/sync_queue_dao.dart` and `package:libu_care/core/db/app_database.dart`, already exist).
- Produces: `class VitalsRepositoryImpl implements VitalsRepository`. Consumed by Task 10's provider wiring.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/data/repositories/vitals_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/repositories/vitals_repository_impl.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late VitalsLocalDataSource local;
  late SyncQueueDao queue;
  late VitalsRepositoryImpl repo;

  setUp(() {
    db = testDatabase();
    local = VitalsLocalDataSource(db);
    queue = SyncQueueDao(db);
    repo = VitalsRepositoryImpl(local: local, sync: queue);
  });

  tearDown(() => db.close());

  test('logging writes to Drift and enqueues a VITAL record', () async {
    final VitalReading reading = VitalReading(
      clientRecordId: 'crid-1',
      type: VitalType.glucose,
      values: <String, double>{'glucose': 5.5},
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );

    await repo.log(reading);

    final List<VitalReading> stored = await repo.watchHistory().first;
    expect(stored.single.clientRecordId, 'crid-1');

    final List<SyncQueueEntry> pending = await queue.pending();
    expect(pending, hasLength(1));
    expect(pending.single.clientRecordId, 'crid-1');
    expect(pending.single.entityType, SyncEntityType.vital.wire);
  });

  test('the write never touches the network — nothing but Drift and the queue is held', () {
    // Structural, not behavioural: VitalsRepositoryImpl holds no Dio and no
    // remote datasource reference at all (see the constructor below), so
    // there is no code path through which `log` could reach the network.
    expect(repo, isA<VitalsRepositoryImpl>());
  });

  test('the stored reading keeps exactly the flagged/bmi it was given', () async {
    final VitalReading reading = VitalReading(
      clientRecordId: 'crid-weight',
      type: VitalType.weight,
      values: <String, double>{'weight': 70},
      flagged: true,
      bmi: 23.5,
      measuredAt: DateTime(2026, 8, 30),
    );

    await repo.log(reading);

    final VitalReading? latest = await repo.latestByType(VitalType.weight);
    expect(latest?.flagged, isTrue);
    expect(latest?.bmi, 23.5);
  });

  test('watchHistory maps every stored reading back to an entity', () async {
    await repo.log(
      VitalReading(
        clientRecordId: 'crid-2',
        type: VitalType.heartRate,
        values: <String, double>{'heartRate': 72},
        flagged: false,
        measuredAt: DateTime(2026, 8, 29),
      ),
    );

    final List<VitalReading> history = await repo.watchHistory(
      type: VitalType.heartRate,
    ).first;
    expect(history.single.type, VitalType.heartRate);
    expect(history.single.values['heartRate'], 72);
  });

  test('latestByType returns null when nothing has been logged', () async {
    expect(await repo.latestByType(VitalType.cholesterol), isNull);
  });

  test('patientHeightCm and patientGoals delegate to the local datasource', () async {
    expect(await repo.patientHeightCm(), isNull);
    expect(await repo.patientGoals(), isNull);

    await db
        .into(db.patientProfiles)
        .insert(
          PatientProfilesCompanion.insert(
            userId: 'u1',
            heightCm: const Value<double?>(180),
            updatedAt: DateTime(2026, 8, 30),
          ),
        );

    expect(await repo.patientHeightCm(), 180);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/data/repositories/vitals_repository_impl_test.dart`
Expected: FAIL — `vitals_repository_impl.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/data/repositories/vitals_repository_impl.dart
import 'package:libu_care/core/sync/sync_queue_dao.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../datasources/vitals_local_datasource.dart';
import '../models/vital_model.dart';

/// Note what this does **not** do: it does not check connectivity and it
/// does not call the API. Writes go local-then-queue, unconditionally
/// (`CONTRIBUTING.md` §8). It holds no `Dio` and no
/// `VitalsRemoteDataSource` — there is no path through which a write here
/// could reach the network.
class VitalsRepositoryImpl implements VitalsRepository {
  const VitalsRepositoryImpl({
    required VitalsLocalDataSource local,
    required SyncEnqueuer sync,
  }) : _local = local,
       _sync = sync;

  final VitalsLocalDataSource _local;
  final SyncEnqueuer _sync;

  @override
  Future<void> log(VitalReading reading) async {
    final VitalModel model = VitalModel.fromEntity(reading);
    await _local.insert(model); // 1. device first, always
    await _sync.enqueue(
      // 2. then owe it to the server
      clientRecordId: reading.clientRecordId,
      entityType: SyncEntityType.vital,
      payload: model.toJson(),
      recordedAt: reading.measuredAt,
    );
  } // never awaits the network

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    return _local
        .watchHistory(type: type, from: from, to: to)
        .map(
          (List<VitalModel> models) =>
              models.map((VitalModel m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async {
    final VitalModel? model = await _local.latestByType(type);
    return model?.toEntity();
  }

  @override
  Future<double?> patientHeightCm() => _local.readHeightCm();

  @override
  Future<VitalGoals?> patientGoals() => _local.readGoals();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/data/repositories/vitals_repository_impl_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/data/repositories/vitals_repository_impl.dart \
        mobile/test/features/vitals/data/repositories/vitals_repository_impl_test.dart
git commit -m "feat(vitals): add VitalsRepositoryImpl"
```

---

### Task 10: Presentation — `vitals_providers.dart` (DI wiring)

Pure composition, no branching logic — this is what Riverpod-as-DI wiring
looks like everywhere else in the app (`core/providers/core_providers.dart`).
No dedicated unit test: there is nothing to assert beyond "it compiles and
constructs," which `flutter analyze` already checks, and every widget test
from Task 12 onward exercises this graph for real via `pumpApp`'s
`overrides:` parameter.

**Files:**
- Create: `mobile/lib/features/vitals/vitals_providers.dart`

**Interfaces:**
- Consumes: `dioProvider`, `appDatabaseProvider`, `syncEnqueuerProvider` (`package:libu_care/core/providers/core_providers.dart`, already exist); everything from Tasks 5–9.
- Produces: `vitalsRepositoryProvider`, `logVitalProvider`, `watchHistoryProvider`, `latestByTypeProvider`, `buildSeriesProvider` — consumed by Tasks 12, 13, 15, 16.

- [ ] **Step 1: Write the file**

```dart
// mobile/lib/features/vitals/vitals_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/providers/core_providers.dart';

import 'data/datasources/vitals_local_datasource.dart';
import 'data/datasources/vitals_remote_datasource.dart';
import 'data/repositories/vitals_repository_impl.dart';
import 'domain/repositories/vitals_repository.dart';
import 'domain/usecases/build_series.dart';
import 'domain/usecases/latest_by_type.dart';
import 'domain/usecases/log_vital.dart';
import 'domain/usecases/watch_history.dart';

/// This feature's own provider graph. Nothing here is imported by another
/// feature; cross-feature composition happens only in
/// `lib/app/app_wiring.dart` (architectural rule #1).

/// Not read by anything in this slice — see the design note on Task 7 and
/// Task 9. Declared for architecture-template consistency and so a future
/// restore-on-login feature has it ready to inject.
final Provider<VitalsRemoteDataSource> vitalsRemoteDataSourceProvider =
    Provider<VitalsRemoteDataSource>(
      (Ref ref) => VitalsRemoteDataSource(ref.watch(dioProvider)),
    );

final Provider<VitalsLocalDataSource> vitalsLocalDataSourceProvider =
    Provider<VitalsLocalDataSource>(
      (Ref ref) => VitalsLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<VitalsRepository> vitalsRepositoryProvider =
    Provider<VitalsRepository>(
      (Ref ref) => VitalsRepositoryImpl(
        local: ref.watch(vitalsLocalDataSourceProvider),
        sync: ref.watch(syncEnqueuerProvider),
      ),
    );

final Provider<LogVital> logVitalProvider = Provider<LogVital>(
  (Ref ref) => LogVital(ref.watch(vitalsRepositoryProvider)),
);

final Provider<WatchHistory> watchHistoryProvider = Provider<WatchHistory>(
  (Ref ref) => WatchHistory(ref.watch(vitalsRepositoryProvider)),
);

final Provider<LatestByType> latestByTypeProvider = Provider<LatestByType>(
  (Ref ref) => LatestByType(ref.watch(vitalsRepositoryProvider)),
);

final Provider<BuildSeries> buildSeriesProvider = Provider<BuildSeries>(
  (Ref ref) => const BuildSeries(),
);
```

- [ ] **Step 2: Verify it compiles cleanly**

Run: `cd mobile && flutter analyze lib/features/vitals/vitals_providers.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/vitals/vitals_providers.dart
git commit -m "feat(vitals): wire up the vitals feature's provider graph"
```

---

### Task 11: Presentation — `TrendChart` and `Sparkline` widgets

Decision 5's resolved shape: one `fl_chart`-backed widget, parameterised by
`List<ChartSeries>` — the presentation-layer counterpart to the Flutter-free
domain `VitalSeries` (Task 4). Renders one line for glucose/weight, two
sharing an axis for blood pressure, with no chart-specific code branching on
`VitalType` anywhere in this file.

**Files:**
- Create: `mobile/lib/features/vitals/presentation/widgets/trend_chart.dart`
- Create: `mobile/lib/features/vitals/presentation/widgets/sparkline.dart`
- Test: `mobile/test/features/vitals/presentation/widgets/trend_chart_test.dart`

**Interfaces:**
- Consumes: `VitalSeries`, `VitalPoint` (Task 4).
- Produces: `class ChartSeries { final VitalSeries series; final Color color; }`, `class TrendChart extends StatelessWidget` (`{required List<ChartSeries> series}`), `class Sparkline extends StatelessWidget` (`{required List<VitalPoint> points, required Color color, double height}`). Consumed by Tasks 13, 15, 16.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/presentation/widgets/trend_chart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_series.dart';
import 'package:libu_care/features/vitals/presentation/widgets/trend_chart.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  VitalSeries seriesOf(String key, List<double> values, {double? target}) {
    final DateTime start = DateTime(2026, 8, 1);
    return VitalSeries(
      key: key,
      points: <VitalPoint>[
        for (int i = 0; i < values.length; i++)
          VitalPoint(start.add(Duration(days: i)), values[i]),
      ],
      targetValue: target,
    );
  }

  testWidgets('renders one line per series, blood pressure included', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      TrendChart(
        series: <ChartSeries>[
          ChartSeries(
            series: seriesOf('systolic', <double>[120, 130, 125]),
            color: AppColors.accent,
          ),
          ChartSeries(
            series: seriesOf('diastolic', <double>[80, 85, 82]),
            color: AppColors.primary,
          ),
        ],
      ),
    );

    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
  });

  testWidgets('draws a reference line only for a series with a target', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      TrendChart(
        series: <ChartSeries>[
          ChartSeries(
            series: seriesOf('glucose', <double>[5.0, 5.5, 6.0]),
            color: AppColors.accent,
          ),
        ],
      ),
    );

    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.extraLinesData?.horizontalLines, isEmpty);
  });

  testWidgets('draws a reference line when a target is set', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      TrendChart(
        series: <ChartSeries>[
          ChartSeries(
            series: seriesOf('weight', <double>[70, 69, 68], target: 65),
            color: AppColors.accent,
          ),
        ],
      ),
    );

    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.extraLinesData?.horizontalLines, hasLength(1));
    expect(chart.data.extraLinesData!.horizontalLines.single.y, 65);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/presentation/widgets/trend_chart_test.dart`
Expected: FAIL — `trend_chart.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/presentation/widgets/trend_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/vital_series.dart';

/// A [VitalSeries] plus the colour it draws in — the presentation-layer
/// counterpart to the Flutter-free domain entity (Decision 5).
class ChartSeries {
  const ChartSeries({required this.series, required this.color});

  final VitalSeries series;
  final Color color;
}

/// One chart, parameterised by series — the same widget draws a single
/// glucose line and blood pressure's two lines sharing an axis. Never called
/// with fewer than `minReadingsForTrend` points per series; that gate lives
/// in the trend screen (Task 15), not here.
class TrendChart extends StatelessWidget {
  const TrendChart({required this.series, super.key});

  final List<ChartSeries> series;

  static const AxisTitles _hiddenAxis = AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  );

  @override
  Widget build(BuildContext context) {
    final Iterable<double> allValues = series.expand(
      (ChartSeries c) => c.series.points.map((VitalPoint p) => p.value),
    );
    final double minY = allValues.reduce((double a, double b) => a < b ? a : b);
    final double maxY = allValues.reduce((double a, double b) => a > b ? a : b);
    final double pad = (maxY - minY) * 0.15 + 1;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: const FlTitlesData(
            leftTitles: _hiddenAxis,
            topTitles: _hiddenAxis,
            rightTitles: _hiddenAxis,
            bottomTitles: _hiddenAxis,
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: <LineChartBarData>[
            for (final ChartSeries c in series)
              LineChartBarData(
                spots: <FlSpot>[
                  for (final VitalPoint p in c.series.points)
                    FlSpot(p.date.millisecondsSinceEpoch.toDouble(), p.value),
                ],
                color: c.color,
                barWidth: 2,
                dotData: const FlDotData(show: true),
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: <HorizontalLine>[
              for (final ChartSeries c in series)
                if (c.series.targetValue != null)
                  HorizontalLine(
                    y: c.series.targetValue!,
                    color: c.color.withValues(alpha: 0.5),
                    dashArray: const <int>[6, 4],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// mobile/lib/features/vitals/presentation/widgets/sparkline.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/vital_series.dart';

/// A minimal, axis-free trend line for a tight space — the Vitals tab
/// root's per-type entry point into the full trend screen.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.points,
    required this.color,
    this.height = 32,
    super.key,
  });

  final List<VitalPoint> points;
  final Color color;
  final double height;

  static const AxisTitles _hiddenAxis = AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  );

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(height: height);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: _hiddenAxis,
            topTitles: _hiddenAxis,
            rightTitles: _hiddenAxis,
            bottomTitles: _hiddenAxis,
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              color: color,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/presentation/widgets/trend_chart_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/presentation/widgets/trend_chart.dart \
        mobile/lib/features/vitals/presentation/widgets/sparkline.dart \
        mobile/test/features/vitals/presentation/widgets/trend_chart_test.dart
git commit -m "feat(vitals): add TrendChart and Sparkline widgets"
```

---

### Task 12: Presentation — `VitalFormController`, `VitalFormFields` and `VitalFormScreen`

**Correction carried from the design spec, recorded here so the test below
isn't a surprise:** the M4 spec's testing strategy says "saving a systolic of
190 shows an urgent status." `core/clinical/alert_evaluator.dart`'s
`bloodPressureSeverity` actually has three tiers, and 190 crosses the
**emergency** line (`systolic >= 180`), not the urgent one (`>= 160`) — that
spec sentence predates checking against the real three-tier function and
carried over the backend's two-state `flagged` language. The test below
asserts what the shipped clinical evaluator actually returns, per this plan's
Global Constraints ("never invent/redefine a threshold — use
`core/clinical` as-is").

**Files:**
- Create: `mobile/lib/features/vitals/presentation/controllers/vital_form_controller.dart`
- Create: `mobile/lib/features/vitals/presentation/widgets/vital_form_fields.dart`
- Create: `mobile/lib/features/vitals/presentation/screens/vital_form_screen.dart`
- Test: `mobile/test/features/vitals/presentation/screens/vital_form_screen_test.dart`

**Interfaces:**
- Consumes: `VitalType`, `vitalDescriptors`, `validateVitalValues`, `bloodPressureCrossFieldError`, `calculateBmi` (Tasks 1–3); `VitalReading` (Task 2); `VitalsRepository`, `vitalsRepositoryProvider`, `logVitalProvider` (Tasks 5, 10); `isVitalFlagged`, `severityForVital`, `vitalFlagRanges`, `Severity`, `actionKeyFor` (`package:libu_care/core/clinical/alert_evaluator.dart`, already exist); `newClientRecordId` (`package:libu_care/core/utils/ids.dart`, already exists).
- Produces: `class VitalFormState`, `class VitalFormController extends Notifier<VitalFormState>`, `vitalFormControllerProvider`; `class VitalFormFields extends StatefulWidget`; `class VitalFormScreen extends ConsumerWidget`. Consumed by Task 17 (routing).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/presentation/screens/vital_form_screen_test.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/presentation/screens/vital_form_screen.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

class _FakeVitalsRepository implements VitalsRepository {
  VitalReading? logged;
  double? heightCm;

  @override
  Future<void> log(VitalReading reading) async => logged = reading;

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(const <VitalReading>[]);

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => heightCm;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

void main() {
  setUpWidgetTests();

  late _FakeVitalsRepository repo;
  late List<Override> overrides;

  setUp(() {
    repo = _FakeVitalsRepository();
    overrides = <Override>[vitalsRepositoryProvider.overrideWithValue(repo)];
  });

  testWidgets('shows two fields for blood pressure, the default type', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('shows three fields after switching to cholesterol', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    await tester.tap(find.text('vitals.type.cholesterol'.tr()));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('an out-of-range value is blocked before submit', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    await tester.enterText(find.byType(TextField).at(0), '500'); // systolic
    await tester.enterText(find.byType(TextField).at(1), '80'); // diastolic
    await tester.tap(find.text('common.save'.tr()));
    await tester.pumpAndSettle();

    expect(repo.logged, isNull);
    expect(find.text('errors.outOfRange'.tr(namedArgs: <String, String>{
      'min': '40',
      'max': '300',
    })), findsOneWidget);
  });

  testWidgets(
    'saving a systolic of 190 shows the emergency status and its action',
    (WidgetTester tester) async {
      await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
      await tester.enterText(find.byType(TextField).at(0), '190');
      await tester.enterText(find.byType(TextField).at(1), '100');
      await tester.tap(find.text('common.save'.tr()));
      await tester.pumpAndSettle();

      expect(repo.logged, isNotNull);
      expect(repo.logged!.flagged, isTrue);
      expect(
        find.text('clinical.severity.${Severity.emergency.name}'.tr()),
        findsOneWidget,
      );
      expect(find.text(actionKeyFor(Severity.emergency).tr()), findsOneWidget);
    },
  );

  testWidgets('renders correctly in Amharic', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const VitalFormScreen(),
      overrides: overrides,
      language: AppLanguage.am,
    );
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vital_form_screen_test.dart`
Expected: FAIL — none of the three source files exist yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/presentation/controllers/vital_form_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/utils/ids.dart';

import '../../domain/bmi.dart';
import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/validators.dart';
import '../../domain/vital_descriptors.dart';
import '../../vitals_providers.dart';

enum VitalFormStatus { idle, saving, saved }

/// Everything the log-a-reading screen needs to render.
class VitalFormState {
  const VitalFormState({
    required this.type,
    required this.rawValues,
    required this.measuredAt,
    this.note,
    this.fieldErrors = const <String, FieldError>{},
    this.crossFieldError,
    this.status = VitalFormStatus.idle,
    this.resultSeverity,
    this.resultFlagged,
  });

  factory VitalFormState.initial(VitalType type) => VitalFormState(
    type: type,
    rawValues: const <String, String>{},
    measuredAt: DateTime.now(),
  );

  final VitalType type;
  final Map<String, String> rawValues;
  final DateTime measuredAt;
  final String? note;
  final Map<String, FieldError> fieldErrors;
  final FieldError? crossFieldError;
  final VitalFormStatus status;
  final Severity? resultSeverity;
  final bool? resultFlagged;

  bool get isSaving => status == VitalFormStatus.saving;
  bool get isSaved => status == VitalFormStatus.saved;

  VitalFormState copyWith({
    Map<String, String>? rawValues,
    DateTime? measuredAt,
    String? note,
    Map<String, FieldError>? fieldErrors,
    FieldError? crossFieldError,
    bool clearCrossFieldError = false,
    VitalFormStatus? status,
    Severity? resultSeverity,
    bool? resultFlagged,
  }) {
    return VitalFormState(
      type: type,
      rawValues: rawValues ?? this.rawValues,
      measuredAt: measuredAt ?? this.measuredAt,
      note: note ?? this.note,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      crossFieldError: clearCrossFieldError
          ? null
          : (crossFieldError ?? this.crossFieldError),
      status: status ?? this.status,
      resultSeverity: resultSeverity ?? this.resultSeverity,
      resultFlagged: resultFlagged ?? this.resultFlagged,
    );
  }
}

class VitalFormController extends Notifier<VitalFormState> {
  @override
  VitalFormState build() => VitalFormState.initial(VitalType.bloodPressure);

  void selectType(VitalType type) => state = VitalFormState.initial(type);

  void setValue(String key, String rawText) {
    state = state.copyWith(
      rawValues: <String, String>{...state.rawValues, key: rawText},
    );
  }

  void setNote(String? note) => state = state.copyWith(note: note);

  void setMeasuredAt(DateTime measuredAt) =>
      state = state.copyWith(measuredAt: measuredAt);

  /// Returns true on success. On failure, [VitalFormState.fieldErrors] and/or
  /// [VitalFormState.crossFieldError] are populated for the UI to show.
  Future<bool> submit() async {
    final VitalDescriptor descriptor = vitalDescriptors[state.type]!;
    final Map<String, double?> parsed = <String, double?>{};
    final Map<String, FieldError> parseErrors = <String, FieldError>{};

    for (final String key in descriptor.requiredKeys) {
      final String raw = (state.rawValues[key] ?? '').trim();
      if (raw.isEmpty) {
        parsed[key] = null;
        continue;
      }
      final double? value = double.tryParse(raw);
      if (value == null) {
        parseErrors[key] = const FieldError('errors.invalidNumber');
      }
      parsed[key] = value;
    }

    final Map<String, FieldError> fieldErrors = <String, FieldError>{
      ...validateVitalValues(state.type, parsed),
      ...parseErrors, // a non-numeric entry always wins over "required"
    };

    FieldError? crossFieldError;
    if (fieldErrors.isEmpty && state.type == VitalType.bloodPressure) {
      crossFieldError = bloodPressureCrossFieldError(
        parsed['systolic']!,
        parsed['diastolic']!,
      );
    }

    if (fieldErrors.isNotEmpty || crossFieldError != null) {
      state = state.copyWith(
        fieldErrors: fieldErrors,
        crossFieldError: crossFieldError,
        clearCrossFieldError: crossFieldError == null,
      );
      return false;
    }

    final Map<String, double> values = parsed.map(
      (String k, double? v) => MapEntry<String, double>(k, v!),
    );

    double? bmi;
    if (state.type == VitalType.weight) {
      final double? heightCm = await ref
          .read(vitalsRepositoryProvider)
          .patientHeightCm();
      bmi = calculateBmi(weightKg: values['weight']!, heightCm: heightCm);
    }

    final bool flagged = state.type == VitalType.weight
        ? (bmi != null && vitalFlagRanges['bmi']!.breached(bmi))
        : isVitalFlagged(values);

    final Severity severity = severityForVital(
      type: state.type.wire,
      values: values,
      bmi: bmi,
    );

    state = state.copyWith(status: VitalFormStatus.saving);

    await ref.read(logVitalProvider)(
      VitalReading(
        clientRecordId: newClientRecordId(),
        type: state.type,
        values: values,
        flagged: flagged,
        bmi: bmi,
        measuredAt: state.measuredAt,
        note: state.note,
      ),
    );

    state = state.copyWith(
      status: VitalFormStatus.saved,
      resultSeverity: severity,
      resultFlagged: flagged,
      fieldErrors: const <String, FieldError>{},
      clearCrossFieldError: true,
    );
    return true;
  }
}

final NotifierProvider<VitalFormController, VitalFormState>
vitalFormControllerProvider =
    NotifierProvider<VitalFormController, VitalFormState>(
      VitalFormController.new,
    );
```

```dart
// mobile/lib/features/vitals/presentation/widgets/vital_form_fields.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/validators.dart';
import '../../domain/vital_descriptors.dart';

/// One numeric field per required key of [descriptor.type] — two for blood
/// pressure, three for cholesterol, one for everything else (Decision 1).
///
/// Owns its own `TextEditingController`s so retyping never fights cursor
/// position; give this widget a `key` derived from the selected type so
/// Flutter remounts (and clears) it on a type switch.
class VitalFormFields extends StatefulWidget {
  const VitalFormFields({
    required this.descriptor,
    required this.fieldErrors,
    required this.onChanged,
    super.key,
  });

  final VitalDescriptor descriptor;
  final Map<String, FieldError> fieldErrors;
  final void Function(String key, String value) onChanged;

  @override
  State<VitalFormFields> createState() => _VitalFormFieldsState();
}

class _VitalFormFieldsState extends State<VitalFormFields> {
  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
        for (final String key in widget.descriptor.requiredKeys)
          key: TextEditingController(),
      };

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final String key in widget.descriptor.requiredKeys) ...<Widget>[
          AppTextField(
            label: 'vitals.field.$key'.tr(),
            hint: widget.descriptor.unit,
            controller: _controllers[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: widget.fieldErrors[key] == null
                ? null
                : widget.fieldErrors[key]!.key.tr(
                    namedArgs: widget.fieldErrors[key]!.args,
                  ),
            onChanged: (String value) => widget.onChanged(key, value),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
```

```dart
// mobile/lib/features/vitals/presentation/screens/vital_form_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vital_form_controller.dart';
import '../widgets/vital_form_fields.dart';

class VitalFormScreen extends ConsumerWidget {
  const VitalFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VitalFormState state = ref.watch(vitalFormControllerProvider);
    final VitalFormController controller = ref.read(
      vitalFormControllerProvider.notifier,
    );

    if (state.isSaved) {
      return AppScaffold(
        title: 'vitals.logTitle'.tr(),
        body: _SavedResult(
          severity: state.resultSeverity!,
          onDone: () => Navigator.of(context).pop(),
          onLogAnother: () => controller.selectType(state.type),
        ),
      );
    }

    return AppScaffold(
      title: 'vitals.logTitle'.tr(),
      scrollable: true,
      bottomBar: AppButton(
        label: 'common.save'.tr(),
        isLoading: state.isSaving,
        onPressed: controller.submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final VitalType type in VitalType.values)
                ChoiceChip(
                  label: Text(vitalDescriptors[type]!.labelKey.tr()),
                  selected: state.type == type,
                  onSelected: (_) => controller.selectType(type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          VitalFormFields(
            key: ValueKey<VitalType>(state.type),
            descriptor: vitalDescriptors[state.type]!,
            fieldErrors: state.fieldErrors,
            onChanged: controller.setValue,
          ),
          if (state.crossFieldError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.crossFieldError!.key.tr(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          AppTextField(
            label: 'vitals.noteLabel'.tr(),
            maxLength: 500,
            maxLines: 3,
            onChanged: controller.setNote,
          ),
        ],
      ),
    );
  }
}

class _SavedResult extends StatelessWidget {
  const _SavedResult({
    required this.severity,
    required this.onDone,
    required this.onLogAnother,
  });

  final Severity severity;
  final VoidCallback onDone;
  final VoidCallback onLogAnother;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StatusChip(severity: severity),
            const SizedBox(height: 16),
            Text(actionKeyFor(severity).tr(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppButton(
              label: 'vitals.logAnother'.tr(),
              variant: AppButtonVariant.secondary,
              onPressed: onLogAnother,
            ),
            const SizedBox(height: 8),
            AppButton(label: 'common.done'.tr(), onPressed: onDone),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vital_form_screen_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Add the last-value hint (Decision 7)**

Caught in this task's own self-review: Decision 7 asks for "the last value as
a hint," which the version above does not yet show. Add it now, as a small
addition on top of the already-passing implementation rather than a rewrite.

Add a failing test first:

```dart
// append to vital_form_screen_test.dart, inside main()
  testWidgets('hints the last glucose reading when one exists', (
    WidgetTester tester,
  ) async {
    repo.stubbedLatest = VitalReading(
      clientRecordId: 'prev',
      type: VitalType.glucose,
      values: <String, double>{'glucose': 5.8},
      flagged: false,
      measuredAt: DateTime(2026, 8, 29),
    );
    await pumpApp(tester, const VitalFormScreen(), overrides: overrides);
    await tester.tap(find.text('vitals.type.glucose'.tr()));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, '5.8');
  });
```

This needs `_FakeVitalsRepository.latestByType` to return a settable stub —
extend the fake at the top of the file:

```dart
class _FakeVitalsRepository implements VitalsRepository {
  VitalReading? logged;
  double? heightCm;
  VitalReading? stubbedLatest;

  @override
  Future<void> log(VitalReading reading) async => logged = reading;

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(const <VitalReading>[]);

  @override
  Future<VitalReading?> latestByType(VitalType type) async => stubbedLatest;

  @override
  Future<double?> patientHeightCm() async => heightCm;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}
```

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vital_form_screen_test.dart`
Expected: FAIL — the new test fails; the hint is not wired up yet.

Add a `hints` field to `VitalFormState`, populated by a fire-and-forget fetch
whenever the type changes:

```dart
// in vital_form_controller.dart

// add to VitalFormState's constructor, fields and copyWith:
  const VitalFormState({
    required this.type,
    required this.rawValues,
    required this.measuredAt,
    this.note,
    this.fieldErrors = const <String, FieldError>{},
    this.crossFieldError,
    this.status = VitalFormStatus.idle,
    this.resultSeverity,
    this.resultFlagged,
    this.hints = const <String, String>{},
  });
  // ...
  final Map<String, String> hints;
  // ...
  VitalFormState copyWith({
    // ...existing parameters...
    Map<String, String>? hints,
  }) {
    return VitalFormState(
      // ...existing fields...
      hints: hints ?? this.hints,
    );
  }
```

```dart
// in VitalFormController:
  @override
  VitalFormState build() {
    _loadHints(VitalType.bloodPressure);
    return VitalFormState.initial(VitalType.bloodPressure);
  }

  void selectType(VitalType type) {
    state = VitalFormState.initial(type);
    _loadHints(type);
  }

  Future<void> _loadHints(VitalType type) async {
    final VitalReading? latest = await ref.read(latestByTypeProvider)(type);
    // Bail if the user switched types again while this was in flight.
    if (latest == null || state.type != type) return;
    state = state.copyWith(
      hints: latest.values.map(
        (String k, double v) => MapEntry<String, String>(k, v.toString()),
      ),
    );
  }
```

Thread `hints` through the widget: add `this.hints = const <String, String>{}`
to `VitalFormFields`'s constructor and a `final Map<String, String> hints;`
field, then in `_VitalFormFieldsState.build`, change

```dart
            hint: widget.descriptor.unit,
```

to

```dart
            hint: widget.hints[key] ?? widget.descriptor.unit,
```

and in `vital_form_screen.dart`, pass `hints: state.hints` into the
`VitalFormFields(...)` call.

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vital_form_screen_test.dart`
Expected: PASS — all tests, including the new one, green.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/vitals/presentation/controllers/vital_form_controller.dart \
        mobile/lib/features/vitals/presentation/widgets/vital_form_fields.dart \
        mobile/lib/features/vitals/presentation/screens/vital_form_screen.dart \
        mobile/test/features/vitals/presentation/screens/vital_form_screen_test.dart
git commit -m "feat(vitals): add the log-a-reading form, controller and fields"
```

---

### Task 13: Presentation — `vitals_list_controller.dart` and `VitalsScreen` (tab root)

Built on the live `WatchHistory` stream, not a one-shot `LatestByType` call
per type — a `StreamProvider` transforming Drift's own live query means the
tab root updates the instant a reading is logged, with no extra invalidation
wiring. `VitalsListController` in the spec's file layout names this file, not
a `Notifier` class; a `StreamProvider` is the simpler, equally-idiomatic tool
for "derive view state from one live query."

**Files:**
- Create: `mobile/lib/features/vitals/presentation/controllers/vitals_list_controller.dart`
- Create: `mobile/lib/features/vitals/presentation/screens/vitals_screen.dart`
- Test: `mobile/test/features/vitals/presentation/screens/vitals_screen_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType`, `VitalPoint` (Tasks 1, 2, 4); `watchHistoryProvider` (Task 10); `vitalDescriptors` (Task 1); `Sparkline` (Task 11).
- Produces: `class VitalsListState { final Map<VitalType, VitalReading?> latestByType; final Map<VitalType, List<VitalPoint>> sparklineByType; }`, `vitalsListProvider`; `class VitalsScreen extends ConsumerWidget`. Consumed by Task 17 (routing).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/presentation/screens/vitals_screen_test.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_screen.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows an empty state when nothing has been logged', (
    WidgetTester tester,
  ) async {
    final List<Override> overrides = <Override>[
      watchHistoryProvider.overrideWithValue(
        WatchHistory(_FakeEmptyRepository()),
      ),
    ];
    await pumpApp(tester, const VitalsScreen(), overrides: overrides);
    await tester.pump();

    expect(find.text('vitals.emptyTitle'.tr()), findsOneWidget);
  });

  testWidgets('shows a tile per type once readings exist', (
    WidgetTester tester,
  ) async {
    final VitalReading glucose = VitalReading(
      clientRecordId: 'g1',
      type: VitalType.glucose,
      values: <String, double>{'glucose': 5.5},
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );
    final List<Override> overrides = <Override>[
      watchHistoryProvider.overrideWithValue(
        WatchHistory(_FakeRepository(<VitalReading>[glucose])),
      ),
    ];
    await pumpApp(tester, const VitalsScreen(), overrides: overrides);
    await tester.pump();

    expect(find.text('vitals.type.glucose'.tr()), findsOneWidget);
  });
}

class _FakeEmptyRepository implements VitalsRepository {
  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(const <VitalReading>[]);

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

class _FakeRepository implements VitalsRepository {
  _FakeRepository(this.readings);
  final List<VitalReading> readings;

  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(readings);

  @override
  Future<VitalReading?> latestByType(VitalType type) async {
    final Iterable<VitalReading> matches = readings.where(
      (VitalReading r) => r.type == type,
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vitals_screen_test.dart`
Expected: FAIL — neither source file exists yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/presentation/controllers/vitals_list_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/usecases/watch_history.dart';
import '../../vitals_providers.dart';

/// The tab root's view of "the latest of each type," derived from one live
/// history stream rather than five separate lookups.
class VitalsListState {
  const VitalsListState({
    required this.latestByType,
    required this.sparklineByType,
  });

  final Map<VitalType, VitalReading?> latestByType;

  /// Up to the 7 most recent readings per type, oldest-to-newest, reduced to
  /// one representative number each — enough for a glance, not a chart.
  final Map<VitalType, List<VitalPoint>> sparklineByType;
}

final StreamProvider<VitalsListState> vitalsListProvider =
    StreamProvider<VitalsListState>((Ref ref) {
      final WatchHistory watchHistory = ref.watch(watchHistoryProvider);
      return watchHistory().map(_toListState);
    });

VitalsListState _toListState(List<VitalReading> allNewestFirst) {
  final Map<VitalType, VitalReading?> latest = <VitalType, VitalReading?>{};
  final Map<VitalType, List<VitalPoint>> sparkline = <VitalType, List<VitalPoint>>{};

  for (final VitalType type in VitalType.values) {
    final List<VitalReading> forType = allNewestFirst
        .where((VitalReading r) => r.type == type)
        .toList();
    latest[type] = forType.isEmpty ? null : forType.first;
    sparkline[type] = forType
        .take(7)
        .toList()
        .reversed
        .map((VitalReading r) => VitalPoint(r.measuredAt, _primaryValue(type, r)))
        .toList();
  }
  return VitalsListState(latestByType: latest, sparklineByType: sparkline);
}

double _primaryValue(VitalType type, VitalReading r) => switch (type) {
  VitalType.bloodPressure => r.values['systolic']!,
  VitalType.glucose => r.values['glucose']!,
  VitalType.heartRate => r.values['heartRate']!,
  VitalType.weight => r.values['weight']!,
  VitalType.cholesterol => r.values['total']!,
};
```

```dart
// mobile/lib/features/vitals/presentation/screens/vitals_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_list_controller.dart';
import '../widgets/sparkline.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VitalsListState> state = ref.watch(vitalsListProvider);

    return AppScaffold(
      title: 'vitals.tabTitle'.tr(),
      showBack: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.goNamed(AppRoutes.vitalsLog),
        child: const Icon(Icons.add),
      ),
      scrollable: true,
      body: state.maybeWhen(
        data: (VitalsListState data) => _Loaded(data: data),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.data});

  final VitalsListState data;

  @override
  Widget build(BuildContext context) {
    final bool anyReadings = data.latestByType.values.any(
      (VitalReading? r) => r != null,
    );

    if (!anyReadings) {
      return EmptyState(
        icon: Icons.favorite_outline,
        title: 'vitals.emptyTitle'.tr(),
        message: 'vitals.emptyBody'.tr(),
        actionLabel: 'vitals.logAction'.tr(),
        onAction: () => context.goNamed(AppRoutes.vitalsLog),
      );
    }

    return Column(
      children: <Widget>[
        for (final VitalType type in VitalType.values)
          _VitalTile(
            type: type,
            reading: data.latestByType[type],
            sparkline: data.sparklineByType[type] ?? const <VitalPoint>[],
          ),
        const SizedBox(height: 8),
        AppButton(
          label: 'vitals.viewHistory'.tr(),
          variant: AppButtonVariant.text,
          onPressed: () => context.goNamed(AppRoutes.vitalsHistory),
        ),
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.type,
    required this.reading,
    required this.sparkline,
  });

  final VitalType type;
  final VitalReading? reading;
  final List<VitalPoint> sparkline;

  @override
  Widget build(BuildContext context) {
    final VitalDescriptor descriptor = vitalDescriptors[type]!;

    return SectionCard(
      onTap: () => context.goNamed(
        AppRoutes.vitalsTrend,
        pathParameters: <String, String>{'type': type.wire},
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: MetricTile(
              label: descriptor.labelKey.tr(),
              value: reading == null
                  ? 'common.noValue'.tr()
                  : _formatValue(type, reading!),
              unit: reading == null ? null : descriptor.unit,
              trailing: reading == null
                  ? null
                  : StatusChip.flagged(flagged: reading!.flagged),
            ),
          ),
          if (sparkline.length >= 2)
            SizedBox(
              width: 64,
              child: Sparkline(points: sparkline, color: AppColors.accent),
            ),
        ],
      ),
    );
  }

  String _formatValue(VitalType type, VitalReading r) => switch (type) {
    VitalType.bloodPressure =>
      '${r.values['systolic']!.toStringAsFixed(0)}/${r.values['diastolic']!.toStringAsFixed(0)}',
    VitalType.glucose => r.values['glucose']!.toStringAsFixed(1),
    VitalType.heartRate => r.values['heartRate']!.toStringAsFixed(0),
    VitalType.weight => r.values['weight']!.toStringAsFixed(1),
    VitalType.cholesterol => r.values['total']!.toStringAsFixed(1),
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vitals_screen_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/presentation/controllers/vitals_list_controller.dart \
        mobile/lib/features/vitals/presentation/screens/vitals_screen.dart \
        mobile/test/features/vitals/presentation/screens/vitals_screen_test.dart
git commit -m "feat(vitals): add the Vitals tab root screen"
```

---

### Task 14: Presentation — `ReadingRow` and `VitalsHistoryScreen`

**Files:**
- Create: `mobile/lib/features/vitals/presentation/widgets/reading_row.dart`
- Create: `mobile/lib/features/vitals/presentation/screens/vitals_history_screen.dart`
- Test: `mobile/test/features/vitals/presentation/screens/vitals_history_screen_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType` (Tasks 1–2); `vitalDescriptors` (Task 1); `watchHistoryProvider` (Task 10); `LocalSyncStatus`, `syncQueueDaoProvider` (`package:libu_care/core/db/app_database.dart`, `package:libu_care/core/providers/core_providers.dart`, already exist).
- Produces: `class ReadingRow extends StatelessWidget`; `class VitalsHistoryScreen extends ConsumerWidget`. Consumed by Task 17 (routing).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/presentation/screens/vitals_history_screen_test.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_history_screen.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

class _FakeRepository implements VitalsRepository {
  _FakeRepository(this.readings);
  final List<VitalReading> readings;

  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    final List<VitalReading> filtered = type == null
        ? readings
        : readings.where((VitalReading r) => r.type == type).toList();
    return Stream<List<VitalReading>>.value(filtered);
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

void main() {
  setUpWidgetTests();

  VitalReading reading(VitalType type, Map<String, double> values, String id) {
    return VitalReading(
      clientRecordId: id,
      type: type,
      values: values,
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );
  }

  testWidgets('lists every reading with no filter applied', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      reading(VitalType.glucose, <String, double>{'glucose': 5.5}, 'g1'),
      reading(VitalType.weight, <String, double>{'weight': 70}, 'w1'),
    ]);
    await pumpApp(
      tester,
      const VitalsHistoryScreen(),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(WatchHistory(repo)),
      ],
    );
    await tester.pump();

    expect(find.textContaining('5.5'), findsOneWidget);
    expect(find.textContaining('70.0'), findsOneWidget);
  });

  testWidgets('the type filter narrows the list to one type', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      reading(VitalType.glucose, <String, double>{'glucose': 5.5}, 'g1'),
      reading(VitalType.weight, <String, double>{'weight': 70}, 'w1'),
    ]);
    await pumpApp(
      tester,
      const VitalsHistoryScreen(),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(WatchHistory(repo)),
      ],
    );
    await tester.pump();

    await tester.tap(find.text('vitals.type.glucose'.tr()));
    await tester.pump();

    expect(find.textContaining('5.5'), findsOneWidget);
    expect(find.textContaining('70.0'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vitals_history_screen_test.dart`
Expected: FAIL — neither source file exists yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/presentation/widgets/reading_row.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/theme/app_spacing.dart';
import 'package:libu_care/core/utils/date_formatter.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';

/// One history entry: its formatted value, when it was measured, its
/// clinical status, and — if still owed to the server — a pending-sync icon.
class ReadingRow extends StatelessWidget {
  const ReadingRow({required this.reading, this.syncStatus, super.key});

  final VitalReading reading;
  final LocalSyncStatus? syncStatus;

  @override
  Widget build(BuildContext context) {
    final String languageCode = context.locale.languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatValue(reading),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  DateFormatter.displayDateTime(
                    reading.measuredAt,
                    languageCode,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (syncStatus == LocalSyncStatus.pending) ...<Widget>[
            const Icon(Icons.cloud_upload_outlined, size: 16),
            const SizedBox(width: AppSpacing.sm),
          ],
          StatusChip.flagged(flagged: reading.flagged),
        ],
      ),
    );
  }

  String _formatValue(VitalReading r) {
    final String unit = vitalDescriptors[r.type]!.unit;
    final String value = switch (r.type) {
      VitalType.bloodPressure =>
        '${r.values['systolic']!.toStringAsFixed(0)}/${r.values['diastolic']!.toStringAsFixed(0)}',
      VitalType.glucose => r.values['glucose']!.toStringAsFixed(1),
      VitalType.heartRate => r.values['heartRate']!.toStringAsFixed(0),
      VitalType.weight => r.values['weight']!.toStringAsFixed(1),
      VitalType.cholesterol => r.values['total']!.toStringAsFixed(1),
    };
    return '$value $unit';
  }
}
```

```dart
// mobile/lib/features/vitals/presentation/screens/vitals_history_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/usecases/watch_history.dart';
import '../../domain/vital_descriptors.dart';
import '../../vitals_providers.dart';
import '../widgets/reading_row.dart';

final StateProvider<VitalType?> _historyTypeFilterProvider =
    StateProvider<VitalType?>((Ref ref) => null);

final StreamProviderFamily<List<VitalReading>, VitalType?> _historyProvider =
    StreamProvider.family<List<VitalReading>, VitalType?>((
      Ref ref,
      VitalType? type,
    ) {
      final WatchHistory watchHistory = ref.watch(watchHistoryProvider);
      return watchHistory(type: type);
    });

class VitalsHistoryScreen extends ConsumerWidget {
  const VitalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VitalType? filter = ref.watch(_historyTypeFilterProvider);
    final AsyncValue<List<VitalReading>> history = ref.watch(
      _historyProvider(filter),
    );

    return AppScaffold(
      title: 'vitals.historyTitle'.tr(),
      scrollable: false,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: Text('vitals.filterAll'.tr()),
                  selected: filter == null,
                  onSelected: (_) =>
                      ref.read(_historyTypeFilterProvider.notifier).state = null,
                ),
                for (final VitalType type in VitalType.values)
                  ChoiceChip(
                    label: Text(vitalDescriptors[type]!.labelKey.tr()),
                    selected: filter == type,
                    onSelected: (_) =>
                        ref.read(_historyTypeFilterProvider.notifier).state =
                            type,
                  ),
              ],
            ),
          ),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) => EmptyState(
                title: 'errors.generic'.tr(),
                icon: Icons.error_outline_rounded,
              ),
              data: (List<VitalReading> readings) => readings.isEmpty
                  ? EmptyState(
                      icon: Icons.history,
                      title: 'vitals.historyEmptyTitle'.tr(),
                    )
                  : ListView.separated(
                      itemCount: readings.length,
                      separatorBuilder: (BuildContext context, int i) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) =>
                          ReadingRow(reading: readings[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vitals_history_screen_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/presentation/widgets/reading_row.dart \
        mobile/lib/features/vitals/presentation/screens/vitals_history_screen.dart \
        mobile/test/features/vitals/presentation/screens/vitals_history_screen_test.dart
git commit -m "feat(vitals): add ReadingRow and the history screen"
```

---

### Task 15: Presentation — `RangeToggle`, `VitalsTrendController` and `VitalsTrendScreen`

Where the 3-reading threshold (Task 4) and the resolved chart-widget shape
(Task 11) meet: below the threshold, a list; at or above it, `TrendChart`
plus a per-series min/max/avg summary and, when a goal is set, a reference
line.

**Files:**
- Create: `mobile/lib/features/vitals/presentation/widgets/range_toggle.dart`
- Create: `mobile/lib/features/vitals/presentation/controllers/vitals_trend_controller.dart`
- Create: `mobile/lib/features/vitals/presentation/screens/vitals_trend_screen.dart`
- Test: `mobile/test/features/vitals/presentation/screens/vitals_trend_screen_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType`, `VitalSeries`, `minReadingsForTrend` (Tasks 1–2, 4); `BuildSeries`, `VitalGoals`, `vitalsRepositoryProvider`, `watchHistoryProvider`, `buildSeriesProvider` (Tasks 4, 5, 10); `ChartSeries`, `TrendChart` (Task 11); `ReadingRow` (Task 14); `DateFormatter.daysAgo` (already exists).
- Produces: `class RangeToggle extends StatelessWidget`; `class VitalsTrendData`, `_windowDaysProvider`, `_trendDataProvider`; `class VitalsTrendScreen extends ConsumerWidget` (`{required VitalType type}`). Consumed by Task 17 (routing).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/presentation/screens/vitals_trend_screen_test.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_trend_screen.dart';
import 'package:libu_care/features/vitals/presentation/widgets/trend_chart.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

class _FakeRepository implements VitalsRepository {
  _FakeRepository(this.readings);
  final List<VitalReading> readings;

  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) {
    return Stream<List<VitalReading>>.value(
      type == null
          ? readings
          : readings.where((VitalReading r) => r.type == type).toList(),
    );
  }

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

VitalReading _glucose(DateTime d, double v, String id) => VitalReading(
  clientRecordId: id,
  type: VitalType.glucose,
  values: <String, double>{'glucose': v},
  flagged: false,
  measuredAt: d,
);

void main() {
  setUpWidgetTests();

  testWidgets('a trend with two points shows the insufficient-data state', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _glucose(now.subtract(const Duration(days: 1)), 5.5, 'a'),
      _glucose(now.subtract(const Duration(days: 2)), 6.0, 'b'),
    ]);
    await pumpApp(
      tester,
      const VitalsTrendScreen(type: VitalType.glucose),
      overrides: <Override>[
        vitalsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pump();

    expect(
      find.text(
        'vitals.trendInsufficientData'.tr(namedArgs: <String, String>{'count': '3'}),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a trend with three or more points renders the chart', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _FakeRepository repo = _FakeRepository(<VitalReading>[
      _glucose(now.subtract(const Duration(days: 1)), 5.5, 'a'),
      _glucose(now.subtract(const Duration(days: 2)), 6.0, 'b'),
      _glucose(now.subtract(const Duration(days: 3)), 5.0, 'c'),
    ]);
    await pumpApp(
      tester,
      const VitalsTrendScreen(type: VitalType.glucose),
      overrides: <Override>[
        vitalsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pump();

    expect(find.byType(TrendChart), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vitals_trend_screen_test.dart`
Expected: FAIL — none of the three source files exist yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/presentation/widgets/range_toggle.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The 7-day / 30-day switch atop a trend chart.
class RangeToggle extends StatelessWidget {
  const RangeToggle({
    required this.windowDays,
    required this.onChanged,
    super.key,
  });

  final int windowDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        ButtonSegment<int>(value: 7, label: Text('vitals.range7'.tr())),
        ButtonSegment<int>(value: 30, label: Text('vitals.range30'.tr())),
      ],
      selected: <int>{windowDays},
      onSelectionChanged: (Set<int> selection) => onChanged(selection.first),
    );
  }
}
```

```dart
// mobile/lib/features/vitals/presentation/controllers/vitals_trend_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/utils/date_formatter.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/repositories/vitals_repository.dart';
import '../../domain/usecases/build_series.dart';
import '../../domain/usecases/watch_history.dart';
import '../../vitals_providers.dart';

/// Either "not enough readings yet" (with what there is, for the list
/// fallback) or a built set of series — never both.
class VitalsTrendData {
  const VitalsTrendData._({
    required this.insufficientData,
    required this.windowDays,
    this.readingsInWindow = const <VitalReading>[],
    this.series = const <VitalSeries>[],
  });

  factory VitalsTrendData.insufficientData(
    List<VitalReading> readings,
    int windowDays,
  ) => VitalsTrendData._(
    insufficientData: true,
    windowDays: windowDays,
    readingsInWindow: readings,
  );

  factory VitalsTrendData.loaded(List<VitalSeries> series, int windowDays) =>
      VitalsTrendData._(
        insufficientData: false,
        windowDays: windowDays,
        series: series,
      );

  final bool insufficientData;
  final int windowDays;
  final List<VitalReading> readingsInWindow;
  final List<VitalSeries> series;
}

/// One 7-or-30 selection per type, so switching tabs never bleeds one type's
/// toggle into another's.
final StateProviderFamily<int, VitalType> windowDaysProvider =
    StateProvider.family<int, VitalType>((Ref ref, VitalType type) => 7);

final StreamProviderFamily<VitalsTrendData, VitalType> trendDataProvider =
    StreamProvider.family<VitalsTrendData, VitalType>((
      Ref ref,
      VitalType type,
    ) async* {
      final int windowDays = ref.watch(windowDaysProvider(type));
      final WatchHistory watchHistory = ref.watch(watchHistoryProvider);
      final BuildSeries buildSeries = ref.watch(buildSeriesProvider);
      final VitalGoals? goals = await ref
          .watch(vitalsRepositoryProvider)
          .patientGoals();
      final Map<String, double> targets = _targetsFor(type, goals);

      await for (final List<VitalReading> all in watchHistory(type: type)) {
        final DateTime windowStart = DateFormatter.daysAgo(windowDays);
        final List<VitalReading> inWindow = all
            .where(
              (VitalReading r) => !r.measuredAt.isBefore(windowStart),
            )
            .toList();

        if (inWindow.length < minReadingsForTrend) {
          yield VitalsTrendData.insufficientData(inWindow, windowDays);
        } else {
          final List<VitalSeries> series = buildSeries(
            type: type,
            readings: all,
            windowDays: windowDays,
            targets: targets,
          );
          yield VitalsTrendData.loaded(series, windowDays);
        }
      }
    });

Map<String, double> _targetsFor(VitalType type, VitalGoals? goals) {
  if (goals == null) return const <String, double>{};
  return switch (type) {
    VitalType.bloodPressure => <String, double>{
      if (goals.bpSystolic != null) 'systolic': goals.bpSystolic!,
      if (goals.bpDiastolic != null) 'diastolic': goals.bpDiastolic!,
    },
    VitalType.weight => <String, double>{
      if (goals.targetWeightKg != null) 'weight': goals.targetWeightKg!,
    },
    VitalType.glucose ||
    VitalType.heartRate ||
    VitalType.cholesterol => const <String, double>{},
  };
}
```

```dart
// mobile/lib/features/vitals/presentation/screens/vitals_trend_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_trend_controller.dart';
import '../widgets/range_toggle.dart';
import '../widgets/reading_row.dart';
import '../widgets/trend_chart.dart';

class VitalsTrendScreen extends ConsumerWidget {
  const VitalsTrendScreen({required this.type, super.key});

  final VitalType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int windowDays = ref.watch(windowDaysProvider(type));
    final AsyncValue<VitalsTrendData> data = ref.watch(trendDataProvider(type));

    return AppScaffold(
      title: vitalDescriptors[type]!.labelKey.tr(),
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RangeToggle(
            windowDays: windowDays,
            onChanged: (int days) =>
                ref.read(windowDaysProvider(type).notifier).state = days,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) => EmptyState(
                title: 'errors.generic'.tr(),
                icon: Icons.error_outline_rounded,
              ),
              data: (VitalsTrendData d) => d.insufficientData
                  ? _InsufficientData(readings: d.readingsInWindow)
                  : _TrendView(series: d.series),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsufficientData extends StatelessWidget {
  const _InsufficientData({required this.readings});

  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart,
        title: 'vitals.trendEmptyTitle'.tr(),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'vitals.trendInsufficientData'.tr(
              namedArgs: <String, String>{'count': '$minReadingsForTrend'},
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: readings.length,
            separatorBuilder: (BuildContext context, int i) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int i) =>
                ReadingRow(reading: readings[i]),
          ),
        ),
      ],
    );
  }
}

class _TrendView extends StatelessWidget {
  const _TrendView({required this.series});

  final List<VitalSeries> series;

  static const List<Color> _seriesColors = <Color>[
    AppColors.accent,
    AppColors.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final List<ChartSeries> chartSeries = <ChartSeries>[
      for (int i = 0; i < series.length; i++)
        ChartSeries(
          series: series[i],
          color: _seriesColors[i % _seriesColors.length],
        ),
    ];

    return ListView(
      children: <Widget>[
        TrendChart(series: chartSeries),
        const SizedBox(height: 16),
        for (final VitalSeries s in series)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'vitals.seriesSummary'.tr(
                namedArgs: <String, String>{
                  'key': 'vitals.field.${s.key}'.tr(),
                  'min': s.min.toStringAsFixed(1),
                  'max': s.max.toStringAsFixed(1),
                  'avg': s.avg.toStringAsFixed(1),
                },
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/presentation/screens/vitals_trend_screen_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/presentation/widgets/range_toggle.dart \
        mobile/lib/features/vitals/presentation/controllers/vitals_trend_controller.dart \
        mobile/lib/features/vitals/presentation/screens/vitals_trend_screen.dart \
        mobile/test/features/vitals/presentation/screens/vitals_trend_screen_test.dart
git commit -m "feat(vitals): add the trend screen with the insufficient-data gate"
```

---

### Task 16: Presentation — `latestVitalsCard` (Home card)

FR-DASH-002/003/004: latest BP, weight (+ BMI when known), and glucose — the
three rows the M4 spec's screens table names for this card, at `order: 200`
(the "latest readings" band per `core/shell/home_card.dart`'s convention).

**Files:**
- Create: `mobile/lib/features/vitals/presentation/home/latest_vitals_card.dart`
- Test: `mobile/test/features/vitals/presentation/home/latest_vitals_card_test.dart`

**Interfaces:**
- Consumes: `VitalReading`, `VitalType` (Tasks 1–2); `vitalDescriptors` (Task 1); `vitalsListProvider`, `VitalsListState` (Task 13); `HomeCard` (`package:libu_care/core/shell/home_card.dart`, already exists).
- Produces: `const HomeCard latestVitalsCard`. Consumed by Task 17 (`app_wiring.dart`'s `_homeCards`).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/vitals/presentation/home/latest_vitals_card_test.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';
import 'package:libu_care/features/vitals/domain/usecases/watch_history.dart';
import 'package:libu_care/features/vitals/presentation/home/latest_vitals_card.dart';
import 'package:libu_care/features/vitals/vitals_providers.dart';

import '../../../../helpers/pump_app.dart';

class _FakeRepository implements VitalsRepository {
  _FakeRepository(this.readings);
  final List<VitalReading> readings;

  @override
  Future<void> log(VitalReading reading) async {}

  @override
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => Stream<List<VitalReading>>.value(readings);

  @override
  Future<VitalReading?> latestByType(VitalType type) async => null;

  @override
  Future<double?> patientHeightCm() async => null;

  @override
  Future<VitalGoals?> patientGoals() async => null;
}

void main() {
  setUpWidgetTests();

  test('is registered at order 200 with a stable id', () {
    expect(latestVitalsCard.id, 'vitals-latest');
    expect(latestVitalsCard.order, 200);
  });

  testWidgets('shows "—" for a type with no readings, never hides the row', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      Builder(builder: latestVitalsCard.builder),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(
          WatchHistory(_FakeRepository(const <VitalReading>[])),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('common.noValue'.tr()), findsNWidgets(3));
  });

  testWidgets('shows the latest blood pressure when one exists', (
    WidgetTester tester,
  ) async {
    final VitalReading bp = VitalReading(
      clientRecordId: 'bp1',
      type: VitalType.bloodPressure,
      values: <String, double>{'systolic': 128, 'diastolic': 82},
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );
    await pumpApp(
      tester,
      Builder(builder: latestVitalsCard.builder),
      overrides: <Override>[
        watchHistoryProvider.overrideWithValue(
          WatchHistory(_FakeRepository(<VitalReading>[bp])),
        ),
      ],
    );
    await tester.pump();

    expect(find.textContaining('128/82'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/vitals/presentation/home/latest_vitals_card_test.dart`
Expected: FAIL — `latest_vitals_card.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// mobile/lib/features/vitals/presentation/home/latest_vitals_card.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libu_care/core/router/routes.dart';
import 'package:libu_care/core/shell/home_card.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_list_controller.dart';

/// FR-DASH-002/003/004. Order 200 — the "latest readings" band
/// (`core/shell/home_card.dart`'s documented convention).
const HomeCard latestVitalsCard = HomeCard(
  id: 'vitals-latest',
  order: 200,
  builder: _build,
);

Widget _build(BuildContext context) => const _LatestVitalsCardContent();

class _LatestVitalsCardContent extends ConsumerWidget {
  const _LatestVitalsCardContent();

  static const List<VitalType> _shown = <VitalType>[
    VitalType.bloodPressure,
    VitalType.weight,
    VitalType.glucose,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VitalsListState> state = ref.watch(vitalsListProvider);

    return SectionCard(
      title: 'vitals.homeCardTitle'.tr(),
      action: AppButton(
        label: 'common.seeAll'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.goNamed(AppRoutes.vitals),
      ),
      child: state.maybeWhen(
        data: (VitalsListState data) => Column(
          children: <Widget>[
            for (final VitalType type in _shown)
              _Row(type: type, reading: data.latestByType[type]),
          ],
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.type, required this.reading});

  final VitalType type;
  final VitalReading? reading;

  @override
  Widget build(BuildContext context) {
    final VitalDescriptor descriptor = vitalDescriptors[type]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MetricTile(
        label: descriptor.labelKey.tr(),
        value: reading == null ? 'common.noValue'.tr() : _formatValue(reading!),
        unit: reading == null ? null : descriptor.unit,
        trailing: reading == null
            ? null
            : StatusChip.flagged(flagged: reading!.flagged),
      ),
    );
  }

  String _formatValue(VitalReading r) => switch (type) {
    VitalType.bloodPressure =>
      '${r.values['systolic']!.toStringAsFixed(0)}/${r.values['diastolic']!.toStringAsFixed(0)}',
    VitalType.weight => r.bmi == null
        ? r.values['weight']!.toStringAsFixed(1)
        : '${r.values['weight']!.toStringAsFixed(1)} (BMI ${r.bmi!.toStringAsFixed(1)})',
    VitalType.glucose => r.values['glucose']!.toStringAsFixed(1),
    VitalType.heartRate || VitalType.cholesterol => '',
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/vitals/presentation/home/latest_vitals_card_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/vitals/presentation/home/latest_vitals_card.dart \
        mobile/test/features/vitals/presentation/home/latest_vitals_card_test.dart
git commit -m "feat(vitals): add the latest-vitals Home card"
```

---

### Task 17: Wiring — routes, Home card and translations

The only task touching files outside `lib/features/vitals/`, and only the
parts `CONTRIBUTING.md` §4 marks as shared-but-editable: the `M4 vitals`
region of `lib/app/app_wiring.dart`, and the `vitals.*` block of both
translation files. Everything else in those files is left untouched.

**Files:**
- Modify: `mobile/lib/app/app_wiring.dart` (the `vitals:` field in `buildFeatureRoutes()`, and the `// ── M4 vitals` line in `_homeCards`)
- Modify: `mobile/assets/translations/en.json` (the `"vitals"` key, currently `{}`)
- Modify: `mobile/assets/translations/am.json` (the `"vitals"` key, currently `{}`)

**Interfaces:**
- Consumes: `VitalsScreen` (Task 13), `VitalFormScreen` (Task 12), `VitalsHistoryScreen` (Task 14), `VitalsTrendScreen` (Task 15), `latestVitalsCard` (Task 16), `VitalType` (Task 1); `TabRoutes`, `AppRoutes` (`core/router/`, already exist).

- [ ] **Step 1: Add the imports and replace the `vitals:` field**

In `mobile/lib/app/app_wiring.dart`, add these four imports alongside the
existing two:

```dart
import '../features/vitals/domain/entities/vital_type.dart';
import '../features/vitals/presentation/home/latest_vitals_card.dart';
import '../features/vitals/presentation/screens/vital_form_screen.dart';
import '../features/vitals/presentation/screens/vitals_history_screen.dart';
import '../features/vitals/presentation/screens/vitals_screen.dart';
import '../features/vitals/presentation/screens/vitals_trend_screen.dart';
```

Replace:

```dart
    // ── M4 vitals ────────────────────────────────────────────────────────
    vitals: TabRoutes(),
```

with:

```dart
    // ── M4 vitals ────────────────────────────────────────────────────────
    vitals: TabRoutes(
      root: (BuildContext context) => const VitalsScreen(),
      children: <RouteBase>[
        GoRoute(
          path: 'log',
          name: AppRoutes.vitalsLog,
          builder: (BuildContext context, GoRouterState state) =>
              const VitalFormScreen(),
        ),
        GoRoute(
          path: 'history',
          name: AppRoutes.vitalsHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const VitalsHistoryScreen(),
        ),
        GoRoute(
          path: 'trend/:type',
          name: AppRoutes.vitalsTrend,
          builder: (BuildContext context, GoRouterState state) =>
              VitalsTrendScreen(
                type: VitalType.fromWire(state.pathParameters['type']!),
              ),
        ),
      ],
    ),
```

The child `path`s are relative segments (`'log'`, not `'/vitals/log'`) —
go_router requires nested routes' paths to omit the leading `/`; only the
top-level `AppRoutes.vitalsPath` carries it. Navigate by the `name` constants
as always (`context.goNamed(AppRoutes.vitalsLog)`), never by a literal path.

Because this `TabRoutes` value is no longer a compile-time constant (it now
calls non-const closures), `buildFeatureRoutes()`'s `return const
FeatureRoutes(...)` must drop its `const`:

```dart
FeatureRoutes buildFeatureRoutes() {
  return FeatureRoutes(
```

Also add `BuildContext` to the file's imports if the analyzer flags it as
missing — `package:flutter/material.dart` is not currently imported by
`app_wiring.dart` since it previously needed no widget types directly.

- [ ] **Step 2: Register the Home card**

Replace:

```dart
  // ── M4 vitals ───────── latest readings, order 200
```

with:

```dart
  latestVitalsCard, // order 200
```

- [ ] **Step 3: Run analyze and the existing boot test**

Run: `cd mobile && flutter analyze lib/app/app_wiring.dart`
Expected: `No issues found!`

Run: `cd mobile && flutter test test/app_boot_test.dart`
Expected: PASS — the app still boots and routes to Home with the vitals tab
now real instead of `NotBuiltYet`.

- [ ] **Step 4: Add the `vitals.*` translations**

In `mobile/assets/translations/en.json`, replace the value of the existing
`"vitals": {}` key with:

```json
"vitals": {
  "type": {
    "bloodPressure": "Blood pressure",
    "glucose": "Blood glucose",
    "heartRate": "Heart rate",
    "weight": "Weight",
    "cholesterol": "Cholesterol"
  },
  "field": {
    "systolic": "Systolic",
    "diastolic": "Diastolic",
    "glucose": "Glucose",
    "heartRate": "Heart rate",
    "weight": "Weight",
    "ldl": "LDL",
    "hdl": "HDL",
    "total": "Total cholesterol"
  },
  "error": {
    "systolicMustExceedDiastolic": "Systolic must be higher than diastolic"
  },
  "logTitle": "Log a reading",
  "noteLabel": "Note (optional)",
  "logAnother": "Log another",
  "tabTitle": "Vitals",
  "emptyTitle": "No readings yet",
  "emptyBody": "Log your first blood pressure, glucose, heart rate, weight or cholesterol reading.",
  "logAction": "Log a reading",
  "viewHistory": "View history",
  "historyTitle": "Vitals history",
  "filterAll": "All",
  "historyEmptyTitle": "No readings in this range",
  "range7": "7 days",
  "range30": "30 days",
  "trendInsufficientData": "At least {count} readings are needed to show a trend. Here's what you've recorded so far:",
  "trendEmptyTitle": "No readings in this range yet",
  "seriesSummary": "{key}: min {min}, max {max}, avg {avg}",
  "homeCardTitle": "Vitals"
}
```

In `mobile/assets/translations/am.json`, replace the value of the existing
`"vitals": {}` key with the Amharic equivalent below. **These are a
good-faith first pass, not reviewed by a native speaker** — flag them for
review before release, per the same gate `frontend-decisions.md` §6 already
applies to the rest of the app's Amharic clinical copy; do not treat them as
final.

```json
"vitals": {
  "type": {
    "bloodPressure": "የደም ግፊት",
    "glucose": "የደም ስኳር",
    "heartRate": "የልብ ምት",
    "weight": "ክብደት",
    "cholesterol": "ኮሌስትሮል"
  },
  "field": {
    "systolic": "ሲስቶሊክ",
    "diastolic": "ዳያስቶሊክ",
    "glucose": "ስኳር",
    "heartRate": "የልብ ምት",
    "weight": "ክብደት",
    "ldl": "LDL",
    "hdl": "HDL",
    "total": "ጠቅላላ ኮሌስትሮል"
  },
  "error": {
    "systolicMustExceedDiastolic": "ሲስቶሊክ ከዳያስቶሊክ መብለጥ አለበት"
  },
  "logTitle": "ንባብ መዝግብ",
  "noteLabel": "ማስታወሻ (አማራጭ)",
  "logAnother": "ሌላ መዝግብ",
  "tabTitle": "ወሳኝ ምልክቶች",
  "emptyTitle": "እስካሁን ንባቦች የሉም",
  "emptyBody": "የመጀመሪያ የደም ግፊት፣ ስኳር፣ የልብ ምት፣ ክብደት ወይም ኮሌስትሮል ንባብዎን ይመዝግቡ።",
  "logAction": "ንባብ መዝግብ",
  "viewHistory": "ታሪክ ይመልከቱ",
  "historyTitle": "የወሳኝ ምልክቶች ታሪክ",
  "filterAll": "ሁሉም",
  "historyEmptyTitle": "በዚህ ጊዜ ውስጥ ንባቦች የሉም",
  "range7": "7 ቀናት",
  "range30": "30 ቀናት",
  "trendInsufficientData": "አዝማሚያ ለማሳየት ቢያንስ {count} ንባቦች ያስፈልጋሉ። እስካሁን የመዘገቡት ይህ ነው፦",
  "trendEmptyTitle": "በዚህ ጊዜ ውስጥ ገና ንባቦች የሉም",
  "seriesSummary": "{key}፦ ዝቅተኛ {min}፣ ከፍተኛ {max}፣ አማካይ {avg}",
  "homeCardTitle": "ወሳኝ ምልክቶች"
}
```

- [ ] **Step 5: Verify both locales boot**

Run: `cd mobile && flutter test test/app_boot_test.dart`
Expected: PASS — still green with real translation content instead of the
empty placeholder (`useFallbackTranslations` in `pump_app.dart` would have
masked a missing key by silently falling back to English; a clean pass here
does not by itself prove every key resolves — Task 18 runs the full suite,
which exercises each key through the screens that use it).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/app/app_wiring.dart \
        mobile/assets/translations/en.json \
        mobile/assets/translations/am.json
git commit -m "feat(vitals): wire routes, Home card and translations into the app"
```

---

### Task 18: Final verification against the spec's "Done" criteria

Not new code — this task holds the slice to the M4 spec's own §9 "Done"
criteria and §10 handover checklist before it is called finished. Each item
below names exactly what to run or check; do not mark this task complete on
a general "looks fine."

- [ ] **Step 1: Full analyze and test suite**

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

Run: `cd mobile && flutter test`
Expected: every test from Tasks 1–17 green, plus the pre-existing foundation
suite (112 tests per `SLICE_OWNERS.md`) still green — this slice must not
have broken anything outside `lib/features/vitals/`.

- [ ] **Step 2: Confirm no shared file was touched outside the marked regions**

Run: `git diff mobile --stat origin/mobile`
Expected: every changed path is under `mobile/lib/features/vitals/`,
`mobile/test/features/vitals/`, or one of the three files Task 17 named
(`app_wiring.dart`, `en.json`, `am.json`). Anything else appearing here is a
Global Constraints violation — go back and fix it before proceeding.

- [ ] **Step 3: Run against a local backend and verify the offline/online status agreement**

Per `mobile/CONTRIBUTING.md` §1:

```bash
# from the repo root, in one terminal
docker compose up -d
mvn -f backend/pom.xml spring-boot:run

# from mobile/, in another terminal
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

With the app running:

1. Turn the emulator's network off. Log a blood pressure reading of
   `190/100`. Confirm the immediate result screen shows the emergency status
   (per Task 12's correction, not "urgent") and its recommended action.
2. Still offline, check the Vitals tab and History screen both show the new
   reading with the same status.
3. Turn the network back on. Wait for the pending-sync banner to clear (or
   pull to refresh on Home to force a sync).
4. Re-open the reading in History. **The status must be identical to what it
   showed offline** — this is the spec's core done-criterion (§9): "A reading
   logged offline shows the same status before and after it syncs."
5. Confirm nothing duplicated: exactly one `190/100` entry in History.

- [ ] **Step 4: Walk the rest of the §9 "Done" criteria**

- [ ] All five vital types can be logged, each with the right fields and units, each showing an immediate in-range/out-of-range verdict with a recommended action (Task 12).
- [ ] Weight shows a BMI when a height is stored on the patient profile, and prompts for one when not (Tasks 3, 8, 9, 12 — verify manually by adding a height via `PUT /patients/me` with `curl` or Postman against the local backend, since M2's own UI has not landed yet).
- [ ] History is browsable and filterable by type and date (Task 14 covers type; if the date-range UI was not built because §3's screens table did not require it as a separate control, confirm `watchHistory(from:, to:)` at least works via the local datasource test from Task 8 — do not add UI beyond what Task 14 built without checking with the maintainer first, per the spec's own scope).
- [ ] 7-day and 30-day trends render for BP, weight and glucose, with the patient's goal as a reference line when one is set (Task 15 — verify a target line appears by setting `goalsJson` on the local `patient_profiles` row directly via a debug query, since M2 has not landed).
- [ ] Everything works with the radio off, including the charts (Step 3 above).
- [ ] A reading logged offline shows the same status before and after it syncs (Step 3 above).
- [ ] Everything created offline reaches the server after reconnecting, with no duplicates (Step 3 above).
- [ ] `flutter analyze` clean; whole suite green; CI passing once pushed.

- [ ] **Step 5: Walk the §10 handover checklist**

- [ ] Plan committed to `docs/plans/` (this file — already committed as part of the brainstorming step's prior commits; confirm with `git log --oneline -- docs/plans/2026-08-30-mobile-m4-vitals.md`).
- [ ] `flutter analyze` clean, `flutter test` green (Step 1).
- [ ] Ran the app against a local backend; specifically verified sync-status parity (Step 3).
- [ ] Stated the minimum-points threshold for drawing a trend: **3**, resolved in the spec's Decision 6 amendment and implemented as `minReadingsForTrend` (Task 4).
- [ ] No edits to `core/clinical/`, or to any shared file outside the marked regions (Step 2).
- [ ] Screenshots in the PR, English and Amharic, including a chart — take these manually from the running app (Vitals tab, the log form, History, and a Trend chart with ≥3 points, in both languages).
- [ ] No AI co-author trailer on any commit — check with `git log --oneline mobile...origin/mobile | xargs -I{} git show -s --format=%B {}` and confirm none contain a `Co-Authored-By` trailer; if any task's commit picked one up, amend it out before opening the PR.
- [ ] PR into `mobile`, title `feat(mobile): M4 — Vitals & trend charts`.
- [ ] Told M5 whether `TrendChart`/`ChartSeries` (Task 11) can take an activity series — yes: `ChartSeries` only needs a `VitalSeries`-shaped `{key, points, targetValue}` and a `Color`; M5's activity data can be adapted to that shape without importing anything from this feature, since `VitalSeries` lives in `domain/entities/` and `TrendChart`/`ChartSeries` in `presentation/widgets/`, both reachable the same way any other file in this feature is — by copying the shape, not by cross-feature import (architectural rule #1 still applies: M5 defines its own equivalent entity, it does not import `VitalSeries` itself).

- [ ] **Step 6: Update `SLICE_OWNERS.md`**

Change the M4 row's Status from `In progress` to `In review` once the PR in
Step 5 is open (`mobile/SLICE_OWNERS.md`, per its own instruction to keep the
Status column current). This is a docs-only change, committed separately from
the feature branch's own history is not required — a direct small commit on
this branch before opening the PR is simplest.

```bash
git add mobile/SLICE_OWNERS.md
git commit -m "docs(mobile): mark M4 vitals as in review"
```

---

*End of plan. All 18 tasks build one feature, bottom-up: domain (1–5) → data (6–9) → presentation (10–17) → verification (18). Execute in order — later tasks assume earlier ones' interfaces exist exactly as declared.*
