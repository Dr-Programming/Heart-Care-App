# Security Review — Backend

**Date:** 2026-07-19
**Scope:** `backend/` — all 7 merged slices (auth, patient, medication, vitals, symptoms, activity, sync), Flyway migrations V1–V7, Spring config, `docker-compose.yml`. `mobile/` has no source and was not reviewed.
**Method:** Manual read of every controller, service, repository, DTO, entity, security component, and migration. No dynamic testing.

**Remediation pass:** 2026-07-19 — H-1, M-4, M-5, L-3, L-4, L-5 fixed; suite green at 222 tests (215 before, 7 added). M-1 was fixed on 2026-08-06 alongside the phone+PIN auth change; M-2 (token revocation) remains open and is the only item now blocking a production deploy.

---

## Summary

| Severity | Count | Fixed | Open |
|---|---|---|---|
| High | 1 | 1 | 0 |
| Medium | 5 | 3 | 2 |
| Low | 6 | 3 | 3 |
| Verified good | 8 | — | — |

The core authorization model is sound: **every** query is scoped by `user_id`, entities never reach the wire (all responses are DTO records), and the sync engine re-validates payloads it deserializes by hand. The one High finding was a deployment-configuration hazard, not an application-logic flaw.

---

## High

### H-1 — Dev profile is the default, and it ships a hardcoded JWT signing secret — ✅ FIXED

`application.yml:5` sets `profiles.active: ${SPRING_PROFILES_ACTIVE:dev}` — if that env var is unset, the **dev** profile activates. `application-dev.yml:8` then supplies:

```yaml
app:
  jwt:
    secret: ${JWT_SECRET:dev-only-secret-change-me-please-32bytes-minimum}
```

`application.yml:18` correctly declares `secret: ${JWT_SECRET}` with **no** default so startup fails loudly when the secret is missing — but the dev profile's default silently overrides that safety. A deploy that forgets `SPRING_PROFILES_ACTIVE` boots happily and signs every token with a secret that is public in this repo. Anyone reading the repo can forge a token for any `userId` and read or write that patient's entire health record.

The dev datasource points at `localhost:5432`, which looks like it would prevent a bad boot — it does not. A platform-supplied `SPRING_DATASOURCE_URL` env var takes precedence over the YAML value, so on Railway the app connects to the real database while still using the fallback secret.

**Fixed by:**
- Removed the `:dev-only-...` default from `application-dev.yml`. No profile now supplies a secret, so the app is fail-closed: a deploy that forgets `JWT_SECRET` cannot start.
- `JwtTokenProvider` now rejects a secret under 32 bytes at construction with an actionable message, covering the remaining case of a secret that is set but worthless.
- Tests run under the default `dev` profile and relied on that fallback, so `src/test/resources/application-dev.yml` shadows the dev profile on the **test classpath only** — a usable default never exists in a deployable artifact.
- `.env.example` and `backend/README.md` now state that `JWT_SECRET` must be exported (docker-compose reads `.env`; `mvn spring-boot:run` does not).

**Verified:** booting with `JWT_SECRET` and `SPRING_PROFILES_ACTIVE` both unset fails with `PlaceholderResolutionException: Could not resolve placeholder 'JWT_SECRET'` — confirmed by running it, not by inspection.

---

## Medium

### M-1 — No rate limiting or lockout on `/api/v1/auth/login` — ✅ FIXED (2026-08-06)

`AuthService.login` is unthrottled. BCrypt's work factor slows an offline crack but does nothing against an online attacker pacing requests. For a health record system this is the highest-value unauthenticated endpoint. Add per-IP and per-account throttling (bucket4j, or a gateway rule).

Left open deliberately: every option adds a dependency (bucket4j / Redis) or a platform rule, which is a decision about deployment shape rather than a code fix.

**Fixed 2026-08-06** (`feature/phone-pin-auth`). Per-account lockout held in `users`
(`failed_login_attempts`, `locked_until`): 5 consecutive failures → 15 minutes, cleared by any
successful login or by the window elapsing. Configured at `app.auth.lockout.*`. The counter is
incremented by a single atomic `UPDATE` so parallel guessing cannot lose increments, and
`login` is annotated `noRollbackFor` so the rejection does not roll the increment back. No new
dependency (no bucket4j, no Redis). Locked logins return `423`.

This is per-account, not per-IP: it stops PIN guessing against a known phone number, which is the
threat a 4-digit PIN creates. A distributed attack spraying one PIN across many accounts is not
covered and needs an edge/gateway rule.

The move to a 4-digit PIN (same change) is what made this urgent rather than merely advisable: the
keyspace is 10,000, so an unthrottled endpoint would be exhaustible in minutes.

