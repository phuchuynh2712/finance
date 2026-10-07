# Quickstart: Verifying the App Lock and the PIN

**Feature**: `20261007-170025-pin-lock-fallback` | **Date**: 2026-10-07

How the implementer (and a reviewer) proves each story. Run the gate after every story; the manual checks are recorded
as text in `verification/README.md` (screenshots are reviewed and deleted, not committed).

## 0. Prerequisites

```bash
flutter pub get                          # picks up the two new direct dependencies: crypto, web
cp tool/env.example.json tool/env.json   # public Supabase URL + publishable key (README "Setup")
```

The QA account is in `.env.test-credentials` (read by scripts only, never printed). **Setting a PIN needs the account
password once**, so the manual runs read it from that file inside the script; nothing here changes the password, and
the real project's data is only read.

A short inactivity period for manual runs (non-release builds only):

```bash
flutter run  --dart-define-from-file=tool/env.json --dart-define=INACTIVITY_LOCK_SECONDS=20          # Android / iOS
flutter build web --profile --dart-define-from-file=tool/env.json --dart-define=INACTIVITY_LOCK_SECONDS=20
python3 -m http.server 5000 --directory build/web
```

A release build ignores the define (always 5 minutes), so a profile build is used for the web.

## 1. Automated gate (every story)

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze                          # only the 2 existing onReorder infos
flutter test                             # whole suite
```

| Story | New tests |
|-------|-----------|
| US1 | `test/unit/core/auth/app_lock_policy_test.dart`, `activity_tracker_test.dart` (fakeAsync), `lock_channel_message_test.dart`, `app_lock_notifier_test.dart`, the rewritten `app_lifecycle_observer_test.dart` |
| US2–US4 | `test/unit/core/auth/pin_rules_test.dart`, `pin_hasher_test.dart`, `pin_lock_repository_test.dart` (fake secure storage), `test/unit/features/account/pin_flow_controller_test.dart`, `test/widget/features/account/pin_keypad_test.dart`, `test/widget/features/account/pin_entry_panel_test.dart`, `pin_flow_screen_test.dart`, `sign_in_lock_pin_test.dart` |
| US5–US6 | `test/widget/features/account/security_pin_row_test.dart`, `pin_offer_prompt_test.dart`, `sign_in_pin_offer_test.dart`, `test/unit/core/auth/auth_repository_pin_clear_test.dart` |
| all | `test/widget/core/adaptive_sweep_pin_test.dart` (lock screen in PIN mode and the flow, 7 widths × light/dark, 500 dp high, 130 % text), `test/unit/core/auth/pin_never_logged_test.dart`, `l10n_key_parity_test.dart` extended |

Every widget test pins a compact (412 × 915) and an expanded (1440 × 900) viewport. The existing sign-in and Security
tests must pass **unmodified**: the PIN panel and row only appear when the PIN is available and active.

## 2. Manual checks, per story

### US1 — inactivity lock (web profile build and an Android or iOS run, period 20 s)

| Check | Pass |
|-------|------|
| Sign in on the web, leave the tab in view without touching it for 25 s | the lock screen replaces the content |
| Same, with the mouse only hovering | locked at 20 s (hover does not count) |
| Keep scrolling or clicking every 10 s for 60 s | never locks |
| Hide the tab (another tab) for 25 s, return | the lock screen, with **no frame of content** first (take a screenshot immediately after the visibility change; a flash of content is a defect) |
| Open the app in two pages of one browser context (Playwright, `context.new_page()` twice); work only in page B for 60 s | page A did not lock |
| Stop interacting in both for 25 s | both locked; unlock in A with the password → B unlocks |
| Phone: leave the app in front for 25 s; then background it 25 s and return | locked both times |
| Release build with the define set | still 5 minutes (read the build log / test) |

### US2–US4 — PIN (Android emulator Pixel_10 and iOS simulator iPhone 17 with **no** fingerprint or face enrolled)

| Check | Pass |
|-------|------|
| Bảo mật on the emulator | the PIN row is shown (availability `notEnrolled`); on web, and after enrolling a fingerprint **with no PIN set**, it is absent |
| Turn it on, wrong password, then the right one | wrong stops with a message, right continues |
| Enter 111111, then 123456, then 483920 / 483921 | easy ones refused; mismatch restarts only the repeat step; match sets it |
| Lock the app (20 s idle), airplane mode on, enter the PIN | opens with no network |
| Enter 5 wrong PINs, restarting the app after the second | count continues; the fifth invalidates; only the password remains |
| "Quên mã PIN" then the password | signed in, PIN gone, offered a new one |
| Change the PIN, then turn it off | old PIN stops working; then password only |
| Sign out and in again | no PIN; no second offer |

Record the real time of the hash + verify on the emulator (research Decision 6 expects well under 100 ms).

### US6 — one-time offer

Sign in with an account that has no marker on the emulator: the offer shows once; decline; sign out and in: it does
not show again; the Bảo mật row remains.

### Tips for the device runs

- Android: `adb shell cmd connectivity airplane-mode enable` for the offline unlock; `adb shell locksettings set-pin 1234`
  then `adb shell am start -a android.settings.FINGERPRINT_ENROLL` and `adb emu finger touch 1` (then `finger remove 1`)
  to enrol a fingerprint on the emulator; `adb shell locksettings clear --old 1234` takes the lock, and so the
  fingerprints, away again; `adb shell settings put system font_scale 1.3` for 130 % text.
- iOS simulator: if typing into a field turns "test" into "tét", the software keyboard is on Vietnamese Telex; tap the
  globe key ("Next keyboard") once to get the English keyboard, which the simulator then remembers.

## 3. Regression on devices that must not change (SC-008)

- A phone with biometrics enrolled and **no PIN** (emulator after enrolling a fingerprint): the lock screen, the biometric
  offer and the biometric switch are as before; no PIN row, no PIN offer.
- A phone where a PIN was set and a fingerprint is enrolled afterwards: the PIN entry is still shown, the PIN row is still
  in Bảo mật, and with biometric sign-in switched on the fingerprint button sits beside the PIN entry.
- Web: no PIN row or offer anywhere; the only visible change is the inactivity lock.

## 4. Done checklist (per story)

- [ ] Contract rows of the story pass (`contracts/`, recorded in `verification/README.md`).
- [ ] Format, analyze and the full suite are green.
- [ ] Manual checks above done and written down as text; screenshots deleted.
- [ ] Layout and accessibility checks of `contracts/pin-ui.md` §7 pass for every new screen.
- [ ] New strings exist in `vi` and `en`.
- [ ] `tasks.md` items checked off.
- [ ] The pull request description lists the `core/` changes (`core/auth`, `core/router`, `main.dart`, `core/l10n`,
      `pubspec.yaml`) and the rewritten lifecycle tests, as the constitution's Development Workflow requires.
