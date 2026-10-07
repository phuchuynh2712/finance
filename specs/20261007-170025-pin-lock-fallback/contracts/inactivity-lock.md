# Contract: Inactivity Lock

**Stories**: US1 | **Requirements**: FR-001, FR-001a, FR-002, FR-003, FR-004, FR-005 | **Code**: `lib/core/auth/`

## 1. Policy (pure Dart, no Flutter import)

```text
AppLockPolicy
  static const Duration inactivityPeriod            // 5 minutes; debug/profile override INACTIVITY_LOCK_SECONDS
  static bool shouldLock({
    required DateTime? lastActivityAt,
    required DateTime now,
    required bool isSignedIn,
    required bool isLocked,
  })                                                 // isSignedIn && !isLocked && lastActivityAt != null
                                                     //   && now − lastActivityAt >= inactivityPeriod
```

- `INACTIVITY_LOCK_SECONDS` is read once; it is **ignored when `kReleaseMode`** (a release build always uses 5 minutes).
- A `lastActivityAt` in the future (the clock moved back) is treated as `now`: it never extends the period.

## 2. What counts as an interaction

| Counts | Does not count |
|--------|----------------|
| pointer down and up (tap, click, touch), pointer scroll (wheel, trackpad), a move while a button or finger is down (drag, touch scroll), a key-down on a hardware keyboard | a mouse passing over the window (hover), sync or timers, media, the window gaining or losing focus |

Typing on an on-screen keyboard is covered by the taps around it (spec Assumptions).

## 3. Tracker behavior (`ActivityTracker`)

1. Created once at the app root (`FinanceApp` watches its provider, as it does the lifecycle observer).
2. On an interaction: `lastActivityAt = now`; if the last `activity` message was sent more than
   `activityBroadcastInterval` (5 s) ago, send one (web only).
3. Every `checkInterval` (10 s) and on every `resumed` lifecycle event: `if shouldLock → appLockProvider.lock()` and send
   `lock`. `lock` is sent **only** from this decision: a window that starts locked (the cold-start rule of a page load)
   sends nothing, so opening a tab never locks a tab that is in use. On `hidden` and `paused` nothing is written; the next check measures the gap.
4. While signed out the tracker does nothing (no timer is armed).
5. A successful unlock (password, biometric or PIN) sets `lastActivityAt = now` and sends `unlock`.
6. Locking does not touch sync, the outbox worker or the pull service; it only changes `appLockProvider`.
7. The tracker never reads or writes financial data and never logs.

## 4. Window channel (web; a no-op on other platforms)

`LockChannel` (interface): `send(message)`, `Stream<LockMessage> messages`, `close()`. The web implementation wraps
`BroadcastChannel('finance-app-lock')`; others return an empty stream and ignore `send`.

| Message | Receiver action |
|---------|-----------------|
| `activity(at)` | `lastActivityAt = max(lastActivityAt, at)` |
| `lock` (sent only after an inactivity or resume decision, never for a window's cold-start lock) | if signed in and unlocked → `appLockProvider.lock()` (no re-broadcast) |
| `unlock` | if locked → `appLockProvider.unlock()`; `lastActivityAt = now` (no re-broadcast) |

Rules: messages carry no account data; unknown `v` or `type` is ignored; a message from the same window id is ignored;
no message ever *skips* the password, because `unlock` is only sent after a successful authentication in the sender.

## 5. Behavior table (acceptance)

| Situation | Result |
|-----------|--------|
| Signed in, no interaction for 5 min | locked; sign-in screen as lock; data hidden |
| Interaction at least every 4 min, for 20 min | never locked |
| Hover only for 10 min | locked at 5 min |
| Tab hidden 5+ min, becomes visible | locked at the `resumed` check |
| Phone backgrounded 5+ min, returns | locked (superset of today's rule) |
| Two tabs, interaction only in tab B for 20 min | neither locks |
| Two tabs, no interaction for 5 min | both locked; unlocking one unlocks the other |
| A second tab is opened (it starts locked) while the first is in use | the first stays unlocked and keeps working |
| Signed out | nothing happens |
| Release build, `INACTIVITY_LOCK_SECONDS=5` | still 5 minutes |

## 6. Tests this contract requires

`app_lock_policy_test` (table above, future timestamp, signed-out and already-locked cases);
`activity_tracker_test` with `fakeAsync` and an injected clock: 5-minute lock, interaction resets, hover ignored, scroll
and key count, resume check, signed-out no-op, two trackers over a fake channel (activity shared, lock and unlock
mirrored, own messages ignored, a second window that starts locked never locks the first); the same file also proves
FR-005 at the provider level: with `syncWorkerProvider` and `pullServiceProvider` overridden by recording fakes, locking
and unlocking neither dispose, restart nor rebuild them; `lock_channel_message_test` (codec, unknown version); the
rewritten `app_lifecycle_observer_test` (only `resumed` is handled; `hidden`, `inactive` and `paused` are ignored because the decision rests on the last interaction); `app_lock_notifier_test` (a session restored at the first auth event locks the app even when the notifier was created before that event).
