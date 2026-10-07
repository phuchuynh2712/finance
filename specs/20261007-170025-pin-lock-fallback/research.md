# Research: App Lock to the Banking Security Standard

**Feature**: `20261007-170025-pin-lock-fallback` | **Date**: 2026-10-07

Every decision below was checked against the code on `master` (`3f0589b`) or the framework's own documentation. Nothing
in the Technical Context stayed "NEEDS CLARIFICATION".

## Decision 1: How an interaction is detected, on every platform

**Decision**: one `ActivityTracker` in `core/auth/`, created once at the app root next to the existing lifecycle observer.
It records the time of the last interaction from two framework hooks that see every event regardless of which widget
handles it:

- `GestureBinding.instance.pointerRouter.addGlobalRoute` for pointer events: **down, up, scroll signal, and moves made
  while a button or finger is down** (a drag or a touch scroll). Hover moves (a mouse passing over the window) are
  ignored, as the spec says movement alone does not count.
- `HardwareKeyboard.instance.addHandler` for key-down events (always returning `false`, so it never consumes a key).

Recording is a single timestamp write; nothing rebuilds and nothing allocates per event, so the cost is O(1) per event.

**Rationale**: a `Listener` at the root would miss events that a descendant handles with `HitTestBehavior.opaque` or a
gesture arena, and would have to be placed inside the router's tree; the pointer router and the keyboard handler are
global, work the same on Android, iOS and Web, and need no widget. Both are public, documented APIs.

