# Phase 1 Data Model: Web Platform Enablement

No persisted schema, domain entity, or migration is introduced or changed
by this feature — it fixes platform *configuration* and *integration*
defects, not data shape. What follows are the new, framework-independent
(or thin-Flutter) configuration/value types this feature introduces, per
research.md.

## `AppEnvironment.webPasswordResetRedirectUrl` (new field)

Defined in `lib/core/config/app_environment.dart`, alongside the existing
`supabaseUrl`/`supabasePublishableKey`.

| Field | Type | Source | Meaning |
|---|---|---|---|
| `webPasswordResetRedirectUrl` | `String` | `String.fromEnvironment('WEB_PASSWORD_RESET_REDIRECT_URL')` | The fixed `https://` URL Supabase redirects to after a Web password-reset link is opened (FR-004) |

**Validation rule** (in `AppEnvironment.validate()`, extended): only
checked when `kIsWeb` — MUST be non-empty and MUST parse as a `Uri` with
an `https` scheme and a non-empty host. Unchecked (and unused) on mobile,
so a mobile build with no `WEB_PASSWORD_RESET_REDIRECT_URL` define
supplied continues to build and run exactly as today (FR-012).

## `resolvePasswordResetRedirectUrl` (new pure function)

A small, directly-testable function (exact location: `lib/core/auth/
auth_repository.dart` or a private helper alongside it) — shape:

```text
String resolvePasswordResetRedirectUrl({
  required bool isWeb,
  required String webRedirectUrl,
  required String mobileRedirectUrl,
})
```

Returns `webRedirectUrl` when `isWeb` is `true`, otherwise
`mobileRedirectUrl`. Exists solely so `flutter test` (VM-only, `kIsWeb`
always `false`) can exercise both branches directly (research.md Decision
10) — `resetPasswordForEmail` calls it with the real `kIsWeb` and the two
real constants (`AppEnvironment.webPasswordResetRedirectUrl` and the
existing `'com.finance.finance://reset-callback'` literal).

## `_StartupFailureReason` (new, private, `lib/main.dart`)

A small enum distinguishing which localized copy `_StartupErrorApp` shows,
so the widget's existing structure (icon + title + centered message) is
reused without reusing its Supabase-specific wording for a different
failure (research.md Decision 9):

| Value | Title l10n key | Message l10n key | Triggered by |
|---|---|---|---|
| `supabaseConfig` (existing behavior, renamed from today's only case) | `startupConfigurationTitle` (existing, unchanged) | `startupConfigurationMessage` (existing, unchanged) | `initSupabase()` throwing |
| `webStorage` (new) | `startupWebStorageTitle` (new ARB key, vi+en) | `startupWebStorageMessage` (new ARB key, vi+en) | The `kIsWeb`-only database warm-up query (FR-014) throwing |

`_StartupErrorApp` takes a `required _StartupFailureReason reason`
constructor parameter and switches on it inside its existing `Builder` (where
`AppLocalizations.of(context)` is already resolved) to pick the right pair
of getters — no other change to its structure.

## Relationship to existing entities

None. This feature reads no domain entity (`ExpenseControlItem`,
`FinancialTransaction`, etc.) — `AppDatabase`'s tables and `AuthRepository`'s
`Session`/`User` shapes are entirely unchanged; only *how* the database
connection is opened (research.md Decision 1) and *which* redirect URL/
warm-up check runs (Decisions 5, 9) are new. `web/manifest.json` and
`web/index.html` (research.md Decision 8) are static platform-configuration
files, not application data.
