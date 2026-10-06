# Research: Security Screen, Change Password, and Platform Config Normalization

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

Evidence was gathered on 2026-10-06 on `master` (`4e1db0f`) with Flutter 3.47.5 /
Dart 3.13.4, `supabase_flutter 2.16.0` (`gotrue 2.26.0`, `supabase 2.14.0`),
`go_router 14.8.1`, `flutter_riverpod 2.6.1`. The platform-config findings come
from real builds (iOS Simulator and Android debug) on a clean tree.

## Decision 1 — Verify the current password on a temporary session over plain REST; update on that session; hand it to the app; then end any other session

**Decision**: Changing the password is one service operation with this
sequence:

0. **Confirm this device's own session** is still valid by refreshing it
   (`AuthRepository.verifySessionAlive()`, the same call the biometric unlock
   already makes), capped at 8 seconds. A revoked or expired session fails here,
   before anything is changed (spec scenario 10 / edge case "session no longer
   valid"); gotrue emits `signedOut` for an invalid refresh token, so the app's
   existing redirect takes the person to sign in. Because gotrue's `_doRefresh`
   removes the local session and emits `signedOut` for **every** refresh failure
   except `AuthRetryableFetchException` (HTTP 5xx and network errors), including
   a 429, any such failure at step 0 is reported as `sessionExpired`, not
   `rateLimited`: the device has already been signed out. The 8-second cap
   exists because gotrue retries a refresh with backoff for up to ~30 s while
   offline (measured: the form spun for 30 s before saying "no connection");
   the timeout surfaces as `TimeoutException`, which reads as offline.
1. **Sign a temporary session in over plain HTTP** — `POST /auth/v1/token?grant_type=password`
   with the signed-in user's email and the **current** password, the project
   URL and the publishable key (`SupabaseAuthRest`, using the `http` package;
   no second `GoTrueClient`). `invalid_credentials` ⇒ "wrong current password";
   nothing changed.
2. On that fresh session, `PUT /auth/v1/user {password}`. **The server then
   revokes every OTHER session of the account** (measured, below) — this
   device's old session included — and keeps only the session that did the
   update.
3. **Hand the temporary session to the app**: `GoTrueClient.setSession(refreshToken)`
   on the app's own client refreshes it, stores it and emits an ordinary
   `tokenRefreshed`. This device now continues on that valid session. If the
   hand-over fails the temporary session is revoked (`POST /logout?scope=local`)
   and the outcome is `changedOthersNotEnded` (the change stands).
4. On the app's own client call `signOut(scope: others)` to end any session the
   server did not already end — a safety net that is a no-op against today's
   server. **Guarded**: `GoTrueClient.signOut` ignores 401/403/404 from the
   admin endpoint (`_signOut` in `gotrue_client.dart`, lines 1000-1009), so with
   scope `others` a stale access token would return normally and end nothing;
   the repository throws `AuthSessionMissingException` when `currentSession` is
   null or expired instead, and the service reports `changedOthersNotEnded`.

**Measured against the real service** (QA account, public API only, passwords
restored afterwards):

- *Updating a password revokes every other session.* With two sessions U and O,
  `PUT /user` from U returned 200; then refreshing O failed with
  `400 refresh_token_not_found` while U still refreshed. The first design
  updated the password on the temporary session and then closed it, which
  left the account with **no** session at all: this device was signed out right
  after a successful change (FR-005 violated). Step 3 exists because of this.
- *A second `GoTrueClient` is not isolated on web.* gotrue starts a
  `BroadcastChannel` named after the project in every client it constructs, and
  a client that receives a broadcast saves (or removes) the session it carries
  (`_mayStartBroadcastChannel`). A throwaway client therefore made the app's own
  client adopt the temporary session at sign-in and drop it at sign-out — in the
  browser, the "isolated" client could sign the app out. Plain HTTP has no
  channel, storage or events, so nothing can leak on any platform.

**Rationale**:

- *No side effects on the app's session.* The app's `authStateChangesProvider`
  drives the router, the app lock, the sync pull and the biometric offer. The
  temporary session emits nothing the app listens to; the only event the app
  sees is the hand-over's ordinary `tokenRefreshed` (the same event an hourly
  refresh produces; `AppLockNotifier` ignores everything after the first event,
  and `isSignedInProvider`'s value does not change).
- *Works with Supabase's "secure password change" setting.* When that dashboard
  option is on, a password update is rejected with `reauthentication_needed`
  unless the updating session is recent. The temporary session was created
  seconds ago, so it satisfies the rule without an email OTP, whichever way the
  option is set — and, because it is the session the app then adopts, this
  device is not penalised for having an old session.
- `AuthRepository.signOut(scope)` already exists; only the `local` scope clears
  the biometric preference (`clearBiometricLoginState`), so none of the steps
  above touches FR-009.
- *Dependency.* `http` 1.6.0 (dart-lang, BSD-3, no platform permissions) was
  already in the graph through `supabase`/`gotrue`; it becomes a direct
  dependency with the same locked version, so no new code is pulled in
  (constitution dependency hygiene reviewed).

**Alternatives considered**:

| Alternative | Why rejected |
|---|---|
| A second `SupabaseClient`/`GoTrueClient` as the temporary session | Not isolated on web (shared `BroadcastChannel`, see above); also spawns a JSON isolate per client. |
| Update the password on the app's own session after verifying the password elsewhere | Fails with `reauthentication_needed` when "secure password change" is on and this device's session is older than the recency window. |
| Close the temporary session after the update (the first design) | The server revokes all other sessions on update, so this device is signed out too (measured). |
| Re-sign-in on the main client with the new password | Emits `signedIn`, restarts the pull, may trigger the biometric offer and router refresh; the sign-in timing bugs found in #26 show how fragile that path is. |
| `reauthenticate()` + emailed nonce | Asks the person for an email OTP on every change; heavier than the spec's "current password" requirement. |
| Call the update without verifying the current password | Violates FR-004; an unattended unlocked device could change the credential. |

## Decision 2 — Partial failure: the password changed but ending other sessions failed

**Decision**: Step 4 failing after step 2 succeeded is reported as **success
with a notice**, not as a failure: "Đã đổi mật khẩu, nhưng chưa đăng xuất được
các thiết bị khác." plus a **Thử lại** button on the Security screen. The service
returns `ChangePasswordOutcome.changedOthersNotEnded`; the form is cleared and
the person stays signed in. The button calls
`ChangePasswordService.signOutOtherDevices()` (session check + end other
sessions, returning a `ChangePasswordResult`) so that single step can be
repeated without changing the password again; a failed retry shows the mapped
error text in a SnackBar so it is never silent. Failures before step 2 leave the password unchanged and keep the entered
values on retryable errors (offline, 5xx, rate limit).

**Rationale**: the credential is already changed; telling the person it failed
would make them retry with a "current password" that no longer works. The
remaining exposure is the very case a password change exists for (a device that
should be locked out), so the notice must not be a dead end: without a retry the
only remedy would be changing the password a second time to a *different* value
(the client rejects reusing it). The retry reuses `endOtherSessions`, so it adds
one small controller and no new service call. The notice lives while the
Security screen is open; leaving drops it (the next password change still ends
the sessions). No background queue is added.

## Decision 3 — A separate `PasswordChangeGateway` interface, not an extension of `AccountAuthActions`

**Decision**: Add two small interfaces in `lib/core/auth/`:

```dart
abstract interface class PasswordChangeGateway {
  /// Refreshes this device's own session; throws if it was revoked/expired.
  Future<void> ensureSessionActive();

  /// Signs a temporary session in (plain REST) with the current password.
  /// Throws AuthApiException(invalid_credentials) when it is wrong.
  Future<VerifiedPasswordSession> verifyCurrentPassword(String currentPassword);

  /// Ends every session of the account except this device's; throws instead
  /// of silently doing nothing when this device has no live access token.
  Future<void> endOtherSessions();
}

abstract interface class VerifiedPasswordSession {
  Future<void> setNewPassword(String newPassword);
  /// Hands the temporary session to the app so this device stays signed in
  /// (the server revoked every other session when the password changed).
  Future<void> continueOnThisDevice();
  /// Revokes the temporary session unless it was handed over; never throws.
  Future<void> close();
}
```

`AuthRepository` implements `PasswordChangeGateway` (it already wraps the
Supabase auth client; the temporary REST session is created inside it from
`AppEnvironment`). A `ChangePasswordService` in `features/account/application/`
orchestrates the sequence from Decision 1 against these interfaces, so the
ordering and every failure branch are unit-testable with fakes and no SDK.

**Rationale**: four existing tests implement `AccountAuthActions` fakes
(`app_shell_nav_bar_test`, `app_shell_discard_prompt_test`,
`overview_screen_test`, `account_screen_test`); widening that interface would
break them for no reason (interface segregation). The constitution requires
third-party SDKs behind an abstraction so the flow is unit-testable without a
live Supabase client; the temporary-session construction hides behind the
gateway.

**Alternatives considered**: adding the methods to `AccountAuthActions` (forces
fake changes in 4 files); putting the sequence inside `AuthRepository` (mixes
orchestration and SDK calls, hard to test the ordering).

## Decision 4 — One `PasswordPolicy` (8 characters), reused by sign-up, reset and change

**Decision**: Add `lib/features/account/domain/password_policy.dart` (pure
Dart): `minLength = 8`, `meetsMinimum`, `differsFrom`, `matches`. Sign-up's
`SignUpValidation.isPasswordValid` delegates to it; the reset screen gains the
missing length check; the change-password form uses it. Length is counted in
characters (Unicode code points via `runes.length`) exactly as typed (no trim, no
composition rules). Code points is the most lenient common unit, so the client
rule is never stricter than a server minimum counted in bytes or UTF-16 units
(any password with ≥ 8 code points has at least as many of either); the
server stays the backstop for other clients. Strings: replace
`signUpPasswordTooShortError` (currently "…ít nhất 6 ký tự") by a generic
`passwordTooShortError` ("Mật khẩu phải có ít nhất 8 ký tự." / "Password must be at
least 8 characters.") and add a visible hint `passwordRequirementHint` shown as
helper text under every password-setting field (FR-015: visible before typing).

**Evidence** that today only sign-up enforces a length: `isPasswordValid` is
referenced only from `sign_up_screen.dart`; `reset_password_screen.dart` checks
`isConfirmPasswordValid` only; `sign_in_screen.dart` checks nothing. Sign-in
stays untouched.

**Rationale**: a single constant removes the drift that produced the current
inconsistency; `domain/` pure Dart keeps the rule unit-testable and satisfies
the architecture test (`domain` may not import Flutter/Supabase/Riverpod).

## Decision 5 — Server-side minimum is an external, owner-run setting; verify it with a request

**Decision**: The repository has no `supabase/config.toml`; the hosted
project's minimum password length (default 6) lives in the dashboard
(Authentication → password settings). Tasks list it as an `[EXT]` owner action,
and `quickstart.md` verifies it by sending a sign-up request with a 7-character
password directly to the Auth API and expecting HTTP 422 `weak_password`. The
client check (Decision 4) stops the same input before any request, so the
server rule is the defense in depth against other clients.

**Status (2026-10-06)**: the owner raised the minimum to 8 in the dashboard and it was
verified with the request above: HTTP 422, `error_code: weak_password`, message
"Password should be at least 8 characters.", no account created. The `[EXT]`
task is therefore already done and only needs re-checking at the end.

**Alternatives considered**: adding a `config.toml` for `supabase config push`
(introduces CLI setup the project does not use); relying on client checks only
(bypassable).

## Decision 6 — Error mapping

**Decision**: One mapping table for message **text**: extend the shared
`mapErrorToMessage` for the codes the change flow can now produce. The service
only classifies *where* a failure belongs (`ChangePasswordOutcome`) and carries
the raw error in `ChangePasswordResult`; the controller then resolves the text
with `mapErrorToMessage(result.error, l10n)`, so there is no second message
table. The one context-specific case stays in the controller:

| Source | Code / type | Message (vi / en intent) |
|---|---|---|
| Verify step | `AuthApiException` `invalid_credentials` | **controller-specific**: "Mật khẩu hiện tại không đúng." (the shared message talks about email+password and would mislead) |
| Update step | `same_password` | "Mật khẩu mới phải khác mật khẩu hiện tại." (also pre-checked client-side) |
| Update step | `AuthWeakPasswordException` / `weak_password` | existing `errorMapperWeakPassword`, copy updated to mention the 8-character minimum |
| Verify and update steps | `over_request_rate_limit` (sign-in throttling, HTTP 429; at the session-check step it is `sessionExpired`, see Decision 1) | existing `errorMapperRateLimited` ("Bạn đã thử quá nhiều lần…", already generic; only the code mapping is added) |
| Any step | `session_expired` / `session_not_found` / `reauthentication_needed` / `bad_jwt` / `refresh_token_not_found` / `refresh_token_already_used` / `AuthSessionMissingException` | new `errorMapperSessionExpired`; the redirect to sign-in comes from gotrue's `signedOut` event on an invalid refresh token, not from the screen (Edge Case "session no longer valid") |
| Any step | `SocketException`, `TimeoutException`, `AuthRetryableFetchException` | existing network message; values kept |
| Step 4 only | any | `changedOthersNotEnded` notice (Decision 2) |

Codes exist in `gotrue 2.26.0` `ErrorCode` (`samePassword`, `weakPassword`,
`overRequestRateLimit`, `sessionExpired`, `sessionNotFound`,
`reauthenticationNeeded`, `badJwt`); `invalid_credentials`, `refresh_token_not_found`
and `refresh_token_already_used` have no constant, so the literal wire strings
are compared as the existing mapper already does. The sign-in, sign-up and email
reset flows gain the friendlier messages for free (`over_request_rate_limit` is
what sign-in throttling returns).

## Decision 7 — Routes and navigation

**Decision**: Two nested routes under the existing `/account` branch:
`/account/security` (Security screen) and `/account/security/change-password`
(form, a pushed sub-screen with the shell chrome kept). The Hồ sơ row calls
`context.go('/account/security')` — `push` was tried first and, verified on web,
leaves the address bar on `/account`, so the screen could not be bookmarked or
reloaded; `/account/security` is a child of `/account`, so Back still returns to
Hồ sơ. The change-password form is opened with `push` because the Security screen
awaits its result; `AccountPlaceholderFeature.security` is
removed from the enum (and its switch arm) — notifications and help keep their
placeholders. After a successful change the form shows its confirmation and
`pop`s back to the Security screen where a transient confirmation is shown.

**Rationale**: matches the existing nested-route convention
(`/account/placeholder/:feature`), gives every screen a real URL on web, and
keeps back-stack behavior identical to the other Hồ sơ destinations.

**Alternatives considered**: an inline form on the Security screen (long form +
keyboard on small screens, harder to test); a dialog (poor for three fields,
autofill and accessibility).

## Decision 8 — Biometric toggle: explicit availability and honest state

**Decision**:

- Add `BiometricAvailability { available, webUnsupported, noHardware, notEnrolled }`
  and `Future<BiometricAvailability> availability()` to
  `BiometricLoginRepository`: web ⇒ `webUnsupported`; `!isDeviceSupported` ⇒
  `noHardware`; no entries from `getAvailableBiometrics()` ⇒ `notEnrolled`;
  otherwise `available`. The existing `isDeviceCapable()` stays unchanged for
  the sign-in screen and the post-sign-in offer.
- A `SecurityController` (`StateNotifier<SecuritySettings>`) holds `{availability, enabled}`. The switch is
  **on** only when `enabled && availability == available`. Enabling = `authenticate()`
  → on success `setBiometricLoginEnabled(true)`; cancel/failure leaves it off
  (FR-007); disabling = `setBiometricLoginEnabled(false)` immediately.
- If `enabled` but availability is no longer `available` (enrollment removed),
  the switch shows off + disabled with the reason, and the stored preference is
  not rewritten (the sign-in screen's existing logic stays the one place that
  clears it).
- Availability is re-read when the screen opens and on app resume
  (`AppLifecycleListener`), so removing enrollment in system settings is
  reflected when the person comes back.
- Explanations (all localized): web, no hardware, not enrolled.

**Rationale**: `local_auth.canCheckBiometrics` cannot distinguish "no hardware"
from "none enrolled"; the spec requires a specific reason (FR-008).

## Decision 9 — Screen design (no mockup exists)

**Decision**: Follow the Hồ sơ patterns.

- **Security screen**: app bar with back + `shieldCheck` badge (like other
  sub-screens), `AdaptiveBody` capped width, a grouped card with two rows:
  **Đổi mật khẩu** (`keyRound`, chevron → sub-screen) and **Đăng nhập bằng vân
  tay** (`fingerprint`, a `Switch` with an optional caption explaining why it is
  disabled). The row/card widgets (`_MenuCard`, `_MenuRow`) are currently private
  to `account_screen.dart` and `_MenuCard` is hard-wired to the three Hồ sơ rows
  while `_MenuRow` always ends in a chevron; generalize them into
  `presentation/widgets/account_menu.dart` — `AccountMenuCard(children)` and
  `AccountMenuRow(trailing, caption, nullable onTap)` with the same paddings,
  border and text styles — so Hồ sơ looks identical and the Security screen
  reuses them for its `Switch` row (no duplicated styling). An inline
  other-devices notice with a **Thử lại** button sits above the card (Decision 2).
- **Change-password screen**: three password fields (current, new, confirm), each
  with a show/hide `IconButton` (`eye`/`eyeOff`, tooltip + semantic label), the
  8-character hint as helper text under the new-password field, inline errors,
  a primary "Đổi mật khẩu" button with a spinner and single-flight guard, and a
  success state.
- **Hygiene**: `AutofillGroup` with `AutofillHints.password` (current) and
  `AutofillHints.newPassword` (new, confirm); `autocorrect: false`,
  `enableSuggestions: false`; controllers disposed and cleared on leave; no
  `print`/logging of any value; the screen never renders a password it did not
  just receive from the person.
- **Icons**: `keyRound`, `fingerprint`, `shieldCheck`, `eye`, `eyeOff`,
  `chevronRight`, `chevronLeft` — all exist in `lucide_flutter` and go through
  `app_icons.dart`; nothing is drawn or edited.
- **Adaptive/a11y**: ≥ 48 dp targets, keyboard focus order top→bottom with
  Enter submitting the last field, hover tooltips, semantics labels, both
  appearances, compact and expanded widths.

## Decision 10 — Platform configuration: canonical form of the tracked files (US4)

**Measured** (clean tree, then `flutter build ios --simulator --debug` and
`flutter build apk --debug`, web builds earlier):

| File | What the toolchain changes | Verdict |
|---|---|---|
| `ios/Flutter/Debug.xcconfig`, `Release.xcconfig` | adds `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.<mode>.xcconfig"` | commit canonical |
| `ios/Runner.xcodeproj/project.pbxproj` | +142 lines: CocoaPods integration (`Pods_Runner`/`Pods_RunnerTests` frameworks, "[CP] Check Pods Manifest.lock", "[CP] Embed Pods Frameworks"), Swift Package Manager integration (`FlutterGeneratedPluginSwiftPackage`), and **`IPHONEOS_DEPLOYMENT_TARGET` 13.0 → 15.0 in all three build configurations** | commit canonical; see below |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | adds a `PreActions` "Run Prepare Flutter Framework Script" | commit canonical |
| `ios/Runner.xcworkspace/contents.xcworkspacedata` | adds `group:Pods/Pods.xcodeproj` | commit canonical |
| `android/gradle.properties` | adds `android.builtInKotlin=false` and `android.newDsl=false` (Flutter 3.47 migrator opt-outs) | commit canonical |
| web (`web/*`) | none | verify unchanged |

**Deployment target**: the spec said the config change must not alter
deployment targets, but the toolchain itself rewrites 13.0 → 15.0 on every iOS
build as part of Flutter's own project migration for this plugin set and Flutter 3.47;
the toolchain does not let a 13.0 value stand (not separately proven by building
with 13.0 forced). Committing 15.0 makes the file
describe reality and stops the churn. The app is unreleased, so no user on iOS
13/14 is affected. **This is a planning finding that amends FR-012** (identifier,
signing and permissions stay untouched; the deployment target becomes 15.0) and
was accepted by the owner on 2026-10-06.

**Coherence with #27**: the pbxproj references CocoaPods, but `ios/Podfile` and
`Podfile.lock` stay ignored: Flutter regenerates the Podfile from its template
and runs `pod install` on every iOS build (observed: "Running pod install…"), so
a machine with CocoaPods installed builds from a clean checkout. This is
exactly why CocoaPods is a documented prerequisite (Decision 11).

**Idempotence check** (SC-007): after committing the canonical files, a second
build for each platform must leave `git status` clean; the tasks include that
verification on a clean clone.

## Decision 11 — One documented setup, with the runtime keys tested

**Decision**:

- Rewrite the README "Getting Started" into one section: supported toolchain
  (Flutter 3.41+ — the first Flutter with Dart 3.11, verified on 3.47.5; Dart
  `^3.11.0`), per-platform prerequisites and the exact steps found in this
  verification: **Android** needs a JDK 17–24 (21 recommended; Gradle 8.14), and
  when Android Studio's bundled JDK is newer, `flutter config --jdk-dir <jdk21>`
  (symptom text quoted); **iOS** needs full Xcode selected
  (`sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`) and
  CocoaPods (`brew install cocoapods`), symptom texts quoted; **web** needs Chrome
  and the fixed port from `WEB_PASSWORD_RESET_REDIRECT_URL`. Add a runtime-values
  table (key, meaning, platforms) and copy-run commands for the three platforms.
- Add `static const keys = [...]` to `AppEnvironment` (the three keys it reads),
  and a unit test that fails when `tool/env.example.json`'s keys differ from it
  or the README omits one — this is SC-008's "0 missing/undocumented keys" made
  executable. (JSON has no comments, so the "what/where" description lives in the
  README table.)
- Add `flutter: ">=3.41.0"` to `pubspec.yaml` `environment` so the supported
  floor is enforced, not only prose (consistent with `sdk: ^3.11.0`). Verified
  while implementing: `pub get` changes no package version, but pub records the
  effective floor, so exactly one line of `pubspec.lock` changes —
  `sdks: flutter: ">=3.38.4"` becomes `">=3.41.0"` — and is committed with the
  `pubspec.yaml` line.
- Android Gradle: **document, don't upgrade** (spec default) — Gradle 8.14
  supports JDK 17–24; the failure is only the IDE-bundled JDK 25.

**Rejected**: a scripted `tool/doctor` check (more surface to maintain; the
README plus the keys test cover the stated criteria).

## Decision 12 — Test strategy

- **Unit** (pure Dart / fakes): `PasswordPolicy`; `ChangePasswordService`
  (ordering session-check→verify→update→local sign-out→others, each failure
  branch incl. Decision 2 and the retry); controller error mapping; the
  other-devices notice controller; **`AuthRepository`'s gateway code** with a
  `Fake implements GoTrueClient` for the app's client and `package:http`'s own
  `MockClient` for the REST calls (the exact requests — method, path, headers,
  body — are asserted): the temporary session signs in with the given
  credentials over REST and never touches the app's client, the hand-over calls
  `setSession` with the temporary refresh token, `close()` never throws and does
  not revoke a session that was handed over, `endOtherSessions` uses scope
  `others` only and refuses to run on a missing/expired token (the
  swallowed-401 guard of Decision 1), the session check times out; `BiometricAvailability` mapping via a
  fake `LocalAuthentication`; `AppEnvironment.keys` vs `tool/env.example.json` vs
  README.
- **Widget** (with fakes for `PasswordChangeGateway`, `AccountAuthActions`,
  `BiometricLoginRepository`): Security screen states (available on/off,
  each disabled reason, enabling success/cancel, disabling), change-password
  validation precedence, single-flight, success, errors; **compact (<600dp) and
  expanded (≥840dp)** widths for both screens (constitution Principle II);
  updated sign-up and reset tests for 8 characters.
- **Routing**: tapping Bảo mật reaches the real screen (no placeholder);
  existing placeholder routes for notifications/help unaffected.
- **Existing suite** stays green; the architecture test must still pass
  (`domain/` pure; icons only through `app_icons.dart`).
- **Manual** (quickstart): change password across two devices (web + emulator)
  to prove other sessions end; biometric matrix on the iOS Simulator (enrollable)
  and web (disabled); the Supabase 7-character request; clean-clone config check.

## Decision 13 — Verification scope and platform statement

Web (Chrome), Android emulator and iOS Simulator are all available and were
used in the previous feature; this feature is verified on all three, light and
dark, compact and wide. Sessions-ended checks use two clients of the same
account (web + an emulator/simulator). Real-device biometrics are not
available here; the iOS Simulator offers enrolled Face ID for the enable flow.

## Observations (not acted on here)

- `maybeShowBiometricEnablePrompt` still depends on `context.mounted` after
  awaits; unrelated to this feature, recorded in the previous feature's research.
- The cold-start lock race is out of scope (spec Out of Scope); the reasoning
  and the pointer are in `plan.md` Complexity Tracking. It also means a *cold
  relaunch* is not a reliable way to see the lock screen while verifying the
  biometric switch: lock through background/resume instead (quickstart
  Scenario 4).
- **Found only by running against the real service** (unit tests with fakes
  passed throughout): the server revokes all other sessions when a password is
  updated, and a second `GoTrueClient` leaks events over the web
  `BroadcastChannel` (Decision 1). Both are invisible to fakes; the verification
  scenarios are therefore part of the feature, not an extra.
- A second runtime-values example existed: the repository-root `.env.example`
  (dotenv format, from #3) listed only `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY` and no document pointed at it, so it silently
  contradicted the README/`tool/env.example.json`. Found while dry-running the
  README (T049); completed with the third key, a header pointing at the
  canonical example, and covered by `app_environment_keys_test.dart` so it
  cannot drift again. Not deleted: removing a tracked file the owner may use is
  their call.
- `GoTrueClient.signOut(scope: others)` swallows 401/403/404 from the admin
  endpoint (found while analysing this feature's tasks); the guard in Decision 1
  step 4 exists because of it. The same behavior applies to any other caller of
  `signOut(others)`; none exists today.
- `ErrorCode` has no `invalidCredentials` constant in `gotrue 2.26.0`; the
  literal wire string is used (as the shared mapper already does).
