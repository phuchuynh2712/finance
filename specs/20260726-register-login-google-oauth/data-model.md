# Data Model: Registration & Google Sign-In

This feature extends how existing Supabase Auth accounts are created and authenticated against. It does **not** introduce new application-owned tables — `auth.users` and `auth.identities` (Supabase-managed) already model everything the spec's Key Entities require.

## Entities

### Account (maps to `auth.users`, no schema change)

Existing Supabase-managed entity. No new columns required by this feature.

| Field | Source | Notes |
|---|---|---|
| `id` | `auth.users.id` | Unchanged; already the FK target for every user-owned table (`envelopes`, `expense_entries`, etc. per `supabase/migrations/20260726154343_budget_envelopes.sql`) |
| `email` | `auth.users.email` | The sole login identifier per FR-014 — no separate username column is added |
| password (hashed) | `auth.users.encrypted_password` | Present only for accounts that registered via email/password (FR-001); absent for Google-only accounts |
| `display_name` | `auth.users.raw_user_meta_data.display_name` (JSON) | **NEW (2026-08-04, FR-001/FR-019)**: optional, set via `signUp()`'s `data:` parameter — same metadata mechanism already used for `avatar_url` by `AuthRepository.updateAvatar()`. Blank if not supplied at registration; may be filled in later from Profile (existing `updateAvatar`-style update, out of scope to build here beyond registration-time capture) |
| `phone_number` | `auth.users.raw_user_meta_data.phone_number` (JSON) | **NEW (2026-08-04, FR-001/FR-019/FR-020)**: optional, same `data:` mechanism. Stored as plain text, no format validation beyond non-empty-if-provided, no OTP/SMS verification (FR-020) — distinct from Supabase's separate built-in `auth.users.phone` column, which is reserved for phone-based auth and is not used here |
| created_at | `auth.users.created_at` | Unchanged |

**Validation rules** (client-side, enforced before calling Supabase):
- Email: standard email format (FR-002).
- Password: minimum 6 characters (FR-002, matching Supabase Auth's own default minimum).
- Confirm Password: must exactly match Password (FR-002, 2026-08-04).
- Display Name / Phone Number: no format validation — any non-empty string is accepted, empty is accepted (both optional per FR-019).

**Lifecycle**: Created by `AuthRepository.signUp()` (email/password, FR-001/FR-004) in an **unconfirmed** state (2026-08-04, FR-015 reversed) — the account exists but cannot sign in until the confirmation link is clicked (FR-021/FR-022). Google sign-in accounts (`signInWithIdToken()`, FR-006) are always immediately confirmed since Google already verified the email — this reversal does not affect the Google path. No delete/deactivate lifecycle is introduced by this feature.

**Confirmation state** (Supabase-managed, not a new column added by this feature): every `Account` has an underlying confirmed/unconfirmed flag internally, exposed to the client indirectly — `AuthResponse.session` is `null` from `signUp()` while unconfirmed (FR-021), and `signInWithPassword()` throws `AuthApiException(code: 'email_not_confirmed')` if attempted before confirming (FR-022). **2026-08-04 (2)**: this flag is now user-facing (the whole point of the reversal), but its existence was already the mechanism that makes FR-008's automatic Google-linking safe — see Google Identity Link below and research.md §6 — independently of whether the flag is also gating the ordinary email/password sign-in path.

### Google Identity Link (maps to `auth.identities`, no schema change)

Existing Supabase-managed entity (populated by `signInWithIdToken` and `linkIdentityWithIdToken`). Represents the association between one `Account` and one Google account.

| Field | Source | Notes |
|---|---|---|
| `user_id` | `auth.identities.user_id` | FK to the linked `Account` |
| `provider` | `auth.identities.provider` | `"google"` for all rows this feature creates |
| `identity_data` | `auth.identities.identity_data` (JSON) | Contains the Google account's email, used for display in Profile per FR-018 |

**Uniqueness rule** (enforced by Supabase Auth, not application code): at most one `google` identity per `Account`; at most one `Account` per distinct Google identity — attempting to violate this via `linkIdentityWithIdToken` raises `identity_already_exists` (FR-017, research.md §3).

**Lifecycle / state transitions**:
1. **None** → **Linked (new account)**: first-time Google sign-in with an email that has no existing `Account` (FR-006).
2. **None** → **Linked (existing account, automatic)**: Google sign-in with an email matching an existing password-based `Account` (FR-008) — Supabase's server-side `signInWithIdToken` performs this automatically; the client makes no linking decision itself. If that existing `Account` was unconfirmed (e.g. never signed in before, or a pre-registration by someone other than the real owner), Supabase evicts its other identities — including any password — as part of this transition (research.md §6).
3. **None** → **Linked (existing account, explicit)**: signed-in user explicitly links a Google account under a *different* email from Profile (FR-016) — the only case automatic linking (transition 2) cannot cover.
4. **Linked** → **Linked** (no-op, same account): repeat Google sign-in with an already-linked Google identity (FR-007).
5. **Rejected transition**: attempting to link (automatically or explicitly) a Google identity already linked to a *different* `Account` → no state change, `identity_already_exists` error surfaced (FR-017).

No other state transitions exist; this feature does not implement unlinking (out of scope, per spec Assumptions). Transition 2's safety against pre-registration takeover comes from the unconfirmed-identity eviction described above, and remains true regardless of FR-015's confirmation requirement (2026-08-04: now required) — see research.md §6 for the verified mechanism, and its process note on why this is independent of the Confirm Email project setting.

## Relationships

```text
Account (auth.users) 1 ──── 0..1 Google Identity Link (auth.identities, provider='google')
```

One `Account` optionally has exactly one Google identity linked. No entity in this feature has a relationship to the pre-existing `envelopes`/`expense_entries`/etc. tables beyond the existing `user_id` foreign key those tables already carry — this feature does not touch that schema.

## Out of scope for this data model

- A separate `profiles` table for a distinct "username" field — explicitly not needed per FR-014 (email is the only identifier).
- Any new Supabase migration file — this feature is pure Auth-API usage plus Dashboard configuration (Manual Linking toggle, OAuth provider setup per research.md §4), not schema change.
