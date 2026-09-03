# Mobile Foundation & Auth (Frontend Half) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Flutter app — project scaffold, `core/` layer, and the auth feature end-to-end — so a patient can register with phone + PIN, be auto-logged-in, land on Home, and reopen the app offline without signing in again.

**Architecture:** Feature-first clean architecture. `core/` owns theme, config, errors, network, database, localization and routing; `features/auth/` owns its own `data` / `domain` / `presentation` layers and reaches the rest of the app only through the `AuthRepository` interface and the `authController` provider. Local and remote datasources are separate classes so offline mode needs no conditionals. Riverpod is both state management and DI.

**Tech Stack:** Flutter 3.44.8 · Dart 3.12.2 · Riverpod (+ codegen) · go_router · Drift · Dio · flutter_secure_storage · connectivity_plus · easy_localization · google_fonts (Poppins + Noto Sans Ethiopic) · iconsax · freezed + json_serializable · mocktail

**Spec:** `docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md` — §3 is this plan's scope. §2 (the backend half) shipped in `v1.0.0`; treat the API as frozen. Decisions log: `docs/frontend-decisions.md`. API contract: `backend/docs/API.md` §1.

**Supersedes:** the deleted plan `docs/plans/2026-08-17-slice8-mobile-foundation-auth-frontend.md` (written against Figma file `B2D41kike6v4YRjHQMlszS`, which had bespoke phone+PIN frames). This plan is rebuilt against the Figma file the designer actually shipped — `2ulgCN3pghwu6g4bzzi4mw` ("Capstone") — whose "Screen 2" is the 3-step medical wizard, not an identity form. The reconciliation is recorded under Global Constraints.

---

## Global Constraints

Every task's requirements implicitly include this section.

**Toolchain**
- Flutter **3.44.8** stable, Dart **3.12.2** (the versions installed on this machine — do not `flutter upgrade`). Java 21 is present for the Android toolchain.
- Repo root is `C:\src\Heart-Care-App`. Everything this plan creates lives under `mobile/`. The repo root already has `backend/`, `docs/`, `docker-compose.yml`.
- Shell examples are written for the Bash tool (Git Bash). Run them from the repo root unless a `cd mobile` is shown. On PowerShell, `&&` chains must become `;`-with-`if ($?)`.

**Platform**
- Android package / iOS bundle id: **`com.libucare.app`**. Dart package name: **`libu_care`**. minSdk **21**. **Portrait only.**
- API base URL is injected: `--dart-define=API_BASE_URL=...`, default **`http://10.0.2.2:8080`** (Android emulator → host localhost). Never hardcode a URL outside `core/config/env.dart`.

**API contract (frozen — backend is released at `v1.0.0`, verified against `backend/docs/API.md` §1)**
- Base path `/api/v1`. Public: `POST /auth/register`, `POST /auth/login`. Authenticated: `GET /auth/me`.
- **Every** response — success or error — is the envelope `{ "success": bool, "data": T|null, "message": string, "timestamp": string }`.
- **Success is always `200`. The API never returns `201`,** including from register.
- `register` request: `{phone, pin, name, preferredLanguage}` → `data` is `{token, user}`. `message` is `"Registered"`.
- `login` request: `{phone, pin}` → `data` is `{token, user}`. `message` is `"Logged in"`.
- `me` → `data` is the user object directly: `{id, name, phone, preferredLanguage, role}`.
- Error codes to handle: `400` validation · `401` `"Invalid phone or PIN"` · `409` `"Phone already registered"` · `423` lockout · `500` `"An unexpected error occurred"`.
- **`423` message is `"Too many failed attempts. Try again in N minutes."` and is singular on the final minute (`"Try again in 1 minute."`). Never match on the plural.**
- `423` must be surfaced as "wait", never as "wrong PIN". Do not auto-retry it on a timer.
- Token lifetime is **7 days**; there is no refresh and no revocation endpoint.

**Validation (must match the server exactly, so the client fails fast rather than round-tripping)**
- Phone: `^\+251\d{9}$` — literal `+251` then exactly 9 digits.
- PIN: `^\d{4}$` — exactly 4 digits.
- Name: not blank, ≤ 255 characters.
- `preferredLanguage`: `en` or `am`.