**Residual risks, accepted by the owner on 2026-08-06 — the fix is not risk-free and these were
not closed silently:**

1. **`423` is an account-enumeration oracle.** A locked account answers `423` where an unregistered
   phone answers `401`, so five deliberate wrong PINs tell an attacker whether a phone is
   registered — defeating, for that phone, the generic `"Invalid phone or PIN"` message. Accepted
   because registration already leaks the same fact through `409 "Phone already registered"`
   (M-3, still open), so `423` adds no capability an attacker lacks; and because a patient who is
   locked out needs to be told *"try again in 15 minutes"* rather than *"wrong PIN"*, which is the
   whole point of a distinct code. Closing this properly means fixing M-3 first — at which point
   the `423`/`401` split should be revisited in the same pass.

2. **Lockout is a denial-of-service primitive.** Anyone who knows a patient's phone number can lock
   that account for 15 minutes at will, repeatedly, and a patient locked out of a CHD app cannot
   log a symptom or check a medication schedule. Accepted as the inherent cost of *any* per-account
   lockout: the alternative (per-IP throttling) does not protect a 4-digit PIN against an attacker
   who can change IP. The offline-first design blunts it — the device holds a 7-day token and its
   own local database, so an already-logged-in patient keeps working through a lockout and the
   attack only bites at re-login. Revisit if abuse appears in the field; the fix is an edge rule,
   not an app change.

3. **A lockout does not revoke tokens already issued.** Lockout gates `POST /auth/login` only, so a
   session opened before the lock survives it — a stolen phone with a live token is unaffected by
   locking the account. This is correct per the spec (the lock exists to stop *guessing*, not to
   terminate sessions) but it means "lock the account" is not a containment action for a
   compromised device. That gap is M-2's, not M-1's: it disappears the moment token revocation
   exists.

### M-2 — Tokens live 7 days with no revocation path — ⚠️ OPEN (needs your call)

`application.yml:19` sets `expiration-ms: 604800000`. There is no refresh token, no logout, no deny-list, and no server-side session. A token lifted off a shared phone stays valid for a week, and a password reset cannot invalidate it. The offline-first design justifies a long-ish life, but pair it with a short access token + refresh token, or at minimum a `token_version` claim checked against the user row.

Left open deliberately: a refresh-token flow changes the mobile client's auth contract, and the Flutter side is unwritten — better decided together with it than retrofitted now.

Raised in impact by the 2026-08-06 auth rework: the login lockout added for M-1 gates `POST /auth/login` only, so locking an account does not end sessions already open on it. Until this is fixed there is **no** way to contain a compromised device short of waiting out the 7-day token. A `token_version` claim would make both a PIN change and an account lock revoke live tokens.

### M-3 — Account enumeration on registration — ⚠️ OPEN (accepted tradeoff?)

`AuthService.register` returns `409 "Phone already registered"`. Login is correctly generic (`"Invalid phone or PIN"` for both branches — good), but register leaks which phone numbers have accounts. For a CHD patient app, mere account existence is sensitive. Consider a generic 202 + an SMS confirmation step, or accept the tradeoff explicitly.

Unchanged by the 2026-08-06 phone+PIN rework: the identifier is now a phone number rather than an email, but the leak is the same shape. Still open.

### M-4 — CORS allows all origins — ✅ FIXED

`CorsConfig.java:17` set `setAllowedOriginPatterns(List.of("*"))`. `allowCredentials` was `false`, so cookies were not exposed and the practical risk was limited (auth is an `Authorization: Bearer` header a foreign page cannot mint). Still, the comment said "tighten for prod" while nothing enforced it, and there is no prod override file — so the permissive value was what shipped.

**Fixed by:** origins now come from `app.cors.allowed-origins` (`CORS_ALLOWED_ORIGINS`), defaulting to `http://localhost:*`. The wildcard is gone from the code entirely. Worth noting the default is safe rather than merely convenient: the Flutter client is a native app, and CORS is not enforced by native HTTP clients at all, so a restrictive default costs the real client nothing.

### M-5 — Request body size is unbounded; batch cap applies too late — ✅ FIXED

`SyncService.sync:55` rejects batches over `max-batch-size: 200`, but only *after* Spring has fully deserialized the JSON into `List<SyncRecord>` with arbitrary `JsonNode` payloads. Tomcat's `maxPostSize` does not apply to `application/json`. A single request with a multi-hundred-megabyte body could exhaust heap before the guard ran.

