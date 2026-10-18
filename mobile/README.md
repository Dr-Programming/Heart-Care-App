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
which is where Docker publishes the API on port 8080.

Start the backend first, from the repo root:

```bash
cp .env.example .env                 # first time only - set JWT_SECRET
docker compose up -d --build         # PostgreSQL + API
```

### Server URL

The API address is set in `lib/core/config/env.dart` (`Env.apiBaseUrl`) and
is compiled into the app at build time. `--dart-define=API_BASE_URL=...`
overrides it; without the define the app uses the default in that file,
currently the ngrok tunnel `https://kinetic-tasting-venue.ngrok-free.dev`.

| Where the app runs | `API_BASE_URL` |
|---|---|
| Android emulator, local backend | `http://10.0.2.2:8080` |
| Physical phone, same Wi-Fi | `http://<your-LAN-IP>:8080` |
| Physical phone, anywhere | the ngrok URL (the default) |

The ngrok URL only works while the tunnel is running on the host machine and
forwarding to port 8080. If the tunnel's URL changes, rebuild the app with the
new one; an installed app keeps the URL it was built with. `10.0.2.2` does not
work on a physical device.

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

Package `com.libucare.app`, minSdk is Flutter's default (`flutter.minSdkVersion`), portrait only.
The version is `1.2.0+3`, set in `pubspec.yaml`. Bump it there, or override it for one build with
`--build-name` / `--build-number`.

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
[CONTRIBUTING.md](CONTRIBUTING.md) for the architectural rules and the list of shared
files.

## Notes

- **Generated code is gitignored.** `*.g.dart` and `*.freezed.dart` are built,
  not committed. A fresh clone does not compile until `build_runner` runs.
- **The device is the source of truth.** Reads come from Drift, writes go to
  Drift and then onto the sync queue. Nothing user-facing awaits the network.
- **`backend/docs/API.md` is the contract** for every endpoint the app calls.
- Poppins has no Ethiopic glyphs, so Amharic renders in Noto Sans Ethiopic.
  The theme handles it; check Amharic layouts for overflow.
