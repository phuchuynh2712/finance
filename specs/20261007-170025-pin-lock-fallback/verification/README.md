# Verification record: App Lock to the Banking Security Standard

Everything below was observed in this session on 2026-10-07. Screenshots were reviewed and are not kept; the written
record is the evidence. The QA account was used by scripts that read `.env.test-credentials` and never print it; nothing
here changed a password, and the real project's data was only read.

## Baseline (T001)

- Branch `20261007-170025-pin-lock-fallback`, from `master` at `3f0589b` (PR #30 merged).
- `dart format --output=none --set-exit-if-changed lib test`: 0 changed.
- `flutter analyze`: only the 2 existing `onReorder` infos.
- `flutter test`: 1410 tests pass.
- Local inputs present and untracked: `tool/env.json`, `.env.test-credentials`. Android emulator `Pixel_10` and an iOS
  simulator (`iPhone 17`) exist.

## Before (T003): how the lock behaved

- `AppLockNotifier` (`core/auth/auth_state_provider.dart`) locks when the first auth event of an app instance already
  carries a session (cold start); `AppLifecycleObserver` locked on `resumed` if the time recorded on `paused` was more
  than 5 minutes ago. `shouldRelockOnResume` and `appLockProvider` are used by: `app_lifecycle_observer.dart`,
  `app_router.dart` (the redirect), `sign_in_screen.dart` (unlock after a real sign-in or a biometric unlock) and the
  tests `test/unit/core/auth/app_lifecycle_observer_test.dart` and `test/widget/core/router/app_shell_discard_prompt_test.dart`.
- Fact: Flutter documents `AppLifecycleState.paused` as "only entered on iOS and Android"; a hidden browser tab reaches
  `hidden` at most. So on the web the old background rule never fired: the app locked at page load and never again.

## Dependency review (T027, T020)

Constitution, Security: third-party packages are reviewed before they are added. `flutter pub outdated` lists none of the
three as behind a resolvable version (checked on 2026-10-07).

| Package | Where | Version | Publisher / license | Why | Permissions |
|---------|-------|---------|---------------------|-----|-------------|
| `crypto` | direct | 3.0.7 | Dart team (`dart-lang/core`), BSD-3-Clause | the HMAC-SHA-256 under the PIN's PBKDF2; hand-written HMAC would be worse | none (pure Dart) |
| `web` | direct | 1.1.1 | Dart team (`dart-lang/web`), BSD-3-Clause | `BroadcastChannel`, to share the inactivity timer and the lock across browser tabs; it was already in `pubspec.lock` through other packages | none (loaded only in the web build, through a conditional import) |
| `fake_async` | dev | 1.3.3 | Dart team (`dart-lang/test`), Apache-2.0 | `flutter_test` does not re-export it; the tracker's timing tests need a fake clock | none (tests only, never shipped) |

## US1: the inactivity lock (T018, T019, T020)

### Browser (T018): `flutter build web --profile ... --dart-define=INACTIVITY_LOCK_SECONDS=20`, Playwright, 1440×900

First run: four checks failed (I stopped the run to fix them). It found a real defect that no unit test had: after a page
**reload** (and a direct address, and a second tab) the app opened on the content, not on the lock screen. Cause: the activity tracker listens to the lock
from the first frame, so `AppLockNotifier` was now created before the first auth event arrived, and it decided on the
"still loading" value and never locked. Fix: it waits for the first real auth event; a test fails without the fix and
passes with it (`app_lock_notifier_test`, "created before the first auth event arrives"). The profile bundle was rebuilt
and the whole script run again: **21 of 21 pass**.

| Scenario (period 20 s) | Result |
|------------------------|--------|
| signed in, content visible | pass |
| S1 36 s without interaction | pass: the lock screen replaced the content; unlock with the password works |
| S2 mouse only hovering for 36 s | pass: locked (hover does not count) |
| S3 a wheel scroll every 10 s for 70 s | pass: never locked |
| S4 tab reported hidden for 36 s, then visible | pass: the first snapshot after returning has no content label at all, then unlock works |
| S5 idle again, then reload, `/expense-control`, `/spending/income`, browser Back | pass: every one lands on the lock screen, never on Kế hoạch or the content |
| S6 second tab opened while the first is in use | pass: the new tab starts locked, the first stays unlocked |
| S6 interaction only in tab B for 48 s | pass: both stay unlocked |
| S6 no interaction in either for 36 s | pass: both locked |
| S6 unlock tab A with the password | pass: tab B unlocks too |

Limit, stated honestly: S4 overrides `document.visibilityState` and fires `visibilitychange`; it proves that nothing
leaks in the first snapshot, but a real hidden tab also pauses the browser's timers, which a script cannot reproduce. The
guarantee for a really hidden tab is the resume check, which `activity_tracker_test` proves with a fake clock (a gap of
5 minutes or more locks on `onResumed`); the periodic check is best-effort.

### Release build ignores the define (T018)

`flutter build web --release --dart-define=INACTIVITY_LOCK_SECONDS=5`, Playwright, one signed-in tab left untouched: still
unlocked after 30 s (the define is ignored), and locked after the real 5 minutes (5 min 25 s untouched). 3 of 3 pass.

### Phone (T019): Android emulator `Pixel_10`, debug APK with the 20 s define

| Check | Result |
|-------|--------|
| 25 s untouched in front | pass: lock screen (password form, no PIN was set) |
| backgrounded 25 s, returned | pass: lock screen |
| a swipe every 10 s for 60 s | pass: never locked |
| (US6) the one-time PIN offer after the first sign-in on a device with no fingerprint | pass: shown once |

A dialog that is open when the 20 s pass is replaced by the lock screen, like any other screen (seen once while a script
was slow): the lock covers the whole app.

### Contract rows of `contracts/inactivity-lock.md` §5

| Row | Evidence |
|-----|----------|
| signed in, no interaction 5 min → locked | `app_lock_policy_test`, `activity_tracker_test` (fake clock); browser S1; Android 25 s |
| interaction at least every 4 min for 20 min → never | `activity_tracker_test`; browser S3; Android 60 s of swipes |
| hover only → locked | `activity_tracker_test` (hover is not an interaction); browser S2 |
| tab hidden 5+ min, visible → locked at the resume check | `activity_tracker_test` (`onResumed`); browser S4 (with the limit above) |
| phone backgrounded 5+ min, returns → locked | `app_lifecycle_observer_test`, `activity_tracker_test`; Android background run |
| two tabs, only B in use → neither locks | `activity_tracker_test` (two trackers over a fake channel); browser S6 |
| two tabs, no interaction → both lock, unlocking one unlocks the other | same; browser S6 |
| a second tab opens (starts locked) while the first is in use → the first stays unlocked | `activity_tracker_test`, `app_lock_notifier_test`; browser S6 |
| signed out → nothing happens | `activity_tracker_test` |
| release build with the define → still 5 minutes | `app_lock_policy_test` (`resolvePeriod`), release bundle run above |

The rewritten lifecycle test replaces the `shouldRelockOnResume` tests: `app_lifecycle_observer_test` now covers only
`resumed`, because the decision rests on the last interaction, not on any lifecycle state.

## US2–US6: the PIN

### Android emulator `Pixel_10` (no fingerprint enrolled), debug APK, 20 s define (T070)

Scripts drove the app with `adb` and `uiautomator`; the QA password was read from the credentials file by the script and
never printed. Only sign-ins and PIN actions were made: no financial data was written.

| Check (quickstart §2) | Result |
|-----------------------|--------|
| Bảo mật shows the PIN row ("Mở app nhanh bằng 6 số") | pass |
| set-up: a wrong password stops with the sign-in message, the right one continues | pass |
| `111111` and `123456` refused; `483920` then `483921` says "Hai lần nhập chưa khớp" and restarts only the repeat step; `483920` sets it | pass |
| after the set-up Bảo mật shows "Đang bật" and the "Đổi mã" row | pass |
| the 20 s idle lock shows the PIN entry (dots, "Dùng mật khẩu", "Quên mã PIN"), not the password form | pass |
| airplane mode on, the right PIN unlocks | pass: 3.0 s from the first tap to the app open (SC-002, under 5 s) |
| cold start asks for the PIN; wrong PINs: 4, 3 tries left; restart; the count continues (2 left); then 1 left | pass |
| the fifth wrong PIN: the invalidation message and the password form; after another restart only the password form | pass |
| a password sign-in right after an invalidation offers a new PIN, accepting opens the set-up | pass |
| "Quên mã PIN" then the password: signed in, one dialog offering a new PIN, declined; the row is off again | pass |
| change: the current PIN, the new one twice; the old PIN stops working (4 tries left), the new one unlocks | pass |
| turn off: a wrong PIN keeps it on and counts; the right one turns it off; a cold start asks for the password only | pass |
| sign out and in again: no PIN is left, no second offer, the row is off | pass |
| the one-time offer after the first sign-in on a clean install: shown once | pass |

A restart between an invalidation and the password sign-in loses the screen's memory of it, so that sign-in shows no
new-PIN dialog (the one-time marker was set earlier); the PIN row in Bảo mật is there to set one. Documented in
`contracts/pin-ui.md` §2.

**Measured.** Set-up (SC-003): 18.2 s from the password step to the PIN saved, three steps (password, new PIN, repeat);
script-driven, so an upper bound that includes `adb` round trips. Hash + verify on the build machine (JIT, tests): 100
to 170 ms for the two derivations of a set-and-verify round trip, about 50 to 85 ms each (research expected well under
100 ms). On the emulator the whole unlock was 3.0 s in a **debug** build.

### iOS simulator `iPhone 17` (no Face ID enrolled) (T071)

The same subset, 17 of 17: the one-time offer after the first sign-in, set-up (14.0 s), a cold start asks for the PIN, 4
and 3 tries left, the count continues after a restart (2 left), the right PIN unlocks (3.6 s from the last tap to the
app open), "Quên mã PIN" then the password offers a new PIN, the old PIN is gone, set again, change (the old PIN stops
working, the new one unlocks), turn off (the password form only afterwards). Differences from Android: none in
behavior. The simulator has no airplane mode, so the offline claim rests on the Android run and on
`pin_never_logged_test`, which shows the only requests made are the password confirmation's.

### Regression, SC-008 (T072)

| Situation | Result |
|-----------|--------|
| Android, fingerprint enrolled, **no PIN** | pass: the lock screen is the password form, no PIN offer after sign-in, no PIN row in Bảo mật, the biometric offer shows once and the biometric row is usable |
| biometric switched on, cold start | pass: password form with the fingerprint button, the fingerprint unlocks, as before |
| PIN set first, fingerprint enrolled afterwards | pass: the lock screen still asks for the PIN, the PIN unlocks, the PIN row stays ("Đang bật") |
| biometric sign-in switched on in that state | pass: the fingerprint button sits beside the PIN entry and unlocks from there |
| the PIN can still be turned off on that device; the row then disappears (biometrics available, no PIN) | pass |
| web profile build | pass: no PIN offer after sign-in, no PIN row in Bảo mật, the biometric row still says it is not supported on the web; the only visible change is the inactivity lock |

### Accessibility and layout on the device (T073)

At 130 % text (`font_scale 1.3`) the Bảo mật screen with the PIN row and the "Đổi mã" row, every step of the set-up
flow (password, new PIN, the refused-PIN message, repeat) and the lock screen in PIN mode (with the wrong-tries message)
were looked at: nothing overflows, the keypad and the message line stay readable. The accessibility tree (uiautomator)
shows "Đã nhập 0 trên 6 chữ số" and mid-entry "Đã nhập 4 trên 6 chữ số", the keys as single digits, and never the
typed digits in any label. Screenshots were reviewed and deleted.

### Contract rows of `contracts/pin-lock-repository.md`

| Row | Evidence |
|-----|----------|
| §1 interface (`status`, `triesLeft`, `set`, `verify`, `clear`, offer marker; no account → none and no-op writes) | `pin_lock_repository_test` |
| §2 `verify`: the try is counted before comparing; `wrong(4…1)`; the fifth invalidates and deletes record and count; success resets; `unavailable` | `pin_lock_repository_test`; Android and iOS runs |
| §3 `pin_rules` (format, easy PINs, expiry at exactly 365 days) | `pin_rules_test` |
| §4 hasher: PBKDF2-HMAC-SHA-256 known answers (RFC 7914 §11, the "password"/"salt" vectors, a PIN vector computed independently with Python `hashlib`), random salt, under 250 ms | `pin_hasher_test` |
| §5 the PIN, its digits and its hash never appear in storage values, logs, exception messages, semantic labels or requests | `pin_never_logged_test`, `pin_lock_repository_test` ("the PIN never leaks"), `pin_entry_panel_test` (semantics); Android accessibility tree |
| §5 a tampered or unparsable record reads as none; `set` replaces the whole record and the count; `clear` keeps the offer marker; two accounts never see each other; no network call | `pin_lock_repository_test`, `auth_repository_pin_clear_test`, `pin_never_logged_test` |
| §6 providers: `pinAvailable` false and `pinInUse` true on a device that gained biometrics; the web has neither | `sign_in_lock_pin_test`, `security_pin_row_test`, `pin_offer_prompt_test` |
| sign-out clears the PIN and the count but keeps the marker | `auth_repository_pin_clear_test`; Android sign-out run |

### Contract rows of `contracts/pin-ui.md`

| Section | Evidence |
|---------|----------|
| §1 `PinDots`, `PinKeypad` (48 dp keys, hardware keyboard, disabled while a check runs, one label) | `pin_keypad_test` |
| §2 lock screen: PIN first, "Dùng mật khẩu", six-digit auto verify, wrong tries, invalidation, no network, loading shows only the logo and a spinner, fingerprint button beside the panel, a PIN on a device that gained biometrics, expired opens the password form with the message, forgot/expired/invalidated clear and offer once | `pin_entry_panel_test`, `sign_in_lock_pin_test`; Android and iOS runs |
| §3 flow: three modes, easy PIN, mismatch restarts only the repeat step, nothing written before the last step, Escape and Back leave with nothing saved, hardware-keyboard-only completion, focus rules | `pin_flow_controller_test`, `pin_flow_screen_test`; Android and iOS runs |
| §4 the Bảo mật row (off, on, expired; present with a PIN although biometrics are available; absent on the web) | `security_pin_row_test`; Android regression runs |
| §5 one-time offer (marker before the dialog, decline or close never repeats, per account, sign-out keeps it, after the biometric offer, never blocks) | `pin_offer_prompt_test`, `sign_in_pin_offer_test`; Android runs |
| §7 layout: 320 to 2560 dp, light and dark, 500 dp high, 130 % text, keypad never over 450 dp | `adaptive_sweep_pin_test` (144 cases: lock screen, set-up, change, Bảo mật with and without a PIN, the offer); 130 % text on the emulator |

## Gate (every story)

`dart format --output=none --set-exit-if-changed lib test`: 0 changed. `flutter analyze`: only the 2 existing `onReorder`
infos. `flutter test`: 1813 tests pass (1410 at the baseline).

## Pull-request notes (constitution, Development Workflow)

The work is meant to ship as two independent pull requests from `origin/master`.

**Pull request 1, US1 (the inactivity lock).** `core/` changes: `core/auth/app_lock_policy.dart`, `activity_tracker.dart`,
`lock_channel*.dart` (new); `app_lifecycle_observer.dart` rewritten (only `resumed` is handled; its tests are
rewritten and `shouldRelockOnResume` and the `APP_LAST_BACKGROUNDED_AT` value are gone); `auth_state_provider.dart`
(`lockChannelProvider`, `activityTrackerProvider`, and `AppLockNotifier` now waits for the first real auth event);
`core/config/app_environment.dart`, `tool/env.example.json`, `.env.example` and the README table
(`INACTIVITY_LOCK_SECONDS`, ignored by a release build); `main.dart` watches the tracker; `pubspec.yaml`: `web`, dev
`fake_async`.

**Pull request 2, US2 to US6 (the PIN).** `core/` changes: `core/auth/pin_rules.dart`, `pin_hasher.dart`,
`pin_lock_repository.dart` (new; in `core/` only because the core `AuthRepository.signOut` must clear the PIN);
`auth_repository.dart` (optional `pinLock`, cleared on a local sign-out) and `auth_state_provider.dart` (PIN providers);
`core/l10n` (the `pin*` strings, both languages); `core/router/app_router.dart` (the `/account/security/pin/:mode`
route); `pubspec.yaml`: `crypto`. The account feature gains the keypad, dots, entry panel, flow, offer, the Security row
and a `PasswordField` extracted from the change-password screen.