**Fixed by:** new `RequestSizeLimitFilter` at `HIGHEST_PRECEDENCE` (ahead of authentication, so the cost is bounded for unauthenticated callers too), capping bodies at `app.sync.max-body-bytes` = 2 MB and returning 413. It checks `Content-Length` first, then wraps the input stream to count bytes — because a chunked request declares no `Content-Length` and a header-only check would be trivially bypassable. Both paths are covered by tests.

---

## Low

### L-1 — No composite FK tying `dose_logs.user_id` to `medications.user_id` — ⚠️ OPEN

`V4__create_dose_logs.sql` has separate FKs to `users` and `medications`. Nothing at the database level prevents a dose log referencing user A while pointing at user B's medication. Application code does enforce it (`DoseLogService.log` calls `findByIdAndUserId` first, and `DoseLogSyncHandler.resolveMedicationId` resolves client record IDs within the user's own rows), and a regression test covers cross-user isolation — but the invariant is app-only. A `UNIQUE (id, user_id)` on `medications` plus a composite FK would make it structural.

Left open: requires a migration (`V8__`) adding `UNIQUE (id, user_id)` on `medications` plus a composite FK. Defensible to do, but it is a schema change to close a gap that application code and a regression test already cover — worth batching with the next migration rather than shipping alone.

### L-2 — `role` claim is trusted from the token without a user lookup — ⚠️ OPEN (revisit with CLINICIAN)

`JwtAuthFilter:39-44` builds authorities straight from the JWT. A role downgrade or account deletion has no effect until the token expires (see M-2). Currently harmless — the app is patient-only and no endpoint uses `@PreAuthorize`/`hasRole` — but it becomes a real privilege issue the moment CLINICIAN endpoints land.

### L-3 — Malformed subject in a validly-signed token throws inside the filter — ✅ FIXED

`JwtAuthFilter:38` called `UUID.fromString(...)` unguarded. A signed token with a non-UUID `sub` raised `IllegalArgumentException` from a filter, bypassing `GlobalExceptionHandler` and yielding a container error page instead of a 401. An absent `role` claim separately produced the authority `ROLE_null`.

**Fixed by:** claim handling extracted to `JwtAuthFilter.authenticate`, which returns without authenticating on either a non-UUID subject or a missing/blank role — yielding a clean 401 from the entry point. Both cases have regression tests that sign real tokens with the live key so they exercise the post-validation path.

### L-4 — Password policy is length-only — ✅ FIXED (partially)

`RegisterRequest` enforced `@Size(min = 8)` and nothing else.

**Fixed by:** `@Size(min = 8, max = 72)`. The upper bound is the substantive part — BCrypt silently truncates at 72 bytes, so a longer passphrase was weaker than the user believed. A breach-list check (e.g. HIBP k-anonymity) is still not implemented; it needs an outbound network call, which is a poor fit for this deployment.

### L-5 — `PatientService.upsertProfile` has an unhandled insert race — ✅ FIXED

`PatientService:33-35` did `findById(...).orElseGet(new PatientProfile(userId))` then `save`. Two concurrent first-time upserts both saw empty, both inserted the same PK, and one got a `DataIntegrityViolationException` → 500.

**Fixed by:** routing the create-if-absent step through `IdempotentSaver`, the same idiom the log services use — the loser of the race re-reads the winner's row instead of failing. The method is now non-`@Transactional` for the reason documented in `IdempotentWriter`: the insert must run `REQUIRES_NEW` or the violation poisons the caller's persistence context. Last-write-wins between two concurrent *updates* is unchanged, matching the documented conflict policy.

### L-6 — Rejection reasons echo internal detail to the client — ⚠️ OPEN (no action needed)

`SyncService.process:87` returns `e.getMessage()` verbatim in `SyncResult.reason` (e.g. `"Medication not found for clientRecordId <uuid>"`). Messages are all developer-authored and user-scoped, so no cross-tenant leak — noted only because the pattern would leak if a future exception embedded query or schema detail. Generic exceptions are already correctly masked (`GlobalExceptionHandler:57`).

---

## Verified good

These were specifically checked and are correct:

