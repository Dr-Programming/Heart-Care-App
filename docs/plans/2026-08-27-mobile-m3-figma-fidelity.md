# M3 Figma Fidelity Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the built M3 medication flow (already complete, reviewed, and running on a real device) into exact visual and structural alignment with the real Figma design — two new screens (medication search, review-before-save), a restructured Medications screen (Today/Schedule/History tabs), and a local-only caregiver-notify field — without touching anything outside `lib/features/medication/`.

**Architecture:** Feature-first, same conventions as the rest of M3 (Riverpod, no codegen; Drift for local state; `testDatabase()`/`FakeDio`/`pumpApp` test helpers; conventional commits, scope `mobile`, no AI co-author trailer). New screens use plain `Navigator.push`, not new named routes — `core/router/routes.dart` and `app_wiring.dart` are not touched by this plan.

**Tech Stack:** Flutter, Riverpod, Drift (`PreferencesDao` only — no schema change), `easy_localization`.

**Spec:** `docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md` (read this in full — this plan implements it). Original M3 spec/working notes still apply for anything not amended there.

## Global Constraints

- **Never edit** `backend/**`, `database/**`, `lib/core/**`, `lib/main.dart`, `pubspec.yaml`, `android/**`, `ios/**`, `lib/app/app_wiring.dart`, `core/router/routes.dart`. Every task only creates/modifies files under `lib/features/medication/`, `test/features/medication/`, plus the `meds.*` namespace in `assets/translations/{en,am}.json`.
- **No new named routes.** `MedicationSearchScreen` and `ReviewMedicationScreen` are reached via `Navigator.of(context).push(MaterialPageRoute(builder: ...))`, never `context.pushNamed`/a new `AppRoutes` member.
- **Colors/spacing:** `AppColors`/`AppSpacing` tokens only — no raw hex, no literal spacing numbers, matching every prior M3 task's rule (CONTRIBUTING.md §6). The exact mapping (confirmed against real Figma node data) is in the spec's Decision G table — `#282a2a`→`AppColors.ink`, `#6b7280`→`AppColors.textSecondary`, `#9ca3af`→`AppColors.textTertiary`, `#fcab10`→`AppColors.primary`, the pale-blue highlight → `AppColors.accent` at reduced opacity.
- **Caregiver notify is local-only** (Decision B) — never sent to the server, never added to `Medication`'s sync payload, never a new Drift column. Stored via `PreferencesDao` only.
- **Medication search is a bundled Dart list, not a JSON asset** (Decision A + its implementation note) — `pubspec.yaml` is off-limits, so no new `assets:` entry.
- **The existing offline-first write path, sync, and notification logic are unchanged.** No task in this plan touches `medication_repository_impl.dart`'s write methods, `medication_notifications.dart`, or any datasource.
- Every user-facing string goes in `meds.*`, present in both `en.json` and `am.json` before the task that introduces it is done — same rule as the rest of M3 (a task is not done with an English-only string).
- `flutter analyze` must be clean and `flutter test` all green before every commit.
- Conventional commits, scope `mobile`. **No AI co-author trailer on any commit.**

---

## File Structure

```
lib/features/medication/
  domain/
    medication_library.dart          MedicationLibraryEntry, kMedicationLibrary, searchMedicationLibrary()
  data/
    caregiver_notify_store.dart      CaregiverNotifySettings, CaregiverNotifyStore
  presentation/
    screens/
      medication_search_screen.dart          NEW
      review_medication_screen.dart          NEW
      medication_form_screen.dart            MODIFIED — caregiver field, restyle, navigates to review
      medications_screen.dart                MODIFIED — Today/Schedule/History tabs
      dose_history_screen.dart               MODIFIED — body extracted to DoseHistoryContent
    widgets/
      time_list_field.dart                   MODIFIED — restyle only

test/features/medication/  — mirrors the tree above, one test file per source file
```

---

## Task 1: Medication library data and search

**Files:**
- Create: `lib/features/medication/domain/medication_library.dart`
- Test: `test/features/medication/domain/medication_library_test.dart`

**Interfaces:**
- Produces: `class MedicationLibraryEntry` (`name`, `doseMg`, `drugClass`, `mostCommon`), `const List<MedicationLibraryEntry> kMedicationLibrary`, `List<MedicationLibraryEntry> searchMedicationLibrary(String query)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/domain/medication_library_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/medication_library.dart';

void main() {
  test('empty query returns no suggestions', () {
    expect(searchMedicationLibrary(''), isEmpty);
    expect(searchMedicationLibrary('   '), isEmpty);
  });

  test('matches are case-insensitive substring matches on name', () {
    final results = searchMedicationLibrary('metop');
    expect(results, isNotEmpty);
    expect(results.every((e) => e.name.toLowerCase().contains('metop')), isTrue);
  });

  test('most-common entries sort first, then alphabetically by name, then by dose', () {
    final results = searchMedicationLibrary('metoprolol');
    expect(results.first.mostCommon, isTrue);
    for (int i = 1; i < results.length; i++) {
      if (results[i - 1].mostCommon == results[i].mostCommon) {
        final nameCompare = results[i - 1].name.compareTo(results[i].name);
        expect(nameCompare <= 0, isTrue);
        if (nameCompare == 0) {
          expect(results[i - 1].doseMg <= results[i].doseMg, isTrue);
        }
      }
    }
  });

  test('a query matching nothing returns an empty list, not an error', () {
    expect(searchMedicationLibrary('xyzzynotarealdrug'), isEmpty);
  });

  test('kMedicationLibrary has at least 25 entries covering common CHD drug classes', () {
    expect(kMedicationLibrary.length, greaterThanOrEqualTo(25));
    final classes = kMedicationLibrary.map((e) => e.drugClass).toSet();
    expect(classes, containsAll(<String>['Beta-blocker', 'Statin', 'Antiplatelet', 'ACE inhibitor']));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `mobile/`): `flutter test test/features/medication/domain/medication_library_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/medication_library.dart

