# Quickstart: Verifying Security Screen, Change Password, Password Policy and Config

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

Run from the repository root on the supported toolchain. Use the QA test
account from `.env.test-credentials` (never commit it). Each scenario maps to
spec success criteria. Use a **second client** (web in Chrome plus the Android
emulator or iOS Simulator) for Scenario 3.

## Scenario 1 — Password policy and change-password logic (SC-002, SC-009)

```bash
flutter test test/unit/features/account/domain/password_policy_test.dart
flutter test test/unit/features/account/application/change_password_service_test.dart
flutter test test/unit/core/auth/auth_repository_password_change_test.dart
flutter test test/unit/features/account/presentation/change_password_controller_test.dart test/unit/features/account/presentation/other_devices_notice_controller_test.dart
flutter test test/widget/features/account/change_password_screen_test.dart test/widget/features/account/security_screen_test.dart
flutter test test/unit/features/account/presentation/sign_up_validation_test.dart
flutter test test/widget/features/account/sign_up_screen_test.dart test/widget/features/account/reset_password_screen_test.dart
```

Expected: 7 characters rejected / 8 accepted in sign-up, reset and change;
service sequence session-check → verify → set → close → end-others; each failure
branch maps to its outcome, including the partial failure and its one-tap retry;
the repository refuses to end other sessions on a missing/expired token (the
swallowed-401 guard) and its temporary client is always closed; validation order
and single-flight hold at compact and expanded widths.

## Scenario 2 — Server-side minimum (SC-009, FR-015) — already done by the owner; re-check at the end

1. In the Supabase dashboard raise **Minimum password length** to 8
   (Authentication → password settings). `[EXT]`
2. Verify with a direct request (publishable key from `tool/env.json`):

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "apikey: $SUPABASE_PUBLISHABLE_KEY" -H "Content-Type: application/json" \
  -d '{"email":"minlen-check+'"$(date +%s)"'@example.com","password":"1234567"}'
# expect 422 (weak_password); a 7-character password must NOT create an account
```

## Scenario 3 — Change password end to end on web, Android and iOS (SC-001, SC-003, SC-004)

1. Sign in with the QA account on **two** clients (A = the one you will use,
   B = a second device or browser). Confirm both show Tổng quan.
2. On A: Hồ sơ → Bảo mật → Đổi mật khẩu. Try, in order: empty current;
   7-character new; new equal to current; mismatched confirmation (each shows
   its own inline message, no request); wrong current (message, nothing
   changed); then a valid change.
3. Expected on A: confirmation "Đã đổi mật khẩu", back on the Security screen,
   **still signed in** — and still signed in *on the server*: opening the form
   again and submitting a wrong current password must answer "Mật khẩu hiện tại
   không đúng." (a session that was revoked would answer "session ended"). This
   is the check that caught the original design signing this device out.
4. Expected on B: signed out immediately (or at the latest when its access
   token expires): the next action or refresh lands on sign-in.
5. Sign out on A and sign in with the **new** password (works) and the old one
   (rejected). Change the password back afterwards so the QA credentials stay
   valid.
6. Time the whole change on A: under 60 seconds (SC-001).
7. Offline: turn the network off on A, submit — friendly message, values kept,
   password unchanged.
8. Revoked device (spec scenario 10): with A and B both signed in, change the
   password **on B** (this ends A's session). On A, without restarting, open
   Hồ sơ → Bảo mật → Đổi mật khẩu and submit a valid form. Expected: the
   password is **not** changed again, A shows the "session has ended" message
   and lands on sign-in. (Do this last, then sign in again with the current
   password; change it back if you changed it.)
9. The partial-failure notice (spec scenario 9) cannot be provoked reliably by
   hand; it is covered by the service, notice-controller and Security-screen
   tests. If you want to see it once, point the app at an unreachable network
   *exactly* after the password update succeeds (for example with a proxy that
   blocks the logout call) — optional.

## Scenario 4 — Biometric switch matrix (SC-005)

| Setup | Expected |
|-------|----------|
| iOS Simulator, Face ID enrolled (Features → Face ID → Enrolled) | switch enabled; turn on → Face ID prompt → on; lock the app by sending it to the background for over 5 minutes (or the existing lock trigger) and resuming → the lock screen shows the biometric button. Do not use a cold relaunch as the pass/fail signal: the known cold-start lock race (plan.md Complexity Tracking) can skip the lock screen regardless of this feature |
| same, prompt cancelled (Features → Face ID → Non-matching) | switch stays off, brief notice |
| same, turn off | immediate; lock screen no longer shows the button |
| answered "Để sau" after first sign-in | switch is off and can be turned on |
| iOS Simulator, Face ID not enrolled | switch disabled + "not enrolled" caption |
| Android emulator without a fingerprint | switch disabled + caption (no hardware or not enrolled) |
| Chrome | switch disabled + "chưa hỗ trợ trên web" |
| enabled, then change the password | switch unchanged (FR-009) |

## Scenario 5 — Navigation and screens (SC-006)

- Hồ sơ → Bảo mật opens the real screen (no "Tính năng đang được phát triển");
  the URL on web is `/account/security`; Back returns to Hồ sơ; the
  notifications and help rows still show their placeholders.
- Light and dark, compact (phone) and expanded (rail ≥ 600 dp / Chrome 1280
  wide): both screens correct; every string in Vietnamese and English (switch
  the language in Hồ sơ).
- `flutter test test/widget/features/account/security_screen_test.dart` and the
  l10n parity test pass.

## Scenario 6 — Platform config is stable and documented (SC-007, SC-008)

```bash
flutter test test/unit/core/config/app_environment_keys_test.dart   # example keys == AppEnvironment.keys == README table
# On a clean clone with only the README prerequisites installed:
flutter pub get && git status --short                                # empty (the committed pubspec.lock already carries the `sdks: flutter: ">=3.41.0"` line)
flutter build web --debug   --dart-define-from-file=tool/env.json && git status --short   # empty
flutter build apk --debug   --dart-define-from-file=tool/env.json && git status --short   # empty
flutter build ios --simulator --debug --dart-define-from-file=tool/env.json && git status --short  # empty
```

Expected: every `git status --short` prints nothing; a person who follows only
the README builds and runs the three platforms; the iOS app still has the same
bundle identifier and signing settings (deployment target 15.0 is the only
intended difference, `contracts/platform-config.md`).

## Scenario 7 — No regressions (FR-013)

```bash
flutter analyze        # only the 2 existing onReorder infos
dart format --output=none --set-exit-if-changed lib test
flutter test           # whole suite green

# Hygiene greps over the lines this feature added to lib/ (each must print nothing).
# `git add -N` (intent to add) makes the new files appear in the diff without staging content.
git add -N lib
git diff -U0 master -- lib | grep -E '^\+[^+]' | grep -E "(^\+|[^.a-zA-Z_])(print|debugPrint)\(|developer\.log\("
git diff -U0 master -- lib | grep -E '^\+[^+]' | grep -E "(Text|SelectableText)\(\s*['\"]|(label|tooltip|helperText|errorText|hintText|semanticLabel): ?['\"]"
```

Sign-in, sign-up, "Quên mật khẩu?" reset (now with the 8-character check),
lock screen, sign-out and the other Hồ sơ rows behave as before.
