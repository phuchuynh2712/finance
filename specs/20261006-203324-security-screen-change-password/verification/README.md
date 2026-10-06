# Verification record

**Feature**: `20261006-203324-security-screen-change-password` · measured on
2026-10-06 with Flutter 3.47.5 / Dart 3.13.4, Xcode 26.3, CocoaPods 1.17.0,
JDK 21 (via `flutter config --jdk-dir`), Chrome 154.

This file records what was actually run and observed for the manual tasks.
Screenshots were taken and reviewed during the runs but deliberately not kept in the repository (the record below is the evidence). Passwords and keys never appear here.

## US4 — platform configuration (T045–T049)

| Check | Result |
|-------|--------|
| iOS Simulator build changes only the five files in `contracts/platform-config.md` | ✅ +162/−3 lines in exactly those five files |
| Bundle id / signing untouched | ✅ no `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM` or `CODE_SIGN*` line changed |
| Deployment target | `IPHONEOS_DEPLOYMENT_TARGET` 13.0 → 15.0 in exactly three places (the accepted change) |
| Android debug APK changes only `android/gradle.properties` | ✅ +4 lines (`android.builtInKotlin=false`, `android.newDsl=false` and their comments) |
| Web build changes no tracked file | ✅ |
| Idempotence: after staging the canonical files, a second build of each target leaves `git diff --stat -- ios android web pubspec.lock` empty | ✅ iOS, Android, web |
| `pubspec.lock` after the `flutter: ">=3.41.0"` floor | one line (`sdks: flutter`), no package version change |


README-only dry run (T049): the tree was copied from `git ls-files -co --exclude-standard`
(no `.dart_tool`, `build`, `Pods`, `Podfile`, `tool/env.json`) into a fresh scratch git repo;
following the README literally — `pub get`, copy the example env file, then the three builds —
left `git status --short` empty after every step and needed no undocumented step. The scratch
copy also showed that the repository-root `.env.example` listed only 2 of the 3 keys; it was
completed and is now covered by `app_environment_keys_test.dart`.

## US1 — Security screen and change password (T025)

Run with the QA account against the real project, using only the public URL and publishable
key from `tool/env.json`. Server-side facts were checked with the same public API (a third
session "C" opened before each change; sign-in with the old/new password afterwards).
Every real submit was guarded by reading the typed values back from the form.

| Check | Web (Chrome) | Android emulator | iOS Simulator |
|-------|:---:|:---:|:---:|
| Signs in with ONE press and lands on Tổng quan | ✅ | ✅ | ✅ |
| Hồ sơ → Bảo mật opens the real screen (URL `/account/security` on web), Back returns | ✅ | ✅ | ✅ |
| Empty form: "Nhập mật khẩu hiện tại." + 8-character message; no request | ✅ | ✅ | – |
| 7-character new password rejected; new = current rejected; mismatched confirmation rejected; nothing changed server-side | ✅ | – | – |
| Wrong current password: "Mật khẩu hiện tại không đúng.", password unchanged | ✅ | – | – |
| Offline: friendly message, values kept, password unchanged (after ≤ 8 s) | ✅ | – | – |
| Valid change: confirmation, back on Security | ✅ 1.1 s | ✅ ≤ 5.1 s¹ | ✅ 2.2 s |
| THIS device stays signed in, and its session is valid on the server | ✅ | ✅ | ✅ |
| Old password rejected (`400 invalid_credentials`), new accepted (`200`) | ✅ | ✅ | ✅ |
| Other session C ended (`400 refresh_token_not_found`) | ✅ | ✅ | ✅ |
| Change back through the UI using the handed-over session | ✅ | ✅ ≤ 6.4 s¹ | ✅ 2.1 s |
| Re-opening the form shows empty fields | ✅ | ✅ | ✅ |

¹ Android was timed by polling `uiautomator`, which itself takes about a second per poll; the
real latency is lower. Web and iOS were polled in sub-second steps.

**Revoked-device check (spec scenario 10).** After the web run changed the password, the
Android emulator (a session that had been revoked by the server) was opened and a valid-looking
form was submitted: the app went to the sign-in screen by itself and the password was not
changed again.

**Timing vs SC-001.** The system answers in 1–2 s (web, iOS); the 60-second budget is therefore
dominated by typing three fields, which was not timed with a person.

## US2 — biometric switch (T033)

| Setup | Observed |
|-------|----------|
| iOS Simulator, Face ID **not enrolled** | switch disabled, caption "Hãy thêm vân tay hoặc khuôn mặt…" |
| Same, after enrolling Face ID and sending the app to the background and back | caption gone, switch enabled (availability re-read on resume) |
| Turn on, Face ID **not recognised**, then Cancel | switch stays off, notice "Chưa bật được đăng nhập bằng vân tay." |
| Turn on, Face ID matches | switch on |
| Switch on, **change the password** (FR-009) | switch still on, device still signed in |
| Switch on, app in the background for 5 min | lock screen shows "Đăng nhập bằng vân tay"; unlocking with a matching Face ID reaches Tổng quan (the handed-over session is valid)² |
| Turn off | immediate, no Face ID prompt |
| Switch off, app in the background for 5 min | lock screen has **no** biometric button |
| Preference absent ("Để sau" is the same stored state) | switch off and can be turned on |
| Android emulator (no fingerprint hardware) | switch disabled, caption "Thiết bị này không hỗ trợ đăng nhập bằng vân tay." |
| Chrome | switch disabled (`aria-disabled`), caption "chưa hỗ trợ trên web." |

