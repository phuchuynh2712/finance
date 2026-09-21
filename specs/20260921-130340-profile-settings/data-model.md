# Phase 1 Data Model: Profile Screen with Theme and Language Settings

## Entities

### Appearance Preference

A single device-level value representing the user's chosen app appearance.

| Field | Type | Notes |
|---|---|---|
| value | `ThemeMode` (`system` \| `light` \| `dark`) | `system` is the implicit default when no persisted value exists — matches current behavior (spec.md FR-004). |

**Persistence**: `shared_preferences`, key `pref_theme_mode`, stored as a `String` (`ThemeMode.name`: `"system"`/`"light"`/`"dark"`). Absent key ⇒ treated as `ThemeMode.system`.

**State transitions**: `system → light`, `system → dark`, `light → dark`, `dark → light` — all via explicit user selection on the Profile screen's Appearance toggle (FR-001). There is no UI path back to `system` once an explicit choice is made (per the reference mockup's two-option toggle — only Light/Dark are user-selectable options; `system` is purely the unset-default state, not a third selectable option). This matches spec.md's Key Entities section exactly.

**Validation**: N/A — the toggle only ever offers the two valid non-default values; no free-form input.

### Language Preference

A single device-level value representing the user's chosen display language.

| Field | Type | Notes |
|---|---|---|
| value | `Locale` (`vi` \| `en`) | `vi` is the implicit default when no persisted value exists — matches current hard-coded behavior (spec.md FR-008) and Constitution Principle III ("Vietnamese MUST be the default locale"). |

**Persistence**: `shared_preferences`, key `pref_locale`, stored as a `String` (the locale's `languageCode`: `"vi"`/`"en"`). Absent key ⇒ treated as `Locale('vi')`.

**State transitions**: `vi → en`, `en → vi` — via explicit selection in the Language selector dialog (FR-005). No `system`/unset state is user-reachable after a first explicit choice (mirrors Appearance).

**Validation**: Only `vi`/`en` are ever offered (spec.md Out of Scope: "Any third language beyond Vietnamese and English"). `AppLocalizations.supportedLocales` remains the single source of truth for which locales the app can render; the selector's option list MUST be derived from (or kept in lockstep with) that list, not hard-coded separately, so a future third language addition doesn't require touching two places.

## Existing entities referenced (not modified by this feature)

### Signed-in user identity (Supabase Auth `User`)

Read-only, already exists via `supabase_flutter`'s `SupabaseClient.auth.currentUser`. This feature adds two narrow read accessors on `AuthRepository` (research.md Decision 6) rather than a new entity:

| Field | Source | Notes |
|---|---|---|
| `currentEmail` | `currentUser?.email` | Always present for a signed-in user (email/password is the only auth method — Constitution-adjacent existing constraint in `auth_repository.dart`'s own doc comment). |
| `currentDisplayName` | `currentUser?.userMetadata?['display_name']` | Optional — set at sign-up (`auth_repository.dart:65-69`) but may be absent for accounts that skipped it. FR-009/Edge Cases: when absent, the UI derives a display name/initial from the email's local part (the substring before `@`) instead. |
| `currentAvatarUrl` | `currentUser?.userMetadata?['avatar_url']` | Already exists (`auth_repository.dart:130-131`), unchanged by this feature. When absent, FR-010's initial-letter placeholder is shown instead — no new upload path is introduced (Out of Scope). |

## Removed fields (research.md Decision 7)

The following `AccountState` fields and their backing `AccountController`/`AuthRepository` interface methods are deleted as part of this feature, per spec.md's Clarifications:

- `AccountState.isSubmittingAvatar`, `.avatarErrorMessage`, `.avatarSaved`
- `AccountState.isSubmittingPassword`, `.passwordErrorMessage`, `.passwordSaved`
- `AccountState.isBiometricEnabled`
- `AccountAuthActions.updateAvatar`, `.changePassword`

`AccountState.isSubmittingSignOut`-equivalent behavior (if any is added) and `signOut` itself are retained.
