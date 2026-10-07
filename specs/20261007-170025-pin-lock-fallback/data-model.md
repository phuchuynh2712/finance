# Data Model: App Lock and PIN

**Feature**: `20261007-170025-pin-lock-fallback` | **Date**: 2026-10-07

Nothing here touches the Drift database, the sync outbox or the server. All state is in memory, in the platform's secure
storage (the PIN, on phones and tablets) or in a transient browser message (the web's shared timer).

## 1. Entities

### 1.1 Activity state (in memory, per window)

| Field | Type | Meaning |
|-------|------|---------|
| `lastActivityAt` | `DateTime` | the last interaction seen in this window, or the later of that and the last `activity` / `unlock` message from another window |
| `isLocked` | `bool` | the existing `appLockProvider` state; the tracker only reads it and calls `lock()` |
| `isSignedIn` | `bool` | the existing `isSignedInProvider`; the tracker does nothing while signed out |

Created at app start with `lastActivityAt = now`. Reset by an interaction, by an `unlock`, and by a successful sign-in.
Never persisted: a killed process starts locked by the existing cold-start rule.

### 1.2 Lock policy (constant, one place)

| Name | Value | Notes |
|------|-------|-------|
| `inactivityPeriod` | 5 minutes | the single named setting (FR-004); a non-release build may override it with `--dart-define=INACTIVITY_LOCK_SECONDS=N` |
| `activityBroadcastInterval` | 5 seconds | upper bound on `activity` messages from one window |
| `checkInterval` | 10 seconds | the tracker's periodic check; best-effort in a hidden browser tab |

`shouldLock = isSignedIn && !isLocked && now − lastActivityAt >= inactivityPeriod`

### 1.3 PIN record (secure storage, per account per device)

Key `PIN_RECORD_<userId>`; value is JSON:

| Field | Type | Meaning |
|-------|------|---------|
| `v` | int | format version, `1` |
| `salt` | base64 (16 bytes) | random per PIN |
| `hash` | base64 (32 bytes) | PBKDF2-HMAC-SHA256(PIN, salt, `iterations`) |
| `iterations` | int | `10000`; stored so it can be raised later without invalidating records |
| `setAt` | ISO-8601 UTC | when the PIN was set or last changed; expiry is `setAt + 365 days` |

The PIN itself is never stored, logged or sent. A record that cannot be parsed counts as "no PIN".

### 1.4 Wrong-tries count (secure storage)

Key `PIN_FAILS_<userId>`; an integer string, absent when zero. Maximum 5: reaching 5 deletes the record and the count.

### 1.5 PIN offer marker (secure storage)

Key `PIN_OFFER_SHOWN_<userId>`; the value `true` once the one-time offer was shown to this account on this device.

### 1.6 Window message (web only, transient)

`{"v":1,"type":"activity"|"lock"|"unlock","at":<epoch ms>,"from":"<window id>"}`. Unknown versions and types are ignored.
Never stored and never contains anything about the account.

## 2. Derived values

| Name | Definition |
|------|------------|
| `pinAvailable` | `!kIsWeb && availability ∈ {noHardware, notEnrolled}`: a PIN **may be created** (see research Decision 5); read again on every use, never cached |
| `pinInUse` | `!kIsWeb && status != none`: a PIN exists, whatever the biometric availability is now (FR-019) |
| `PinStatus` | `none` (no record) · `active` (record, not expired) · `expired` (record, `now >= setAt + 365 d`) |
| `triesLeft` | `5 − PIN_FAILS` |
| `lockScreenMode` | `pin` if `pinInUse && status == active`; otherwise `password` |
| `securityRowVisible` | `pinAvailable || pinInUse` |

## 3. State transitions

### 3.1 PIN lifecycle

```text
          set (password confirmed, PIN entered twice)
none ───────────────────────────────────────────────▶ active
  ▲                                                     │  │  │
  │  turn off (current PIN)                             │  │  │ change (current PIN, new PIN twice)
  ├─────────────────────────────────────────────────────┘  │  └──▶ active (setAt = now, fails = 0)
  │  sign-out                                               │
  ├─────────────────────────────────────────────────────────┤
  │  5th wrong try in a row → invalidated, record deleted   │
  ├─────────────────────────────────────────────────────────┤
  │  now ≥ setAt + 365 d → expired; the next lock shows the password form; a password sign-in deletes the record
  └─────────────────────────────────────────────────────────┘
```

### 3.2 Verifying a PIN (lock screen, change, turn off)

1. `status == active` and `fails < 5`, else do not ask.
2. `fails = fails + 1`, written to storage **before** comparing.
3. Compare the typed PIN with the record in constant time.
4. Match → `fails = 0`; return `success`. No match and the new `fails == 5` → delete record and count; return `invalidated`.
   Otherwise return `wrong(triesLeft = 5 − fails)`.

### 3.3 Lock state

```text
unlocked ──(no interaction for inactivityPeriod | resume after ≥ inactivityPeriod | cold start with a session)──▶ locked
locked   ──(correct PIN | biometric | password sign-in)──▶ unlocked          (then land on Tổng quan, as today)
```

On the web an inactivity or resume lock and every unlock are mirrored to the other windows by the `lock` / `unlock` messages. A window that merely loads locked (cold start) sends nothing, so it never locks a window that is in use.

## 4. Validation rules (pure, `pin_rules.dart`)

| Rule | Check |
|------|-------|
| format | exactly six characters, all `0-9` |
| easy PIN | not all six digits equal; not a straight run (each digit exactly +1 or exactly −1 from the previous) |
| match | the second entry equals the first |
| expiry | `now < setAt + 365 days` |

## 5. Invalidation and cleanup

- Sign-out: `PinLockRepository.clear()` runs where the biometric state is cleared today (before the session goes), deleting the
  record and the count. It keeps the offer marker on purpose: FR-018 says the one-time offer never comes back for an
  account on a device once shown (unlike the biometric offer, which a sign-out resets), so a person who signs out and in
  again is not asked a second time and finds the PIN row in Bảo mật.
- A password sign-in that follows "Quên mã PIN", an expired PIN or an invalidated PIN deletes the record and the count; it
  keeps the offer marker so the one-time offer is not repeated (the person is offered a new PIN directly, once).
- A password sign-in made while signed out (the ordinary sign-in screen, not the lock screen) deletes any leftover record and count of that account: this covers a session that expired or was revoked elsewhere, where no sign-out ran.
- Changing the PIN writes a new record (new salt) and resets the count.