1. **`@JsonIgnore` on `User.passwordHash`** (`User.java:28`) — and, more importantly, no entity is ever returned from a controller. Every response is a hand-mapped DTO record (`UserResponse`, `MedicationResponse`, …), so the hash has no serialization path even without the annotation. Defense in depth, correctly applied.
2. **No SQL injection.** Every query is a derived Spring Data method or a `@Query` with `@Param` binding. No string concatenation, no `nativeQuery` with interpolation anywhere.
3. **No IDOR.** Every read and write is scoped by `userId` taken from `@AuthenticationPrincipal`, never from a request parameter. Mutations use `findByIdAndUserId`; `PatientProfile` is keyed by `user_id` as its PK so `findById(userId)` is inherently scoped.
4. **BCrypt for password storage** (`PasswordEncoderConfig`), not a raw hash.
5. **Correct deny-by-default authorization.** `SecurityConfig:34-35` permits only `register` and `login`; `anyRequest().authenticated()`. Sessions are `STATELESS` and CSRF disabled — the right combination for a token API with no cookies.
6. **ACID / transaction handling is deliberate and correct.** The non-`@Transactional` service write paths are not an oversight: `IdempotentWriter.insert` runs `REQUIRES_NEW` so a `UNIQUE` violation can be caught without poisoning the caller's persistence context, and `IdempotentSaver` re-reads the winner's row. `SyncService` is intentionally non-transactional so one bad record cannot roll back its neighbours — each handler call commits alone. Reads are `@Transactional(readOnly = true)`. `IdempotentSaver` correctly rethrows when the finder cannot locate a row, so an unrelated constraint violation is never swallowed as an idempotent hit.
7. **Idempotency is enforced by the database**, not by application check-then-act: `UNIQUE (user_id, client_record_id)` on all five log tables. The app-level pre-check is an optimization; correctness holds under concurrency. Note that `client_record_id` is nullable and Postgres permits multiple NULLs — so direct POSTs without a key are deduplicated by nothing. That is by design (the sync path requires the key via `@NotNull`).
8. **Sync payloads are re-validated.** `SyncPayloadMapper` invokes the Jakarta `Validator` by hand because `@Valid` does not fire on a hand-deserialized `JsonNode` — a genuine bypass that was correctly anticipated. `SyncRecord.clientRecordId` is authoritative and overwrites any value inside the payload, so a client cannot claim another record's key. Vitals/symptoms/activity JSONB maps are strictly key-whitelisted and range-checked, and server-computed fields (`bmi`, `assessment`, `flagged`) are stripped from client input rather than trusted.

No secrets are committed: `git ls-files` turns up only `.env.example` with placeholders.

---

## Not assessed

- **Transport security.** No HTTPS enforcement, HSTS, or `server.ssl.*` in the app; TLS is presumably terminated by Railway. Confirm the platform redirects HTTP→HTTPS — health data over cleartext on Ethiopian mobile networks would be the single worst exposure here, and it is invisible from inside this codebase.
- **Dependency CVEs.** No SCA run. Spring Boot 4.1.0 and jjwt 0.12.6 are current as of this review; add `mvn dependency-check` or Dependabot to keep it that way.
- **Data at rest.** No column-level encryption on PHI (`disease_history`, `symptom_logs.data`, …). Whether that is required depends on the deployment's regulatory posture, which is out of scope for a code review.
- **Audit logging.** There is none — no record of who read or wrote a patient record. Likely a compliance gap for a clinical system.

---

## Remaining work

Blocking a production deploy:

1. **M-2 — token lifetime and revocation.** Best decided alongside the Flutter auth flow, which is unwritten; a `token_version` claim checked against the user row is the cheapest option that makes a PIN reset meaningful.
2. **Confirm HTTPS enforcement at the platform edge.** Not visible from this codebase and outranks everything above in impact.

Worth doing, not blocking:

3. M-3 — decide whether registration enumeration is an accepted tradeoff, and record it either way.
4. L-1 — composite FK on `dose_logs`; batch with the next migration.
5. L-2 — re-check the trusted `role` claim the moment CLINICIAN endpoints are added.

## Changes made in the remediation pass

| File | Change |
|---|---|
| `application-dev.yml` (main) | Removed the JWT secret default; documented why it must stay absent |
| `application-dev.yml` (test, new) | Test-classpath-only secret so the suite runs without a deployable default existing |
| `application.yml` | Added `app.cors.allowed-origins`, `app.sync.max-body-bytes`, header/multipart caps |
| `JwtTokenProvider` | Rejects secrets under 32 bytes at construction |
| `JwtAuthFilter` | Guards non-UUID subject and missing role; extracted `authenticate` |
| `CorsConfig` | Configurable origins, wildcard removed |
| `RequestSizeLimitFilter` (new) | 413 on oversized bodies; Content-Length check + counting stream wrapper |
| `RegisterRequest` | `@Size(max = 72)` for BCrypt truncation |
| `PatientService` | Create-if-absent via `IdempotentSaver` |
| `.env.example`, `backend/README.md` | `JWT_SECRET` now mandatory and must be exported; documented `CORS_ALLOWED_ORIGINS` |
| Tests | +7: weak/null secret rejection, bad-subject and missing-role tokens, three size-limit cases; `PatientServiceTest` updated for the new collaborator |
