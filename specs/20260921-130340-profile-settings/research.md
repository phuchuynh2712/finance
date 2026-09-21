# Phase 0 Research: Profile Screen with Theme and Language Settings

## Decision 1: Preference storage mechanism

**Decision**: Add `shared_preferences` as a new dependency. Wrap it behind a narrow interface, `AppPreferencesStorage`, in `lib/core/storage/app_preferences_storage.dart`.

**Rationale**: The Constitution's Offline-First Data & Sync section explicitly permits a key-value store "for non-relational, non-financial data (e.g. app settings, UI preferences)" and explicitly forbids it as a source of truth for money data — Appearance/Language preferences are exactly the permitted case. Drift would be architectural overkill for two scalar values with no relational structure and no sync requirement (Assumptions: these preferences are device-level, never synced to Supabase). `flutter_secure_storage` (already a dependency, used for biometric state) is the wrong tool here: it exists to protect secrets, and a theme/language choice is not sensitive data — using it anyway would misrepresent intent to future readers and adds unnecessary OS-keychain overhead for a value read on every cold start.

**Alternatives considered**:
- **Drift table**: rejected — no relational needs, and would pull two simple UI preferences into the same migration-versioned schema as financial data, working against the separation the Constitution's Offline-First section draws.
- **`flutter_secure_storage`**: rejected — wrong tool for non-secret data (see Rationale); also slower (OS keychain round-trip) for a value read synchronously-equivalent at every launch.
- **Hive**: rejected — the Constitution names Hive explicitly as the kind of key-value store that's acceptable for this exact use case, but the project has zero existing Hive dependency, while `shared_preferences` is the standard, actively-maintained Flutter-team-owned package with no added setup (no box registration, no adapters) for two scalar keys — smaller footprint for this project.

**Dependency hygiene review** (Constitution: Security § "Dependency hygiene"): `shared_preferences` is a Flutter-team-maintained federated plugin (`flutter.dev` first-party), BSD-3-Clause licensed, no elevated platform permissions requested (it reads/writes app-sandboxed `NSUserDefaults`/`SharedPreferences`/an XML file depending on platform). No maintenance-status concerns.

## Decision 2: Loading preferences before first frame

**Decision**: Load persisted `ThemeMode` and `Locale` synchronously-equivalent in `main()`, before `runApp()`, exactly like the existing `await initSupabase()` call. Pass the loaded initial values into the `ProviderScope` as provider `overrides`, so `themeModeProvider`/`localeProvider` start already holding the correct value on frame 1.

**Rationale**: `MaterialApp.router`'s `themeMode`/`locale` parameters are synchronous — if the providers instead loaded their persisted value asynchronously *after* first build (e.g. inside a `FutureBuilder` or a notifier's constructor firing an unawaited future), the app would render one frame with the defaults (light, Vietnamese) and then visibly flash to the user's actual stored preference. Constitution Principle III requires "A locale switch MUST be reflected immediately across the whole app without requiring a restart" — a launch-time flash is a visible violation of that immediacy guarantee, just at a different moment (cold start instead of user action). Loading before `runApp()` costs a few milliseconds of one-time startup latency, well inside the Constitution's <2s cold-start budget, and eliminates the flash entirely.

**Alternatives considered**:
- **Async load inside the notifier, defaulted state until loaded**: rejected — produces the flash described above.
- **`FutureBuilder` wrapping `MaterialApp`**: rejected — same flash risk (a loading frame before the real `MaterialApp` even mounts), and more complex than reusing the `main()`-level await pattern already established for Supabase init.

## Decision 3: State management shape

**Decision**: Two `StateNotifierProvider`s, matching the codebase's existing Riverpod `StateNotifier` pattern (e.g. `AccountController`, `IncomeFormController`):
- `themeModeProvider` → `ThemeModeNotifier extends StateNotifier<ThemeMode>`
- `localeProvider` → `LocaleNotifier extends StateNotifier<Locale>`