**Known limit (recorded in the spec's Assumptions)**: text typed on an **on-screen keyboard** produces neither a pointer
event nor a hardware key event. The taps that focus a field and press Done are interactions, and the app's text fields
are short (a name, an amount, a note), so a person cannot realistically type for five minutes without touching the
screen. Not worth hooking the text-input channel, which the framework owns.

**Alternatives considered**:
- *A root `Listener`*: misses handled events; needs to sit inside `MaterialApp.router`'s builder.
- *`WidgetsBindingObserver.didChangeMetrics` / frame callbacks as a heartbeat*: measures rendering, not people.
- *Counting only taps*: scrolling a long list for a few minutes would lock the person out mid-read.

## Decision 2: One lock policy, replacing the "background for 5 minutes" rule

**Decision**: a pure `AppLockPolicy` (`core/auth/app_lock_policy.dart`) with one named constant,
`inactivityPeriod = Duration(minutes: 5)` (FR-004), and `shouldLock({lastActivityAt, now, isSignedIn, isLocked})`.
The existing `shouldRelockOnResume` (time since the app was *backgrounded*) is **replaced** by it (time since the last
*interaction*, which is never shorter): returning after more than 5 minutes away is still a lock (FR-003), and so is
5 idle minutes in the foreground. The `APP_LAST_BACKGROUNDED_AT` value in secure storage is no longer needed: nothing
survives a killed process anyway, because a cold start locks by itself (`AppLockNotifier`'s first-event rule).

**Root cause fixed here (constitution, Development Workflow)**: the old observer records the time only on
`AppLifecycleState.paused`. The framework documents `paused` as "only entered on iOS and Android"; a hidden browser tab
only reaches `hidden`, so on the web the rule never fired. The fix is at the observer, not at a call site, and it is
simpler than first planned: the decision now rests on the time of the last interaction, which no lifecycle state has to
report, so the observer handles only `resumed` (it asks the tracker to check at once) and `hidden`, `inactive` and
`paused` need no handling at all.

**Found by the browser run, fixed here**: the tracker listens to the lock from the first frame, so `AppLockNotifier` is
now created *before* the first auth event arrives. It used to decide on the first value it saw, which was then the
"still loading" state, so a page reload with a saved session no longer landed on the lock screen. It now waits for the
first real auth event (`app_lock_notifier_test`, group "created before the first auth event arrives").

**Rationale**: two rules measuring different things (time in the background, time since interaction) would disagree at
the edges and need two tests of the same promise. One rule, one number, one place to change it.

**Debug override for verification**: waiting 5 minutes per scenario makes manual checks impractical, so the period
accepts `--dart-define=INACTIVITY_LOCK_SECONDS=N`, **ignored in release builds** (`kReleaseMode`). Web verification
therefore uses a profile build (`flutter build web --profile`). A release build can never be shipped with a shorter
period, and unit tests inject the clock instead.

**Alternatives considered**: sign the person out instead of locking (rejected in the spec's Assumptions: it discards the
stored session and can drop unsynced changes); keep both rules (above).

## Decision 3: Hidden tabs and throttled timers

**Decision**: the lock decision is made from **timestamps**, not from a timer's tick count. The tracker runs a periodic
check (every 10 seconds) *and* checks immediately on every `resumed` (tab visible again, app back in front). A browser
may throttle or stop timers in a hidden tab, so the periodic check is best-effort; the on-resume check is what
is what applies the lock in the same event that reports `resumed`, before the next frame is built, so the first
frame the person sees should already be the lock screen (the quickstart has a browser step that looks for a flash of
content right after the tab becomes visible; if one shows up, the content layer is hidden while a check is pending).

**Consequence for the success criteria**: SC-001's "within 5 minutes plus 10 seconds" is measured at the moment the
person can see the screen (the tab becoming visible, or the window being in view), which is the only moment it matters.
The test injects a fake clock and a fake lifecycle event rather than waiting.

## Decision 4: Sharing the timer and the lock across browser tabs (FR-001a)

**Decision**: a small `LockChannel` abstraction in `core/auth/`, implemented on Web with the browser's
`BroadcastChannel` (named `finance-app-lock`) through `package:web`, and as a no-op everywhere else, selected by a
conditional import (`dart.library.js_interop`), the same isolation rule the constitution requires for platform
integration points. Messages (all versioned, `v: 1`):

| `type` | Sent when | Receiver does |
|--------|-----------|---------------|
| `activity` | an interaction, at most once every 5 seconds | `lastActivityAt = max(own, at)` |
| `lock` | this window's tracker locked the app (inactivity or resume check) | lock locally (idempotent) |
| `unlock` | this window unlocked (password or biometric) | unlock locally and `lastActivityAt = now` |

A newly opened tab does not need a message: a page load with a stored session is always locked (existing rule), so the
second tab shows the lock and the person unlocks it, which broadcasts `unlock` to the first. **A window's cold-start lock
never sends `lock`**: the tracker sends it only from its own inactivity or resume decision, otherwise opening a tab would
lock the tab the person is working in.

**Rationale**: `BroadcastChannel` is what the Supabase client already uses between tabs on the web (the comment on
`AuthRepository.verifyCurrentPassword` documents it), is delivered to hidden tabs, and needs no polling. A `localStorage` +
`storage` event approach works too but writes on every interaction and has no message types.

**Dependency**: `package:web` is added as a direct dependency (it is already in `pubspec.lock` through other packages and
is the Dart team's own library). `crypto` is added the same way (Decision 6). Both pass the constitution's
dependency-hygiene review: maintained by the Dart team, permissive license, no platform permissions.

**Alternatives considered**: `shared_preferences` on web (no change events); a `SharedWorker` (poor support); doing
nothing across tabs (rejected by the owner: a hidden tab would lock while the person works in another).

## Decision 5: When the PIN is offered

**Decision**: `pinAvailable = !kIsWeb && availability ∈ {noHardware, notEnrolled}`, where `availability` is the existing
`BiometricLoginRepository.availability()` (`available`, `webUnsupported`, `noHardware`, `notEnrolled`). It is decided at
runtime from what the device reports, never from the platform name (spec FR-006, constitution capability-detection
rule). Both the Security row and the one-time offer use the same provider, so they cannot disagree.

**A PIN that exists keeps working** even when biometrics later become available (spec FR-019), so two derived values are
used: `pinAvailable` (a PIN may be *created*: the rule above) and `pinInUse` (`!kIsWeb` and a record exists). The lock
screen's PIN mode and the Security row follow `pinInUse` (the row also follows `pinAvailable`); the one-time offer
follows `pinAvailable` only.

**Note on testing devices**: a stock Android emulator and the iOS simulator report `notEnrolled` until a fingerprint or
face is enrolled, so they show the PIN path without any special setup (and show the biometric path after enrolling).

## Decision 6: Storing and checking the PIN

**Decision**: `PinLockRepository` (`core/auth/`), behind a small interface so tests use an in-memory fake, stores three
things in `flutter_secure_storage` (Keychain / Keystore-backed), keyed by user id exactly like the biometric
preference (`BIOMETRIC_ENABLED_<userId>`):

- `PIN_RECORD_<userId>`: JSON `{v, salt, hash, iterations, setAt}` (salt: 16 random bytes; hash: 32 bytes of
  PBKDF2-HMAC-SHA256 over the PIN, 10 000 iterations, built on the `crypto` package's `Hmac`; both base64);
- `PIN_FAILS_<userId>`: the consecutive wrong-tries count;
- `PIN_OFFER_SHOWN_<userId>`: the one-time offer marker.

Checking follows an order that makes the limit impossible to bypass by killing the app mid-check: **increment the
persisted count first, then compare** (constant-time), then reset on success or invalidate (delete the record and the
count) when the count reaches 5.

**Rationale and honest limit**: a six-digit PIN has 10⁶ possibilities, so no hash makes it safe against someone who can
read the stored record; the protection is the attempt limit at the lock screen and the platform's secure storage (the
spec says so in Assumptions). The salted, iterated hash is there so the record never contains the PIN and cannot be
read back, which is the requirement (FR-012). 10 000 iterations are expected to take well under 100 ms on a phone (not
measured yet: the unit test asserts the hash+verify round trip stays under 250 ms on the test machine, and the emulator
pass records the real figure; if a device proves slower the work moves to an isolate with `Isolate.run`, no API
change).

**Expiry**: 365 days after `setAt` (never more than 12 months, the circular's bound), checked whenever the lock screen
asks for the PIN state; an expired PIN is treated like a forgotten one (spec FR-014).

**Alternatives considered**: the `cryptography` package for Argon2 (heavier dependency, no real gain for 10⁶ values);
storing the PIN itself in secure storage (violates "cannot be read back"); a server-side PIN (out of scope, and not
offline).

## Decision 7: Confirming the account password before the first PIN (FR-009)

**Decision**: reuse `AuthRepository.verifyCurrentPassword`, which already signs a *temporary* session in over plain REST
so the app's own session, router, lock and sync never see a second sign-in; the temporary session is closed right away
(the Security feature's change-password flow already does the same). A wrong password maps through the existing error
mapper to the same message; no connection maps to the existing "no connection" message and the set-up simply cannot
start (spec: setting the first PIN needs the network once).

**Alternatives considered**: a new password-check endpoint (none needed); asking for the password through the
sign-in screen (would be a real sign-in and re-trigger sync wiring).

## Decision 8: Where the PIN appears on screen

**Decision**:

- **Lock screen**: the existing `SignInScreen` already is the lock screen (the router sends a signed-in but locked
  person to `/sign-in`). When a PIN is active it shows a `PinEntryPanel` first, with "Dùng mật khẩu" and "Quên mã PIN"
  both revealing the existing password form; the biometric button (when both are on) sits beside the panel. Nothing
  about how the router locks changes.
- **Set up / change / turn off**: one `PinFlowScreen` (a pushed route from Bảo mật, in the shared column) with a `mode`
  and a linear step list (`confirmPassword → newPin → repeatPin`, `currentPin → newPin → repeatPin`, `currentPin`),
  driven by a controller that is a pure state machine (unit-testable).
- **Keypad**: one `PinKeypad` + `PinDots` in `features/account/presentation/widgets/`, shared by the lock screen and the
  flow. Both are screens of the account feature, so the widgets stay in the feature (the constitution puts something in
  `core/` only when two or more features use it). Digits and Backspace also work from a hardware keyboard.
- **One-time offer**: `maybeShowPinOfferPrompt`, called right after `maybeShowBiometricEnablePrompt` on every successful
  sign-in, with the same "shown once per account per device" rule and the same dialog focus rules.

**A password sign-in made while signed out** (the ordinary sign-in screen) also deletes any PIN left over for that
account: a session that expired or was revoked elsewhere ends without `AuthRepository.signOut` running, so this is
where the leftover is cleaned, with no auth-event listener and no change to `main.dart` in the PIN slice.

**After a password sign-in on the lock screen** the PIN is removed only if the person chose "Quên mã PIN" or the PIN was
expired or invalidated; "Dùng mật khẩu" keeps it (spec Story 2, scenario 3 versus Story 4).

## Decision 9: Layering and what goes in `core/`

`app_lock_policy`, `pin_rules`, `pin_hasher`, `pin_lock_repository`, `activity_tracker` and the lock channel live in
`core/auth/` beside `biometric_login_repository.dart`. The reasons differ by file:

- `app_lock_policy`, `activity_tracker` and the lock channel gate the whole app (the app root, the lifecycle observer and
  the router's lock) and are not specific to one feature.
- `pin_rules`, `pin_hasher` and `pin_lock_repository` are used only by the account feature's screens, **but** the core
  `AuthRepository` must clear the PIN on sign-out, exactly as it clears the biometric preference today, and the
  constitution forbids `core/` importing a feature's internals. Putting them in the feature would break that rule, so they
  stay in `core/auth/`; this is recorded as a justified exception in plan.md's Complexity Tracking.

The set-up screen, its controller, the offer and the keypad widgets stay in `features/account/presentation/` because only
the account feature shows them. Presentation holds no business rule: validation (`pin_rules`) and the state machine are pure Dart.

## Decision 10: Tests

- **Unit (pure)**: `AppLockPolicy`, `pin_rules` (length, easy PINs, expiry), `pin_hasher` (known-answer vector and
  round trip), the PIN verify sequence (increment-then-compare, invalidate at 5, reset on success), the flow state
  machine, the channel message codec.
- **Unit with a fake clock and `fakeAsync`** (`package:fake_async`, a Dart-team package already in the lock file through `flutter_test`; `flutter_test` does not re-export it, so it is added as a dev dependency): `ActivityTracker` locks at 5 minutes
  with no interaction, does not lock with an interaction every 4, ignores hover, counts scroll and key down, checks on
  resume, shares activity through a fake channel (two trackers), never locks when signed out.
- **Widget** at compact (412 × 915) and expanded (1440 × 900): lock screen with a PIN, flow screens, Security row states
  (offered / not offered on web / not offered with biometrics), the offer, the dots' semantics, 130 % text, light and
  dark, keyboard entry.
- **Existing tests**: the `shouldRelockOnResume` tests are rewritten for `AppLockPolicy`; the sign-in tests keep passing
  unmodified (the PIN panel only appears when a PIN is active).
- **Real devices and browsers**: Android emulator and iOS simulator (PIN path via `notEnrolled`), Chrome with two pages
  in one browser context (the `BroadcastChannel` is shared), a profile build with a short inactivity period.

## Decision 11: Strings and accessibility

All new text goes through the generated localizations in `vi` and `en`, with the parity test extended. The dots expose
one semantic label ("Đã nhập 3 trên 6 chữ số"), never the digits; the keypad keys carry their digit as a label, as
Chi tiêu's pad already does; error and tries-left messages are live regions so a screen reader announces them.

## Out-of-scope notes carried from the spec

Password composition and 12-month password expiry (deferred by the owner), a PIN on the web, an e-mail code, the
cold-start lock race (the new tracker neither depends on it nor changes `AppLockNotifier`'s first-event rule).
