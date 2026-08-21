# Contributing — Libu Care mobile

Read this once before your first commit. `mobile/CLAUDE.md` has the
architectural rules; this has the workflow.

## 1. Set up

```bash
git clone https://github.com/Dr-Programming/Heart-Care-App.git
cd Heart-Care-App/mobile
flutter pub get
dart run build_runner build          # REQUIRED - see below
flutter analyze                      # expect: No issues found!
flutter test                         # expect: all green
```

**`build_runner` is not optional.** Generated files (`*.g.dart`,
`*.freezed.dart`) are gitignored, so a fresh clone will not compile until you
run it. Re-run it any time you add or change a freezed model or a Drift table.

Run the app against a local backend:

```bash
# from the repo root, in another terminal
docker compose up -d
mvn -f backend/pom.xml spring-boot:run

# then
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's alias for your machine's localhost. On a
physical device use your machine's LAN IP.

## 2. Branches

```
main                                  protected, release only
└── dev                               integration
    └── mobile                        the foundation + where your work lands
        ├── feature/mobile/auth
        ├── feature/mobile/profile
        ├── feature/mobile/medications
        ├── feature/mobile/vitals
        └── feature/mobile/symptoms-activity
```

```bash
git checkout mobile
git pull
git checkout -b feature/mobile/<your-slice>
```

Branch from `mobile`, PR into `mobile`. Never PR into `dev` or `main`.
Rebase or merge `mobile` into your branch regularly — a week-old branch is a
week of conflicts.

## 3. How to build your slice

Your spec is `docs/design/2026-08-22-mobile-m<N>-*-design.md`. It is a design
document, not a plan — turning it into a plan is your first job, and it is
where your judgement shows.

With Claude Code, run the same pipeline the backend was built with:

1. `/superpowers:brainstorming` — work through the spec, resolve what it left
   open, write down decisions.
2. `/superpowers:writing-plans` — produce a task-by-task plan in
   `docs/plans/2026-XX-XX-mobile-m<N>-<slice>.md`. Bite-sized TDD tasks, each
   ending green and committed.
3. `/superpowers:subagent-driven-development` — execute it task by task.
4. `/superpowers:requesting-code-review` — review your own branch before you
   ask a human to.
5. `/superpowers:finishing-a-development-branch` — push and open the PR.

The plugin set is committed in `.claude/settings.json`, so everyone runs the
same tools.

## 4. Order of work

Build bottom-up. It is tempting to start with screens; don't.

1. **domain** — entity, repository interface, use cases. Pure Dart, fully
   testable, no Flutter import.
2. **data** — freezed models, remote datasource (Dio), local datasource
   (Drift), repository implementation. This is where offline-first lives and
   where the hard bugs are.
3. **presentation** — controller, then screens.

In an offline-first app the hard part is the data flow, not the pixels.
Screens plug into proven controllers instead of a moving target.

## 5. The canonical layer template

Copy this shape. Names change, structure does not.

```dart
// domain/entities/vital_reading.dart  — no JSON, no Drift, no Flutter
class VitalReading {
  const VitalReading({required this.clientRecordId, required this.type, ...});
  final String clientRecordId;
  final VitalType type;
}

// domain/repositories/vitals_repository.dart
abstract interface class VitalsRepository {
  /// Returns a value or throws a [Failure]. Never returns null for an error.
  Future<void> log(VitalReading reading);
  Stream<List<VitalReading>> watchHistory({VitalType? type});
}

// domain/usecases/log_vital.dart  — thin, one job
class LogVital {
  const LogVital(this._repository);
  final VitalsRepository _repository;
  Future<void> call(VitalReading reading) => _repository.log(reading);
}

// data/models/vital_model.dart  — freezed; toEntity() / toCompanion() / toJson()
// data/datasources/vitals_remote_datasource.dart  — Dio only, unwraps ApiResponse
// data/datasources/vitals_local_datasource.dart   — Drift only

// data/repositories/vitals_repository_impl.dart
class VitalsRepositoryImpl implements VitalsRepository {
  @override
  Future<void> log(VitalReading reading) async {
    await _local.insert(reading);                 // 1. device first, always
    await _sync.enqueue(                          // 2. then owe it to the server
      clientRecordId: reading.clientRecordId,
      entityType: SyncEntityType.vital,
      payload: VitalModel.fromEntity(reading).toJson(),
      recordedAt: reading.measuredAt,
    );
  }                                               // never awaits the network
}

// presentation/controllers/vitals_controller.dart
class VitalsController extends AsyncNotifier<VitalsState> { ... }
```

Note what the repository does **not** do: it does not check connectivity, and
it does not call the API. Writes go local-then-queue, unconditionally. The one
exception in the whole app is first-time login, which genuinely cannot work
offline.

## 6. Traps in the API contract

From `backend/docs/API.md`. Each of these has bitten someone already.

- **Success is always `200`.** There is no `201`, not even for creates.
- Every response is wrapped in `{success, data, message, timestamp}`. Unwrap
  with `ApiResponse.fromJson` before touching `data`.
- `PUT /patients/me` is a **full replace** — omitted fields are cleared to
  null. Always send the complete profile.
- `404` also means "exists but belongs to another user". Never `403`.
- `GET /dose-logs?medicationId=<unknown-but-valid-uuid>` returns `200 []`.
- The `423` lockout message is singular on the final minute ("1 minute").
  Parse with `parseLockoutMinutes`, which already handles it.
- Retry only `500`. `400/404/405/409/413` are permanent; `423` is temporary
  but must not be retried on a timer.

## 7. Pull requests

Title: `feat(mobile): M<N> — <slice name>`. In the description:

- what the slice delivers, against its spec's "Done criteria"
- anything you deliberately left out, and why
- screenshots for new screens, English and Amharic

Before you open it:

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] you ran the app and used the feature, including with the radio off
- [ ] no edits to shared files outside your marked region
- [ ] no AI co-author trailer on any commit

Request review from the maintainer plus `j444cky`. The maintainer merges.

## 8. When you are stuck

- The spec is wrong or incomplete → say so in the PR or an issue. Specs are
  drafts, not scripture.
- You need something from `core/` that isn't there → ask. Do not add it on
  your branch; the next person needs it too, and two people adding the same
  helper in two places is worse than waiting a day.
- You need a backend change → almost certainly no, but ask. The API is frozen
  at `v1.0.0` and reopening it affects everyone.
