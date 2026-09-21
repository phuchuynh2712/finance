# Tasks: Profile Screen with Theme and Language Settings

**Input**: Design documents from `specs/20260921-130340-profile-settings/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/profile_ui_state.md, quickstart.md

**Tests**: Included — Constitution Principle II requires tests in the same PR as the behavior they cover; plan.md's Testing Standards Constitution Check and research.md Decision 8 both commit to a specific test plan.

**Organization**: Tasks are grouped by user story (US1 Appearance, US2 Language, US3 Account identity/menu/sign-out) per spec.md's priorities, after a Setup and Foundational phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps the task to US1/US2/US3, or none for Setup/Foundational/Polish
- File paths are exact, per plan.md's Project Structure

---

## Phase 1: Setup

**Purpose**: Add the new dependency and confirm the project compiles with it before any feature code is written.

- [X] T001 Add `shared_preferences` to `pubspec.yaml` dependencies (research.md Decision 1 — version per `flutter pub add shared_preferences`'s resolved latest stable), then run `flutter pub get`

**Checkpoint**: `shared_preferences` is resolvable and importable.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The storage abstraction and `AuthRepository` identity getters that both US1/US2 (storage) and US3 (identity) depend on. Must complete before any user story phase.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] Define the `AppPreferencesStorage` interface (`getThemeMode`/`setThemeMode`/`getLocale`/`setLocale`, per contracts/profile_ui_state.md's `AppPreferencesStorage contract`) and its `SharedPreferences`-backed implementation in `lib/core/storage/app_preferences_storage.dart` — read failures (malformed stored value, plugin error) MUST be caught and treated as "never set" (return `null`), never rethrown (contracts/profile_ui_state.md)
- [X] T003 [P] Unit test `AppPreferencesStorage`'s `SharedPreferences` implementation in `test/unit/core/storage/app_preferences_storage_test.dart` using `SharedPreferences.setMockInitialValues({})` (the package's standard test seam): round-trip get/set for both `ThemeMode` and `Locale`, absent key returns `null`, a malformed stored string is treated as `null` rather than thrown (depends on T002)
- [X] T004 [P] Add `String? get currentDisplayName` (reads `userMetadata['display_name']`) and `String? get currentEmail` (reads `currentUser?.email`) getters to `AuthRepository` in `lib/core/auth/auth_repository.dart` (research.md Decision 6, data-model.md)

**Checkpoint**: Storage abstraction and identity getters exist and are unit-tested. User story implementation can now begin.

---

## Phase 3: User Story 1 - Switch between light and dark appearance (Priority: P1) 🎯 MVP

**Goal**: A working Appearance toggle on the Profile screen that immediately re-themes the whole app and persists the choice across restarts, with no launch-time flash of the wrong appearance.

**Independent Test**: Per spec.md — tap the inactive Appearance option, confirm the whole app (Profile screen + at least one other tab) re-renders immediately; close and relaunch the app, confirm the choice is still active.

### Tests for User Story 1 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T005 [P] [US1] Unit test `ThemeModeNotifier` in `test/unit/core/theme/theme_mode_notifier_test.dart` using a fake `AppPreferencesStorage`: constructed with an initial value reflects it as `state`; `setThemeMode` updates `state` synchronously (before the storage write resolves) AND calls through to `setThemeMode` on the fake storage; a storage write failure does not throw out of `setThemeMode` and the in-memory `state` change still applies (contracts/profile_ui_state.md's notifier contract, spec.md Edge Cases)

### Implementation for User Story 1

- [X] T006 [US1] Implement `ThemeModeNotifier extends StateNotifier<ThemeMode>` and `themeModeProvider` in `lib/core/theme/theme_mode_notifier.dart`, per contracts/profile_ui_state.md's notifier contract (depends on T002, T005)
- [X] T007 [US1] In `lib/main.dart`, before `runApp()`: construct the `AppPreferencesStorage` implementation, read the persisted `ThemeMode` (defaulting to `ThemeMode.system` when absent, per FR-004), and pass it into `ProviderScope`'s `overrides` so `themeModeProvider` starts already holding the correct value on frame 1 (research.md Decision 2 — avoids the launch-time flash; mirrors the existing `await initSupabase()` pattern) (depends on T006)
- [X] T008 [US1] In `lib/main.dart`'s `FinanceApp.build`, replace the hard-coded `themeMode: ThemeMode.system` with `themeMode: ref.watch(themeModeProvider)` (depends on T007)
- [X] T009 [US1] Add the Appearance ("Giao diện") segmented toggle to `lib/features/account/presentation/account_screen.dart`: two options Sáng/Tối, highlighting whichever matches `ref.watch(themeModeProvider)` (when current value is `ThemeMode.system`, apply the same "inactive" visual style to both options rather than highlighting either — no reference screenshot depicts this state since the mockup only shows an explicit choice already made, per spec.md Acceptance Scenario 1.3), each tap calling `ref.read(themeModeProvider.notifier).setThemeMode(...)` — icon `LucideIcons.sunMoon` (research.md Decision 4), styling per `reference/ho-so-spec.md`'s "Card 'Giao diện'" section and the app's existing `AppColors`/`AppSemanticColors` tokens (depends on T006; can proceed in parallel with T007/T008 since it only needs the provider to exist, not the main.dart wiring, but cannot be manually verified end-to-end until T008 lands). **Note**: also rewrote the screen file wholesale (removing the pre-existing avatar-URL/password/biometric UI) rather than editing around it, and front-loaded T019's `AccountController`/`AccountState` cleanup immediately after — see T019.
- [X] T010 [US1] Widget test in `test/widget/features/account/account_screen_test.dart` (new/rewritten file — see T017 for the rest of this file's US3 coverage): tapping "Tối" calls `themeModeProvider.notifier.setThemeMode(ThemeMode.dark)` and the toggle reflects the new active state; tapping "Sáng" reflects back (depends on T009)

**Checkpoint**: Appearance toggle is fully functional, persists across restart, and is independently testable/demoable — this alone is a shippable MVP increment.

---

## Phase 4: User Story 2 - Switch the app's display language (Priority: P2)

**Goal**: A working Language selector on the Profile screen that immediately re-renders all app text and persists the choice across restarts, with no launch-time flash of the wrong language.

**Independent Test**: Per spec.md — open the "Ngôn ngữ" row, select the other language, confirm all text (including the Profile screen's own labels) switches immediately; relaunch, confirm it persists.

### Tests for User Story 2 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T011 [P] [US2] Unit test `LocaleNotifier` in `test/unit/core/l10n/locale_notifier_test.dart` using a fake `AppPreferencesStorage`: mirrors T005's structure for `Locale('vi')`/`Locale('en')` — initial value reflected, `setLocale` updates `state` before the storage write resolves, a storage write failure doesn't throw and the in-memory change still applies

### Implementation for User Story 2

- [X] T012 [US2] Implement `LocaleNotifier extends StateNotifier<Locale>` and `localeProvider` in `lib/core/l10n/locale_notifier.dart`, per contracts/profile_ui_state.md's notifier contract (depends on T002, T011)
- [X] T013 [US2] In `lib/main.dart`, alongside T007's Appearance load: read the persisted `Locale` (defaulting to `Locale('vi')` when absent, per FR-008) and pass it into `ProviderScope`'s `overrides` so `localeProvider` starts already holding the correct value on frame 1 (depends on T012; touches the same `main.dart` block as T007 — sequence after T007, not parallel, to avoid overrides-list conflicts in the same edit)
- [X] T014 [US2] In `lib/main.dart`'s `FinanceApp.build`, replace the hard-coded `locale: const Locale('vi')` with `locale: ref.watch(localeProvider)` (depends on T013)
- [X] T015 [US2] Add the Language ("Ngôn ngữ") menu row to `lib/features/account/presentation/account_screen.dart`, showing `ref.watch(localeProvider)`'s current value as its label ("Tiếng Việt"/"English"); tapping it opens a `showDialog` → `SimpleDialog` with one `SimpleDialogOption` per locale in `AppLocalizations.supportedLocales` (research.md Decision 5 — do not hard-code the option list separately from `supportedLocales`, per data-model.md's validation note), selecting an option calls `ref.read(localeProvider.notifier).setLocale(...)` and closes the dialog (depends on T012)
- [X] T016 [US2] Extend `test/widget/features/account/account_screen_test.dart`: tapping the "Ngôn ngữ" row opens the selector showing both languages with the current one indicated; selecting "English" calls `localeProvider.notifier.setLocale(Locale('en'))` and closes the dialog (depends on T015)

**Checkpoint**: Language selector is fully functional, persists across restart, and is independently testable/demoable alongside US1.

---

## Phase 5: User Story 3 - View account identity and access other settings (Priority: P3)

**Goal**: The Profile screen shows the signed-in user's identity, offers Notifications/Security/Help entry points, and lets the user sign out — completing the redesign to match the reference mockup and removing the old ad hoc fields.

**Independent Test**: Per spec.md — open Profile while signed in, confirm name/email/avatar are shown correctly (including the no-display-name fallback), confirm the three menu rows navigate to distinct placeholders, confirm sign-out works.

### Tests for User Story 3 ⚠️

> Write these tests FIRST; confirm they fail before implementation.

- [X] T017 [P] [US3] Widget tests in `test/widget/features/account/account_screen_test.dart` (this task supersedes the old file's contents entirely — the previous tests targeted the removed avatar-URL/password/biometric UI, per research.md Decision 7): renders display name + email when both are set; renders an avatar photo when `currentAvatarUrl` is set, otherwise an initial-letter placeholder derived from the display name, falling back to the email's local part when no display name is set (spec.md Edge Cases); tapping "Thông báo"/"Bảo mật"/"Trợ giúp" each navigate to `NotAvailablePlaceholderScreen` with a distinct title; tapping "Đăng xuất" calls the sign-out action

### Implementation for User Story 3

- [X] T018 [US3] In `lib/core/auth/auth_repository.dart`, delete `updateAvatar` and `changePassword` entirely — both from the `AccountAuthActions` interface AND their concrete implementations in `AuthRepository` (verified via grep during planning: neither is called anywhere outside the UI being deleted in T019/T020, and neither is referenced by any test assertion — only by disposable stub fakes, trimmed in T021). Keep `signOut`, `isBiometricLoginEnabled`, `setBiometricLoginEnabled`, `shouldShowBiometricEnablePrompt`, `clearBiometricLoginState` untouched (still used by the separate biometric sign-in flow, out of scope here) (depends on T004). **Expanded scope (advisor-confirmed during T017 prep)**: also added `currentDisplayName`/`currentEmail`/`currentAvatarUrl` as getters on `AccountAuthActions` itself (not a new interface) — `AccountAuthActions` was already the established "narrow, test-fakeable surface of `AuthRepository`" pattern in this codebase, so identity data needed by T017/T020 belongs on the same interface as `signOut`, not a second one. `AuthRepository`'s existing `currentDisplayName`/`currentEmail`/`currentAvatarUrl` getters (added in T004) now carry `@override`.
- [X] T019 [US3] In `lib/features/account/presentation/account_controller.dart`, remove `AccountState`'s `isSubmittingAvatar`, `avatarErrorMessage`, `avatarSaved`, `isSubmittingPassword`, `passwordErrorMessage`, `passwordSaved`, `isBiometricEnabled` fields and the `updateAvatar`, `changePassword`, `setBiometricEnabled` methods (and the now-unused `_loadBiometricState` constructor call); keep `signOut` (depends on T018). **Done ahead of schedule** (right after T009/T010): `AccountController` no longer has any state to hold, so it was simplified from `StateNotifierProvider`/`StateNotifier<AccountState>` to a plain `Provider<AccountController>` (the `AccountState` class itself is now gone entirely, not just trimmed) — `account_screen.dart` updated to `ref.read(accountControllerProvider)` instead of `.notifier`. `AccountAuthActions` interface still has `updateAvatar`/`changePassword` at this point (T018 not yet done) — they're simply unused by the controller now, not yet removed from the interface.
- [X] T020 [US3] Rewrite `lib/features/account/presentation/account_screen.dart`'s layout to match `reference/ho-so-spec.md`: header (icon badge `LucideIcons.user` — research.md Decision 4 — + "Hồ sơ" title), user info block (avatar via `AuthRepository.currentAvatarUrl`/initial-letter fallback per data-model.md, name via `currentDisplayName` falling back to `currentEmail`'s local part, email via `currentEmail`), then the Appearance card (T009) and Language row (T015) already added in US1/US2, then a menu card with three rows — "Thông báo" (`LucideIcons.bell`), "Bảo mật" (`LucideIcons.shieldCheck`), "Trợ giúp" (`LucideIcons.helpCircle` — research.md Decision 4) — each `Navigator.push`ing `NotAvailablePlaceholderScreen` with a distinct icon/title/message, then a standalone "Đăng xuất" row (`LucideIcons.logOut`, danger-colored per `reference/theme-tokens.json`) calling `controller.signOut()`; styling throughout uses the app's existing `AppColors`/`AppSemanticColors` tokens (FR-014) (depends on T009, T015, T019)
- [X] T021 [US3] Update the three router test fakes — `test/widget/core/router/app_shell_nav_bar_test.dart`, `app_shell_discard_prompt_test.dart`, `overview_placeholder_test.dart` — to delete their now-removed-from-interface `updateAvatar`/`changePassword` stub overrides on their local `AccountAuthActions` fakes, so they keep compiling against the trimmed interface (research.md Decision 7); no test assertions in these files change (depends on T018). **Scope grew during T009/T015**: two of the three files (`app_shell_nav_bar_test.dart`, `app_shell_discard_prompt_test.dart`) render the real `AccountScreen` via the app shell's "Hồ sơ" tab, which now depends on `themeModeProvider`/`localeProvider` — both files' `ProviderContainer` needed `themeModeProvider.overrideWith(...)`/`localeProvider.overrideWith(...)` added (with a local `_FakeAppPreferencesStorage`) *immediately*, not deferred to this task, since without them every test touching the "Hồ sơ" tab threw `UnimplementedError` at Phase 3/4 checkpoint time (the providers' intentional "must be overridden" guard — see T006/T012). This was done proactively right after T009 and T016 respectively, confirmed via a full `flutter test` regression pass at each phase's checkpoint. `overview_placeholder_test.dart` doesn't render `AccountScreen` and only needed the interface-trim part. All three files' fakes now implement the T018-expanded `AccountAuthActions` shape (`currentDisplayName`/`currentEmail`/`currentAvatarUrl` getters instead of `updateAvatar`/`changePassword`).

**Checkpoint**: All three user stories are complete; the Profile screen fully matches the reference mockup and the old ad hoc fields are gone.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cross-story verification the individual story checkpoints don't cover on their own.

- [X] T022 [P] Integration test in `test/integration/profile_preferences_persistence_test.dart`: using a real (non-mocked) `SharedPreferences` instance with `setMockInitialValues({})`, set Appearance to Dark and Language to English via the notifiers, construct a fresh `ProviderScope` reading from the same underlying preferences, and confirm both choices are still active — proving spec.md SC-003 end-to-end across the notifier + storage + main.dart-load boundary, not just within a single notifier's unit test. Add a second case in the same file that also proves FR-013 directly: after setting both preferences, simulate a sign-out/sign-in-as-a-different-account cycle (call `AuthRepository.signOut()` against a fake/test auth setup, or — if a live auth call is impractical in this test's harness — construct a fresh `ProviderScope` as if a different account had signed in) and confirm the preferences are still Dark/English, unaffected by the account change (spec.md Edge Cases 3rd bullet, quickstart.md's "Cross-cutting" section — this is the one edge case that was previously untested by this task)
- [X] T023 Run `flutter analyze` and fix any issues; run `dart format` across all touched files (Constitution: Code Quality, Development Workflow)
- [X] T024 Run the full `flutter test` suite and confirm no regressions in previously-passing tests (especially the three router tests touched in T021)
- [ ] T025 Walk through every scenario in `quickstart.md` on a real device/emulator, including the corrupted-preference edge case and the sign-out/sign-in-as-different-user cross-cutting scenario — confirm no launch-time appearance/language flash on a cold start after a preference has been set. Additionally, visually compare the redesigned Profile screen itself against `reference/screen-light.png` (in light appearance) and `reference/screen-dark.png` (in dark appearance) — layout, spacing, icon colors, and card styling should match (Constitution Principle III: "Both light and dark mode MUST be supported and visually verified for every new screen"). **Known mockup artifact — do not replicate**: `reference/screen-dark.png` shows the Appearance toggle with "Sáng" (Light) highlighted as active even though the screenshot itself is otherwise rendered in the dark color scheme — this is a designer copy-paste artifact (the toggle's active state wasn't updated when the dark variant was produced from the light one), not an intentional design decision. The built toggle MUST always reflect the actual live `ThemeMode` (FR-001) — when verifying in dark appearance, "Tối" MUST be the highlighted option, contradicting this one detail of the reference image; every other visual aspect of the dark screenshot (colors, spacing, icons, card styling) is still valid to match. **Not completed in this session**: the app was rebuilt on-device (Pixel 9 emulator) and reached the login screen, but the session ended before re-authenticating and stepping through the walkthrough itself — no visual confirmation was captured. All other tasks (T001–T024) are complete and independently verified via automated tests (`flutter analyze` clean, full `flutter test` suite passing) — only this manual on-device pass remains outstanding.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (needs `shared_preferences` resolvable) — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational (T002). No dependency on US2/US3.
- **User Story 2 (Phase 4)**: Depends on Foundational (T002). No dependency on US1, but T013 touches the same `main.dart` region as T007 — do T007 first if both are in flight, to avoid a merge conflict in the `overrides` list.
- **User Story 3 (Phase 5)**: Depends on Foundational (T004) AND on T009 (US1's Appearance card) + T015 (US2's Language row), since T020 assembles the full screen including both — US3's *screen assembly* task is therefore the one place this feature isn't fully story-independent, matching spec.md's own framing ("US3 rounds out the screen... does not block the value delivered by Stories 1 and 2" — the dependency runs the other direction: US3 depends on US1/US2 having landed, not vice versa).
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Parallel Opportunities

- T002, T003, T004 (Foundational) can all run in parallel — different files, no shared dependencies.
- T005 and T011 (US1/US2 notifier unit tests) can run in parallel — different files.
- T009 (US1's toggle UI) and T015 (US2's language row UI) touch the same file (`account_screen.dart`) but different, non-overlapping sections — sequence them rather than running truly in parallel to avoid edit conflicts, even though neither depends on the other's logic.
- T021 (three router test fakes) can be done in parallel across its three files.

---

## Parallel Example: Foundational Phase

```bash
Task: "Define AppPreferencesStorage interface + SharedPreferences impl in lib/core/storage/app_preferences_storage.dart"
Task: "Add currentDisplayName/currentEmail getters to AuthRepository in lib/core/auth/auth_repository.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) + Phase 2 (Foundational).
2. Complete Phase 3 (US1 — Appearance toggle).
3. **STOP and VALIDATE**: run quickstart.md's US1 section on-device, confirm no launch flash.
4. This alone is a demoable increment: the app gains real user-controlled theming for the first time.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. US1 (Appearance) → validate independently → demoable.
3. US2 (Language) → validate independently → demoable (US1 and US2 can be built in either order, or concurrently by two people, once Foundational is done).
4. US3 (Account identity/menu/sign-out) → validate — this is also where the old ad hoc fields are actually removed, so the screen only fully matches the reference mockup once US3 lands.
5. Polish (Phase 6) → full regression pass + quickstart.md walkthrough.

---

## Notes

- [P] tasks touch different files with no completed-task dependency between them.
- [Story] labels map every user-story-phase task back to spec.md's US1/US2/US3 for traceability.
- T007/T013 both edit `lib/main.dart`'s pre-`runApp()` block — do them in sequence (T007 then T013), not in parallel, even though they're in different user-story phases.
- Commit after each task or logical group, per the Development Workflow section of the Constitution.
- T020 is the single task where all three stories' work is assembled into the final screen — don't treat it as "done" until T009 and T015 have already landed.