Both live in `lib/core/theme/` and `lib/core/l10n/` respectively (co-located with the `AppTheme`/`AppLocalizations` infrastructure they control), not inside any feature directory, since both are consumed app-wide from `main.dart`'s `FinanceApp` — the Constitution's "something belongs in `core/` only if it is used by two or more features" applies directly (every feature/screen is a consumer via the app-wide `MaterialApp`).

**Rationale**: Consistent with the one-state-management-approach rule (Constitution: Recommended Architecture) and the existing StateNotifier convention used throughout `lib/features/`. `FinanceApp` is already a `ConsumerWidget` (`lib/main.dart:19`), so wiring is a small diff: `ref.watch(themeModeProvider)` / `ref.watch(localeProvider)` passed straight into `MaterialApp.router`'s `themeMode`/`locale` parameters.

**Alternatives considered**:
- **A single combined `AppPreferences` notifier holding both values**: rejected — Appearance and Language are independently toggled, independently tested (spec.md's Independent Test sections), and have no shared invariant; splitting them keeps each notifier trivial to unit test in isolation and avoids one screen's toggle triggering an unrelated rebuild dependency.

## Decision 4: Icon substitution for names not present in `lucide_icons: ^0.257.0`

The reference `icons.json` names two icons not present under those exact identifiers in the installed package version. Resolved by direct inspection of `lucide_icons-0.257.0/lib/lucide_icons.dart`:

| Mockup name | Requested Flutter constant | Available in package? | Resolution |
|---|---|---|---|
| `sun-moon` | `LucideIcons.sunMoon` | **Yes** | Use as specified — no substitution needed. |
| `user-round` | `LucideIcons.userRound` | No | Use `LucideIcons.user` — the package's plain circular-head-and-shoulders glyph, already used elsewhere in the app's bottom nav for this exact tab (`app_router.dart`), so this is also a consistency win, not just a fallback. |
| `circle-help` | `LucideIcons.circleHelp` | No | Use `LucideIcons.helpCircle` — the same glyph under the package's older naming convention; visually identical to what the mockup specifies. |
| `bell` | `LucideIcons.bell` | Yes | Use as specified. |
| `shield-check` | `LucideIcons.shieldCheck` | Yes | Use as specified. |
| `chevron-right` | `LucideIcons.chevronRight` | Yes | Use as specified. |
| `log-out` | `LucideIcons.logOut` | Yes | Use as specified. |

**Rationale**: Verified directly against the resolved package source rather than assumed, per this project's established practice of confirming third-party API shape before relying on it (see prior feature's Drift `customUpdate` investigation). No visible difference in user-facing meaning for either substitution (spec.md Assumptions already documents this at a high level; this table is the concrete resolution).

## Decision 5: Language selector UI pattern

**Decision**: `showDialog` + `SimpleDialog` with one `SimpleDialogOption` per language (Tiếng Việt, English), reusing the app's existing dominant dialog pattern.

