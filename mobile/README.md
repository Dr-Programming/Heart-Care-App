# Libu Care — Flutter app

Offline-first coronary heart disease self-management for patients in Ethiopia.
English and አማርኛ. Talks to the Spring Boot API in `../backend`.

New here? Read [CONTRIBUTING.md](CONTRIBUTING.md).

## Run

```bash
flutter pub get
dart run build_runner build          # required - generated code is not committed
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's alias for the host machine's localhost,
which is where `mvn spring-boot:run` serves the API. On a physical device use
your machine's LAN address. The default if you omit the define is the same
emulator address.

Start the backend first, from the repo root:

```bash
docker compose up -d                 # PostgreSQL
mvn -f backend/pom.xml spring-boot:run
```

## Test

```bash
flutter analyze                      # expect: No issues found!
flutter test                         # whole suite
flutter test test/core/sync          # one directory
flutter test --plain-name "logs a vital while offline"
```

Helpers in `test/helpers/` — `testDatabase()`, `FakeDio`, `pumpApp()` — are
the intended entry points. `pumpApp` sets up localization, Riverpod and the
theme, and works around several failure modes that otherwise make a widget
test hang with no output.

## Build

```bash
flutter build apk --dart-define=API_BASE_URL=https://<host>
flutter build ios --dart-define=API_BASE_URL=https://<host>
```

Package `com.libucare.app`, minSdk 21, portrait only.

## Layout

```
lib/
  app/          composition root - the one file where features meet
  core/         shared: theme, db, network, sync, router, shell, widgets, clinical
  features/     one folder per feature slice, each data/domain/presentation
  main.dart
assets/
  translations/ en.json · am.json
test/
  helpers/      test harness used by every slice
```

`core/` is owned by the foundation and is not edited on a feature branch. See
[CLAUDE.md](CLAUDE.md) for the architectural rules and the list of shared
files.

## Notes

- **Generated code is gitignored.** `*.g.dart` and `*.freezed.dart` are built,
  not committed. A fresh clone does not compile until `build_runner` runs.
- **The device is the source of truth.** Reads come from Drift, writes go to
  Drift and then onto the sync queue. Nothing user-facing awaits the network.
- **The backend is frozen** at `v1.0.0`. `backend/docs/API.md` is the contract.
- Poppins has no Ethiopic glyphs, so Amharic renders in Noto Sans Ethiopic.
  The theme handles it; check Amharic layouts for overflow.