**Design fidelity (non-negotiable — colours and fonts are exact; layout is the implementer's latitude)**
- Font: **Poppins** (Regular 400, Bold 700) via `google_fonts`. **No other font may be introduced for Latin text.**
- **Poppins has no Ethiopic coverage.** Amharic text falls back to **Noto Sans Ethiopic** (also via `google_fonts`). This is an addition for a script Poppins cannot draw — not a substitution of the design font. Confirmed by the user during planning.
- Palette. The Figma file has **no variables** (`get_variable_defs` returned `{}`); values below are read from the two frames' text layers plus the `docs/frontend-decisions.md` extraction. Use these literals and no others:

  | Token | Hex | Source | Use |
  |---|---|---|---|
  | `primary` | `#FCAB10` | decisions log | primary CTA fill ("Sign in", "Continue"), active nav |
  | `accent` | `#1D4ED8` | frame text layer `368:697`, `368:706` | links, "Works offline", "Forgot PIN?" |
  | `success` | `#16A34A` | decisions log | normal / in range (unused this slice; define it) |
  | `warning` | `#D97706` | decisions log | elevated / watch (unused this slice; define it) |
  | `critical` | `#DC2626` | decisions log | error banners, destructive |
  | `ink` | `#282A2A` | frame text layer `368:689` | headings, primary text, selected-pill fill |
  | `textSecondary` | `#6B7280` | frame text layer `368:690` | body / muted / helper |
  | `textTertiary` | `#9CA3AF` | frame text layer `368:693` | placeholders, disabled |
  | `surface` | `#FFFFFF` | frame background `368:682` | screen + card background |
  | `surfaceAlt` | `#F5F6F8` | decisions log | page backdrop behind cards |
  | `headerBand` | `#DBD5B5` | decisions log — **verify in Task 2** | the cream band at the top of every screen |
  | `border` | `#EAEDF1` | decisions log | field + card borders |
  | `borderStrong` | `#D1D5DB` | decisions log | inactive dots, stronger dividers |
  | `accentBg` | `#E8F0FE` | decisions log | "Works offline" chip background |
  | `criticalBg` | `#FEE2E2` | decisions log | error-banner background |

- **Two fills came back from Figma as flattened SVG vectors, not text layers, so their hex is not machine-readable:** the `headerBand` cream and the `primary` amber button (`Sign in button` node `368:698`). Task 2 Step 3 colour-picks both from the rendered frame and corrects the table above if they differ from `#DBD5B5` / `#FCAB10`.
- Type scale (Poppins), from the frames: h1 **24** Bold (`368:689` "Welcome back") · h2 **22** Bold (`368:641` "Tell us about yourself") · section/button **15** Bold (`368:699` "Sign in") · body/label/placeholder **12** Regular (every field label, hint and helper on both frames). Define a fuller scale (`display 30`, `bodyLarge 14`, `caption 12`, `micro 11`) for later slices but the auth screens use 24 / 22 / 15 / 12.
- Field & button geometry, measured off the 402-px frames with a ~30-px gutter (`inset ... 7.45%` ≈ 30 px): content column ~342 px, fields full-width in that column, tall rounded-pill corners (radius ≈ 24), leading icon inside each field. Primary button full-width, same radius, ~52 px tall, Bold 15 white label.

**Figma frames this slice implements** (file `2ulgCN3pghwu6g4bzzi4mw`, page "Main", section "LibuCare - Main Design"):

| Screen | Frame | Node | Role in this plan |
|---|---|---|---|
| Login | Screen 1 | `368:680` | implemented directly |
| Personal details (medical wizard step 1) | Screen 2 | `368:632` | **visual reference only** for Create account — see reconciliation below |
| Choose language (first run) | — | — | no frame; built from the design system, implementer's latitude |
| Forgot PIN (info) | — | — | no frame; built from the design system, implementer's latitude |
| Home (placeholder shell) | — | — | no frame; header band + greeting + sign-out only |

**Figma reconciliation — Create account screen (decided with the user during planning)**
- The designer's "Screen 2" (`368:632`) is **Step 1 of 3 — Personal details** of the medical-onboarding wizard: it collects name, **date of birth, height, sex**, and language, with a "Step 1 of 3" caption and a 3-dot progress indicator.
- This slice's registration is **identity only** (spec §3, decisions log §3): phone, PIN, name, preferred language → one screen → `POST /auth/register` → auto-login.
- **Resolution:** build a Create account screen that reuses Screen 2's *visual system* — cream header band, full-width rounded-pill fields with a leading icon, a "label above field" rhythm, dark (`ink`) selected / outlined unselected choice pills, amber primary button, Poppins, the palette — but whose fields are **phone (`+251` prefix, call icon), full name (user icon), 4-digit PIN (lock icon, obscured), confirm PIN (lock icon, obscured), preferred-language pills (English / አማርኛ)**. **Do not render** date of birth, height, sex, the "Step 1 of 3" caption, or the progress dots. Those belong to the patient-profile slice and `POST /auth/register` would reject them.
- **Confirm-PIN field** is added deliberately (it is on neither frame): a mistyped 4-digit PIN with no self-service reset locks a patient out of their own record permanently. Client-side equality check only; it is never sent to the server.

**Architectural rules (from `CLAUDE.md` — a reviewer will reject violations)**
1. Features never import from each other; only from `core/`.
2. DTOs never leave their feature package — map to entities at the boundary.
3. Local and remote datasources are always separate classes.
4. All API URLs live in `core/constants/api_endpoints.dart` and nowhere else.

**Scope decisions already made — do not re-litigate mid-build**
- Registration is **identity only**: phone, PIN, name, language. No DOB / height / sex / medical wizard — that is the patient-profile slice.
- Forgot PIN is **info-only**. No self-service reset exists on the server. The screen must not imply one does.
- The language choice is **device-local this slice**. Registration seeds `users.preferred_language` server-side; nothing else updates it, and there is no post-login settings screen here, so the two server columns cannot diverge yet. Ownership of `preferredLanguage` is settled in the patient-profile slice.
- `fl_chart` is **not** a dependency of this slice.
- No `get_it`. No `sync_queue`. No offline write queue — this slice has no offline writes.
- Backend is **read-only**. This plan changes nothing under `backend/`.

**Testing**
- TDD throughout: failing test → run it → minimal implementation → run it green → commit.
- `mocktail` for mocks (no build_runner-generated mocks).
- Every task ends green on `cd mobile && flutter analyze && flutter test`.
- Generated files (`*.g.dart`, `*.freezed.dart`) are **gitignored** in this repo (root `.gitignore` lines 97–98). Anyone checking out `mobile/` must run `dart run build_runner build --delete-conflicting-outputs` before it compiles. Tasks that touch generated code say so explicitly.

---

## File Structure

```
mobile/
  pubspec.yaml
  analysis_options.yaml
  assets/
    translations/en.json · am.json
    images/libu_care_logo.png
  lib/
    main.dart                          app bootstrap: ensureInitialized, EasyLocalization, ProviderScope
    core/
      config/env.dart                  API_BASE_URL from --dart-define
      constants/api_endpoints.dart     THE only place URLs exist
      theme/app_colors.dart            the palette literals above
      theme/app_spacing.dart           gutter, radii, field/button sizes
      theme/app_typography.dart        Poppins scale + Ethiopic fallback
      theme/app_theme.dart             ThemeData assembly
      error/failure.dart               sealed Failure hierarchy + parseLockoutMinutes
      network/api_response.dart        the {success,data,message,timestamp} envelope
      network/dio_client.dart          Dio factory + HTTP-status → Failure mapping
      network/interceptors/auth_token_interceptor.dart
      db/app_database.dart             Drift DB + CachedUsers + Preferences tables
      db/daos/cached_user_dao.dart
      db/daos/preferences_dao.dart
      localization/language.dart       AppLanguage enum + LanguageStore
      security/jwt.dart                base64url exp decode, no extra dependency
      security/token_store.dart        the JWT in the platform keystore
      router/routes.dart               route path constants
      router/redirect.dart             the auth-gate rule, as a pure function
      router/app_router.dart           go_router wiring (built in Task 11)
      providers/core_providers.dart    db, secureStorage, tokenStore, dio, connectivity, languageStore
    features/auth/
      auth_providers.dart              datasource + repository providers
      domain/entities/auth_user.dart
      domain/repositories/auth_repository.dart
      domain/validators.dart
      domain/usecases/{login,register,get_me,logout}.dart
      data/models/{user_model,auth_response_model}.dart
      data/datasources/auth_remote_datasource.dart
      data/datasources/auth_local_datasource.dart
      data/repositories/auth_repository_impl.dart
      presentation/controllers/auth_controller.dart
      presentation/screens/{splash,language,login,register,forgot_pin,home_placeholder}_screen.dart
      presentation/widgets/{header_band,primary_button,phone_field,pin_input,choice_pills,failure_message}.dart
  test/
    core/…            theme, envelope, failure, interceptors, jwt, db, localization, redirect
    features/auth/…   validators, usecases, datasources, repository, controller
    widget/…          login + register screen tests, helpers
```

**Why these boundaries:** `core/network` knows HTTP and the envelope but nothing about auth. `features/auth/data` knows auth JSON but not widgets. `features/auth/presentation` knows `AuthRepository` but never Dio. Each layer is independently testable, which is what makes the task decomposition below hold.

**`core/` never imports `features/`.** The dependency runs one way. That is why the JWT and token store live in `core/security/` rather than inside the auth feature: `dioProvider` must read the token to set the `Authorization` header, and if `core/providers` reached into `features/auth/data` for it, core and auth would import each other. Auth-specific wiring lives in `features/auth/auth_providers.dart`.

---

### Task 1: Scaffold the Flutter project and lock the toolchain

Nothing user-visible ships here, but every later task depends on the project existing with the right package id, dependency set and lint config — and on `flutter test` being green so later red tests mean something. Platform config and analyzer setup are folded in: a scaffold that does not analyse clean is not a usable deliverable.

**Files:**
- Create: `mobile/` (whole `flutter create` output)
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/analysis_options.yaml`
- Modify: `mobile/android/app/build.gradle.kts` (or `.gradle` — check which exists)
- Modify: `mobile/ios/Runner/Info.plist`
- Create: `mobile/test/scaffold_test.dart`
- Delete: `mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a `mobile/` package named `libu_care` with every dependency this plan uses already resolved, so no later task runs `flutter pub add` except the two test-only helpers called out in Tasks 5 and 11.

- [ ] **Step 1: Generate the project**

Run from the repo root. `--project-name` sets the Dart package name; the Android `applicationId` is corrected in Step 4.

```bash
cd /c/src/Heart-Care-App
flutter create --org com.libucare --project-name libu_care --platforms=android,ios mobile
```

- [ ] **Step 2: Add dependencies**

Use `flutter pub add` so versions resolve against the installed Flutter 3.44.8 / Dart 3.12.2 rather than pinning numbers that may be stale.

```bash
cd /c/src/Heart-Care-App/mobile
flutter pub add flutter_riverpod riverpod_annotation go_router dio drift sqlite3_flutter_libs path_provider path flutter_secure_storage connectivity_plus easy_localization google_fonts iconsax freezed_annotation json_annotation
flutter pub add --dev build_runner riverpod_generator freezed json_serializable drift_dev mocktail
```

Do **not** add `fl_chart` (vitals slice) or `get_it` (Riverpod is the DI container).

- [ ] **Step 3: Declare assets in `mobile/pubspec.yaml`**

Under the existing `flutter:` key:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/translations/
    - assets/images/
```

Then create the directories so `flutter pub get` does not fail on a missing asset path:

```bash
cd /c/src/Heart-Care-App/mobile
mkdir -p assets/translations assets/images
```

- [ ] **Step 4: Set the package id, minSdk and portrait lock**

Check which Android build file exists:

```bash
ls mobile/android/app/build.gradle.kts mobile/android/app/build.gradle 2>/dev/null
```

In the Kotlin DSL file (`build.gradle.kts`), inside `android { }`:

```kotlin
android {
    namespace = "com.libucare.app"

    defaultConfig {
        applicationId = "com.libucare.app"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}
```

If it is the Groovy file (`build.gradle`), apply the same values with Groovy syntax: `namespace 'com.libucare.app'`, `applicationId "com.libucare.app"`, `minSdk 21`.

In `mobile/ios/Runner/Info.plist`, restrict orientation to portrait:

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
```

Android's runtime portrait lock is applied in code in Task 11 (`SystemChrome.setPreferredOrientations`) so it holds on both platforms from one place.

- [ ] **Step 5: Tighten the analyzer**

Replace `mobile/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - prefer_const_constructors
    - prefer_final_locals
    - avoid_print
    - always_declare_return_types
```

- [ ] **Step 6: Write the scaffold test**

Delete the generated widget test (it references the counter app removed in Task 11) and add a trivial one so the runner has something green:

```bash
cd /c/src/Heart-Care-App/mobile
rm test/widget_test.dart
```

Create `mobile/test/scaffold_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toolchain is wired up and the test runner executes', () {
    expect(2 + 2, 4);
  });
}
```

- [ ] **Step 7: Verify the project analyses and tests clean**

```bash
cd /c/src/Heart-Care-App/mobile
flutter analyze
flutter test
```

Expected: `No issues found!` and `All tests passed!`. Fix any analyzer issue in generated Android/iOS files now — every later task gates on a clean analyze.

- [ ] **Step 8: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/ .gitignore
git commit -m "chore(mobile): scaffold Flutter app with core dependency set"
```

---

### Task 2: Theme — exact Figma tokens, Poppins, and the Amharic fallback

The palette and type scale are contractual (see Global Constraints). This task makes them the single source of truth in code so no screen writes a raw hex. It also solves a problem the Figma file hides: **the design contains no Amharic text at all** — Screen 2 labels the option `"Amharic"` in Latin — so nothing in the design proves Poppins can render `አማርኛ`. It cannot. Without a fallback, every Amharic string renders as tofu boxes.

**Files:**
- Create: `mobile/lib/core/theme/app_colors.dart`
- Create: `mobile/lib/core/theme/app_spacing.dart`
- Create: `mobile/lib/core/theme/app_typography.dart`
- Create: `mobile/lib/core/theme/app_theme.dart`
- Test: `mobile/test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppColors` (static `Color` fields, names exactly as in the Global Constraints table), `AppSpacing.gutter/fieldHeight/fieldRadius/buttonHeight/buttonRadius/headerBandHeight` plus `xs…xxl`, `AppTypography.textTheme(String languageCode) → TextTheme`, `AppTheme.light(String languageCode) → ThemeData`.

- [ ] **Step 1: Write the failing theme test**

Create `mobile/test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/theme/app_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AppColors', () {
    test('carries the exact Figma palette', () {
      expect(AppColors.primary, const Color(0xFFFCAB10));
      expect(AppColors.accent, const Color(0xFF1D4ED8));
      expect(AppColors.critical, const Color(0xFFDC2626));
      expect(AppColors.ink, const Color(0xFF282A2A));
      expect(AppColors.textSecondary, const Color(0xFF6B7280));
      expect(AppColors.textTertiary, const Color(0xFF9CA3AF));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.headerBand, const Color(0xFFDBD5B5));
      expect(AppColors.border, const Color(0xFFEAEDF1));
    });
  });

  group('AppTheme', () {
    test('uses the brand amber as the primary colour', () {
      final theme = AppTheme.light('en');
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.scaffoldBackgroundColor, AppColors.surface);
    });

    test('English uses Poppins', () {
      final theme = AppTheme.light('en');
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Poppins'));
    });

    test('Amharic falls back to an Ethiopic-capable family, because Poppins '
        'has no Ethiopic glyphs', () {
      final theme = AppTheme.light('am');
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Noto'));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/theme/app_theme_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:libu_care/core/theme/app_colors.dart'`.

- [ ] **Step 3: Colour-pick the two vector fills, then write the colour tokens**

Open the Login frame render (from `get_design_context` on `368:680`, or `get_screenshot` at `maxDimension: 2048`). With a colour picker, sample:
- the cream **header band** behind the logo → compare to `#DBD5B5`
- the amber **"Sign in" button** fill → compare to `#FCAB10`

If either differs, use the sampled value in the file below **and** update the palette table in Global Constraints so the record stays honest.

Create `mobile/lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// The Libu Care palette, read from Figma file `2ulgCN3pghwu6g4bzzi4mw`
/// ("Capstone", section "LibuCare - Main Design"). The file has no variables,
/// so text-layer colours were read directly and the two flattened vector fills
/// (header band, primary button) were colour-picked from the rendered frame.
///
/// These values are contractual: the design agreement is that colours and
/// fonts match exactly while layout is the implementer's latitude. Never write
/// a raw hex anywhere else in the app.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFFCAB10);
  static const Color accent = Color(0xFF1D4ED8);

  // Clinical status (defined now, first used in later slices)
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color critical = Color(0xFFDC2626);

  // Text
  static const Color ink = Color(0xFF282A2A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5F6F8);
  static const Color headerBand = Color(0xFFDBD5B5);

  // Lines
  static const Color border = Color(0xFFEAEDF1);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // Chip / banner backgrounds
  static const Color accentBg = Color(0xFFE8F0FE);
  static const Color criticalBg = Color(0xFFFEE2E2);
}
```

- [ ] **Step 4: Write the spacing tokens**

Create `mobile/lib/core/theme/app_spacing.dart`. Values measured off the 402-px frames (fields sit at a ~30-px gutter; the primary button is a tall rounded pill).

```dart
/// Geometry measured from the Figma frames. A 402-pt-wide design with a ~30-pt
/// gutter gives a ~342-pt content column.
abstract final class AppSpacing {
  static const double gutter = 30;
  static const double fieldHeight = 52;
  static const double fieldRadius = 24;
  static const double buttonHeight = 52;
  static const double buttonRadius = 24;
  static const double headerBandHeight = 215;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
```

- [ ] **Step 5: Write the typography**

Create `mobile/lib/core/theme/app_typography.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Poppins is the design font, but it ships **no Ethiopic glyphs** — Amharic
/// text rendered in Poppins comes out as tofu. The Figma file never exposed
/// this because it labels the language option "Amharic" in Latin script.
///
/// So: Latin locales get Poppins exactly as designed; the Amharic locale gets
/// Noto Sans Ethiopic. This is an addition for a script the design font cannot
/// draw, not a substitution of the design font.
abstract final class AppTypography {
  static TextTheme textTheme(String languageCode) {
    final TextTheme base = languageCode == 'am'
        ? GoogleFonts.notoSansEthiopicTextTheme()
        : GoogleFonts.poppinsTextTheme();

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
          fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineLarge: base.headlineLarge?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
      titleMedium: base.titleMedium?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.ink),
      bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodySmall: base.bodySmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelSmall: base.labelSmall?.copyWith(
          fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary),
    );
  }
}
```

- [ ] **Step 6: Assemble the theme**

Create `mobile/lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light(String languageCode) {
    final TextTheme text = AppTypography.textTheme(languageCode);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: text,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.critical,
        surface: AppColors.surface,
        onPrimary: AppColors.surface,
        onSurface: AppColors.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: text.titleMedium?.copyWith(color: AppColors.surface),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          side: const BorderSide(color: AppColors.ink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: text.titleMedium,
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/theme/app_theme_test.dart
```

Expected: PASS, 5 tests. `google_fonts` fetches font files over the network on first use; in `flutter test` it falls back to the bundled default and still reports the requested family name, so these assertions hold offline.

- [ ] **Step 8: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/theme mobile/test/core/theme
git commit -m "feat(mobile): add Figma colour, spacing and type tokens with Amharic fallback"
```

---

### Task 3: Config, the response envelope, and the failure hierarchy

Everything that talks to the backend needs three things first: where the server is, how to unwrap `{success, data, message, timestamp}`, and a vocabulary of failures the UI can switch on. Grouped into one task because the envelope is meaningless without the failures it produces.

**Files:**
- Create: `mobile/lib/core/config/env.dart`
- Create: `mobile/lib/core/constants/api_endpoints.dart`
- Create: `mobile/lib/core/network/api_response.dart`
- Create: `mobile/lib/core/error/failure.dart`
- Test: `mobile/test/core/network/api_response_test.dart`
- Test: `mobile/test/core/error/failure_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Env.apiBaseUrl → String`
  - `ApiEndpoints.register/login/me → String` (paths relative to the base URL)
  - `ApiResponse<T>.fromJson(Map<String, dynamic>, T Function(Object?))` with fields `success`, `data`, `message`, `timestamp`
  - sealed `Failure` with subclasses `NetworkFailure`, `ValidationFailure`, `InvalidCredentialsFailure`, `AccountLockedFailure({int? minutesRemaining})`, `PhoneAlreadyRegisteredFailure`, `SessionExpiredFailure`, `ServerFailure`, `UnknownFailure` — all carrying `message`
  - `int? parseLockoutMinutes(String)`

- [ ] **Step 1: Write the failing envelope and failure tests**

Create `mobile/test/core/network/api_response_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/network/api_response.dart';

void main() {
  group('ApiResponse', () {
    test('unwraps a successful payload', () {
      final json = {
        'success': true,
        'data': {'id': '3f2a9c1e', 'name': 'Abebe Bekele'},
        'message': 'OK',
        'timestamp': '2026-08-06T10:00:00Z',
      };

      final res = ApiResponse.fromJson(
        json,
        (d) => (d! as Map<String, dynamic>)['name'] as String,
      );

      expect(res.success, isTrue);
      expect(res.data, 'Abebe Bekele');
      expect(res.message, 'OK');
      expect(res.timestamp, DateTime.utc(2026, 8, 6, 10));
    });

    test('handles the error envelope, where data is null', () {
      final json = {
        'success': false,
        'data': null,
        'message': 'Invalid phone or PIN',
        'timestamp': '2026-08-06T10:00:00Z',
      };

      final res = ApiResponse.fromJson(json, (d) => d);

      expect(res.success, isFalse);
      expect(res.data, isNull);
      expect(res.message, 'Invalid phone or PIN');
    });

    test('survives a malformed timestamp rather than throwing', () {
      final res = ApiResponse.fromJson(
        {'success': true, 'data': null, 'message': 'OK', 'timestamp': 'not-a-date'},
        (d) => d,
      );
      expect(res.timestamp, isNull);
    });
  });
}
```

Create `mobile/test/core/error/failure_test.dart`. The lockout parser is the interesting case — the API documents the message is **singular on the final minute**, so a naive `"minutes"` match silently fails exactly when the user is closest to getting back in:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';

void main() {
  group('parseLockoutMinutes', () {
    test('reads the plural form', () {
      expect(
        parseLockoutMinutes('Too many failed attempts. Try again in 15 minutes.'),
        15,
      );
    });

    test('reads the singular form on the final minute', () {
      expect(
        parseLockoutMinutes('Too many failed attempts. Try again in 1 minute.'),
        1,
      );
    });

    test('returns null when the message carries no duration', () {
      expect(parseLockoutMinutes('Account locked.'), isNull);
    });
  });

  group('Failure', () {
    test('AccountLockedFailure carries the remaining minutes', () {
      const f = AccountLockedFailure('Try again in 4 minutes.', minutesRemaining: 4);
      expect(f.minutesRemaining, 4);
      expect(f, isA<Failure>());
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/network/api_response_test.dart test/core/error/failure_test.dart
```

Expected: FAIL — both URIs don't exist.

- [ ] **Step 3: Write the config and endpoints**

Create `mobile/lib/core/config/env.dart`:

```dart
/// Compile-time configuration.
///
/// Supply a real host with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
///
/// The default targets the Android emulator's alias for the host machine's
/// localhost, which is where `mvn spring-boot:run` serves the backend.
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
```

Create `mobile/lib/core/constants/api_endpoints.dart`. Per architectural rule 4 this is the **only** file in the app allowed to contain a URL path:

```dart
/// Every API path in the app. Nothing else may hardcode a URL.
abstract final class ApiEndpoints {
  static const String _v1 = '/api/v1';

  // Auth
  static const String register = '$_v1/auth/register';
  static const String login = '$_v1/auth/login';
  static const String me = '$_v1/auth/me';
}
```

- [ ] **Step 4: Write the envelope**

Create `mobile/lib/core/network/api_response.dart`:

```dart
/// The envelope every Heart-Care endpoint returns, success or error:
/// `{ "success": bool, "data": T|null, "message": string, "timestamp": string }`.
///
/// The API returns **200 for creates as well** — there is no 201 anywhere — so
/// callers must never treat 201 as the success case.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.data,
    required this.message,
    required this.timestamp,
  });

  final bool success;
  final T? data;
  final String message;
  final DateTime? timestamp;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) fromData,
  ) {
    final Object? raw = json['data'];
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: raw == null ? null : fromData(raw),
      message: json['message'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}
```

- [ ] **Step 5: Write the failure hierarchy**

Create `mobile/lib/core/error/failure.dart`:

```dart
/// Everything the UI needs to know about a request that did not succeed.
///
/// Repositories throw these; Riverpod's `AsyncValue.guard` captures them into
/// `AsyncError`, and screens switch on the subtype. Deliberately a sealed class
/// so a missed case is a compile error rather than a silent fallthrough.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// No usable connection, or the request timed out. Retryable.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// 400 — the server rejected the body. `message` is `field: reason` pairs
/// joined by `; ` and sorted.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// 401 on login — deliberately identical for an unknown phone and a wrong PIN.
final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure(super.message);
}

/// 423 — five consecutive failures locked the account for 15 minutes.
/// Must be surfaced as "wait", never as "wrong PIN", and must not be retried
/// on a timer.
final class AccountLockedFailure extends Failure {
  const AccountLockedFailure(super.message, {this.minutesRemaining});
  final int? minutesRemaining;
}

/// 409 on register.
final class PhoneAlreadyRegisteredFailure extends Failure {
  const PhoneAlreadyRegisteredFailure(super.message);
}

/// 401 on an authenticated call — the 7-day token expired or was rejected.
/// There is no refresh endpoint, so the only cure is signing in again.
final class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure(super.message);
}

/// 500 — the only transient server condition worth retrying.
final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

final RegExp _lockoutPattern = RegExp(r'(\d+)\s+minute');

/// Pulls the remaining minutes out of a 423 message.
///
/// The API sends "Try again in 15 minutes." but switches to the singular
/// "Try again in 1 minute." on the final minute — matching on "minutes"
/// would break exactly when the user is one minute from getting back in.
int? parseLockoutMinutes(String message) {
  final RegExpMatch? match = _lockoutPattern.firstMatch(message);
  return match == null ? null : int.tryParse(match.group(1)!);
}
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/network/api_response_test.dart test/core/error/failure_test.dart
```

Expected: PASS, 7 tests.

- [ ] **Step 7: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core mobile/test/core
git commit -m "feat(mobile): add env config, response envelope and failure types"
```

---

### Task 4: Dio client, bearer token, and failure mapping

Turns the envelope and failure types into an HTTP client the rest of the app can use. One interceptor attaches the bearer token; a single pure function maps every HTTP status onto the `Failure` vocabulary.

**Files:**
- Create: `mobile/lib/core/network/interceptors/auth_token_interceptor.dart`
- Create: `mobile/lib/core/network/dio_client.dart`
- Test: `mobile/test/core/network/failure_mapping_test.dart`
- Test: `mobile/test/core/network/auth_token_interceptor_test.dart`

**Interfaces:**
- Consumes: `Failure` + `parseLockoutMinutes` (Task 3).
- Produces:
  - `AuthTokenInterceptor(Future<String?> Function() readToken)`
  - `Dio buildDio({required String baseUrl, required Future<String?> Function() readToken})`
  - `Failure failureFromDioException(DioException)` — the single HTTP-status → `Failure` mapping, called by repositories

> **There is deliberately no `ErrorMappingInterceptor`.** The design doc §3.4 describes error mapping as an interceptor, but an interceptor that classifies an error and re-throws it adds a class without adding behaviour — the repository still has to catch and unwrap. `failureFromDioException` keeps the mapping in exactly one place, which is what §3.4 is actually asking for. (Recorded as a deliberate deviation in Self-Review.)

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/core/network/failure_mapping_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/network/dio_client.dart';

/// Serves a fixed status + envelope so the mapping can be exercised
/// without a live server.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int status, String message) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = _StubAdapter(status, {
    'success': false,
    'data': null,
    'message': message,
    'timestamp': '2026-09-03T10:00:00Z',
  });
  return dio;
}

Future<Failure> _failureFrom(int status, String message) async {
  try {
    await _dioReturning(status, message).get<dynamic>('/anything');
    fail('expected the request to throw');
  } on DioException catch (e) {
    return failureFromDioException(e);
  }
}

void main() {
  test('400 becomes a ValidationFailure carrying the server message', () async {
    final f = await _failureFrom(400, 'pin: PIN must be exactly 4 digits');
    expect(f, isA<ValidationFailure>());
    expect(f.message, 'pin: PIN must be exactly 4 digits');
  });

  test('401 becomes InvalidCredentialsFailure', () async {
    final f = await _failureFrom(401, 'Invalid phone or PIN');
    expect(f, isA<InvalidCredentialsFailure>());
  });

  test('409 becomes PhoneAlreadyRegisteredFailure', () async {
    final f = await _failureFrom(409, 'Phone already registered');
    expect(f, isA<PhoneAlreadyRegisteredFailure>());
  });

  test('423 becomes AccountLockedFailure with the minutes parsed out', () async {
    final f = await _failureFrom(
        423, 'Too many failed attempts. Try again in 12 minutes.');
    expect(f, isA<AccountLockedFailure>());
    expect((f as AccountLockedFailure).minutesRemaining, 12);
  });

  test('423 on the final minute still parses, despite the singular noun', () async {
    final f = await _failureFrom(
        423, 'Too many failed attempts. Try again in 1 minute.');
    expect((f as AccountLockedFailure).minutesRemaining, 1);
  });

  test('500 becomes ServerFailure', () async {
    final f = await _failureFrom(500, 'An unexpected error occurred');
    expect(f, isA<ServerFailure>());
  });

  test('a connection error becomes NetworkFailure', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    );
    expect(failureFromDioException(e), isA<NetworkFailure>());
  });

  test('a timeout becomes NetworkFailure', () {
    final e = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.receiveTimeout,
    );
    expect(failureFromDioException(e), isA<NetworkFailure>());
  });
}
```

Create `mobile/test/core/network/auth_token_interceptor_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/network/interceptors/auth_token_interceptor.dart';

void main() {
  Future<RequestOptions> capture({required String? token}) async {
    final interceptor = AuthTokenInterceptor(() async => token);
    final options = RequestOptions(path: '/api/v1/auth/me');
    interceptor.onRequest(options, RequestInterceptorHandler());
    return options;
  }

  test('attaches the bearer token when one is stored', () async {
    final options = await capture(token: 'jwt-abc');
    expect(options.headers['Authorization'], 'Bearer jwt-abc');
  });

  test('sends no Authorization header when there is no token', () async {
    final options = await capture(token: null);
    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/network/
```

Expected: FAIL — the interceptor and `dio_client` URIs don't exist.

- [ ] **Step 3: Write the auth token interceptor**

Create `mobile/lib/core/network/interceptors/auth_token_interceptor.dart`:

```dart
import 'package:dio/dio.dart';

/// Attaches the stored JWT to every outgoing request.
///
/// Takes a reader function rather than the storage object so `core/network`
/// stays ignorant of where the token lives — the auth feature owns that.
class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this._readToken);

  final Future<String?> Function() _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token = await _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

- [ ] **Step 4: Write the Dio factory and the failure mapper**

Create `mobile/lib/core/network/dio_client.dart`:

```dart
import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'interceptors/auth_token_interceptor.dart';

/// Builds the app's single configured Dio instance.
///
/// Timeouts are deliberately generous: the target deployment is intermittent
/// Ethiopian mobile data, where a 5-second timeout would fail requests that
/// would otherwise have succeeded.
Dio buildDio({
  required String baseUrl,
  required Future<String?> Function() readToken,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      // Let 4xx through to the mapper rather than having Dio throw its own
      // opaque error before we can read the envelope.
      validateStatus: (int? status) => status != null && status < 400,
    ),
  );

  dio.interceptors.add(AuthTokenInterceptor(readToken));
  return dio;
}

const String _offlineMessage = 'errors.offline';

/// The single place that knows how an HTTP status becomes a `Failure`.
Failure failureFromDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure(_offlineMessage);
    case DioExceptionType.cancel:
      return const UnknownFailure('Request cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('errors.secureConnection');
    case DioExceptionType.unknown:
    case DioExceptionType.badResponse:
      break;
  }

  if (e.response == null) return const NetworkFailure(_offlineMessage);

  final Response<dynamic>? response = e.response;
  final int status = response?.statusCode ?? 0;
  final String message = _messageFrom(response);

  return switch (status) {
    400 => ValidationFailure(message),
    401 => InvalidCredentialsFailure(message),
    404 => UnknownFailure(message),
    409 => PhoneAlreadyRegisteredFailure(message),
    413 => ValidationFailure(message),
    423 => AccountLockedFailure(message,
        minutesRemaining: parseLockoutMinutes(message)),
    >= 500 => ServerFailure(message),
    _ => UnknownFailure(message),
  };
}

/// Pulls `message` out of the standard envelope, falling back to a translation
/// key if the body is not the shape we expect.
String _messageFrom(Response<dynamic>? response) {
  final dynamic data = response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return 'errors.generic';
}
```

> **Why `401` maps to `InvalidCredentialsFailure` rather than `SessionExpiredFailure`:** the status alone cannot tell them apart — a bad PIN and an expired token both return `401`. The auth repository resolves the ambiguity by context (Task 8): a `401` from `login` is bad credentials, a `401` from `me` is an expired session.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/network/
```

Expected: PASS, 10 tests.

- [ ] **Step 6: Run the full suite and analyze**

```bash
cd /c/src/Heart-Care-App/mobile
flutter analyze
flutter test
```

Expected: `No issues found!` and all tests passing.

- [ ] **Step 7: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/network mobile/test/core/network
git commit -m "feat(mobile): add Dio client with bearer-token interceptor and failure mapping"
```

---

### Task 5: Drift database — cached user and preferences

The offline auth gate needs two things on disk: the user record (so the app opens to a greeting with no network) and the first-run language choice. Per `CLAUDE.md` the local datasource is the source of truth, so both live in Drift.

**Files:**
- Create: `mobile/lib/core/db/app_database.dart`
- Create: `mobile/lib/core/db/daos/cached_user_dao.dart`
- Create: `mobile/lib/core/db/daos/preferences_dao.dart`
- Test: `mobile/test/core/db/app_database_test.dart`
- Modify: `mobile/pubspec.yaml` (adds the test-only `sqlite3` dep)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `AppDatabase(QueryExecutor)` with tables `CachedUsers` and `Preferences`, exposing `cachedUserDao` and `preferencesDao`
  - `CachedUserDao.save(CachedUsersCompanion)`, `.current() → Future<CachedUser?>`, `.clear()`
  - `PreferencesDao.get(String) → Future<String?>`, `.set(String, String)`, `.remove(String)`
  - `PreferenceKeys.language = 'language'`, `PreferenceKeys.languageChosen = 'language_chosen'`
  - `QueryExecutor openDatabaseConnection()` — used by the app; tests pass `NativeDatabase.memory()`

- [ ] **Step 1: Add the test-only sqlite dependency**

Drift's `NativeDatabase.memory()` needs a sqlite3 binary in the Dart VM (the app gets one from `sqlite3_flutter_libs`; the test runner does not):

```bash
cd /c/src/Heart-Care-App/mobile
flutter pub add --dev sqlite3
```

> **On Windows**, if tests fail with `Failed to load dynamic library 'sqlite3.dll'`, download the sqlite3 DLL bundle from sqlite.org and place `sqlite3.dll` beside the project root or anywhere on `PATH`. This affects the test runner only — the shipped app uses the bundled library.

- [ ] **Step 2: Write the failing database test**

Create `mobile/test/core/db/app_database_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('CachedUserDao', () {
    test('returns null before anything is cached', () async {
      expect(await db.cachedUserDao.current(), isNull);
    });

    test('round-trips the cached user', () async {
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b'),
        name: Value('Abebe Bekele'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('am'),
        role: Value('PATIENT'),
      ));

      final user = await db.cachedUserDao.current();
      expect(user!.name, 'Abebe Bekele');
      expect(user.phone, '+251911234567');
      expect(user.preferredLanguage, 'am');
    });

    test('save replaces rather than accumulates', () async {
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('user-1'), name: Value('First'), phone: Value('+251911111111'),
        preferredLanguage: Value('en'), role: Value('PATIENT'),
      ));
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('user-2'), name: Value('Second'), phone: Value('+251922222222'),
        preferredLanguage: Value('en'), role: Value('PATIENT'),
      ));

      expect(await db.select(db.cachedUsers).get(), hasLength(1));
      expect((await db.cachedUserDao.current())!.name, 'Second');
    });

    test('clear empties the cache on logout', () async {
      await db.cachedUserDao.save(const CachedUsersCompanion(
        id: Value('user-1'), name: Value('First'), phone: Value('+251911111111'),
        preferredLanguage: Value('en'), role: Value('PATIENT'),
      ));
      await db.cachedUserDao.clear();
      expect(await db.cachedUserDao.current(), isNull);
    });
  });

  group('PreferencesDao', () {
    test('returns null for an unset key', () async {
      expect(await db.preferencesDao.get(PreferenceKeys.language), isNull);
    });

    test('round-trips and overwrites a preference', () async {
      await db.preferencesDao.set(PreferenceKeys.language, 'en');
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'en');
      await db.preferencesDao.set(PreferenceKeys.language, 'am');
      expect(await db.preferencesDao.get(PreferenceKeys.language), 'am');
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/db/app_database_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:libu_care/core/db/app_database.dart'`.

- [ ] **Step 4: Write the database**

Create `mobile/lib/core/db/app_database.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cached_user_dao.dart';
import 'daos/preferences_dao.dart';

part 'app_database.g.dart';

/// The signed-in user, cached so the app can open to a greeting with no
/// network. Exactly one row is ever present — see [CachedUserDao.save].
class CachedUsers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get preferredLanguage => text()();
  TextColumn get role => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Small key/value store for device-local settings. The language choice lives
/// here because it is device state, not a secret and not server-owned.
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

abstract final class PreferenceKeys {
  static const String language = 'language';
  static const String languageChosen = 'language_chosen';
}

@DriftDatabase(
  tables: <Type>[CachedUsers, Preferences],
  daos: <Type>[CachedUserDao, PreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

/// Opens the on-device database file. Tests pass `NativeDatabase.memory()` to
/// the constructor instead.
QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return NativeDatabase(File(p.join(dir.path, 'libu_care.sqlite')));
  });
}
```

Create `mobile/lib/core/db/daos/cached_user_dao.dart`:

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';

part 'cached_user_dao.g.dart';

@DriftAccessor(tables: <Type>[CachedUsers])
class CachedUserDao extends DatabaseAccessor<AppDatabase>
    with _$CachedUserDaoMixin {
  CachedUserDao(super.db);

  /// Replaces the cache wholesale. This device serves one patient, so a second
  /// user row would be a bug — signing in as someone else must not leave the
  /// previous user's record behind.
  Future<void> save(CachedUsersCompanion user) async {
    await transaction(() async {
      await delete(cachedUsers).go();
      await into(cachedUsers).insert(user);
    });
  }

  Future<CachedUser?> current() =>
      (select(cachedUsers)..limit(1)).getSingleOrNull();

  Future<void> clear() => delete(cachedUsers).go();
}
```

Create `mobile/lib/core/db/daos/preferences_dao.dart`:

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';

part 'preferences_dao.g.dart';

@DriftAccessor(tables: <Type>[Preferences])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(preferences)
          ..where(($PreferencesTable t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) => (delete(preferences)
        ..where(($PreferencesTable t) => t.key.equals(key)))
      .go();
}
```

- [ ] **Step 5: Generate the Drift code**

```bash
cd /c/src/Heart-Care-App/mobile
dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_database.g.dart`, `cached_user_dao.g.dart`, `preferences_dao.g.dart` written. They are **gitignored** and will not appear in `git status` — expected.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/db/app_database_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 7: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/db mobile/test/core/db mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(mobile): add Drift database with cached user and preferences"
```

---

### Task 6: Localization — EN / አማርኛ

Translation files plus the device-local language store. Both auth screens, the first-run picker and the Home placeholder read from here.

**Files:**
- Create: `mobile/assets/translations/en.json`
- Create: `mobile/assets/translations/am.json`
- Create: `mobile/lib/core/localization/language.dart`
- Test: `mobile/test/core/localization/language_test.dart`

**Interfaces:**
- Consumes: `PreferencesDao`, `PreferenceKeys` (Task 5).
- Produces:
  - `enum AppLanguage { en, am }` with `.code` (`'en'`/`'am'`), `.locale` (`Locale`), `.nativeLabel`, and `static AppLanguage? fromCode(String?)`
  - `LanguageStore(PreferencesDao)` with `.read() → Future<AppLanguage?>`, `.write(AppLanguage) → Future<void>`, `.hasChosen() → Future<bool>`

- [ ] **Step 1: Write the failing language test**

Create `mobile/test/core/localization/language_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';

void main() {
  late AppDatabase db;
  late LanguageStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LanguageStore(db.preferencesDao);
  });
  tearDown(() => db.close());

  group('AppLanguage', () {
    test('maps to the two-letter codes the API accepts', () {
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.am.code, 'am');
    });

    test('parses a stored code, null when unrecognised', () {
      expect(AppLanguage.fromCode('am'), AppLanguage.am);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('fr'), isNull);
      expect(AppLanguage.fromCode(null), isNull);
    });

    test('labels each language in its own script', () {
      expect(AppLanguage.en.nativeLabel, 'English');
      expect(AppLanguage.am.nativeLabel, 'አማርኛ');
    });
  });

  group('LanguageStore', () {
    test('reports no choice before first run completes', () async {
      expect(await store.hasChosen(), isFalse);
      expect(await store.read(), isNull);
    });

    test('persists the chosen language across reads', () async {
      await store.write(AppLanguage.am);
      expect(await store.read(), AppLanguage.am);
      expect(await store.hasChosen(), isTrue);
    });

    test('a later choice overwrites the earlier one', () async {
      await store.write(AppLanguage.am);
      await store.write(AppLanguage.en);
      expect(await store.read(), AppLanguage.en);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/localization/language_test.dart
```

Expected: FAIL — `language.dart` does not exist.

- [ ] **Step 3: Write the language model and store**

Create `mobile/lib/core/localization/language.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../db/daos/preferences_dao.dart';
import '../db/app_database.dart';

/// The two languages the app ships. The codes match exactly what
/// `POST /auth/register` accepts for `preferredLanguage` — do not add a value
/// here without a matching backend change.
enum AppLanguage {
  en('en', 'English'),
  am('am', 'አማርኛ');

  const AppLanguage(this.code, this.nativeLabel);

  final String code;

  /// Each language named in its own script — the standard for a picker shown
  /// before the user has told us which one they read.
  final String nativeLabel;

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? code) {
    for (final AppLanguage l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// Device-local language persistence.
///
/// This slice deliberately does not push the language to the server after
/// registration: `users.preferred_language` has no update endpoint, and there
/// is no post-login settings screen here for it to diverge from. Ownership of
/// that column is settled in the patient-profile slice.
class LanguageStore {
  const LanguageStore(this._prefs);

  final PreferencesDao _prefs;

  Future<AppLanguage?> read() async =>
      AppLanguage.fromCode(await _prefs.get(PreferenceKeys.language));

  Future<void> write(AppLanguage language) async {
    await _prefs.set(PreferenceKeys.language, language.code);
    await _prefs.set(PreferenceKeys.languageChosen, 'true');
  }

  Future<bool> hasChosen() async =>
      await _prefs.get(PreferenceKeys.languageChosen) == 'true';
}
```

- [ ] **Step 4: Write the translation files**

Create `mobile/assets/translations/en.json`:

```json
{
  "app": { "name": "Libu Care", "tagline": "Heart health care" },
  "language": {
    "title": "Choose your language",
    "subtitle": "You can change this later",
    "continue": "Continue"
  },
  "login": {
    "title": "Welcome back",
    "subtitle": "Sign in to continue",
    "phone": "Phone number",
    "phoneHint": "+251 9__ __ __",
    "pin": "4-digit PIN",
    "pinHint": "• • • •",
    "submit": "Sign in",
    "or": "or",
    "createAccount": "Create account",
    "forgotPin": "Forgot PIN?",
    "language": "Language: English · Amharic",
    "worksOffline": "Works offline"
  },
  "register": {
    "title": "Create account",
    "subtitle": "Takes less than a minute",
    "name": "Full name",
    "nameHint": "Abebe Girma",
    "pin": "4-digit PIN",
    "confirmPin": "Confirm PIN",
    "preferredLanguage": "Preferred language",
    "submit": "Create account",
    "haveAccount": "Already have an account?",
    "signIn": "Sign in"
  },
  "forgotPin": {
    "title": "Forgot your PIN?",
    "body": "For your security, a PIN cannot be reset inside the app yet.\n\nPlease contact your clinic to have your account restored. They can verify your identity and help you get back in.\n\nIf you entered the wrong PIN five times, your account is locked for 15 minutes. Nothing is lost — just wait and try again.",
    "back": "Back to sign in"
  },
  "home": { "greeting": "Hello, {name}", "signOut": "Sign out" },
  "errors": {
    "phoneRequired": "Enter your phone number",
    "phoneFormat": "Enter a phone number as +251 followed by 9 digits",
    "pinRequired": "Enter your 4-digit PIN",
    "pinFormat": "Your PIN must be exactly 4 digits",
    "pinMismatch": "The two PINs do not match",
    "nameRequired": "Enter your name",
    "offline": "You need a connection to sign in the first time",
    "secureConnection": "Could not make a secure connection. Try again.",
    "locked": "Too many attempts. Try again in {minutes} min.",
    "lockedNoTime": "Too many attempts. Please wait and try again.",
    "invalidCredentials": "Invalid phone or PIN",
    "phoneTaken": "That phone number is already registered",
    "generic": "Something went wrong. Please try again."
  }
}
```

Create `mobile/assets/translations/am.json` with the same keys and Amharic values:

```json
{
  "app": { "name": "ልቡ ኬር", "tagline": "የልብ ጤና እንክብካቤ" },
  "language": {
    "title": "ቋንቋዎን ይምረጡ",
    "subtitle": "ይህንን በኋላ መቀየር ይችላሉ",
    "continue": "ቀጥል"
  },
  "login": {
    "title": "እንኳን ደህና መጡ",
    "subtitle": "ለመቀጠል ይግቡ",
    "phone": "የስልክ ቁጥር",
    "phoneHint": "+251 9__ __ __",
    "pin": "የ4  አኃዝ ፒን",
    "pinHint": "• • • •",
    "submit": "ግባ",
    "or": "ወይም",
    "createAccount": "መለያ ይክፈቱ",
    "forgotPin": "ፒን ረሱ?",
    "language": "ቋንቋ፦ እንግሊዝኛ · አማርኛ",
    "worksOffline": "ከመስመር ውጭ ይሰራል"
  },
  "register": {
    "title": "መለያ ይክፈቱ",
    "subtitle": "ከአንድ ደቂቃ ያነሰ ጊዜ ይወስዳል",
    "name": "ሙሉ ስም",
    "nameHint": "አበበ ግርማ",
    "pin": "የ4 አኃዝ ፒን",
    "confirmPin": "ፒን ያረጋግጡ",
    "preferredLanguage": "የሚመርጡት ቋንቋ",
    "submit": "መለያ ይክፈቱ",
    "haveAccount": "መለያ አለዎት?",
    "signIn": "ግባ"
  },
  "forgotPin": {
    "title": "ፒንዎን ረሱ?",
    "body": "ለደህንነትዎ ሲባል፣ ፒን በአፕሊኬሽኑ ውስጥ ገና እንደገና ማስጀመር አይቻልም።\n\nመለያዎ እንዲመለስ እባክዎ ክሊኒክዎን ያግኙ። ማንነትዎን አረጋግጠው እንዲገቡ ይረዱዎታል።\n\nየተሳሳተ ፒን አምስት ጊዜ ካስገቡ፣ መለያዎ ለ15 ደቂቃ ይቆለፋል። ምንም አይጠፋም — ትንሽ ጠብቀው እንደገና ይሞክሩ።",
    "back": "ወደ መግቢያ ተመለስ"
  },
  "home": { "greeting": "ሰላም፣ {name}", "signOut": "ውጣ" },
  "errors": {
    "phoneRequired": "የስልክ ቁጥርዎን ያስገቡ",
    "phoneFormat": "ስልክ ቁጥር +251 ተከትሎ 9 አኃዞች ያስገቡ",
    "pinRequired": "የ4 አኃዝ ፒንዎን ያስገቡ",
    "pinFormat": "ፒንዎ በትክክል 4 አኃዞች መሆን አለበት",
    "pinMismatch": "ሁለቱ ፒኖች አይመሳሰሉም",
    "nameRequired": "ስምዎን ያስገቡ",
    "offline": "ለመጀመሪያ ጊዜ ለመግባት ግንኙነት ያስፈልጋል",
    "secureConnection": "ደህንነቱ የተጠበቀ ግንኙነት ማድረግ አልተቻለም። እንደገና ይሞክሩ።",
    "locked": "ብዙ ሙከራዎች። በ{minutes} ደቂቃ ውስጥ እንደገና ይሞክሩ።",
    "lockedNoTime": "ብዙ ሙከራዎች። እባክዎ ጠብቀው እንደገና ይሞክሩ።",
    "invalidCredentials": "የተሳሳተ ስልክ ቁጥር ወይም ፒን",
    "phoneTaken": "ያ የስልክ ቁጥር አስቀድሞ ተመዝግቧል",
    "generic": "የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።"
  }
}
```

> These Amharic strings are a working first pass and **must be reviewed by a native speaker before release** — the same gate that applies to the clinical thresholds. Note this in the PR description.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/localization/language_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/localization mobile/assets/translations mobile/test/core/localization
git commit -m "feat(mobile): add EN/AM translations and device-local language store"
```

---

### Task 7: Auth domain layer

Pure Dart — no Flutter, no Dio, no Drift. Defines what authentication *means* so the data and presentation layers build against a stable contract.

**Files:**
- Create: `mobile/lib/features/auth/domain/entities/auth_user.dart`
- Create: `mobile/lib/features/auth/domain/repositories/auth_repository.dart`
- Create: `mobile/lib/features/auth/domain/validators.dart`
- Create: `mobile/lib/features/auth/domain/usecases/login.dart`
- Create: `mobile/lib/features/auth/domain/usecases/register.dart`
- Create: `mobile/lib/features/auth/domain/usecases/get_me.dart`
- Create: `mobile/lib/features/auth/domain/usecases/logout.dart`
- Test: `mobile/test/features/auth/domain/validators_test.dart`
- Test: `mobile/test/features/auth/domain/usecases_test.dart`

**Interfaces:**
- Consumes: `Failure` (Task 3), `AppLanguage` (Task 6).
- Produces:
  - `AuthUser({required String id, name, phone, preferredLanguage, role})` — immutable, with `==`/`hashCode`
  - `abstract interface class AuthRepository` with `login({required String phone, required String pin}) → Future<AuthUser>`, `register({required String phone, required String pin, required String name, required AppLanguage language}) → Future<AuthUser>`, `getMe() → Future<AuthUser>`, `cachedUser() → Future<AuthUser?>`, `hasValidSession() → Future<bool>`, `logout() → Future<void>`
  - `Login`, `Register`, `GetMe`, `Logout` callable use-case classes (each `const X(AuthRepository)`, `call(...)` delegates)
  - `AuthValidators.phone(String?) → String?`, `.pin(String?) → String?`, `.name(String?) → String?`, `.confirmPin(String? pinValue, String? confirmValue) → String?` — each returns a translation **key** or `null`

- [ ] **Step 1: Write the failing validator and use-case tests**

Create `mobile/test/features/auth/domain/validators_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/validators.dart';

void main() {
  group('phone', () {
    test('accepts +251 followed by exactly 9 digits', () {
      expect(AuthValidators.phone('+251911234567'), isNull);
    });
    test('rejects an empty value', () {
      expect(AuthValidators.phone(''), 'errors.phoneRequired');
      expect(AuthValidators.phone(null), 'errors.phoneRequired');
    });
    test('rejects a local 0-prefixed number', () {
      expect(AuthValidators.phone('0911234567'), 'errors.phoneFormat');
    });
    test('rejects too few and too many digits', () {
      expect(AuthValidators.phone('+25191123456'), 'errors.phoneFormat');
      expect(AuthValidators.phone('+2519112345678'), 'errors.phoneFormat');
    });
    test('rejects a non-Ethiopian country code', () {
      expect(AuthValidators.phone('+254911234567'), 'errors.phoneFormat');
    });
    test('tolerates surrounding whitespace', () {
      expect(AuthValidators.phone('  +251911234567  '), isNull);
    });
  });

  group('pin', () {
    test('accepts exactly four digits', () {
      expect(AuthValidators.pin('1234'), isNull);
      expect(AuthValidators.pin('0000'), isNull);
    });
    test('rejects empty, short, long and non-numeric PINs', () {
      expect(AuthValidators.pin(''), 'errors.pinRequired');
      expect(AuthValidators.pin('123'), 'errors.pinFormat');
      expect(AuthValidators.pin('12345'), 'errors.pinFormat');
      expect(AuthValidators.pin('12a4'), 'errors.pinFormat');
    });
  });

  group('confirmPin', () {
    test('passes when both PINs match', () {
      expect(AuthValidators.confirmPin('1234', '1234'), isNull);
    });
    test('fails when they differ', () {
      expect(AuthValidators.confirmPin('1234', '4321'), 'errors.pinMismatch');
    });
    test('reports the format problem first when the confirm field is itself bad', () {
      expect(AuthValidators.confirmPin('1234', '12'), 'errors.pinFormat');
    });
  });

  group('name', () {
    test('accepts a normal name', () {
      expect(AuthValidators.name('Abebe Bekele'), isNull);
    });
    test('rejects blank and whitespace-only names', () {
      expect(AuthValidators.name(''), 'errors.nameRequired');
      expect(AuthValidators.name('   '), 'errors.nameRequired');
    });
    test('rejects a name over the server limit of 255', () {
      expect(AuthValidators.name('a' * 256), 'errors.nameRequired');
    });
  });
}
```

Create `mobile/test/features/auth/domain/usecases_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/domain/usecases/get_me.dart';
import 'package:libu_care/features/auth/domain/usecases/login.dart';
import 'package:libu_care/features/auth/domain/usecases/logout.dart';
import 'package:libu_care/features/auth/domain/usecases/register.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _user = AuthUser(
  id: '3f2a9c1e', name: 'Abebe Bekele', phone: '+251911234567',
  preferredLanguage: 'am', role: 'PATIENT',
);

void main() {
  late MockAuthRepository repo;
  setUp(() => repo = MockAuthRepository());

  test('Login delegates to the repository and returns the user', () async {
    when(() => repo.login(phone: '+251911234567', pin: '1234'))
        .thenAnswer((_) async => _user);
    final result = await Login(repo)(phone: '+251911234567', pin: '1234');
    expect(result, _user);
    verify(() => repo.login(phone: '+251911234567', pin: '1234')).called(1);
  });

  test('Login propagates a lockout failure untouched', () async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const AccountLockedFailure('Try again in 15 minutes.',
            minutesRemaining: 15));
    expect(
      () => Login(repo)(phone: '+251911234567', pin: '9999'),
      throwsA(isA<AccountLockedFailure>()),
    );
  });

  test('Register passes the language through', () async {
    when(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        )).thenAnswer((_) async => _user);
    await Register(repo)(
      phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
      language: AppLanguage.am,
    );
    verify(() => repo.register(
          phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
          language: AppLanguage.am,
        )).called(1);
  });

  test('GetMe returns the current user', () async {
    when(() => repo.getMe()).thenAnswer((_) async => _user);
    expect(await GetMe(repo)(), _user);
  });

  test('Logout clears the session', () async {
    when(() => repo.logout()).thenAnswer((_) async {});
    await Logout(repo)();
    verify(() => repo.logout()).called(1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/features/auth/domain/
```

Expected: FAIL — none of the domain URIs exist.

- [ ] **Step 3: Write the entity**

Create `mobile/lib/features/auth/domain/entities/auth_user.dart`:

```dart
/// The authenticated patient, as the app understands them.
///
/// Deliberately free of JSON concerns — `UserModel` in the data layer handles
/// serialisation and maps into this (architectural rule 2: DTOs never leave
/// their feature's data layer).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.preferredLanguage,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final String preferredLanguage;

  /// Always `PATIENT` in this build — the clinician role is out of scope.
  final String role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.name == name &&
          other.phone == phone &&
          other.preferredLanguage == preferredLanguage &&
          other.role == role;

  @override
  int get hashCode => Object.hash(id, name, phone, preferredLanguage, role);
}
```

- [ ] **Step 4: Write the repository interface**

Create `mobile/lib/features/auth/domain/repositories/auth_repository.dart`:

```dart
import '../../../../core/localization/language.dart';
import '../entities/auth_user.dart';

/// The auth feature's only outward contract.
///
/// Every method either returns its value or throws a `Failure` subclass;
/// there is no nullable-error return convention to remember.
abstract interface class AuthRepository {
  /// Requires connectivity. Throws `NetworkFailure` when offline,
  /// `InvalidCredentialsFailure` on a bad PIN, `AccountLockedFailure` on 423.
  Future<AuthUser> login({required String phone, required String pin});

  /// Requires connectivity. Throws `PhoneAlreadyRegisteredFailure` on 409.
  /// Succeeds auto-logged-in: the token is stored before this returns.
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  });

  /// Fetches the user from the server. Throws `SessionExpiredFailure` on 401.
  Future<AuthUser> getMe();

  /// The locally cached user, or null. Never touches the network — this is
  /// what makes an offline launch land on Home.
  Future<AuthUser?> cachedUser();

  /// True when a token is stored and its `exp` has not passed. Checked
  /// locally; the server is not consulted.
  Future<bool> hasValidSession();

  /// Drops the token and the cached user.
  Future<void> logout();
}
```

- [ ] **Step 5: Write the validators**

Create `mobile/lib/features/auth/domain/validators.dart`:

```dart
/// Client-side mirrors of the server's validation rules.
///
/// Each returns a **translation key** or null, so the UI stays responsible for
/// rendering language. Keeping these in sync with the backend matters: the
/// server enforces the same regexes and would answer 400, but on intermittent
/// connectivity a wasted round trip can cost the user a minute.
abstract final class AuthValidators {
  static final RegExp _phone = RegExp(r'^\+251\d{9}$');
  static final RegExp _pin = RegExp(r'^\d{4}$');
  static const int _maxNameLength = 255;

  static String? phone(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'errors.phoneRequired';
    return _phone.hasMatch(v) ? null : 'errors.phoneFormat';
  }

  static String? pin(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'errors.pinRequired';
    return _pin.hasMatch(v) ? null : 'errors.pinFormat';
  }

  static String? confirmPin(String? pinValue, String? confirmValue) {
    final String? base = pin(confirmValue);
    if (base != null) return base;
    return (pinValue ?? '').trim() == (confirmValue ?? '').trim()
        ? null
        : 'errors.pinMismatch';
  }

  static String? name(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty || v.length > _maxNameLength) return 'errors.nameRequired';
    return null;
  }
}
```

- [ ] **Step 6: Write the use cases**

Create `mobile/lib/features/auth/domain/usecases/login.dart`:

```dart
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class Login {
  const Login(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call({required String phone, required String pin}) =>
      _repository.login(phone: phone, pin: pin);
}
```

Create `mobile/lib/features/auth/domain/usecases/register.dart`:

```dart
import '../../../../core/localization/language.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class Register {
  const Register(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) =>
      _repository.register(phone: phone, pin: pin, name: name, language: language);
}
```

Create `mobile/lib/features/auth/domain/usecases/get_me.dart`:

```dart
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class GetMe {
  const GetMe(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call() => _repository.getMe();
}
```

Create `mobile/lib/features/auth/domain/usecases/logout.dart`:

```dart
import '../repositories/auth_repository.dart';

class Logout {
  const Logout(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/features/auth/domain/
```

Expected: PASS, 17 tests.

- [ ] **Step 8: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/features/auth/domain mobile/test/features/auth/domain
git commit -m "feat(mobile): add auth domain layer with entity, contract and validators"
```

---

### Task 8: Auth data layer

Models, both datasources, and the repository that joins them. This is where the offline-first behaviour lives: the repository decides when the network is required and when the cache answers.

**Files:**
- Create: `mobile/lib/core/security/jwt.dart`
- Create: `mobile/lib/core/security/token_store.dart`
- Create: `mobile/lib/features/auth/data/models/user_model.dart`
- Create: `mobile/lib/features/auth/data/models/auth_response_model.dart`
- Create: `mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart`
- Create: `mobile/lib/features/auth/data/datasources/auth_local_datasource.dart`
- Create: `mobile/lib/features/auth/data/repositories/auth_repository_impl.dart`
- Test: `mobile/test/core/security/jwt_test.dart`
- Test: `mobile/test/features/auth/data/auth_remote_datasource_test.dart`
- Test: `mobile/test/features/auth/data/auth_repository_impl_test.dart`

**Interfaces:**
- Consumes: `ApiResponse`, `ApiEndpoints`, `failureFromDioException`, `Failure` subclasses (Tasks 3–4); `CachedUserDao`, `CachedUsersCompanion`, `CachedUser` (Task 5); `AppLanguage` (Task 6); `AuthUser`, `AuthRepository` (Task 7).
- Produces:
  - `bool isJwtExpired(String token, {DateTime? now})`
  - `TokenStore(FlutterSecureStorage)` → `.read()`, `.write(String)`, `.clear()`
  - `UserModel` (freezed, `.fromJson`, `.toEntity()`, `.toCompanion()`, `static UserModel fromCached(CachedUser)`)
  - `AuthResponseModel` (freezed, `.fromJson`) with `String token` and `UserModel user`
  - `AuthRemoteDataSource(Dio)` → `.register({phone, pin, name, languageCode}) → Future<AuthResponseModel>`, `.login({phone, pin}) → Future<AuthResponseModel>`, `.me() → Future<UserModel>`
  - `AuthLocalDataSource(TokenStore, CachedUserDao)` → `.saveSession({token, user})`, `.readToken()`, `.readUser()`, `.cacheUser(UserModel)`, `.clear()`
  - `AuthRepositoryImpl(AuthRemoteDataSource, AuthLocalDataSource, {required Future<bool> Function() isOnline})` implementing `AuthRepository`

- [ ] **Step 1: Write the failing JWT test**

Create `mobile/test/core/security/jwt_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/security/jwt.dart';

String _tokenWithExp(int? exp) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg(<String, dynamic>{'sub': 'user-1', if (exp != null) 'exp': exp});
  return '$header.$payload.signature-not-verified-on-device';
}

void main() {
  final DateTime now = DateTime.utc(2026, 9, 3, 12);

  test('a token expiring in the future is not expired', () {
    final t = _tokenWithExp(
        now.add(const Duration(days: 6)).millisecondsSinceEpoch ~/ 1000);
    expect(isJwtExpired(t, now: now), isFalse);
  });

  test('a token that expired an hour ago is expired', () {
    final t = _tokenWithExp(
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
    expect(isJwtExpired(t, now: now), isTrue);
  });

  test('a token with no exp claim is treated as expired', () {
    expect(isJwtExpired(_tokenWithExp(null), now: now), isTrue);
  });

  test('garbage is treated as expired rather than throwing', () {
    expect(isJwtExpired('not-a-jwt', now: now), isTrue);
    expect(isJwtExpired('', now: now), isTrue);
    expect(isJwtExpired('a.b.c', now: now), isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/security/jwt_test.dart
```

Expected: FAIL — `jwt.dart` does not exist.

- [ ] **Step 3: Write the JWT helper**

Create `mobile/lib/core/security/jwt.dart`:

```dart
import 'dart:convert';

/// Reads the `exp` claim without verifying the signature.
///
/// Verification is the server's job — this only exists so the auth gate can
/// avoid routing a user to Home with a token the server will reject. Anything
/// unreadable counts as expired: failing closed sends the user to Login, which
/// is recoverable, while failing open strands them on a broken Home screen.
bool isJwtExpired(String token, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now().toUtc();

  final List<String> parts = token.split('.');
  if (parts.length != 3) return true;

  try {
    final String normalised = base64Url.normalize(parts[1]);
    final Object? decoded = jsonDecode(utf8.decode(base64Url.decode(normalised)));
    if (decoded is! Map<String, dynamic>) return true;

    final Object? exp = decoded['exp'];
    if (exp is! int) return true;

    final DateTime expiry =
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    return !expiry.isAfter(reference);
  } on Object {
    return true;
  }
}
```

- [ ] **Step 4: Write the models**

Create `mobile/lib/features/auth/data/models/user_model.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart';
import '../../domain/entities/auth_user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Wire format of the `user` object returned by register / login / me.
/// Stays inside the auth data layer — everything outside sees `AuthUser`.
@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String name,
    required String phone,
    required String preferredLanguage,
    required String role,
  }) = _UserModel;

  const UserModel._();

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  AuthUser toEntity() => AuthUser(
        id: id, name: name, phone: phone,
        preferredLanguage: preferredLanguage, role: role,
      );

  CachedUsersCompanion toCompanion() => CachedUsersCompanion(
        id: Value<String>(id),
        name: Value<String>(name),
        phone: Value<String>(phone),
        preferredLanguage: Value<String>(preferredLanguage),
        role: Value<String>(role),
      );

  static UserModel fromCached(CachedUser row) => UserModel(
        id: row.id, name: row.name, phone: row.phone,
        preferredLanguage: row.preferredLanguage, role: row.role,
      );
}
```

Create `mobile/lib/features/auth/data/models/auth_response_model.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart';

part 'auth_response_model.freezed.dart';
part 'auth_response_model.g.dart';

/// The `data` payload of register and login: `{ token, user }`.
@freezed
class AuthResponseModel with _$AuthResponseModel {
  const factory AuthResponseModel({
    required String token,
    required UserModel user,
  }) = _AuthResponseModel;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);
}
```

- [ ] **Step 5: Generate the model code**

```bash
cd /c/src/Heart-Care-App/mobile
dart run build_runner build --delete-conflicting-outputs
```

Expected: four generated files (`.freezed.dart` + `.g.dart` per model). Gitignored.

- [ ] **Step 6: Write the failing remote-datasource test**

Create `mobile/test/features/auth/data/auth_remote_datasource_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _envelope(Object? data, {String message = 'OK'}) => {
      'success': true, 'data': data, 'message': message,
      'timestamp': '2026-09-03T10:00:00Z',
    };

const Map<String, dynamic> _userJson = {
  'id': '3f2a9c1e', 'name': 'Abebe Bekele', 'phone': '+251911234567',
  'preferredLanguage': 'am', 'role': 'PATIENT',
};

void main() {
  late Dio dio;
  late _StubAdapter adapter;
  late AuthRemoteDataSource source;

  void serve(Map<String, dynamic> body, {int status = 200}) {
    adapter = _StubAdapter(status, body);
    dio.httpClientAdapter = adapter;
  }

  setUp(() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://test.local',
      validateStatus: (int? s) => s != null && s < 400,
    ));
    source = AuthRemoteDataSource(dio);
  });

  test('register posts the four identity fields and unwraps token + user', () async {
    serve(_envelope({'token': 'jwt-abc', 'user': _userJson}, message: 'Registered'));
    final result = await source.register(
      phone: '+251911234567', pin: '1234', name: 'Abebe Bekele', languageCode: 'am',
    );
    expect(result.token, 'jwt-abc');
    expect(result.user.name, 'Abebe Bekele');
    final sent = adapter.lastRequest!;
    expect(sent.path, '/api/v1/auth/register');
    expect(sent.data, {
      'phone': '+251911234567', 'pin': '1234', 'name': 'Abebe Bekele',
      'preferredLanguage': 'am',
    });
  });

  test('register accepts 200, because this API never returns 201', () async {
    serve(_envelope({'token': 't', 'user': _userJson}), status: 200);
    expect((await source.register(
      phone: '+251911234567', pin: '1234', name: 'A', languageCode: 'en',
    )).token, 't');
  });

  test('login posts only phone and pin', () async {
    serve(_envelope({'token': 'jwt-xyz', 'user': _userJson}, message: 'Logged in'));
    final result = await source.login(phone: '+251911234567', pin: '1234');
    expect(result.token, 'jwt-xyz');
    expect(adapter.lastRequest!.path, '/api/v1/auth/login');
    expect(adapter.lastRequest!.data, {'phone': '+251911234567', 'pin': '1234'});
  });

  test('me unwraps the user directly from data', () async {
    serve(_envelope(_userJson));
    final user = await source.me();
    expect(user.id, '3f2a9c1e');
    expect(user.preferredLanguage, 'am');
    expect(adapter.lastRequest!.path, '/api/v1/auth/me');
  });
}
```

- [ ] **Step 7: Write the remote datasource**

Create `mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart`:

```dart
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Talks to the auth endpoints. Knows nothing about storage or caching —
/// architectural rule 3 keeps that in `AuthLocalDataSource`.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponseModel> register({
    required String phone,
    required String pin,
    required String name,
    required String languageCode,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.register,
      data: <String, dynamic>{
        'phone': phone, 'pin': pin, 'name': name, 'preferredLanguage': languageCode,
      },
    );
    return _authFrom(response);
  }

  Future<AuthResponseModel> login({
    required String phone,
    required String pin,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.login,
      data: <String, dynamic>{'phone': phone, 'pin': pin},
    );
    return _authFrom(response);
  }

  Future<UserModel> me() async {
    final Response<dynamic> response = await _dio.get<dynamic>(ApiEndpoints.me);
    final ApiResponse<UserModel> envelope = ApiResponse<UserModel>.fromJson(
      response.data as Map<String, dynamic>,
      (Object? data) => UserModel.fromJson(data! as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  AuthResponseModel _authFrom(Response<dynamic> response) {
    final ApiResponse<AuthResponseModel> envelope =
        ApiResponse<AuthResponseModel>.fromJson(
      response.data as Map<String, dynamic>,
      (Object? data) => AuthResponseModel.fromJson(data! as Map<String, dynamic>),
    );
    return envelope.data!;
  }
}
```

- [ ] **Step 8: Write the token store and the local datasource**

Create `mobile/lib/core/security/token_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The bearer token at rest, in the platform keystore.
///
/// Lives in `core/`, not the auth feature, because `dioProvider` must read the
/// token to set the `Authorization` header — if core reached into
/// `features/auth` for it, core and auth would import each other.
class TokenStore {
  const TokenStore(this._storage);

  static const String _key = 'auth_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
```

Create `mobile/lib/features/auth/data/datasources/auth_local_datasource.dart`:

```dart
import '../../../../core/db/app_database.dart';
import '../../../../core/db/daos/cached_user_dao.dart';
import '../../../../core/security/token_store.dart';
import '../models/user_model.dart';

/// Session storage: the JWT goes in the platform keystore, the user record in
/// Drift. Split on purpose — the token is a credential and belongs in
/// encrypted storage; the user record is ordinary app data the offline launch
/// path needs to read quickly.
class AuthLocalDataSource {
  const AuthLocalDataSource(this._tokens, this._users);

  final TokenStore _tokens;
  final CachedUserDao _users;

  Future<void> saveSession({
    required String token,
    required UserModel user,
  }) async {
    await _tokens.write(token);
    await _users.save(user.toCompanion());
  }

  Future<String?> readToken() => _tokens.read();

  Future<UserModel?> readUser() async {
    final CachedUser? row = await _users.current();
    return row == null ? null : UserModel.fromCached(row);
  }

  Future<void> cacheUser(UserModel user) => _users.save(user.toCompanion());

  Future<void> clear() async {
    await _tokens.clear();
    await _users.clear();
  }
}
```

- [ ] **Step 9: Write the failing repository test**

Create `mobile/test/features/auth/data/auth_repository_impl_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/models/auth_response_model.dart';
import 'package:libu_care/features/auth/data/models/user_model.dart';
import 'package:libu_care/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}
class MockLocal extends Mock implements AuthLocalDataSource {}

const UserModel _model = UserModel(
  id: '3f2a9c1e', name: 'Abebe Bekele', phone: '+251911234567',
  preferredLanguage: 'am', role: 'PATIENT',
);
const AuthResponseModel _auth = AuthResponseModel(token: 'jwt-abc', user: _model);

DioException _dioError(int status, String message) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: <String, dynamic>{
          'success': false, 'data': null, 'message': message,
          'timestamp': '2026-09-03T10:00:00Z',
        },
      ),
    );

void main() {
  late MockRemote remote;
  late MockLocal local;

  AuthRepositoryImpl build({bool online = true}) =>
      AuthRepositoryImpl(remote, local, isOnline: () async => online);

  setUp(() {
    remote = MockRemote();
    local = MockLocal();
    registerFallbackValue(_model);
    when(() => local.saveSession(
        token: any(named: 'token'), user: any(named: 'user'))).thenAnswer((_) async {});
    when(() => local.cacheUser(any())).thenAnswer((_) async {});
    when(() => local.clear()).thenAnswer((_) async {});
  });

  group('login', () {
    test('stores the session and returns the user', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenAnswer((_) async => _auth);
      final user = await build().login(phone: '+251911234567', pin: '1234');
      expect(user.name, 'Abebe Bekele');
      verify(() => local.saveSession(token: 'jwt-abc', user: _model)).called(1);
    });

    test('fails fast with NetworkFailure when offline, without calling the API', () async {
      expect(
        () => build(online: false).login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<NetworkFailure>()),
      );
      verifyNever(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')));
    });

    test('maps 401 to InvalidCredentialsFailure', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenThrow(_dioError(401, 'Invalid phone or PIN'));
      expect(
        () => build().login(phone: '+251911234567', pin: '9999'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test('maps 423 to AccountLockedFailure carrying the minutes', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenThrow(_dioError(423, 'Too many failed attempts. Try again in 15 minutes.'));
      try {
        await build().login(phone: '+251911234567', pin: '9999');
        fail('expected a failure');
      } on AccountLockedFailure catch (f) {
        expect(f.minutesRemaining, 15);
      }
    });

    test('does not store a session when login fails', () async {
      when(() => remote.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
          .thenThrow(_dioError(401, 'Invalid phone or PIN'));
      await expectLater(
        build().login(phone: '+251911234567', pin: '9999'),
        throwsA(isA<Failure>()),
      );
      verifyNever(() => local.saveSession(
          token: any(named: 'token'), user: any(named: 'user')));
    });
  });

  group('register', () {
    test('sends the language code and auto-logs-in', () async {
      when(() => remote.register(
            phone: any(named: 'phone'), pin: any(named: 'pin'),
            name: any(named: 'name'), languageCode: any(named: 'languageCode'),
          )).thenAnswer((_) async => _auth);
      await build().register(
        phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
        language: AppLanguage.am,
      );
      verify(() => remote.register(
            phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
            languageCode: 'am',
          )).called(1);
      verify(() => local.saveSession(token: 'jwt-abc', user: _model)).called(1);
    });

    test('maps 409 to PhoneAlreadyRegisteredFailure', () async {
      when(() => remote.register(
            phone: any(named: 'phone'), pin: any(named: 'pin'),
            name: any(named: 'name'), languageCode: any(named: 'languageCode'),
          )).thenThrow(_dioError(409, 'Phone already registered'));
      expect(
        () => build().register(
          phone: '+251911234567', pin: '1234', name: 'A', language: AppLanguage.en,
        ),
        throwsA(isA<PhoneAlreadyRegisteredFailure>()),
      );
    });
  });

  group('getMe', () {
    test('refreshes the cache on success', () async {
      when(() => remote.me()).thenAnswer((_) async => _model);
      final user = await build().getMe();
      expect(user.id, '3f2a9c1e');
      verify(() => local.cacheUser(_model)).called(1);
    });

    test('maps 401 to SessionExpiredFailure, not bad credentials', () async {
      when(() => remote.me()).thenThrow(_dioError(401, 'Unauthorized'));
      expect(build().getMe(), throwsA(isA<SessionExpiredFailure>()));
    });
  });

  group('session', () {
    test('cachedUser reads through to local storage', () async {
      when(() => local.readUser()).thenAnswer((_) async => _model);
      expect((await build().cachedUser())!.name, 'Abebe Bekele');
    });

    test('hasValidSession is false with no token', () async {
      when(() => local.readToken()).thenAnswer((_) async => null);
      expect(await build().hasValidSession(), isFalse);
    });

    test('hasValidSession is false for an unreadable token', () async {
      when(() => local.readToken()).thenAnswer((_) async => 'garbage');
      expect(await build().hasValidSession(), isFalse);
    });

    test('logout clears storage', () async {
      await build().logout();
      verify(() => local.clear()).called(1);
    });
  });
}
```

- [ ] **Step 10: Run it to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/features/auth/data/
```

Expected: FAIL — `auth_repository_impl.dart` does not exist.

- [ ] **Step 11: Write the repository**

Create `mobile/lib/features/auth/data/repositories/auth_repository_impl.dart`:

```dart
import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/jwt.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(
    this._remote,
    this._local, {
    required Future<bool> Function() isOnline,
  }) : _isOnline = isOnline;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final Future<bool> Function() _isOnline;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    await _requireConnection();
    final AuthResponseModel result =
        await _guard(() => _remote.login(phone: phone, pin: pin));
    await _local.saveSession(token: result.token, user: result.user);
    return result.user.toEntity();
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) async {
    await _requireConnection();
    final AuthResponseModel result = await _guard(
      () => _remote.register(
        phone: phone, pin: pin, name: name, languageCode: language.code,
      ),
    );
    await _local.saveSession(token: result.token, user: result.user);
    return result.user.toEntity();
  }

  @override
  Future<AuthUser> getMe() async {
    final UserModel user = await _guard(_remote.me, unauthorizedMeansExpired: true);
    await _local.cacheUser(user);
    return user.toEntity();
  }

  @override
  Future<AuthUser?> cachedUser() async => (await _local.readUser())?.toEntity();

  @override
  Future<bool> hasValidSession() async {
    final String? token = await _local.readToken();
    if (token == null || token.isEmpty) return false;
    return !isJwtExpired(token);
  }

  @override
  Future<void> logout() => _local.clear();

  /// First-time auth is inherently online. Checking up front turns a confusing
  /// timeout into an immediate, honest message.
  Future<void> _requireConnection() async {
    if (!await _isOnline()) {
      throw const NetworkFailure('errors.offline');
    }
  }

  /// Converts Dio's exceptions into the `Failure` vocabulary.
  ///
  /// [unauthorizedMeansExpired] disambiguates 401: on `login` it means the PIN
  /// was wrong, on `me` it means the 7-day token ran out. The status code
  /// alone cannot tell these apart, so the caller supplies the context.
  Future<T> _guard<T>(
    Future<T> Function() action, {
    bool unauthorizedMeansExpired = false,
  }) async {
    try {
      return await action();
    } on DioException catch (e) {
      final Failure failure = failureFromDioException(e);
      if (unauthorizedMeansExpired && failure is InvalidCredentialsFailure) {
        throw SessionExpiredFailure(failure.message);
      }
      throw failure;
    }
  }
}
```

- [ ] **Step 12: Run the data-layer tests**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/features/auth/data/ test/core/security/
```

Expected: PASS, 21 tests.

- [ ] **Step 13: Run the full suite and analyze**

```bash
cd /c/src/Heart-Care-App/mobile
flutter analyze
flutter test
```

Expected: clean analyze, all tests green.

- [ ] **Step 14: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/security mobile/lib/features/auth/data mobile/test/core/security mobile/test/features/auth/data
git commit -m "feat(mobile): add auth data layer with offline-aware repository"
```

---

### Task 9: Providers and the auth controller

Wires the dependency graph in Riverpod and exposes the single piece of state the router and every screen reads.

**Files:**
- Create: `mobile/lib/core/providers/core_providers.dart`
- Create: `mobile/lib/features/auth/auth_providers.dart`
- Create: `mobile/lib/features/auth/presentation/controllers/auth_controller.dart`
- Test: `mobile/test/features/auth/presentation/auth_controller_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 3–8.
- Produces:
  - in `core/providers/core_providers.dart`: `appDatabaseProvider`, `secureStorageProvider`, `tokenStoreProvider`, `dioProvider`, `isOnlineProvider` (`Provider<Future<bool> Function()>`), `languageStoreProvider` — **this file imports nothing from `features/`**
  - in `features/auth/auth_providers.dart`: `authLocalDataSourceProvider`, `authRemoteDataSourceProvider`, `authRepositoryProvider` → `AuthRepository`
  - sealed `AuthState`: `AuthUnauthenticated()`, `AuthAuthenticated(AuthUser user)`
  - `authControllerProvider` → `AsyncNotifierProvider<AuthController, AuthState>` with `.login({phone, pin})`, `.register({phone, pin, name, language})`, `.signOut()`

- [ ] **Step 1: Write the failing controller test**

Create `mobile/test/features/auth/presentation/auth_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _user = AuthUser(
  id: '3f2a9c1e', name: 'Abebe Bekele', phone: '+251911234567',
  preferredLanguage: 'am', role: 'PATIENT',
);

void main() {
  late MockAuthRepository repo;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.hasValidSession()).thenAnswer((_) async => false);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
    when(() => repo.logout()).thenAnswer((_) async {});
  });

  test('starts unauthenticated when there is no session', () async {
    final state = await container().read(authControllerProvider.future);
    expect(state, isA<AuthUnauthenticated>());
  });

  test('restores an authenticated session from cache with no network call', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => _user);
    final state = await container().read(authControllerProvider.future);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.name, 'Abebe Bekele');
    verifyNever(() => repo.getMe());
  });

  test('a valid token with no cached user is treated as unauthenticated', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
    expect(await container().read(authControllerProvider.future),
        isA<AuthUnauthenticated>());
  });

  test('login moves the state to authenticated', () async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenAnswer((_) async => _user);
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier)
        .login(phone: '+251911234567', pin: '1234');
    expect(c.read(authControllerProvider).value, isA<AuthAuthenticated>());
  });

  test('a failed login surfaces as AsyncError carrying the Failure', () async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const InvalidCredentialsFailure('Invalid phone or PIN'));
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier)
        .login(phone: '+251911234567', pin: '9999');
    final state = c.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InvalidCredentialsFailure>());
  });

  test('register authenticates on success', () async {
    when(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        )).thenAnswer((_) async => _user);
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).register(
          phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
          language: AppLanguage.am,
        );
    expect(c.read(authControllerProvider).value, isA<AuthAuthenticated>());
  });

  test('signOut clears the repository and returns to unauthenticated', () async {
    when(() => repo.hasValidSession()).thenAnswer((_) async => true);
    when(() => repo.cachedUser()).thenAnswer((_) async => _user);
    final c = container();
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).signOut();
    expect(c.read(authControllerProvider).value, isA<AuthUnauthenticated>());
    verify(() => repo.logout()).called(1);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/features/auth/presentation/
```

Expected: FAIL — the provider and controller URIs don't exist.

- [ ] **Step 3: Write the core providers**

Create `mobile/lib/core/providers/core_providers.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import '../db/app_database.dart';
import '../localization/language.dart';
import '../network/dio_client.dart';
import '../security/token_store.dart';

/// Riverpod is the DI container — there is no `get_it`.
///
/// This file must not import anything from `features/`. Feature wiring lives in
/// that feature's own providers file.

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase(openDatabaseConnection());
  ref.onDispose(db.close);
  return db;
});

