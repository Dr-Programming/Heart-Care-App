# Libu Care — Flutter app

Cross-platform CHD patient app. This is the mobile frontend; the REST API lives in
`../backend`. Offline-first, bilingual (English / አማርኛ).

Slice 1 (**Foundation & Auth**) is built: project scaffold + `core/` layer +
the auth feature end-to-end (phone + PIN register / login / me against the live
backend, offline auth gate, local JWT-expiry check, secure token + cached user).

## Run

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # REQUIRED after checkout — generated code is gitignored
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

- `10.0.2.2` is the **Android emulator's** alias for the host machine's
  `localhost`. On a **physical device** pass the host's LAN address instead
  (e.g. `--dart-define=API_BASE_URL=http://192.168.1.20:8080`).
- The backend must be running: `cd ../backend && mvn spring-boot:run` (needs
  Docker Postgres up — `docker compose up -d` from the repo root, and a `.env`
  copied from `.env.example`).
- `API_BASE_URL` defaults to `http://10.0.2.2:8080` if the define is omitted.

## Web dev preview

```
flutter run -d chrome --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Web is a **development-preview convenience, not a shipping target**.

- `flutter build web` **fails** unless you pass **`--no-tree-shake-icons`** — the
  `iconsax` 0.0.8 icon font defeats Flutter's icon subsetter
  (`IconTreeShakerException: Font subsetting failed`). Use
  `flutter build web --no-tree-shake-icons`.
- drift's WASM database runs on `sharedIndexedDb` (OPFS is unavailable without
  cross-origin-isolation `COOP`/`COEP` headers). Those writes are **not durable
  across a hard refresh**. When online the app recovers the session with
  `GET /auth/me` (`AuthController.build`); a genuine fresh-device restore still
  comes from the server, not local storage. On a real device (SQLite, secure
  storage) persistence is durable.

## Test

```
flutter analyze     # clean — "No issues found!"
flutter test        # 98 tests, all green
```

## Notes

- **Generated files** (`*.g.dart`, `*.freezed.dart`) are **gitignored** (repo
  root `.gitignore`). Run `dart run build_runner build --delete-conflicting-outputs`
  after every checkout, and again after changing a model, DAO, or Drift table.
- **Fonts are bundled** under `assets/fonts/` (Poppins + Noto Sans Ethiopic) — no
  runtime download, works fully offline. Amharic renders in Noto Sans Ethiopic
  (Poppins has no Ethiopic glyphs); Latin text stays Poppins, including on
  Amharic screens, via `fontFamilyFallback`. Mixed strings use both faces by
  design.
- **Amharic copy in `assets/translations/am.json` is a first-pass machine
  translation and MUST be reviewed by a native speaker before release** — same
  release gate as the clinical thresholds.
- **Registration is identity-only** — phone, PIN, name, preferred language. Date
  of birth, height and sex (the Figma "Personal details" frame) belong to the
  patient-profile slice.
- **Toolchain:** Flutter 3.44.8 / Dart 3.12.2. Riverpod is pinned to 2.6.x with
  **no codegen** — `riverpod_generator` cannot co-resolve with `drift_dev` on
  this toolchain. `freezed` is a 3.2.x prerelease (the only build compatible with
  analyzer 12).

## Layout

```
lib/
├── core/            # config, theme, network (Dio), db (Drift), localization,
│                    # security (JWT), router, providers
├── features/
│   └── auth/
│       ├── data/        # models, remote datasource (Dio), local datasource (Drift + secure storage), repository impl
│       ├── domain/      # entity, repository contract, validators, use cases
│       └── presentation/ # controller (Riverpod) + screens (splash gate, language, login, create account, home, forgot PIN)
└── main.dart
```