² The simulator ignored the first "match" notification on the lock screen twice and accepted it
after a "no match → try again" round; the app logic (`authenticate` → `verifySessionAlive` →
unlock) is unchanged by this feature.

## US3 — 8-character minimum (T040, T052)

* Web sign-up form: the hint "Tối thiểu 8 ký tự" is visible before typing; a 7-character
  password is rejected with "Mật khẩu phải có ít nhất 8 ký tự." and no request is sent. A valid
  sign-up was deliberately **not** submitted (it would create a real account); the accepted
  8-character path is covered by the widget test with a fake.
* The reset-by-email screen needs an emailed link; it is covered by its widget tests.
* Server minimum (T052): a direct sign-up request with a 7-character password returned
  `422 weak_password` ("Password should be at least 8 characters.") and created no account.

## Appearance, language, keyboard (T051)

* Screens reviewed (screenshots not kept): web compact/wide × light/dark (Security, and the
  form with errors), Android light/dark, iOS light/dark, English Security screen, the sign-up
  rejection.
* English: Hồ sơ rows, the Security screen (incl. the web reason), and the form labels/hint
  switch language immediately; Enter on the last field submits (shows "Passwords do not match."
  when they differ); Tab goes field → its show/hide toggle → next field → … → submit.
* No horizontal page overflow at 412 and 1280 px; content is capped and centered when wide.
* Unchanged: sign-in, sign-up form, "Quên mật khẩu?" screen, sign-out, and the Thông báo/Trợ giúp
  placeholders behave as before.

## What manual verification found (and unit tests with fakes could not)

1. **The server revokes every other session when a password is updated** and keeps only the
   updating one. The first design updated on a throwaway session and closed it, so this device
   was signed out right after a successful change. Fixed: the temporary session is handed to the
   app (`continueOnThisDevice`). Measured with two sessions: the updater stays valid, the other
   gets `400 refresh_token_not_found`.
2. **A second `GoTrueClient` is not isolated on web** (shared `BroadcastChannel`): it signed the
   app in as the temporary session and out again. Fixed: the temporary session uses plain HTTP.
3. **Offline made the form spin ~30 s** (gotrue retries a refresh with backoff). Fixed: the session
   check gives up after 8 s and reads as offline.
4. **Accessibility:** with one tappable row and one merged (Switch) row in the same card, the first
   row's semantics were merged into a node covering the whole card. Fixed in `AccountMenuRow`
   (every row is its own node) and pinned by a widget test.
5. **Web address bar:** `context.push` leaves the URL on `/account`; the Bảo mật row now uses
   `context.go('/account/security')` so the screen is bookmarkable/reloadable and Back still returns
   to Hồ sơ.
6. A second, incomplete runtime-values example (`.env.example`) — see US4.

**Incident, recorded for honesty.** During the first web run the script's keystrokes dropped the
first character in the second and third fields, so a *real* change was submitted with an unintended
new password (the QA password became its original without the first character). This was caused by
the test script, not the app; it was recovered through the public API (the original password was
restored and verified) and every later run reads the typed values back before submitting.

## Not verified / left open

* Real-device biometrics (only the iOS Simulator's Face ID and an Android emulator without hardware).
* The known cold-start lock race (see `plan.md` Complexity Tracking) — lock behavior was checked by
  backgrounding the app for over 5 minutes, not by cold relaunch.
* The email reset path and the accepted sign-up path against the real service (they would send an
  email / create an account).
* Flutter warns that Kotlin 2.2.20 will soon be unsupported (needs ≥ 2.3.20): unrelated, not acted on.

## PR call-outs (constitution: shared `core/` changes)

* `AuthRepository` now implements `PasswordChangeGateway`: a timed session refresh, a temporary REST
  session with hand-over, and a guarded `signOut(others)`. New files `password_change_gateway.dart`,
  `temporary_password_session.dart`.
* `http` becomes a **direct dependency** (already in the graph at 1.6.0; no version change); the
  `pubspec.lock` change is that flag plus `sdks: flutter: ">=3.41.0"`.
* `BiometricLoginRepository.availability()` + `BiometricAvailability` (existing methods untouched).
* The shared error mapper now maps `same_password`, `over_request_rate_limit`, and the session codes,
  and exposes `isSessionEndedError` / `isConnectivityError`; this changes the messages shown by
  sign-in, sign-up and the email reset for those codes. The weak-password copy now says 8 characters.
* `SignUpValidation` delegates to `PasswordPolicy`; sign-up **and the email reset** now require 8
  characters; the old `signUpPasswordTooShortError` key was replaced by `passwordTooShortError`.
* `AccountMenuCard` / `AccountMenuRow` generalized from the private Hồ sơ widgets (identical look;
  every row is now its own semantics node).
* Router: `/account/security` and `/account/security/change-password`; the `security` placeholder was
  removed.
* **iOS deployment target 13.0 → 15.0** (accepted by the owner) with CocoaPods/SwiftPM integration in
  the committed iOS project; `android/gradle.properties` gained the two migrator flags;
  `pubspec.yaml` gained `flutter: ">=3.41.0"`.
* External: the Supabase minimum password length was raised to 8 (verified again at the end).
* Inherited gaps, documented not hidden: no PIN fallback where biometrics are unavailable; the
  cold-start lock race (root cause, why deferred and pointer are in `plan.md`).
