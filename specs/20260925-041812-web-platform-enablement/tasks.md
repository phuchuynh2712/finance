---

description: "Task list for Web Platform Enablement"
---

# Tasks: Web Platform Enablement

**Input**: Design documents from `/specs/20260925-041812-web-platform-enablement/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/web-platform-enablement.md, quickstart.md

**Tests**: Included — the constitution's Principle II mandates tests with every feature; every task below that can be meaningfully automated on this session's Dart-VM `flutter test` gets one. Per research.md Decision 10, a handful of tasks are honestly marked **manual/best-effort** instead, since real in-browser Web behavior cannot be exercised by this session's test runner.

**Organization**: Tasks are grouped by user story (P1/P2/P3 from spec.md) so each can be implemented, tested, and verified independently, matching how the three stories were deliberately scoped as separable in `/speckit-specify`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1/US2/US3)
- Exact file paths are included in every description

## Path Conventions

Existing Flutter project layout (unchanged by this feature):
`lib/core/...`, `lib/main.dart`, `web/...`, `test/unit/...`, `test/widget/...` — mirroring `lib/`'s own structure per the constitution's Recommended Architecture section.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependency and Web-asset preparation needed before any story's code can actually run on Web (though the story code itself can be written against these independently of exact task order within this phase).

- [ ] T001 [P] Promote `flutter_web_plugins` from a transitive to a **direct** dependency in `pubspec.yaml` (`sdk: flutter`, already resolvable per `pubspec.lock` — no version to pick), then run `flutter pub get` (research.md Decision 6).
- [ ] T002 [P] Compile `web/drift_worker.js` via `dart compile js -o web/drift_worker.js <pub-cache>/drift-2.28.2/web/drift_worker.dart` (the installed `drift` package's own bundled worker entrypoint — offline, no network access needed; research.md Decision 2).
- [ ] T003 [P] Obtain `web/sqlite3.wasm` matching the pinned `sqlite3: 2.9.4` (per `pubspec.lock`) from the `sqlite3` Dart package's GitHub releases (research.md Decision 2). This session's GitHub access is scoped to `phuchuynh2712/finance` only — attempt it, and if it cannot be reached from here, document that plainly in the implementation notes rather than fabricating success; do not substitute an unrelated `.wasm` file (e.g. the DevTools-extension one found in the pub cache, which is not a general-purpose redistributable asset per research.md Decision 2).

**Checkpoint**: `pubspec.yaml` resolves cleanly; `web/drift_worker.js` exists; `web/sqlite3.wasm` exists (or its absence is explicitly documented as a task-execution-time blocker for T010/T028's build checks).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Confirm the starting baseline is clean before any story's changes land — User Stories 1, 2, and 3 otherwise touch disjoint files (database, auth, and Web/`main.dart` identity respectively) and have no other shared blocking prerequisite.

- [ ] T004 Confirm the baseline is clean before any implementation: `flutter analyze` (zero errors/warnings) and `flutter test` (413 tests, all passing — spec.md SC-006) both pass on the current `main`/branch tip, unmodified.

**Checkpoint**: Baseline confirmed clean — user story implementation can now begin.

---

## Phase 3: User Story 1 - Local data loads on Web (Priority: P1) 🎯 MVP

**Goal**: Fix the CRITICAL defect where the local Drift database never opens on Web, and give a total storage failure (even after fallback) a defined, non-silent behavior (FR-001–FR-003, FR-014, Clarification 2).

**Independent Test**: Sign in on a Web build and confirm Tổng quan shows real data matching mobile (not an error/empty state); record a transaction and confirm it survives a full page reload — fully verifiable without touching User Story 2 or 3's code.

### Implementation for User Story 1

- [ ] T005 [US1] In `lib/core/database/app_database.dart:12`, change `AppDatabase() : super(driftDatabase(name: 'finance'));` to pass `web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js'))` (research.md Decision 1; native-platform behavior is unchanged — `DriftNativeOptions` stays unset, matching today).
- [ ] T006 [P] [US1] In `lib/main.dart`, add a private `_StartupFailureReason` enum (`supabaseConfig`, `webStorage`) and give `_StartupErrorApp` a `required _StartupFailureReason reason` constructor parameter; inside its existing `Builder`, switch on `reason` to pick `l10n.startupConfigurationTitle`/`Message` for `supabaseConfig` (unchanged copy, unchanged behavior for the existing Supabase-init-failure call site) versus the new `l10n.startupWebStorageTitle`/`Message` getters for `webStorage` (data-model.md `_StartupFailureReason`). Update the existing `initSupabase()` catch block's call site to pass `reason: _StartupFailureReason.supabaseConfig`.
- [ ] T007 [P] [US1] Add new ARB keys `startupWebStorageTitle`/`startupWebStorageMessage` to both `lib/core/l10n/app_vi.arb` and `lib/core/l10n/app_en.arb` (accurate storage-failure copy — do not reuse the Supabase-specific wording; e.g. vi: "Không thể mở dữ liệu cục bộ" / "Trình duyệt đang chặn lưu trữ cục bộ cần thiết để chạy ứng dụng. Vui lòng kiểm tra cài đặt quyền riêng tư của trình duyệt rồi thử lại."), then run `flutter gen-l10n` to regenerate `app_localizations*.dart` (constitution Localization principle — vi+en together, same PR).
- [ ] T008 [US1] In `lib/main.dart`'s `main()`, after `initSupabase()` succeeds and only when `kIsWeb`: create a `ProviderContainer`, `await` a trivial warm-up query (e.g. `container.read(appDatabaseProvider).customStatement('SELECT 1')`) inside its own `try`/`on Object` block; on failure, `runApp(const _StartupErrorApp(reason: _StartupFailureReason.webStorage))` and `return`, mirroring the existing Supabase-failure early return immediately above it. On success (Web) or when `!kIsWeb` (skip warm-up entirely, per FR-012), proceed to the existing preference-loading step; change the final `runApp(...)` to `runApp(UncontrolledProviderScope(container: container, child: const FinanceApp()))` on the Web success path (reusing the warmed-up container) and leave the existing plain `ProviderScope(...)` path for non-Web platforms exactly as it is today (contracts/web-platform-enablement.md Startup Contract; depends on T005, T006, T007).
- [ ] T009 [P] [US1] Add `test/widget/startup_error_app_test.dart` (named after the widget under test, matching this repo's existing convention — e.g. `app_shell_nav_bar_test.dart`) with a widget test confirming `_StartupErrorApp(reason: .supabaseConfig)` renders `startupConfigurationTitle`/`Message` and `_StartupErrorApp(reason: .webStorage)` renders `startupWebStorageTitle`/`Message` — two distinct, non-overlapping copy pairs (depends on T006, T007).
- [ ] T010 [US1] Verify `flutter build web` completes without error against the now-non-null `web:` parameter and the assets from T001–T003 (a static compile check only — per research.md Decision 10 this cannot execute/prove the runtime `WasmDatabase.open` behavior, only that the code compiles and the referenced assets exist on disk) (depends on T001, T002, T003, T005, T008).
- [ ] T011 [US1] **Manual/best-effort** — attempt quickstart.md steps 1–3 and 8 (real data loads on a Web build against a real/local Supabase project; a write survives a full reload; the app still opens without cross-origin-isolation headers via the IndexedDB fallback; a simulated total-storage-failure browser shows the new `webStorage` startup-error screen). If this sandboxed session cannot reach a running browser/Supabase project to actually perform these checks, document that honestly (mirroring the previous feature's T030 precedent) rather than marking them verified.

**Checkpoint**: User Story 1 is independently functional — Web data loading works, and a total storage failure degrades gracefully instead of hanging silently.

---

## Phase 4: User Story 2 - Password reset works from a browser (Priority: P2)

**Goal**: Web password-reset requests generate an `https://` link instead of a mobile-only deep link, chosen at request time via a fixed build-time value (FR-004–FR-007, Clarification 1).

**Independent Test**: Trigger "forgot password" from a Web session and inspect the generated `redirectTo` value — confirm it is the configured `https://` (or local-dev `http://localhost`) URL, not `com.finance.finance://reset-callback`; confirm the same flow from mobile is completely unaffected.

### Implementation for User Story 2

- [ ] T012 [US2] In `lib/core/config/app_environment.dart`, add `static const webPasswordResetRedirectUrl = String.fromEnvironment('WEB_PASSWORD_RESET_REDIRECT_URL');` and extend `validate()` to check it **only when `kIsWeb`**: non-empty, parses as a `Uri` with a host, and either scheme `https`, or scheme `http` with host exactly `localhost`/`127.0.0.1` (research.md Decision 5 + its localhost-exemption addendum) — throw the same `FormatException` style as the existing checks on failure.
- [ ] T013 [P] [US2] Add a pure `String resolvePasswordResetRedirectUrl({required bool isWeb, required String webRedirectUrl, required String mobileRedirectUrl})` helper near `lib/core/auth/auth_repository.dart` (data-model.md) — returns `webRedirectUrl` when `isWeb`, else `mobileRedirectUrl`; no `BuildContext`, no platform check inside it (the caller supplies `isWeb`), so it is directly unit-testable.
- [ ] T014 [US2] In `lib/core/auth/auth_repository.dart`'s `resetPasswordForEmail`, replace the hardcoded `redirectTo: 'com.finance.finance://reset-callback'` with `redirectTo: resolvePasswordResetRedirectUrl(isWeb: kIsWeb, webRedirectUrl: AppEnvironment.webPasswordResetRedirectUrl, mobileRedirectUrl: 'com.finance.finance://reset-callback')` (depends on T012, T013).
- [ ] T015 [P] [US2] Add `test/unit/core/config/app_environment_test.dart`: `webPasswordResetRedirectUrl`/`validate()`'s new branch — a valid `https://...` value passes; `http://localhost:5000/...` passes (the exemption); `http://example.com/...` (non-localhost) fails; an empty value fails — each exercised via the Web-only validation path with an injected platform flag, not the real `kIsWeb` (research.md Decision 10; depends on T012).
- [ ] T016 [P] [US2] Add unit tests for `resolvePasswordResetRedirectUrl` (co-located with T013's file) covering both `isWeb: true` and `isWeb: false` (depends on T013).
- [ ] T017 [P] [US2] Add `"WEB_PASSWORD_RESET_REDIRECT_URL": "http://localhost:5000/reset-callback"` to `tool/env.example.json`, matching `README.md`'s already-documented `--web-port=5000` local Web dev workflow (research.md Decision 5 addendum).
- [ ] T018 [US2] Update `README.md`'s "Configure public runtime values" section (around line 96) to note the config file now also carries `WEB_PASSWORD_RESET_REDIRECT_URL`, and add one line to its "Prerequisites" section (around line 67) mentioning a Chromium-based browser for Web development — closing the constitution's own tracked Sync Impact Report follow-up TODO ("README.md's tech-stack/setup section still reads mobile-first") now that a real Web-enabling feature has landed (depends on T017, same file region).
- [ ] T019 [US2] **Manual/best-effort** — attempt quickstart.md step 4 (a real password-reset round-trip from a Web build, requiring a real `WEB_PASSWORD_RESET_REDIRECT_URL` already added to Supabase's Dashboard allow-list — the user's own action item per spec.md Assumptions, not something this task can complete unilaterally). Document status honestly rather than assuming the Dashboard entry already exists.

  *`/speckit-analyze` finding E2, resolved as a documented decision rather than a new test task*: FR-007 (the completed reset keeps today's global-sign-out behavior) needs **zero code change** — `confirmPasswordReset()` already calls `signOut(scope: SignOutScope.global)` unconditionally, with no platform branch. A true unit-level regression test would require mocking `SupabaseClient`/`GoTrueClient`, and this project has no mocking dependency today (no `mocktail`/`mockito` in `pubspec.yaml`) — adding one solely to assert a single unchanged line would be disproportionate new test infrastructure for a feature that touches neither this method nor its dependencies. T019's manual coverage (and the existing screen-level `reset_password_screen_test.dart`, which exercises the *caller* via a hand-written fake, unchanged by this feature) remain the appropriate level of coverage here.

**Checkpoint**: User Stories 1 and 2 both work independently; mobile's reset flow is provably unchanged (T016's `isWeb: false` case).

---

## Phase 5: User Story 3 - Web presents as the real "Kiểm Soát" product (Priority: P3)

**Goal**: Replace Flutter's default Web scaffolding identity and hash-based routing with the real product identity and path-based URLs (FR-008–FR-011).

**Independent Test**: Open a Web build, confirm the browser tab/PWA identity shows "Kiểm Soát" branding, navigate to a screen and confirm the address bar shows a clean path (no `#`), and confirm a resizable window isn't locked to one orientation — independent of User Story 1/2's code.

### Implementation for User Story 3

- [ ] T020 [US3] In `lib/main.dart`, call `usePathUrlStrategy()` (from `package:flutter_web_plugins/url_strategy.dart`) once, unconditionally, at the top of `main()` before `initSupabase()` — no `kIsWeb` guard needed, confirmed a no-op on non-Web platforms (research.md Decision 6; depends on T001).
- [ ] T021 [P] [US3] In `lib/main.dart`, change `MaterialApp.router`'s `title: 'Finance'` to `title: 'Kiểm Soát'`.
- [ ] T022 [P] [US3] Update `web/manifest.json`: `name`/`short_name` → `"Kiểm Soát"`; `theme_color`/`background_color` → `"#1A72E0"` (the app's existing verified light-scheme primary, per `test/unit/core/theme/app_theme_test.dart`); `description` → a real one-line description; remove the `"orientation": "portrait-primary"` key entirely (research.md Decision 8).
- [ ] T023 [P] [US3] Update `web/index.html`: `<title>finance</title>` → `<title>Kiểm Soát</title>`; the `description` meta content and `apple-mobile-web-app-title` content → `"Kiểm Soát"`-based values matching `manifest.json`.
- [ ] T024 [P] [US3] Add a file-content test (e.g. `test/unit/web/web_identity_test.dart`) that reads `web/manifest.json` and `web/index.html` directly (JSON parse / plain text search — no browser needed) and asserts: `manifest.json`'s `name`/`short_name`/`description` contain no leftover "finance"/"A new Flutter project" text and no `orientation` key exists; `index.html`'s `<title>` is not `finance` (research.md Decision 10).
- [ ] T025 [US3] **Manual/best-effort** — attempt quickstart.md steps 5–7 and 9 (browser tab/PWA identity inspection; a path-based URL loaded as a fresh/direct page load against hosting with an SPA-fallback rule — spec.md Assumptions; orientation unlocked on window resize; a full mobile regression pass confirming FR-012). Document status honestly, especially step 6's direct-deep-link check, which additionally requires a real chosen Web host this feature does not provide (research.md Decision 7).

**Checkpoint**: All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final, whole-repository verification after all three stories land.

- [ ] T026 [P] Run `dart format --output=none --set-exit-if-changed lib test` and `flutter analyze` across the full repository — zero formatting diffs, zero analyzer errors/warnings (constitution Principle I, Development Workflow).
- [ ] T027 Run the full `flutter test` suite and confirm it is still green, including every new test from T009, T015, T016, T024 (spec.md SC-006 — 413 tests at this feature's start, plus this feature's new coverage, all passing).
- [ ] T028 Run a final consolidated `flutter build web` covering all three stories' combined `web/`/`lib/main.dart` state (depends on T005–T024 all being complete).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup being at least started (T004 itself doesn't need T001–T003 to have finished, since it only checks the *pre-existing* baseline) — BLOCKS all user stories.
- **User Stories (Phase 3–5)**: All depend on Foundational (T004) completing. Genuinely independent of each other's *code* (disjoint files: `core/database/` vs. `core/auth/`+`core/config/` vs. `main.dart`+`web/`), but User Story 1 (T006, T008) and User Story 3 (T020, T021) both edit `lib/main.dart` — sequence US1 before US3 (as numbered) to avoid a same-file merge conflict within this single-implementer session, even though neither story's *logic* depends on the other's.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Within Each User Story

- US1: T005 (DB wiring) and T006–T007 (error-screen plumbing) can proceed in parallel; T008 needs all three; T009 needs T006–T007; T010 needs T001–T003, T005, T008; T011 is last (needs a working build).
- US2: T012–T013 can proceed in parallel; T014 needs both; T015 needs T012; T016 needs T013; T017–T018 (docs) can proceed any time after T012 is decided; T019 is last.
- US3: T020 needs T001; T021–T023 are independent of each other and of T020; T024 needs T022–T023; T025 is last.

### Parallel Opportunities

- Setup: T001, T002, T003 — different files/tools, fully parallel.
- US1: T006 and T007 in parallel (T006 is Dart code, T007 is ARB content); both parallel with T005 (different file).
- US2: T013, T015 (once T012 lands), T016, T017 — largely parallel; T012 and T014 are the two sequential anchors.
- US3: T021, T022, T023 — three different files, fully parallel; T024 waits on T022/T023.
- Across stories: once Phase 2 completes, US1 and US2 can be worked fully in parallel (zero shared files); US3's `main.dart` edits (T020–T021) should follow US1's `main.dart` edits (T006, T008) to avoid a same-file conflict, per the note above.

---

## Parallel Example: User Story 1

```bash
# T005, T006, T007 together (three different files, no shared state):
Task: "Add web: DriftWebOptions(...) to driftDatabase() in lib/core/database/app_database.dart"
Task: "Add _StartupFailureReason enum + parameterize _StartupErrorApp in lib/main.dart"
Task: "Add startupWebStorageTitle/Message ARB keys (vi+en) and regenerate l10n"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003).
2. Complete Phase 2: Foundational (T004).
3. Complete Phase 3: User Story 1 (T005–T011) — this alone resolves the CRITICAL `/speckit-analyze` finding from `adaptive-layout-foundation` (Web data never loads).
4. **STOP and VALIDATE**: confirm T010's build check passes and attempt T011's manual verification.

### Incremental Delivery

1. Setup + Foundational → baseline confirmed clean.
2. User Story 1 → the CRITICAL data-loading defect is fixed → deployable/demoable on its own.
3. User Story 2 → password reset now works from a browser → deployable/demoable.
4. User Story 3 → Web finally *looks* like the shipped product and has real URLs → deployable/demoable.
5. Polish → whole-repository verification, one final `flutter build web`.

---

## Notes

- [P] tasks touch different files with no completed-task dependency between them.
- Every manual/best-effort task (T011, T019, T025) exists so this feature's real-world verification status stays **tracked**, not silently dropped — matching this session's established practice of honestly documenting what a sandboxed environment cannot itself verify (research.md Decision 10), rather than marking a task done without evidence.
- T003's `sqlite3.wasm` download and T011/T019/T025's manual checks are the only tasks whose completion genuinely depends on resources outside this session's current reach (external network access, a real Supabase project, a chosen Web host) — every other task is fully executable here.
- Commit after each task or logical group, per this repository's established per-phase commit pattern from `adaptive-layout-foundation`.