/// One entry in the bundled common-medications list used to power
/// [MedicationSearchScreen]'s suggestions (Decision A of
/// docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md). Not a real
/// drug database — no such catalog exists in the backend or database. Picking
/// a suggestion only pre-fills the add/edit form; saving still goes through
/// the unchanged repository/sync path.
class MedicationLibraryEntry {
  const MedicationLibraryEntry({
    required this.name,
    required this.doseMg,
    required this.drugClass,
    this.mostCommon = false,
  });

  final String name;
  final double doseMg;
  final String drugClass;

  /// Soft hint only — the single most-likely dose for this drug, shown
  /// first and highlighted (Figma's pale-blue top-suggestion row).
  final bool mostCommon;
}

const List<MedicationLibraryEntry> kMedicationLibrary = <MedicationLibraryEntry>[
  MedicationLibraryEntry(name: 'Metoprolol', doseMg: 25, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Metoprolol', doseMg: 50, drugClass: 'Beta-blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Metoprolol', doseMg: 100, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Bisoprolol', doseMg: 2.5, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Bisoprolol', doseMg: 5, drugClass: 'Beta-blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Carvedilol', doseMg: 6.25, drugClass: 'Beta-blocker'),
  MedicationLibraryEntry(name: 'Carvedilol', doseMg: 12.5, drugClass: 'Beta-blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Atorvastatin', doseMg: 10, drugClass: 'Statin'),
  MedicationLibraryEntry(name: 'Atorvastatin', doseMg: 20, drugClass: 'Statin', mostCommon: true),
  MedicationLibraryEntry(name: 'Atorvastatin', doseMg: 40, drugClass: 'Statin'),
  MedicationLibraryEntry(name: 'Rosuvastatin', doseMg: 10, drugClass: 'Statin', mostCommon: true),
  MedicationLibraryEntry(name: 'Rosuvastatin', doseMg: 20, drugClass: 'Statin'),
  MedicationLibraryEntry(name: 'Aspirin', doseMg: 75, drugClass: 'Antiplatelet', mostCommon: true),
  MedicationLibraryEntry(name: 'Aspirin', doseMg: 100, drugClass: 'Antiplatelet'),
  MedicationLibraryEntry(name: 'Clopidogrel', doseMg: 75, drugClass: 'Antiplatelet', mostCommon: true),
  MedicationLibraryEntry(name: 'Lisinopril', doseMg: 5, drugClass: 'ACE inhibitor'),
  MedicationLibraryEntry(name: 'Lisinopril', doseMg: 10, drugClass: 'ACE inhibitor', mostCommon: true),
  MedicationLibraryEntry(name: 'Lisinopril', doseMg: 20, drugClass: 'ACE inhibitor'),
  MedicationLibraryEntry(name: 'Ramipril', doseMg: 2.5, drugClass: 'ACE inhibitor'),
  MedicationLibraryEntry(name: 'Ramipril', doseMg: 5, drugClass: 'ACE inhibitor', mostCommon: true),
  MedicationLibraryEntry(name: 'Losartan', doseMg: 50, drugClass: 'ARB', mostCommon: true),
  MedicationLibraryEntry(name: 'Losartan', doseMg: 100, drugClass: 'ARB'),
  MedicationLibraryEntry(name: 'Amlodipine', doseMg: 5, drugClass: 'Calcium channel blocker', mostCommon: true),
  MedicationLibraryEntry(name: 'Amlodipine', doseMg: 10, drugClass: 'Calcium channel blocker'),
  MedicationLibraryEntry(name: 'Furosemide', doseMg: 20, drugClass: 'Diuretic'),
  MedicationLibraryEntry(name: 'Furosemide', doseMg: 40, drugClass: 'Diuretic', mostCommon: true),
  MedicationLibraryEntry(name: 'Spironolactone', doseMg: 25, drugClass: 'Diuretic', mostCommon: true),
  MedicationLibraryEntry(name: 'Warfarin', doseMg: 1, drugClass: 'Anticoagulant'),
  MedicationLibraryEntry(name: 'Warfarin', doseMg: 5, drugClass: 'Anticoagulant', mostCommon: true),
  MedicationLibraryEntry(name: 'Digoxin', doseMg: 0.125, drugClass: 'Cardiac glycoside', mostCommon: true),
  MedicationLibraryEntry(name: 'Nitroglycerin', doseMg: 0.4, drugClass: 'Nitrate (GTN spray)', mostCommon: true),
  MedicationLibraryEntry(name: 'Isosorbide mononitrate', doseMg: 30, drugClass: 'Nitrate', mostCommon: true),
];

/// Case-insensitive substring match on [MedicationLibraryEntry.name].
/// Most-common entries first, then alphabetical by name, then by dose.
/// An empty/blank query returns nothing — the search screen only shows
/// suggestions once the user has typed something.
List<MedicationLibraryEntry> searchMedicationLibrary(String query) {
  final String trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return const <MedicationLibraryEntry>[];

  final List<MedicationLibraryEntry> matches = kMedicationLibrary
      .where((MedicationLibraryEntry e) => e.name.toLowerCase().contains(trimmed))
      .toList();

  matches.sort((MedicationLibraryEntry a, MedicationLibraryEntry b) {
    if (a.mostCommon != b.mostCommon) return a.mostCommon ? -1 : 1;
    final int nameCompare = a.name.compareTo(b.name);
    if (nameCompare != 0) return nameCompare;
    return a.doseMg.compareTo(b.doseMg);
  });

  return matches;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/domain/medication_library_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/medication_library.dart test/features/medication/domain/medication_library_test.dart
git commit -m "feat(mobile): M3 Figma rework — medication library data and search"
```

---

## Task 2: Local caregiver-notify storage

**Files:**
- Create: `lib/features/medication/data/caregiver_notify_store.dart`
- Test: `test/features/medication/data/caregiver_notify_store_test.dart`

**Interfaces:**
- Consumes: `PreferencesDao` (`core/db/daos/preferences_dao.dart`, read-only core import — already used by this feature's other local-preference logic, e.g. the pending-edit-set in Task 10 of the original M3 plan).
- Produces: `class CaregiverNotifySettings` (`enabled`, `phone`, `CaregiverNotifySettings.empty`), `class CaregiverNotifyStore` with `get(String medicationClientRecordId)` and `set(String medicationClientRecordId, CaregiverNotifySettings settings)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/data/caregiver_notify_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CaregiverNotifyStore store;

  setUp(() {
    db = testDatabase();
    store = CaregiverNotifyStore(db.preferencesDao);
  });

  tearDown(() => db.close());

  test('a medication with nothing saved yet returns empty settings', () async {
    final settings = await store.get('m1');
    expect(settings.enabled, isFalse);
    expect(settings.phone, isEmpty);
  });

  test('round-trips enabled + phone for one medication', () async {
    await store.set('m1', const CaregiverNotifySettings(enabled: true, phone: '+251911234567'));

    final settings = await store.get('m1');
    expect(settings.enabled, isTrue);
    expect(settings.phone, '+251911234567');
  });

  test('settings for different medications do not collide', () async {
    await store.set('m1', const CaregiverNotifySettings(enabled: true, phone: '+251911111111'));
    await store.set('m2', const CaregiverNotifySettings(enabled: false, phone: ''));

    expect((await store.get('m1')).phone, '+251911111111');
    expect((await store.get('m2')).enabled, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/data/caregiver_notify_store_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/data/caregiver_notify_store.dart
import 'dart:convert';

import '../../../core/db/daos/preferences_dao.dart';

/// The "Notify caregiver if missed" toggle + phone number (Decision B of
/// docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md). Local-only —
/// nothing in the backend or sync payload supports actually notifying a
/// caregiver yet. Never persisted to the `Medications` Drift table (that
/// schema is core-owned and off-limits) — stored as a `Preferences` entry
/// per medication instead, the same pattern already used for this
/// feature's other local-only state.
class CaregiverNotifySettings {
  const CaregiverNotifySettings({required this.enabled, required this.phone});

  final bool enabled;
  final String phone;

  static const CaregiverNotifySettings empty = CaregiverNotifySettings(enabled: false, phone: '');
}

class CaregiverNotifyStore {
  const CaregiverNotifyStore(this._prefs);

  final PreferencesDao _prefs;

  String _keyFor(String medicationClientRecordId) => 'm3_caregiver_$medicationClientRecordId';

  Future<CaregiverNotifySettings> get(String medicationClientRecordId) async {
    final String? raw = await _prefs.get(_keyFor(medicationClientRecordId));
    if (raw == null) return CaregiverNotifySettings.empty;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return CaregiverNotifySettings(
      enabled: json['enabled'] as bool? ?? false,
      phone: json['phone'] as String? ?? '',
    );
  }

  Future<void> set(String medicationClientRecordId, CaregiverNotifySettings settings) {
    return _prefs.set(
      _keyFor(medicationClientRecordId),
      jsonEncode(<String, dynamic>{'enabled': settings.enabled, 'phone': settings.phone}),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/data/caregiver_notify_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/data/caregiver_notify_store.dart test/features/medication/data/caregiver_notify_store_test.dart
git commit -m "feat(mobile): M3 Figma rework — local caregiver-notify storage"
```

---

## Task 3: Provider wiring for the two new pieces

**Files:**
- Modify: `lib/features/medication/medication_providers.dart`
- Test: `test/features/medication/medication_providers_test.dart`

**Interfaces:**
- Consumes: `appDatabaseProvider` (`core/providers/core_providers.dart`), `CaregiverNotifyStore` (Task 2).
- Produces: `caregiverNotifyStoreProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/medication_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';
import 'package:libu_care/features/medication/medication_providers.dart';

void main() {
  test('caregiverNotifyStoreProvider provides a CaregiverNotifyStore', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(caregiverNotifyStoreProvider), isA<CaregiverNotifyStore>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/medication_providers_test.dart`
Expected: FAIL — `caregiverNotifyStoreProvider` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Read the current `lib/features/medication/medication_providers.dart` first (it already has `medicationLocalDataSourceProvider`, `medicationRemoteDataSourceProvider`, `medicationRepositoryProvider`, `notificationSchedulerProvider`, `medicationNotificationsProvider` from the original M3 build — this task adds one more provider following the exact same pattern, touching nothing else in the file).

Add, following the existing providers' style exactly:

```dart
import 'data/caregiver_notify_store.dart';
// (add alongside the file's existing imports, same relative-import style)

final Provider<CaregiverNotifyStore> caregiverNotifyStoreProvider =
    Provider<CaregiverNotifyStore>(
      (Ref ref) => CaregiverNotifyStore(ref.watch(appDatabaseProvider).preferencesDao),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/medication_providers_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/medication_providers.dart test/features/medication/medication_providers_test.dart
git commit -m "feat(mobile): M3 Figma rework — wire caregiverNotifyStoreProvider"
```

---

## Task 4: `MedicationSearchScreen`

**Files:**
- Create: `lib/features/medication/presentation/screens/medication_search_screen.dart`
- Test: `test/features/medication/presentation/screens/medication_search_screen_test.dart`

**Interfaces:**
- Consumes: `MedicationLibraryEntry`, `searchMedicationLibrary` (Task 1), `AppScaffold`/`AppTextField`/`SectionCard`/`AppButton` (core widgets — **read `core/widgets/widgets.dart` first** to confirm `AppTextField`'s exact constructor, in particular whether it supports a leading/prefix icon; if not, wrap a plain `TextField` styled with `AppColors`/`AppSpacing` to match Figma's rounded search-bar look instead of forcing an unsupported parameter onto `AppTextField`).
- Produces: `class MedicationSearchScreen extends ConsumerStatefulWidget` with a callback `final void Function(MedicationLibraryEntry?) onSelected` (`null` = "Enter manually" was tapped).

Before writing the implementation, re-read the real Figma screenshot for this screen (frame `368:2790`, described in the spec §3.1) to match copy exactly: title "Add medication", subtitle "Search or enter manually", section label "SUGGESTIONS", empty-search-result hint "Suggestions from offline medication library" / "Can't find your medication?", button "Enter manually".

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/screens/medication_search_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/medication_library.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_search_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('typing a query shows matching suggestions', (tester) async {
    MedicationLibraryEntry? selected;
    await pumpApp(
      tester,
      MedicationSearchScreen(onSelected: (e) => selected = e),
    );

    await tester.enterText(find.byType(TextField).first, 'Metop');
    await tester.pumpAndSettle();

    expect(find.textContaining('Metoprolol'), findsWidgets);
  });

  testWidgets('tapping a suggestion calls onSelected with that entry', (tester) async {
    MedicationLibraryEntry? selected;
    await pumpApp(
      tester,
      MedicationSearchScreen(onSelected: (e) => selected = e),
    );

    await tester.enterText(find.byType(TextField).first, 'Metoprolol 50');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Metoprolol').first);
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.name, 'Metoprolol');
  });

  testWidgets('tapping Enter manually calls onSelected with null', (tester) async {
    MedicationLibraryEntry? selected = const MedicationLibraryEntry(name: 'placeholder', doseMg: 1, drugClass: 'x');
    await pumpApp(
      tester,
      MedicationSearchScreen(onSelected: (e) => selected = e),
    );

    await tester.tap(find.text('common.enterManually'.tr()));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/screens/medication_search_screen_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/screens/medication_search_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/medication_library.dart';

/// The Figma "Add medication" search screen (frame 368:2790) — a new screen
/// per Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md,
/// reached via a plain [Navigator] push, not a named route. Calls
/// [onSelected] with the tapped [MedicationLibraryEntry], or `null` if
/// "Enter manually" was chosen; the caller (MedicationsScreen) is
/// responsible for pushing MedicationFormScreen next with that result.
class MedicationSearchScreen extends StatefulWidget {
  const MedicationSearchScreen({required this.onSelected, super.key});

  final void Function(MedicationLibraryEntry?) onSelected;

  @override
  State<MedicationSearchScreen> createState() => _MedicationSearchScreenState();
}

class _MedicationSearchScreenState extends State<MedicationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<MedicationLibraryEntry> _results = const <MedicationLibraryEntry>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _results = searchMedicationLibrary(value));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'meds.search.title'.tr(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('meds.search.subtitle'.tr(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'meds.search.hint'.tr(),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.xl)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_results.isNotEmpty) ...<Widget>[
            Text(
              'meds.search.suggestions'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final MedicationLibraryEntry entry in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SuggestionCard(entry: entry, onTap: () => widget.onSelected(entry)),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'meds.search.libraryHint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
            Text(
              'meds.search.cantFind'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            label: 'common.enterManually'.tr(),
            variant: AppButtonVariant.outlined,
            onPressed: () => widget.onSelected(null),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.entry, required this.onTap});

  final MedicationLibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String dose = entry.doseMg == entry.doseMg.roundToDouble()
        ? entry.doseMg.toStringAsFixed(0)
        : entry.doseMg.toString();
    return SectionCard(
      onTap: onTap,
      backgroundColor: entry.mostCommon ? AppColors.accent.withValues(alpha: 0.12) : null,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('${entry.name} $dose mg', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  entry.mostCommon
                      ? '${entry.drugClass} · ${'meds.search.mostCommon'.tr()}'
                      : entry.drugClass,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
```

**Verify before committing:** if `SectionCard` doesn't have a `backgroundColor` parameter, read its real constructor in `core/widgets/widgets.dart` and either drop the highlight (report as DONE_WITH_CONCERNS) or wrap `SectionCard` in a `Container`/`DecoratedBox` supplying the tint instead — don't invent a parameter that isn't there. If `AppButtonVariant.outlined` isn't a real value (Task 19 of the original plan confirmed `.text` exists; `.outlined` is unconfirmed for this rework), check the enum and use whatever value renders an outlined/bordered button, or fall back to `AppButton`'s default variant styled to match Figma's outline via a wrapping `OutlinedButton` if `AppButton` truly has no outline variant.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/screens/medication_search_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Add translations**

Add to `assets/translations/en.json`'s `meds` object:
```json
"search": {
  "title": "Add medication",
  "subtitle": "Search or enter manually",
  "hint": "Search medications",
  "suggestions": "SUGGESTIONS",
  "mostCommon": "most common",
  "libraryHint": "Suggestions from offline medication library",
  "cantFind": "Can't find your medication?"
}
```
And the matching Amharic block (transcribe faithfully — if uncertain of a natural phrasing, use a reasonable direct translation and note it as a first pass needing native-speaker review, consistent with the rest of this project's Amharic strings). Also add `"enterManually": "Enter manually"` under the top-level `common` object in both files if `common.enterManually` doesn't already exist (check first — `common.add`/`common.save`/`common.seeAll`/`common.noValue` already exist per the original M3 build).

- [ ] **Step 6: Run full suite and commit**

```bash
flutter test
git add lib/features/medication/presentation/screens/medication_search_screen.dart test/features/medication/presentation/screens/medication_search_screen_test.dart assets/translations/en.json assets/translations/am.json
git commit -m "feat(mobile): M3 Figma rework — medication search screen"
```

---

## Task 5: `ReviewMedicationScreen`

**Files:**
- Create: `lib/features/medication/presentation/screens/review_medication_screen.dart`
- Test: `test/features/medication/presentation/screens/review_medication_screen_test.dart`

**Interfaces:**
- Consumes: `MedicationFormState` (`presentation/controllers/medication_form_controller.dart`, already exists), `MedicationFormController` (already exists — `save()` already returns `Future<bool>` and already has correct error handling from the original build's final-review fix wave).
- Produces: `class ReviewMedicationScreen extends ConsumerWidget` with `final MedicationFormState state` (read-only display) — it does not own form state itself, it displays whatever `MedicationFormController`'s current state is and calls its `save()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/screens/review_medication_screen_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/review_medication_screen.dart';

import '../../../../helpers/pump_app.dart';

class _FakeSavingController extends MedicationFormController {
  _FakeSavingController(this._state);
  MedicationFormState _state;
  bool saveCalled = false;

  @override
  MedicationFormState build() => _state;

  @override
  Future<bool> save() async {
    saveCalled = true;
    _state = _state.copyWith(saved: true);
    state = _state;
    return true;
  }
}

void main() {
  setUpWidgetTests();

  const state = MedicationFormState(
    name: 'Metoprolol',
    doseMg: '50',
    frequency: MedicationFrequency.bid,
    scheduleTimes: <String>['08:00', '20:00'],
  );

  testWidgets('shows the entered name, dose, frequency and times', (tester) async {
    await pumpApp(
      tester,
      const ReviewMedicationScreen(),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(() => _FakeSavingController(state)),
      ],
    );

    expect(find.textContaining('Metoprolol'), findsWidgets);
    expect(find.textContaining('50'), findsWidgets);
    expect(find.textContaining('08:00'), findsWidgets);
  });

  testWidgets('Save medication calls the controller\'s save()', (tester) async {
    final fake = _FakeSavingController(state);
    await pumpApp(
      tester,
      const ReviewMedicationScreen(),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(() => fake),
      ],
    );

    await tester.tap(find.text('meds.review.save'.tr()));
    await tester.pumpAndSettle();

    expect(fake.saveCalled, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/screens/review_medication_screen_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Read `lib/features/medication/presentation/controllers/medication_form_controller.dart` and `lib/features/medication/presentation/screens/medication_form_screen.dart` first (both already exist from the original M3 build) to confirm `MedicationFormState`'s exact field names (`name`, `doseMg`, `frequency`, `scheduleTimes`, `nameError`, `doseError`, `scheduleError`, `isSaving`, `saved`) and how `medication_form_screen.dart`'s existing `_save` error-handling (from Task I7 of the original final-review fix wave — a `SnackBar` on failure) is structured, so this screen's Save button follows the identical error-handling pattern rather than a new one.

```dart
// lib/features/medication/presentation/screens/review_medication_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/medication_form_controller.dart';

/// The Figma "Review medication" screen (frame 368:2651) — a new screen per
/// Decision E of docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md.
/// Purely a read-only summary of the form's current state plus the actual
/// save trigger; MedicationFormScreen pushes this instead of calling
/// save() directly.
class ReviewMedicationScreen extends ConsumerWidget {
  const ReviewMedicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller = ref.read(medicationFormControllerProvider.notifier);

    ref.listen<MedicationFormState>(medicationFormControllerProvider, (previous, next) {
      if (next.saved && (previous == null || !previous.saved) && context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return AppScaffold(
      title: 'meds.review.title'.tr(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('meds.review.subtitle'.tr(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: state.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SummaryRow(label: 'meds.form.doseMg'.tr(), value: '${state.doseMg} mg'),
                _SummaryRow(label: 'meds.review.frequency'.tr(), value: 'meds.frequency.${state.frequency.name}'.tr()),
                _SummaryRow(label: 'meds.form.scheduleTimes'.tr(), value: state.scheduleTimes.join(', ')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            backgroundColor: null,
            child: Text('meds.review.offlineNote'.tr(), style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'meds.review.save'.tr(),
            isLoading: state.isSaving,
            onPressed: () async {
              try {
                await controller.save();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('errors.generic'.tr())),
                  );
                }
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'meds.review.edit'.tr(),
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

**Verify before committing:** confirm `SectionCard(backgroundColor: null, ...)` compiles (i.e. `backgroundColor` is genuinely a real, nullable parameter — introduced/confirmed in Task 4; if Task 4 found it doesn't exist, drop this parameter here too, consistently). Confirm the exact `errors.generic` translation key used by the existing `medication_form_screen.dart`'s save-error handling (Task I7) — reuse that exact key, don't invent a new one.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/screens/review_medication_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Add translations**

Add to `assets/translations/en.json`'s `meds` object:
```json
"review": {
  "title": "Review medication",
  "subtitle": "Confirm before saving",
  "frequency": "Frequency",
  "offlineNote": "Notifications work offline",
  "save": "Save medication",
  "edit": "Edit details"
}
```
Plus the matching Amharic block.

- [ ] **Step 6: Run full suite and commit**

```bash
flutter test
git add lib/features/medication/presentation/screens/review_medication_screen.dart test/features/medication/presentation/screens/review_medication_screen_test.dart assets/translations/en.json assets/translations/am.json
git commit -m "feat(mobile): M3 Figma rework — review medication screen"
```

---

## Task 6: Wire the new screens into the add/edit flow, add the caregiver field

**Files:**
- Modify: `lib/features/medication/presentation/screens/medication_form_screen.dart`
- Modify: `lib/features/medication/presentation/screens/medications_screen.dart`
- Test: extend `test/features/medication/presentation/screens/medication_form_screen_test.dart` and `test/features/medication/presentation/screens/medications_screen_test.dart`

**Interfaces:**
- Consumes: `MedicationSearchScreen` (Task 4), `ReviewMedicationScreen` (Task 5), `CaregiverNotifyStore`/`caregiverNotifyStoreProvider` (Tasks 2–3), `MedicationLibraryEntry` (Task 1).

This task changes navigation, not business logic — read both files in full before editing, since they already exist from the original M3 build and this task must preserve every existing behavior (validation, `loadForEdit`, the deactivate flow from the original final-review fix wave's Critical C3, the auto-dispose fix from Critical C4) while adding:

1. **`MedicationsScreen`'s "+" action** (currently `context.pushNamed(AppRoutes.medicationNew)` in some form) instead pushes `MedicationSearchScreen`:
```dart
final MedicationLibraryEntry? picked = await Navigator.of(context).push<MedicationLibraryEntry?>(
  MaterialPageRoute<MedicationLibraryEntry?>(
    builder: (_) => MedicationSearchScreen(onSelected: (entry) => Navigator.of(context).pop(entry)),
  ),
);
// picked == a sentinel "search was cancelled without a choice" only if the user backed out without
// tapping anything; distinguish that from "Enter manually" (which explicitly pops null) by using a
// separate bool flag or a wrapper result type if Navigator's null-on-back-button collides with the
// deliberate null for "Enter manually" — verify this doesn't happen in practice with a widget test
// (back button vs "Enter manually" must both be handled, but only "Enter manually" should proceed to
// a blank form; backing out should return to MedicationsScreen with no navigation at all).
if (picked != null || /* Enter manually was explicitly chosen */ true) {
  // push MedicationFormScreen, pre-filled from `picked` if non-null
}
```
Resolve the ambiguity above concretely: change `MedicationSearchScreen.onSelected`'s contract (Task 4) if needed so the caller can tell "back button, nothing chosen" apart from "Enter manually, proceed with a blank form" — e.g. by having `MedicationSearchScreen` never pop on system-back without calling a distinct callback, or by wrapping the result in `({bool proceed, MedicationLibraryEntry? entry})`. Pick the cleanest fix and, if it requires changing Task 4's already-committed `onSelected` signature, do so in this task's own diff (updating Task 4's file and test together) — call this out explicitly in your report since it's a cross-task adjustment.

2. **`MedicationFormScreen`** gains the caregiver toggle + phone field (read/write via `caregiverNotifyStoreProvider`, loaded in `initState`/on `loadForEdit` alongside the existing medication load, saved via the store — not via `MedicationFormController`, since it's storage the controller doesn't own) and, on submit, pushes `ReviewMedicationScreen` instead of calling `controller.save()` directly:
```dart
onPressed: () {
  final String? nameError = validateMedicationName(state.name);
  // ... existing validation display, unchanged ...
  if (state.isValid) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewMedicationScreen()));
  }
},
```
Do not duplicate the validation logic already in `MedicationFormController` — call it the same way the existing Save button already does, just redirect the success path to push the review screen instead of calling `save()`.

- [ ] **Step 1: Write the failing tests** (extend both existing test files — add new test cases for: tapping "+" opens the search screen; picking a suggestion opens the form pre-filled; "Enter manually" opens a blank form; filling a valid form and tapping Save opens the review screen, not an immediate save; the caregiver toggle/phone persist via `CaregiverNotifyStore` — write these as concrete `testWidgets` blocks following the exact style of the existing tests in each file, not prose)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medication/presentation/screens/medication_form_screen_test.dart test/features/medication/presentation/screens/medications_screen_test.dart`
Expected: FAIL on the new cases.

- [ ] **Step 3: Implement the changes described above**

- [ ] **Step 4: Run tests to verify they pass, plus the full suite for regressions**

Run: `flutter test`
Expected: every pre-existing test still passes, all new tests pass.

- [ ] **Step 5: Add translations for the caregiver field**

Add to `assets/translations/en.json`'s `meds.form` object (extending the existing object, not replacing it):
```json
"notifyCaregiver": "Notify caregiver if missed",
"caregiverPhone": "Caregiver phone number"
```
Plus the matching Amharic additions.

- [ ] **Step 6: Commit**

```bash
git add lib/features/medication/presentation/screens/medication_form_screen.dart lib/features/medication/presentation/screens/medications_screen.dart lib/features/medication/presentation/screens/medication_search_screen.dart test/features/medication/presentation/screens/medication_form_screen_test.dart test/features/medication/presentation/screens/medications_screen_test.dart test/features/medication/presentation/screens/medication_search_screen_test.dart assets/translations/en.json assets/translations/am.json
git commit -m "feat(mobile): M3 Figma rework — wire search/review into the add/edit flow, add caregiver field"
```

---

## Task 7: `MedicationsScreen` Today/Schedule/History tabs

**Files:**
- Modify: `lib/features/medication/presentation/screens/medications_screen.dart`
- Modify: `lib/features/medication/presentation/screens/dose_history_screen.dart`
- Test: extend `test/features/medication/presentation/screens/medications_screen_test.dart`, `test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart`

**Interfaces:**
- Consumes: `DoseHistoryController`/`doseHistoryControllerProvider` (already exists), `MedicationCard` (already exists), everything `MedicationsScreen` already consumes.
- Produces: `DoseHistoryContent` (extracted, public — was previously `DoseHistoryScreen`'s private body), `MedicationsScreen` gains an in-page `Today`/`Schedule`/`History` segmented control.

Read the current `medications_screen.dart` and `dose_history_screen.dart` in full first — both already exist and are fully tested; this task restructures without changing the underlying logic in either.

**Step A — extract `dose_history_screen.dart`'s body:**
```dart
// dose_history_screen.dart, after this change:
class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'meds.history.title'.tr(),
      body: const DoseHistoryContent(),
    );
  }
}

/// The dose-history list/filter/sync-status content, extracted so
/// MedicationsScreen's History tab (Task 7 of the Figma-fidelity plan) and
/// this screen's own route can share it without duplicating logic.
class DoseHistoryContent extends ConsumerWidget {
  const DoseHistoryContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...move the existing body here verbatim, unchanged...
  }
}
```

**Step B — `MedicationsScreen` tabs**, using `DefaultTabController`/`TabBar`/`TabBarView` (or `IndexedStack` + a manual segmented control styled to match Figma's pill-shaped tab selector — check Figma frame `368:2583` for the exact visual, already described in the spec §3.1/§3.4; either mechanism is acceptable as long as the visual matches and each tab's state — especially the History tab's active filter — survives switching tabs and back, which `TabBarView`'s default `AutomaticKeepAliveClientMixin` handles for you, so prefer `TabBarView` over `IndexedStack` unless there's a concrete reason not to):

```dart
// Today tab: the screen's existing today's-doses content, moved under a tab, unchanged logic.
// Schedule tab: the screen's existing medication-list content (MedicationCard list), moved under a tab, unchanged logic.
// History tab: const DoseHistoryContent(),
```

Also add an app-bar action (an `IconButton`/`PopupMenuButton`) routing to the existing `AppRoutes.adherence`/`AppRoutes.reminderSettings` named routes (unchanged — these routes and their screens already exist and are already wired in `app_wiring.dart` from the original build; this task only adds a UI entry point to them, no routing-table change):
```dart
actions: <Widget>[
  PopupMenuButton<String>(
    onSelected: (value) {
      if (value == 'adherence') context.pushNamed(AppRoutes.adherence);
      if (value == 'reminders') context.pushNamed(AppRoutes.reminderSettings);
    },
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      PopupMenuItem<String>(value: 'adherence', child: Text('meds.adherence.title'.tr())),
      PopupMenuItem<String>(value: 'reminders', child: Text('meds.reminders.title'.tr())),
    ],
  ),
],
```

- [ ] **Step 1: Write the failing tests** (extend `medications_screen_test.dart`: switching to the Schedule tab shows the medication list; switching to the History tab shows dose history content, matching whatever `DoseHistoryContent`'s own already-tested behavior is — a light integration check, not a re-test of history's internals; the app-bar menu navigates to Adherence/Reminder Settings)

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement Steps A and B above**

- [ ] **Step 4: Run tests to verify they pass, plus the full suite for regressions**

Run: `flutter test`

- [ ] **Step 5: Add tab-label translations if not already covered**

`meds.today` (already exists), add `meds.schedule` / reuse `meds.yourMedications` for the Schedule tab label if it fits Figma's "Schedule" copy, `meds.history.title` already exists — confirm and only add what's genuinely missing.

- [ ] **Step 6: Commit**

```bash
git add lib/features/medication/presentation/screens/medications_screen.dart lib/features/medication/presentation/screens/dose_history_screen.dart test/features/medication/presentation/screens/medications_screen_test.dart test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart assets/translations/en.json assets/translations/am.json
git commit -m "feat(mobile): M3 Figma rework — Today/Schedule/History tabs on Medications screen"
```

---

## Task 8: Restyle `TimeListField` and dosage/frequency chips

**Files:**
- Modify: `lib/features/medication/presentation/widgets/time_list_field.dart`
- Modify: `lib/features/medication/presentation/screens/medication_form_screen.dart` (chip styling only, not logic)
- Test: extend `test/features/medication/presentation/widgets/medication_widgets_test.dart`

**Interfaces:** none new — visual-only change (Decision C: flexible chip behavior unchanged, only colors/spacing/shape updated to match Figma frame `368:2706`'s time-slot cards and dosage/frequency `ChoiceChip`s).

Read `time_list_field.dart` and the chip-building code in `medication_form_screen.dart` first. Apply `AppColors`/`AppSpacing` tokens matching Figma (selected chip: `AppColors.ink` background per the design system's existing selected-state convention already used elsewhere in this app — check an existing selected-`ChoiceChip` example in the codebase, e.g. `MedicationFormScreen`'s frequency chips likely already have a selected/unselected color pair from the original build; align the visual weight/roundness to Figma without changing the underlying `ChoiceChip`/chip-list mechanics).

- [ ] **Step 1: Write the failing test** — a widget test asserting no `RenderFlex` overflow and no exception at a realistic width for the restyled chips (following the same pattern as the overflow-regression tests already in `medication_widgets_test.dart` from the original build's Task 15 follow-up fix — reuse `_pumpWithLongLabels`/similar helpers already in that file if a long-label scenario is relevant here, or a plain `pumpApp` + `tester.takeException()` check if not).

- [ ] **Step 2: Run test to verify it fails or passes trivially** (a pure restyle may not have a meaningful RED state — if so, skip to Step 3 and note in the commit that this task is visual-only, verified by the existing overflow-safety suite continuing to pass, not by a new failing test)

- [ ] **Step 3: Apply the restyle**

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: all pre-existing tests (including the overflow-regression suite) still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/widgets/time_list_field.dart lib/features/medication/presentation/screens/medication_form_screen.dart test/features/medication/presentation/widgets/medication_widgets_test.dart
git commit -m "fix(mobile): M3 Figma rework — restyle time picker and dosage/frequency chips"
```

---

## Task 9: Final verification

**Files:** none new — verification only, matching the original M3 plan's own final task.

- [ ] **Step 1:** `flutter analyze` — expect `No issues found!`
- [ ] **Step 2:** `flutter test` — expect every test from Tasks 1–8 passing, no regressions in the pre-existing 263 M3 tests.
- [ ] **Step 3:** Re-read `docs/design/2026-08-27-mobile-m3-figma-fidelity-design.md` §6 (Done criteria) and confirm each bullet against what was actually built; note any gap in the final report rather than silently closing it out.
- [ ] **Step 4:** `git log --oneline` sanity check — confirm the commit sequence matches Tasks 1–8, nothing outside `lib/features/medication/`, `test/features/medication/`, `assets/translations/{en,am}.json`, and this plan's own two doc files changed.
- [ ] **Step 5:** Leave a note in the final report that on-device visual verification against the real Figma screens (colors under real lighting, Amharic text with the real device font, the caregiver field's phone-number keyboard behavior) still needs a real device pass — same category of gap the original M3 plan's Task 21 Step 3 flagged, now doubly relevant since this whole rework exists to fix visual fidelity.