**Rationale**: `showDialog`/`AlertDialog` is the only modal-selection pattern already used in the codebase (`expense_control_screen.dart`); there is no `showModalBottomSheet` usage anywhere in `lib/`. Constitution Principle III: "a new screen MUST NOT invent a bespoke pattern where an existing one applies." A two-option selection list fits `SimpleDialog` (Flutter's standard widget for exactly this: a titled dialog offering a short list of choices) better than repurposing `AlertDialog`'s action-button layout for a selection list.

**Alternatives considered**:
- **`showModalBottomSheet`**: rejected — no existing usage in the codebase to be consistent with; would be a second, competing pattern for the same interaction class (dialogs) with no user-facing benefit for a 2-item list.
- **Inline expansion within the Profile screen (no dialog)**: rejected — the reference mockup and FR-005 both describe a menu row that opens a separate selector, not an inline expansion; also inconsistent with how "Thông báo"/"Bảo mật"/"Trợ giúp" rows behave (tap → navigate/open elsewhere).

## Decision 6: `AuthRepository` additions for display identity

**Decision**: Add two read-only getters to `AuthRepository`: `String? get currentDisplayName` (reads `userMetadata['display_name']`) and `String? get currentEmail` (reads `_client.auth.currentUser?.email`).

**Rationale**: FR-009 requires showing the signed-in user's name and email; `AuthRepository` already reads `userMetadata['avatar_url']` via the identical pattern (`currentAvatarUrl`, `auth_repository.dart:130-131`) and already writes `display_name` at sign-up (`auth_repository.dart:65-69`), but never exposed a getter for reading it back. This closes that gap using the exact existing pattern rather than introducing a new data-access approach.

## Decision 7: Removal scope for the current `AccountScreen`/`AccountController`

**Decision**: Per spec.md's Clarifications (2026-09-21), the avatar-URL text entry, password-change flow, and biometric-login toggle are deleted from the Profile screen and its controller — not hidden, not feature-flagged. This affects:
- `lib/features/account/presentation/account_screen.dart` — full rewrite (UI redesign to match the reference mockup).
- `lib/features/account/presentation/account_controller.dart` — `updateAvatar`, `changePassword`, `setBiometricEnabled` methods and their corresponding `AccountState` fields (`isSubmittingAvatar`, `isSubmittingPassword`, `avatarErrorMessage`, `passwordErrorMessage`, `avatarSaved`, `passwordSaved`, `isBiometricEnabled`) are removed; `signOut` is kept (FR-012).
- `lib/core/auth/auth_repository.dart`'s `AccountAuthActions` interface — `updateAvatar` and `changePassword` are removed from the interface (no longer called from the UI). `signOut` remains. **`setBiometricLoginEnabled`/`isBiometricLoginEnabled`/`shouldShowBiometricEnablePrompt`/`clearBiometricLoginState` are NOT removed from `AuthRepository`** — they remain in active use by the separate biometric quick-login sign-in flow (a prior feature), which is out of scope here; only their exposure as a toggle *on the Profile screen* goes away.
- `test/widget/features/account/account_screen_test.dart` — the entire file tests the removed UI; it is replaced with new tests against the redesigned screen (per plan's Phase 1 test tasks), not merely deleted.
- `test/widget/core/router/app_shell_nav_bar_test.dart`, `app_shell_discard_prompt_test.dart`, `overview_placeholder_test.dart` — each has a local fake implementing `AccountAuthActions` purely so the app shell compiles/routes in the test; verified their fakes only stub `updateAvatar`/`changePassword` without asserting behavior on them (they exist only to satisfy the interface). These fakes need their now-removed-from-interface method stubs deleted to keep compiling — no test assertions change.

**Rationale**: Confirms the "blast radius" before writing implementation tasks, per the Constitution's Code Quality principle (no dead code merged) — deleting the interface methods forces every caller/fake to be found and fixed at compile time rather than left as unreferenced dead code.

## Decision 8: Test plan

Per Constitution Principle II (80% domain/data coverage, tests in the same PR as behavior):
- Unit tests: `AppPreferencesStorage` (fake, in-memory for notifier tests) + `ThemeModeNotifier`/`LocaleNotifier` (initial value from storage, write-through on change, fallback to default on a simulated storage read error — spec.md Edge Cases).
- Widget tests: redesigned `AccountScreen` — renders name/email/avatar-initial fallback, Appearance toggle taps call the notifier and reflect active state, Language row opens the `SimpleDialog` and selecting an option calls the notifier, "Đăng xuất" calls sign-out, "Thông báo"/"Bảo mật"/"Trợ giúp" rows navigate to `NotAvailablePlaceholderScreen` with distinct titles.
- Integration test: choose a theme/language via the notifiers, simulate a fresh app start by constructing a new `ProviderScope` reading from the same underlying storage fake, confirm both choices are still active (spec.md SC-003).