final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ));

final Provider<TokenStore> tokenStoreProvider =
    Provider<TokenStore>((ref) => TokenStore(ref.watch(secureStorageProvider)));

final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final TokenStore tokens = ref.watch(tokenStoreProvider);
  return buildDio(baseUrl: Env.apiBaseUrl, readToken: tokens.read);
});

final Provider<Future<bool> Function()> isOnlineProvider =
    Provider<Future<bool> Function()>((ref) {
  return () async {
    final List<ConnectivityResult> result =
        await Connectivity().checkConnectivity();
    return !result.every((ConnectivityResult r) => r == ConnectivityResult.none);
  };
});

final Provider<LanguageStore> languageStoreProvider = Provider<LanguageStore>(
    (ref) => LanguageStore(ref.watch(appDatabaseProvider).preferencesDao));
```

Create `mobile/lib/features/auth/auth_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';

final Provider<AuthLocalDataSource> authLocalDataSourceProvider =
    Provider<AuthLocalDataSource>((ref) => AuthLocalDataSource(
          ref.watch(tokenStoreProvider),
          ref.watch(appDatabaseProvider).cachedUserDao,
        ));

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>(
        (ref) => AuthRemoteDataSource(ref.watch(dioProvider)));

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl(
          ref.watch(authRemoteDataSourceProvider),
          ref.watch(authLocalDataSourceProvider),
          isOnline: ref.watch(isOnlineProvider),
        ));
