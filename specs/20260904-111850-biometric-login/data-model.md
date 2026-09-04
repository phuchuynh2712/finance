# Data Model: Biometric Login & Sign-Up Refactor

No new Supabase schema and no new Drift tables. Every entity below maps onto either (a) Supabase's existing `auth.users` metadata mechanism, already used by the prior feature, or (b) on-device secure storage / in-memory state. See research.md §5–§9 for the sourcing of each decision below.

## 1. Biometric Login Preference

Per-device, per-account boolean. **Not** a server-side entity — Supabase has no knowledge of this setting, per spec Assumptions ("not synced across devices").

| Field | Type | Storage | Notes |
|---|---|---|---|
| `userId` | `String` | key suffix | Supabase auth user id; scopes the flag to one account so a different account signing in later on the same device does not inherit it (FR-013) |
| `enabled` | `bool` | `flutter_secure_storage` value under key `BIOMETRIC_ENABLED_<userId>` | Absence of the key = disabled (default state for a never-enrolled account/device pair) |
| `promptShown` | `bool` | `flutter_secure_storage` value under key `BIOMETRIC_PROMPT_SHOWN_<userId>` | FR-009 requires the enable-biometric prompt to be one-time — this key distinguishes "never asked" (key absent → show the prompt after this authentication) from "asked once, user declined" (key present, `enabled` still absent → do NOT auto-show again, User Story 3 acceptance #3). Set `true` the moment the prompt is shown, regardless of the user's answer; only ever cleared alongside `enabled` on full sign-out (FR-014a) so a fresh sign-in on that device is treated as a new enrollment opportunity |

**Lifecycle**:
- `promptShown` set `true` the first time FR-009's prompt is shown (right after Sign Up or Sign In) on a device/account pair that has never seen it.
- `enabled` created/set `true` when the user accepts the FR-009 prompt or toggles it on from the Account screen (FR-010).
- Both keys deleted together (not just `enabled` set to `false`, to keep "absent = disabled/never-asked" as the one source of truth) when: the user toggles `enabled` off from the Account screen (FR-010, `promptShown` stays — declining/disabling later should not re-trigger the one-time prompt), the user signs out (FR-014a, both keys cleared — a future sign-in on this device is a fresh enrollment opportunity), the device's OS-level biometric enrollment is found removed (FR-014, `enabled` cleared; `promptShown` may remain since re-prompting immediately would just fail again), or the session is force-revoked by another device's password reset/change (FR-016a/FR-016b, per spec Edge Cases — treated the same as FR-014a once the user re-authenticates).

## 2. User Profile (extension)

Already exists via Supabase `auth.users` + `data:` metadata (prior feature). This feature adds no new fields — full name and phone number were already added as optional `signUp()` parameters previously; this feature only makes email required (client-side validation, not a schema change) and rebuilds the screen that collects them.

| Field | Type | Storage | Notes |
|---|---|---|---|
| `email` | `String` | `auth.users.email` | Sole authentication credential (spec Clarifications); required at sign-up in this feature (previously also required, unaffected by mockup's "optional" label per spec Assumptions) |
| `displayName` | `String?` | `auth.users.raw_user_meta_data.display_name` | Unchanged from prior feature |
| `phoneNumber` | `String?` | `auth.users.raw_user_meta_data.phone_number` | Unchanged from prior feature; profile-only, never a login credential (FR-005) |
| `avatarUrl` | `String?` | `auth.users.raw_user_meta_data.avatar_url` | Pre-existing, untouched by this feature |

## 3. App Lock State

In-memory only (Riverpod `StateNotifierProvider<bool>`, e.g. `appLockProvider`) — not persisted as its own entity; derived at runtime from the two on-device values below plus the existing session state.

| Field | Type | Storage | Notes |
|---|---|---|---|
| `isLocked` | `bool` | Riverpod state (memory only, reset every cold start) | `true` initially whenever a valid session exists at cold start (FR-020); flips to `false` on successful biometric or password unlock |
| `lastBackgroundedAt` | `DateTime?` | `flutter_secure_storage` value under key `APP_LAST_BACKGROUNDED_AT` (device-global, not per-account) | Written on `AppLifecycleState.paused`; read + compared on `AppLifecycleState.resumed` to decide whether to re-lock (FR-020's 5-minute threshold, research.md §4) |
| `isPasswordRecovery` | `bool` | Riverpod state (memory only), derived from `AuthRepository.onPasswordRecoveryEvent` | `true` once the FR-016 recovery deep link opens the app; takes router priority over `isLocked`/`isSignedIn` (contracts/auth_repository_interface.md §4) so the user lands on "Set New Password," not the main app; reset to `false` once `confirmPasswordReset()` completes |

## 4. Password Reset Request

Entirely server-side (Supabase Auth built-in recovery flow) — no local persistence, no new table. Modeled here only to document its shape for the contract in `contracts/auth_repository_interface.md`.

| Concept | Backing mechanism |
|---|---|
| Request a reset | `supabase.auth.resetPasswordForEmail(email, redirectTo: <deep link>)` |
| Recovery session arrival | `AuthChangeEvent.passwordRecovery` on `onAuthStateChange` (research.md §3) |
| Completing the reset | `supabase.auth.updateUser(UserAttributes(password: newPassword))` |
| Side effect (FR-016a) | Immediately followed by `supabase.auth.signOut(scope: SignOutScope.global)` |

## 5. Session Revocation Scope (new concept, not a stored entity)

Documents the three sign-out scopes this feature now uses, all via the existing `AuthRepository.signOut()` surface (extended to accept a scope), per research.md §2:

| Trigger | Scope | Spec FR |
|---|---|---|
| User taps "Sign out" on Account screen | `SignOutScope.local` (unchanged default) | FR-014a |
| Password reset (Forgot Password) completes | `SignOutScope.global` | FR-016a |
| Password change (Account screen) completes | `SignOutScope.others` | FR-016b |

## Entity Relationship Summary

```text
auth.users (Supabase, existing)
 ├─ email, raw_user_meta_data{display_name, phone_number, avatar_url}   (§2, unchanged shape)
 └─ sessions (Supabase-managed, N per user)                              (§5, scope-based revocation)

Device-local (flutter_secure_storage, new keys this feature adds)
 ├─ SUPABASE_PERSIST_SESSION_KEY        existing, unchanged (SecureLocalStorage)
 ├─ BIOMETRIC_ENABLED_<userId>          NEW — §1, one per account ever enabled on this device
 └─ APP_LAST_BACKGROUNDED_AT            NEW — §3, one per device

In-memory (Riverpod, not persisted)
 └─ appLockProvider.isLocked            NEW — §3, recomputed every process start
```