```

- [ ] **Step 4: Write the controller**

Create `mobile/lib/features/auth/presentation/controllers/auth_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/language.dart';
import '../../auth_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Sealed so the router and the screens cannot forget a case.
sealed class AuthState {
  const AuthState();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Restores the session from disk only.
  ///
  /// Deliberately does **not** call `GET /auth/me` — that would make a cold
  /// start fail without a network, the exact scenario the app is built for.
  /// The token's `exp` is checked locally; if the server has since rejected
  /// it, the first authenticated request surfaces that.
  @override
  Future<AuthState> build() async {
    if (!await _repository.hasValidSession()) {
      return const AuthUnauthenticated();
    }
    final AuthUser? cached = await _repository.cachedUser();
    return cached == null
        ? const AuthUnauthenticated()
        : AuthAuthenticated(cached);
  }

  Future<void> login({required String phone, required String pin}) async {
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final AuthUser user = await _repository.login(phone: phone, pin: pin);
      return AuthAuthenticated(user);
    });
  }

  Future<void> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) async {
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final AuthUser user = await _repository.register(
        phone: phone, pin: pin, name: name, language: language,
      );
      return AuthAuthenticated(user);
    });
  }

  Future<void> signOut() async {
    await _repository.logout();
    state = const AsyncValue<AuthState>.data(AuthUnauthenticated());
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/features/auth/presentation/
```

Expected: PASS, 7 tests.

- [ ] **Step 6: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/providers mobile/lib/features/auth/auth_providers.dart mobile/lib/features/auth/presentation mobile/test/features/auth/presentation
git commit -m "feat(mobile): wire Riverpod providers and the auth controller"
```

---

### Task 10: Router and the offline auth gate

The redirect rule is the heart of the offline story, so it is extracted into a pure function and tested directly rather than only through a widget.

**Files:**
- Create: `mobile/lib/core/router/routes.dart`
- Create: `mobile/lib/core/router/redirect.dart`
- Test: `mobile/test/core/router/redirect_test.dart`

**Interfaces:**
- Consumes: nothing (both files are dependency-free).
- Produces:
  - `Routes.splash='/splash'`, `.language='/language'`, `.login='/login'`, `.register='/register'`, `.forgotPin='/forgot-pin'`, `.home='/home'`, `.public` (a `Set<String>`)
  - `String? resolveRedirect({required String location, required bool sessionResolved, required bool languageChosen, required bool authenticated})`

> **`app_router.dart` is built in Task 11, not here.** It imports the six screens, so creating it now would leave this task's commit unable to compile. The rule worth testing in isolation — `resolveRedirect` — has no dependencies at all.

- [ ] **Step 1: Write the failing redirect test**

Create `mobile/test/core/router/redirect_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/router/redirect.dart';
import 'package:libu_care/core/router/routes.dart';

String? redirect({
  required String location,
  bool sessionResolved = true,
  bool languageChosen = true,
  bool authenticated = false,
}) =>
    resolveRedirect(
      location: location,
      sessionResolved: sessionResolved,
      languageChosen: languageChosen,
      authenticated: authenticated,
    );

void main() {
  test('holds on splash until the session has been read from disk', () {
    expect(redirect(location: Routes.splash, sessionResolved: false), isNull);
    expect(redirect(location: Routes.login, sessionResolved: false), Routes.splash);
  });

  test('sends a first-run user to the language picker before anything else', () {
    expect(redirect(location: Routes.login, languageChosen: false), Routes.language);
    expect(redirect(location: Routes.language, languageChosen: false), isNull);
  });

  test('an authenticated user landing on splash goes Home', () {
    expect(redirect(location: Routes.splash, authenticated: true), Routes.home);
  });

  test('an unauthenticated user landing on splash goes to Login', () {
    expect(redirect(location: Routes.splash), Routes.login);
  });

  test('an unauthenticated user cannot reach Home', () {
    expect(redirect(location: Routes.home), Routes.login);
  });

  test('an authenticated user is bounced off the auth screens', () {
    expect(redirect(location: Routes.login, authenticated: true), Routes.home);
    expect(redirect(location: Routes.register, authenticated: true), Routes.home);
  });

  test('an unauthenticated user may sit on login, register and forgot-PIN', () {
    expect(redirect(location: Routes.login), isNull);
    expect(redirect(location: Routes.register), isNull);
    expect(redirect(location: Routes.forgotPin), isNull);
  });

  test('an authenticated user stays on Home', () {
    expect(redirect(location: Routes.home, authenticated: true), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/router/redirect_test.dart
```

Expected: FAIL — `redirect.dart` and `routes.dart` do not exist.

- [ ] **Step 3: Write the routes and the redirect rule**

Create `mobile/lib/core/router/routes.dart`:

```dart
abstract final class Routes {
  static const String splash = '/splash';
  static const String language = '/language';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPin = '/forgot-pin';
  static const String home = '/home';

  /// Screens reachable without a session.
  static const Set<String> public = <String>{login, register, forgotPin};
}
```

Create `mobile/lib/core/router/redirect.dart`:

```dart
import 'routes.dart';

/// The auth gate, as a pure function so it can be tested without a widget tree.
///
/// Order matters:
///   1. Nothing is decided until the session has been read from disk.
///   2. A first-run user picks a language before seeing any other screen.
///   3. Then the ordinary signed-in / signed-out split.
///
/// Returns the location to redirect to, or null to stay put.
String? resolveRedirect({
  required String location,
  required bool sessionResolved,
  required bool languageChosen,
  required bool authenticated,
}) {
  if (!sessionResolved) {
    return location == Routes.splash ? null : Routes.splash;
  }

  if (!languageChosen) {
    return location == Routes.language ? null : Routes.language;
  }

  if (authenticated) {
    return location == Routes.home ? null : Routes.home;
  }

  return Routes.public.contains(location) ? null : Routes.login;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/core/router/redirect_test.dart
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib/core/router mobile/test/core/router
git commit -m "feat(mobile): add route table and the offline auth-gate rule"
```

---

### Task 11: Screens, shared widgets, router wiring and app bootstrap

Builds every screen in the slice. The Login screen follows Figma frame `368:680` exactly for colour and type; Create account reuses Screen 2's (`368:632`) visual system with the identity-only field set from Global Constraints; the language picker, Forgot-PIN and Home screens have no frame and are the implementer's latitude within the design system. **No raw hex in any of these files** — colours come from `AppColors` or the theme.

**Files:**
- Create: `mobile/lib/features/auth/presentation/widgets/header_band.dart`
- Create: `mobile/lib/features/auth/presentation/widgets/primary_button.dart`
- Create: `mobile/lib/features/auth/presentation/widgets/phone_field.dart`
- Create: `mobile/lib/features/auth/presentation/widgets/pin_input.dart`
- Create: `mobile/lib/features/auth/presentation/widgets/choice_pills.dart`
- Create: `mobile/lib/features/auth/presentation/widgets/failure_message.dart`
- Create: `mobile/lib/features/auth/presentation/screens/splash_screen.dart`
- Create: `mobile/lib/features/auth/presentation/screens/language_screen.dart`
- Create: `mobile/lib/features/auth/presentation/screens/login_screen.dart`
- Create: `mobile/lib/features/auth/presentation/screens/register_screen.dart`
- Create: `mobile/lib/features/auth/presentation/screens/forgot_pin_screen.dart`
- Create: `mobile/lib/features/auth/presentation/screens/home_placeholder_screen.dart`
- Create: `mobile/lib/core/router/app_router.dart`
- Create: `mobile/assets/images/libu_care_logo.png` (exported from Figma — see Step 3)
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/widget/helpers.dart`
- Test: `mobile/test/widget/login_screen_test.dart`
- Test: `mobile/test/widget/register_screen_test.dart`
- Modify: `mobile/pubspec.yaml` (adds test-only `shared_preferences`)

**Interfaces:**
- Consumes: theme tokens (Task 2), `AppLanguage`/`LanguageStore` (Task 6), `AuthValidators` (Task 7), `authControllerProvider`/`AuthState` (Task 9), `Routes`/`resolveRedirect` (Task 10), `languageStoreProvider` (Task 9), translation keys (Task 6).
- Produces:
  - widgets: `HeaderBand()`, `PrimaryButton({required String label, required VoidCallback? onPressed, bool isLoading})`, `PhoneField({required TextEditingController controller, required String label, required String hint, required Key fieldKey, String? Function(String?)? validator})`, `PinInput({...same shape...})`, `ChoicePills<T>({required List<T> values, required T selected, required String Function(T) label, required ValueChanged<T> onChanged})`, `FailureMessage(Failure)`
  - screens: `SplashScreen`, `LanguageScreen`, `LoginScreen`, `RegisterScreen`, `ForgotPinScreen`, `HomePlaceholderScreen` — each `const`-constructible
  - `goRouterProvider` → `Provider<GoRouter>` and `languageChosenProvider` → `FutureProvider<bool>` in `app_router.dart`
  - `main()` and `LibuCareApp` in `main.dart`

- [ ] **Step 1: Add the test-only dependency and write the failing widget tests**

```bash
cd /c/src/Heart-Care-App/mobile
flutter pub add --dev shared_preferences
```

Create `mobile/test/widget/helpers.dart`. **Every screen calls `.tr()`, which throws without an `EasyLocalization` ancestor** — pumping a bare `MaterialApp(home: LoginScreen())` fails before a single assertion runs:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Call once in `setUpAll`. `easy_localization` persists the chosen locale
/// through shared_preferences, whose platform channel is absent in tests.
Future<void> initLocalization() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await EasyLocalization.ensureInitialized();
}

/// Pumps a screen inside the same localization + theme + provider stack the
/// real app uses.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales:
          AppLanguage.values.map((AppLanguage l) => l.locale).toList(),
      path: 'assets/translations',
      fallbackLocale: AppLanguage.en.locale,
      child: ProviderScope(
        overrides: overrides,
        child: Builder(
          builder: (BuildContext context) => MaterialApp(
            theme: AppTheme.light(context.locale.languageCode),
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Create `mobile/test/widget/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Future<void> pumpLogin(WidgetTester tester, AuthRepository repo) => pumpScreen(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  late MockAuthRepository repo;

  setUpAll(initLocalization);

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.hasValidSession()).thenAnswer((_) async => false);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
  });

  testWidgets('rejects a local 0-prefixed phone without calling the API', (tester) async {
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '0911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '1234');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')));
  });

  testWidgets('rejects a 3-digit PIN', (tester) async {
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '123');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')));
  });

  testWidgets('submits valid credentials to the repository', (tester) async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const InvalidCredentialsFailure('Invalid phone or PIN'));
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '1234');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    verify(() => repo.login(phone: '+251911234567', pin: '1234')).called(1);
  });

  testWidgets('a lockout is shown as a wait, not a wrong PIN', (tester) async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const AccountLockedFailure(
            'Too many failed attempts. Try again in 12 minutes.',
            minutesRemaining: 12));
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '9999');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12'), findsWidgets);
  });
}
```

Create `mobile/test/widget/register_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/register_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;

  setUpAll(initLocalization);

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.hasValidSession()).thenAnswer((_) async => false);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
      );

  testWidgets('will not submit when the two PINs differ', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('register_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('register_name')), 'Abebe Bekele');
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(find.byKey(const Key('register_confirm_pin')), '4321');
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        ));
  });

  testWidgets('submits when every field is valid', (tester) async {
    when(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        )).thenThrow(Exception('stop here'));
    await pump(tester);
    await tester.enterText(find.byKey(const Key('register_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('register_name')), 'Abebe Bekele');
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(find.byKey(const Key('register_confirm_pin')), '1234');
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    verify(() => repo.register(
          phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
          language: any(named: 'language'),
        )).called(1);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/widget/
```

Expected: FAIL — the screen URIs do not exist.

- [ ] **Step 3: Export the logo asset from Figma**

The header band shows a "Libu Care" wordmark (heartbeat line into a heart, "Heart health care" tagline). On the Login frame it is node `368:713` ("Libu care 3"). Export it as PNG @3x and save to `mobile/assets/images/libu_care_logo.png`. Use `get_screenshot` on `368:713` at `maxDimension: 1024` if a direct asset export is not available, then crop. Transparent background.

- [ ] **Step 4: Write the shared widgets**

Create `mobile/lib/features/auth/presentation/widgets/header_band.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The cream band with the Libu Care mark that tops every screen in the design
/// (Figma frames `368:680` / `368:632`).
class HeaderBand extends StatelessWidget {
  const HeaderBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.headerBandHeight,
      width: double.infinity,
      color: AppColors.headerBand,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/libu_care_logo.png',
        height: 150,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/widgets/primary_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.surface),
              )
            : Text(label),
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/widgets/phone_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

/// Phone entry pinned to the Ethiopian format the API accepts.
///
/// The field is seeded with `+251` and limited to 13 characters so the user
/// types only the 9 national digits and cannot produce a wrong country code.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.fieldKey,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  /// Applied to the `TextFormField` itself so `enterText` has an `EditableText`
  /// to write into.
  final Key fieldKey;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.phone,
          autofillHints: const <String>[AutofillHints.telephoneNumber],
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
            LengthLimitingTextInputFormatter(13),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Iconsax.call),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/widgets/pin_input.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

class PinInput extends StatelessWidget {
  const PinInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.fieldKey,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Key fieldKey;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Iconsax.lock),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/widgets/choice_pills.dart`. This is the dark-selected / outlined-unselected pill row used for language and (on the reference frame) sex — here only for language:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Horizontal row of selectable pills — selected pill filled `ink`, others
/// outlined. Mirrors the language / choice controls on Figma frame `368:632`.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: i == values.length - 1 ? 0 : AppSpacing.md),
              child: _Pill(
                text: label(values[i]),
                selected: values[i] == selected,
                onTap: () => onChanged(values[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          border: Border.all(color: selected ? AppColors.ink : AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
        ),
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/widgets/failure_message.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Turns a `Failure` into a sentence the patient can act on.
///
/// A lockout is phrased as a wait, never as a wrong PIN — re-prompting for the
/// PIN during a lockout invites the user to keep guessing when guessing cannot
/// possibly work.
String failureText(Failure failure) => switch (failure) {
      AccountLockedFailure(:final int? minutesRemaining) =>
        minutesRemaining == null
            ? 'errors.lockedNoTime'.tr()
            : 'errors.locked'.tr(namedArgs: <String, String>{
                'minutes': '$minutesRemaining',
              }),
      InvalidCredentialsFailure() => 'errors.invalidCredentials'.tr(),
      PhoneAlreadyRegisteredFailure() => 'errors.phoneTaken'.tr(),
      NetworkFailure(:final String message) =>
        message.startsWith('errors.') ? message.tr() : message,
      ValidationFailure(:final String message) => message,
      SessionExpiredFailure() => 'errors.invalidCredentials'.tr(),
      ServerFailure() || UnknownFailure() => 'errors.generic'.tr(),
    };

class FailureMessage extends StatelessWidget {
  const FailureMessage(this.failure, {super.key});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.criticalBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Text(
        failureText(failure),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.critical),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the screens**

Create `mobile/lib/features/auth/presentation/screens/splash_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/header_band.dart';

/// Shown only while the session is read from disk. The router redirects away
/// as soon as that resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: <Widget>[
          HeaderBand(),
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/screens/language_screen.dart`. No Figma frame — design-system layout: header band, "Choose your language" (h1), subtitle, one full-width `ChoicePills`-style option per language stacked vertically, `PrimaryButton` "Continue":

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/header_band.dart';
import '../widgets/primary_button.dart';

/// First-run language picker. Persisted; shown once, before Login.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  AppLanguage _selected = AppLanguage.en;

  Future<void> _continue() async {
    await ref.read(languageStoreProvider).write(_selected);
    if (!mounted) return;
    await context.setLocale(_selected.locale);
    ref.invalidate(languageChosenProvider);
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const HeaderBand(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Text('language.title'.tr(),
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text('language.subtitle'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                  for (final AppLanguage language in AppLanguage.values) ...<Widget>[
                    _LanguageRow(
                      language: language,
                      selected: _selected == language,
                      onTap: () => setState(() => _selected = language),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const Spacer(),
                  PrimaryButton(
                      label: 'language.continue'.tr(), onPressed: _continue),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Container(
        height: AppSpacing.fieldHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          border: Border.all(color: selected ? AppColors.ink : AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        ),
        child: Text(
          language.nativeLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
        ),
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/screens/login_screen.dart` — follows Figma frame `368:680`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/failure_message.dart';
import '../widgets/header_band.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_input.dart';
import '../widgets/primary_button.dart';

/// Figma Screen 1, node `368:680`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController(text: '+251');
  final TextEditingController _pin = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          phone: _phone.text.trim(),
          pin: _pin.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthState> auth = ref.watch(authControllerProvider);
    final Object? error = auth.error;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const HeaderBand(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Text('login.title'.tr(),
                        style: Theme.of(context).textTheme.headlineLarge),
                    Text('login.subtitle'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xl),
                    if (error is Failure) FailureMessage(error),
                    PhoneField(
                      fieldKey: const Key('login_phone'),
                      controller: _phone,
                      label: 'login.phone'.tr(),
                      hint: 'login.phoneHint'.tr(),
                      validator: (String? v) => AuthValidators.phone(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PinInput(
                      fieldKey: const Key('login_pin'),
                      controller: _pin,
                      label: 'login.pin'.tr(),
                      hint: 'login.pinHint'.tr(),
                      validator: (String? v) => AuthValidators.pin(v)?.tr(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgotPin),
                        child: Text('login.forgotPin'.tr(),
                            style: const TextStyle(color: AppColors.accent)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      key: const Key('login_submit'),
                      label: 'login.submit'.tr(),
                      isLoading: auth.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text('login.or'.tr(),
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: () => context.push(Routes.register),
                      child: Text('login.createAccount'.tr()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text('login.language'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.accentBg,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.fieldRadius),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Iconsax.wifi,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: AppSpacing.sm),
                            Text('login.worksOffline'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/screens/register_screen.dart` — reuses Screen 2's visual system with the identity-only field set:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/choice_pills.dart';
import '../widgets/failure_message.dart';
import '../widgets/header_band.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_input.dart';
import '../widgets/primary_button.dart';

/// Create account. Visual language from Figma Screen 2 (`368:632`); field set
/// is **identity only** per spec §3 — no DOB, height or sex (those belong to
/// `PUT /patients/me` in the patient-profile slice and `POST /auth/register`
/// would reject them). Confirm-PIN is added so a typo does not permanently
/// lock a patient out (there is no self-service reset).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController(text: '+251');
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirmPin = TextEditingController();

  AppLanguage _language = AppLanguage.en;

  @override
  void initState() {
    super.initState();
    ref.read(languageStoreProvider).read().then((AppLanguage? stored) {
      if (stored != null && mounted) setState(() => _language = stored);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).register(
          phone: _phone.text.trim(),
          pin: _pin.text.trim(),
          name: _name.text.trim(),
          language: _language,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthState> auth = ref.watch(authControllerProvider);
    final Object? error = auth.error;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const HeaderBand(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Text('register.title'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text('register.subtitle'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xl),
                    if (error is Failure) FailureMessage(error),
                    PhoneField(
                      fieldKey: const Key('register_phone'),
                      controller: _phone,
                      label: 'login.phone'.tr(),
                      hint: 'login.phoneHint'.tr(),
                      validator: (String? v) => AuthValidators.phone(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('register.name'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('register_name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'register.nameHint'.tr(),
                        prefixIcon: const Icon(Iconsax.user),
                      ),
                      validator: (String? v) => AuthValidators.name(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PinInput(
                      fieldKey: const Key('register_pin'),
                      controller: _pin,
                      label: 'register.pin'.tr(),
                      hint: 'login.pinHint'.tr(),
                      validator: (String? v) => AuthValidators.pin(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PinInput(
                      fieldKey: const Key('register_confirm_pin'),
                      controller: _confirmPin,
                      label: 'register.confirmPin'.tr(),
                      hint: 'login.pinHint'.tr(),
                      validator: (String? v) =>
                          AuthValidators.confirmPin(_pin.text, v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('register.preferredLanguage'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    ChoicePills<AppLanguage>(
                      values: AppLanguage.values,
                      selected: _language,
                      label: (AppLanguage l) => l.nativeLabel,
                      onChanged: (AppLanguage l) =>
                          setState(() => _language = l),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      key: const Key('register_submit'),
                      label: 'register.submit'.tr(),
                      isLoading: auth.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Text('register.haveAccount'.tr(),
                              style: Theme.of(context).textTheme.bodySmall),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              ' ${'register.signIn'.tr()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/screens/forgot_pin_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../widgets/header_band.dart';
import '../widgets/primary_button.dart';

/// Information only. There is no self-service PIN reset on the server, so this
/// screen must not imply one exists — it explains the lockout and points at
/// the clinic instead.
class ForgotPinScreen extends StatelessWidget {
  const ForgotPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const HeaderBand(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Text('forgotPin.title'.tr(),
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.lg),
                  Text('forgotPin.body'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  PrimaryButton(
                    label: 'forgotPin.back'.tr(),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Create `mobile/lib/features/auth/presentation/screens/home_placeholder_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../controllers/auth_controller.dart';
import '../widgets/header_band.dart';
import '../widgets/primary_button.dart';

/// Placeholder shell. The real dashboard is a later slice — this exists to
/// prove the session survives a cold start with no network.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState? state = ref.watch(authControllerProvider).valueOrNull;
    final String name = state is AuthAuthenticated ? state.user.name : '';

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const HeaderBand(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'home.greeting'.tr(namedArgs: <String, String>{'name': name}),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'home.signOut'.tr(),
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Write the router wiring**

Create `mobile/lib/core/router/app_router.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_pin_screen.dart';
import '../../features/auth/presentation/screens/home_placeholder_screen.dart';
import '../../features/auth/presentation/screens/language_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../providers/core_providers.dart';
import 'redirect.dart';
import 'routes.dart';

/// Whether the first-run language choice has been made. Invalidated by the
/// language screen once the user commits.
final FutureProvider<bool> languageChosenProvider =
    FutureProvider<bool>((ref) => ref.watch(languageStoreProvider).hasChosen());

final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AuthState> auth = ref.read(authControllerProvider);
      final AsyncValue<bool> chosen = ref.read(languageChosenProvider);

      return resolveRedirect(
        location: state.matchedLocation,
        sessionResolved: !auth.isLoading && !chosen.isLoading,
        languageChosen: chosen.valueOrNull ?? false,
        authenticated: auth.valueOrNull is AuthAuthenticated,
      );
    },
    routes: <RouteBase>[
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.language, builder: (_, __) => const LanguageScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPin, builder: (_, __) => const ForgotPinScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const HomePlaceholderScreen()),
    ],
  );
});
```

> **Router refresh:** `go_router` recomputes `redirect` when its `refreshListenable` fires. Wire one by watching `authControllerProvider` and `languageChosenProvider` in the provider body and calling a `ChangeNotifier` — or, simpler and adequate for this slice, `ref.listen` both providers inside `goRouterProvider` and call `router.refresh()`. Implement whichever keeps the redirect test (Task 10) and the widget tests green; the auth-gate *logic* is already proven by `resolveRedirect`.

- [ ] **Step 7: Wire up `main.dart`**

Replace `mobile/lib/main.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales:
          AppLanguage.values.map((AppLanguage l) => l.locale).toList(),
      path: 'assets/translations',
      fallbackLocale: AppLanguage.en.locale,
      child: const ProviderScope(child: LibuCareApp()),
    ),
  );
}

class LibuCareApp extends ConsumerWidget {
  const LibuCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Libu Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(context.locale.languageCode),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
```

- [ ] **Step 8: Run the widget tests**

```bash
cd /c/src/Heart-Care-App/mobile
flutter test test/widget/
```

Expected: PASS, 6 tests.

- [ ] **Step 9: Run the whole suite and analyze**

```bash
cd /c/src/Heart-Care-App/mobile
flutter analyze
flutter test
```

Expected: `No issues found!` and every test green.

- [ ] **Step 10: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/lib mobile/test mobile/assets mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(mobile): add auth screens, shared widgets, router and app bootstrap"
```

---

### Task 12: End-to-end verification and documentation

The slice is not done until the Flutter app has authenticated against the running backend. Everything up to here was tested against stubs.

**Files:**
- Create: `mobile/README.md`
- Modify: `docs/frontend-decisions.md`

- [ ] **Step 1: Start the backend**

```bash
cd /c/src/Heart-Care-App
docker compose up -d
cd backend
mvn spring-boot:run
```

Wait for `Started HeartCareApplication`. Confirm Flyway applied `V1`–`V8`.

- [ ] **Step 2: Sanity-check the API before involving the app**

```bash
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"+251911234567","pin":"1234","name":"Abebe Bekele","preferredLanguage":"en"}'
```

Expected: `200` with `{"success":true,"data":{"token":"…","user":{…}},"message":"Registered"}`.

- [ ] **Step 3: Run the app against it**

```bash
cd /c/src/Heart-Care-App/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

- [ ] **Step 4: Walk the definition of done by hand**

These are the acceptance criteria from spec §5:

- [ ] First launch shows the language picker; choosing አማርኛ renders Amharic **without tofu boxes**
- [ ] The picker does not reappear on the next launch
- [ ] Register with a fresh `+251` number → lands on Home showing the greeting
- [ ] Register with the **same** number again → "That phone number is already registered"
- [ ] Sign out → returns to Login
- [ ] Sign in with the correct PIN → Home
- [ ] Sign in with a wrong PIN → "Invalid phone or PIN"
- [ ] **Five wrong PINs → the sixth attempt shows a wait message with a minute count, not a wrong-PIN message**, and the correct PIN is also refused during the lockout
- [ ] Kill the app, enable airplane mode, relaunch → lands on **Home** with the greeting, no sign-in prompt
- [ ] While offline, sign out then try to sign in → "You need a connection to sign in the first time"
- [ ] Entering `0911234567` on Login is rejected on the device without a network request

- [ ] **Step 5: Write `mobile/README.md`**

```markdown
# Libu Care — Flutter app

## Run

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs   # required: generated code is gitignored
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

`10.0.2.2` is the Android emulator's alias for the host machine. On a physical
device use the host's LAN address. The backend must be running
(`cd backend && mvn spring-boot:run`).

## Test

    flutter analyze
    flutter test

## Notes

- Generated files (`*.g.dart`, `*.freezed.dart`) are **gitignored**; run
  build_runner after every checkout and after changing a model or DAO.
- Amharic renders in Noto Sans Ethiopic — Poppins has no Ethiopic glyphs.
- Amharic copy in `assets/translations/am.json` is a first pass and needs
  native-speaker review before release.
- Registration is identity-only (phone, PIN, name, language). Date of birth,
  height and sex from the Figma "Personal details" frame belong to the
  patient-profile slice.
```

- [ ] **Step 6: Update the decisions log**

In `docs/frontend-decisions.md`, mark slice 1 built and record what this slice settled:

- Slice 1 Foundation & Auth: **built** (2026-09-03).
- Figma file in use for the frontend is `2ulgCN3pghwu6g4bzzi4mw`; its "Screen 2" is the 3-step medical wizard, so Create account was composed from that frame's visual system with an identity-only field set. DOB / height / sex deferred to the patient-profile slice.
- First-run language picker and Forgot-PIN info screen were built from the design system (no Figma frames exist for them).
- `preferredLanguage` is device-local for now; server ownership is decided in the patient-profile slice.
- Poppins has no Ethiopic coverage → Noto Sans Ethiopic fallback for `am`.
- Header-band and primary-button hex were colour-picked from the frame (record the final values).
- Confirm-PIN field added to Create account (not on any frame): a typo with no self-service reset is a permanent lockout.

- [ ] **Step 7: Final verification**

```bash
cd /c/src/Heart-Care-App/mobile
flutter analyze
flutter test
```

Expected: clean, all green. Record the exact test count in the PR description.

- [ ] **Step 8: Commit**

```bash
cd /c/src/Heart-Care-App
git add mobile/README.md docs/frontend-decisions.md
git commit -m "docs(mobile): record slice outcomes and app run instructions"
```

---

## Self-Review

**Spec coverage (§3 of the design doc):**

| Spec section | Task |
|---|---|
| 3.1 Scaffold, deps (`com.libucare.app`, minSdk 21, portrait, `assets/translations/`) | 1 |
| 3.2 `core/` layout (theme, router, network, db, localization, config, error, providers) | 2–6, 9, 10, 11 |
| 3.3 Theme — exact Figma tokens, Poppins, type scale, `--dart-define` default `http://10.0.2.2:8080` | 2, 3 |
| 3.4 Auth feature, three layers, offline data flow, auth gate (decode JWT `exp`), error mapping | 7, 8, 9, 10 |
| 3.5 Screens: SplashGate, Login, Create account (step 1 only), first-run language, Home placeholder, Forgot PIN | 11 |
| 3.6 Tests — unit: repository, controller, datasources; widget: Login, Create account, auth-gate redirect | 7–11 |
| §5 Definition of done | 12 |

**Deviations from the spec, and why:**
1. **Toolchain is Flutter 3.44.8 / Dart 3.12.2**, not the 3.47/3.13 the superseded plan assumed — those are the versions installed on this machine. `flutter pub add` resolves compatible package versions.
2. **Noto Sans Ethiopic fallback** — not in §3.3 (Poppins only). Poppins cannot render Ethiopic, so a bilingual app that follows §3.3 literally ships tofu for Amharic. The design font is unchanged for Latin text. Confirmed with the user.
3. **Create account is composed, not traced.** The Figma "Screen 2" is the medical wizard's step 1 (DOB / height / sex / "Step 1 of 3"). Building it verbatim would ship fields `POST /auth/register` rejects and imply a wizard that is out of scope. The screen reuses that frame's visual system with the identity-only field set. Confirmed with the user.
4. **First-run language picker and Forgot-PIN screen have no Figma frame** and are built within the design system. §3.5 lists both as "inline" / "—"; the DoD requires the language picker to persist.
5. **Confirm-PIN field** added to Create account — not on any frame, but a mistyped 4-digit PIN with no self-service reset is a permanent lockout. Client-side check only.
6. **No `ErrorMappingInterceptor`.** §3.4 describes error mapping as an interceptor; `failureFromDioException` is one pure function called by the repository, which is the same layering with one less indirection.
7. **`core/security/jwt.dart`** rather than under `router/` — the data layer needs it too, and filing it under `router/` would make the data layer import a routing concern.

**Placeholder scan:** no `TBD` / `TODO` / "add error handling" / "similar to Task N" — every code step carries its actual content. The one soft spot is Task 11 Step 6's router-refresh note, which offers two concrete implementations and gates on the existing tests rather than pinning one line; this is deliberate because the auth-gate *logic* is fully specified and tested as a pure function in Task 10.

**Type consistency:** `AuthRepository` method signatures (`login`, `register` with `AppLanguage language`, `getMe`, `cachedUser`, `hasValidSession`, `logout`) are identical across Tasks 7, 8, 9. `AuthState` / `AuthUnauthenticated` / `AuthAuthenticated` identical across Tasks 9, 11. `failureFromDioException`, `parseLockoutMinutes`, `isJwtExpired`, `buildDio` names match their definition and call sites. `AppLanguage.code` / `.nativeLabel` / `.fromCode` consistent across Tasks 6, 7, 8, 11. `CachedUsersCompanion` / `CachedUser` field names (`id`, `name`, `phone`, `preferredLanguage`, `role`) consistent across Tasks 5 and 8.

**Open items this plan deliberately does not close:**
- M-2 (token revocation) and M-3 (registration enumerates phones) remain open by decision.
- `preferredLanguage` column ownership — patient-profile slice.
- Amharic copy needs native-speaker review before release, like the clinical thresholds.
- Exact `headerBand` / `primary` hex — colour-picked in Task 2, recorded in Task 12.

