# Tasks: Restore Buildability — Fix Icon Library Incompatibility

**Input**: Design documents from `specs/20261005-211030-fix-lucide-icons-compat/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/persisted-icon-keys.md](./contracts/persisted-icon-keys.md), [quickstart.md](./quickstart.md)

**Tests**: Included — constitution Principle II requires tests in the same PR as the behavior they cover. Two small tests are added (import-seam rule, persisted icon-key contract; research.md Decision 6); all existing tests keep their intent and only change an import line. No new test framework.

**Organization**: Grouped by user story per spec.md priorities: US1 (P1, MVP — the app builds, the full suite runs, and the constitution's format gate is green), US2 (P2 — every icon stays the same recognizable icon), US3 (P3 — `CLAUDE.md` points at the plan in progress), US4 (P2 — the first sign-in navigates; added 2026-10-06 after the owner confirmed the defect, phase at the end because it was discovered during verification). The format-only change set (FR-011) lives inside US1 because US1 Acceptance Scenario 5 requires it, but it is kept as its own change set/commit so it can be reviewed or dropped independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1, US2, US3, US4 (Setup, Foundational and Polish phases carry no story label)
- File paths are exact, per plan.md's Project Structure

## Path Conventions

Single Flutter project (existing structure): `lib/`, `test/`, repository root config files. Commands run from the repository root `/Users/phuchuynh/finance`.

**Import edit rule** (used by T006–T011): in each listed file, delete the line `import 'package:lucide_icons/lucide_icons.dart';` and add `import 'package:finance/core/theme/app_icons.dart';` inside that file's existing `package:finance/...` import group, in alphabetical position (if the file has no such group, add one after a blank line following the `package:flutter...`/third-party imports). Do **not** rename any `LucideIcons.*` constant and do not touch anything else in the file.

**Format rule** (used by T003, T005, T020): run `dart format <file>` on every file you create or edit so the format gate (T018) only ever has to touch the 11 pre-existing files it lists.

**Baseline & escalation rule** (used by T023–T026): the baseline for each icon is the design reference (`specs/*/reference/icons.json`, which pin 27 of the 52 icons); for the other 25 it is the intended Lucide concept implied by the existing constant name in the `data-model.md` inventory. If you are unsure whether a difference is an acceptable upstream stroke-level redraw or a changed line style/weight, do not decide alone — record it (icon, screen, light/dark) in the task's result and let the owner decide.

---

## Phase 1: Setup

**Purpose**: Confirm the starting state so later before/after claims are meaningful.

- [X] T001 Confirm the starting state: `git branch --show-current` prints `20261005-211030-fix-lucide-icons-compat`; `flutter --version` reports Flutter 3.47.x; `git status --short` shows only Spec Kit files (`.specify/`, `CLAUDE.md`, `specs/20261005-211030-fix-lucide-icons-compat/`) and no change to `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `lib/` or `test/`. The failing baseline (web build error, 22 unloadable test files, 11 format failures) is already recorded in research.md Decisions 1 and 5 — do not re-run it, and if any tool run dirtied `pubspec.lock` or `analysis_options.yaml`, restore them with `git checkout -- pubspec.lock analysis_options.yaml` before continuing.

**Checkpoint**: Clean, known starting point on the right branch and toolchain.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Swap the dependency and create the single import seam — nothing else compiles until this is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] In `pubspec.yaml` (line 70) replace `lucide_icons: ^0.257.0` with `lucide_flutter: ^1.47.0`; change nothing else in the file (research.md Decision 2; FR-003).
- [X] T003 [P] Create `lib/core/theme/app_icons.dart` containing a short `///` doc comment explaining it is the only file allowed to import the third-party icon package (so a future package swap is a one-file change; research.md Decision 3 — avoid writing the literal string `package:lucide_flutter` in the comment, so T012's grep stays unambiguous) followed by exactly one directive: `export 'package:lucide_flutter/lucide_flutter.dart' show LucideIcons;`. No class, no getters, no logic. Apply the Format rule.
- [X] T004 Run `flutter pub get` (after T002). As observed on 2026-10-05, expect `lucide_icons` removed, `lucide_flutter 1.47.0` (or a newer 1.x) added, and toolchain-forced updates `intl` 0.20.3, `matcher` 0.12.20, `meta` 1.19.0, `test_api` 0.7.12, `vector_math` 2.4.3 in `pubspec.lock` (about 7 changes; the exact set may differ if newer pub releases exist — every extra change must be explainable as a toolchain/pub-forced resolution, never a hand edit), plus the toolchain rewriting `analysis_options.yaml` (an `analyzer: exclude:` block for `build/**`, `android/**`, `ios/**` and `web/**`, announced as "Upgrading analysis_options.yaml…"). **Keep these changes** — they are the intended drift reconciliation (FR-006, research.md Decision 5). Verify with `git diff --stat -- pubspec.yaml pubspec.lock analysis_options.yaml`.

**Checkpoint**: Dependency resolved, seam file in place. The app still does not compile (imports not yet rewritten) — expected.

---

## Phase 3: User Story 1 - The app builds and the full test suite runs again (Priority: P1) 🎯 MVP

**Goal**: A clean checkout on the current stable Flutter builds for web (and mobile where the machine allows), analyzes with no new issues, runs the whole test suite with every file loading and passing, passes the format check, and the tree stays clean afterward.

**Independent Test**: On this branch run `flutter build web --debug` and `--release`, `flutter analyze`, `flutter test`, `dart format --output=none --set-exit-if-changed lib test`, then `flutter pub get && flutter analyze` once more and `git status --short` (quickstart.md Scenarios 1–3). Build succeeds, only the 2 existing `onReorder` infos remain, all test files load with 0 failures, the format check exits 0, and the second run changes nothing.

### Test for User Story 1 (write first; it MUST fail until T006–T011 are done)

- [X] T005 [P] [US1] In `test/unit/architecture/architecture_boundary_test.dart` add a test, e.g. `'icon package is imported only through core/theme/app_icons.dart'`, reusing the file's existing `_dartFilesUnder` helper: scan every `.dart` file under `lib/` **and** `test/` and collect any whose source matches `import\s+['"]package:(lucide_flutter|lucide_icons|lucide_icons_flutter)` except `lib/core/theme/app_icons.dart` (compare normalized relative paths; the new file uses `export`, not `import`, so it is not matched anyway). Expect the violation list `isEmpty` with a `reason` pointing at research.md Decision 3. Apply the Format rule. Run `flutter test test/unit/architecture/architecture_boundary_test.dart` — it should FAIL now (28 files still import the old package).

### Implementation for User Story 1

- [X] T006 [P] [US1] Apply the import edit rule to `lib/core/router/app_router.dart` and `lib/core/widgets/expense_control_icons.dart`. (`expense_control_icons.dart` currently has only `package:flutter/widgets.dart` plus the lucide import; add a new `package:finance/...` group after a blank line.)
- [X] T007 [P] [US1] Apply the import edit rule to the account feature: `lib/features/account/account_routes.dart`, `lib/features/account/presentation/account_screen.dart`, `lib/features/account/presentation/sign_in_screen.dart`, `lib/features/account/presentation/sign_up_screen.dart`.
- [X] T008 [P] [US1] Apply the import edit rule to the expense_control feature: `lib/features/expense_control/presentation/expense_control_screen.dart`, `lib/features/expense_control/presentation/widgets/allocation_summary_banner.dart`, `lib/features/expense_control/presentation/widgets/expense_group_card.dart`, `lib/features/expense_control/presentation/widgets/expense_item_row.dart`.
- [X] T009 [P] [US1] Apply the import edit rule to the expenses feature: `lib/features/expenses/expenses_routes.dart`, `lib/features/expenses/presentation/expense_screen.dart`, `lib/features/expenses/presentation/income_screen.dart`, `lib/features/expenses/presentation/overview_screen.dart`, `lib/features/expenses/presentation/report_screen.dart`, `lib/features/expenses/presentation/spending_screen.dart`, `lib/features/expenses/presentation/transaction_history_screen.dart`, `lib/features/expenses/presentation/widgets/balance_group_card.dart`.
- [X] T010 [P] [US1] Apply the import edit rule to the core widget tests: `test/widget/core/router/app_shell_nav_bar_test.dart`, `test/widget/core/theme/adaptive_input_test.dart`, `test/widget/core/widgets/not_available_placeholder_screen_test.dart`. Edit only the import line — no assertion changes.
- [X] T011 [P] [US1] Apply the import edit rule to the feature widget tests: `test/widget/features/expense_control/expense_control_screen_test.dart`, `test/widget/features/expense_control/expense_group_card_test.dart`, `test/widget/features/expenses/expense_screen_test.dart`, `test/widget/features/expenses/income_screen_test.dart`, `test/widget/features/expenses/overview_screen_test.dart`, `test/widget/features/expenses/report_screen_test.dart`, `test/widget/features/expenses/spending_screen_test.dart`. Edit only the import line — no assertion changes.
- [X] T012 [US1] Residual-reference check (quickstart.md Scenario 2): `grep -rn "lucide_icons/" lib test pubspec.yaml` prints nothing; `grep -rl "package:lucide_flutter" lib test --exclude=architecture_boundary_test.dart` prints exactly one **file**, `lib/core/theme/app_icons.dart`; `grep -rlE "package:finance/core/theme/app_icons.dart" lib test | wc -l` prints 28 (it becomes 29 once T020 adds its own import — expected on any later re-run).
- [X] T013 [US1] Run `flutter analyze`. Expected: exactly the 2 pre-existing `onReorder` deprecation infos (`lib/features/expense_control/presentation/expense_control_screen.dart` and `test/widget/features/expense_control/expense_group_card_test.dart`), nothing icon-related (SC-003). Do not "fix" the `onReorder` infos — out of scope per spec.
- [X] T014 [US1] Web builds (SC-001, FR-001). First run `flutter build web --debug` — the exact command that failed originally; expect `✓ Built build/web` with no compile error. Then run `flutter build web --release`; expect `✓ Built build/web` and a line like `Font asset "lucide.ttf" was tree-shaken, reducing it from ~902,000 to ~20,000 bytes` (the 2026-10-05 prototype measured 902460 → 20400; a newer 1.x package may differ slightly). Leave the **release** output in `build/web` for T022.
- [X] T015 [US1] Attempt the mobile builds (FR-001, research.md Decision 7): run `flutter build apk --debug` and `flutter build ios --debug --no-codesign`, and record each outcome as success or **BLOCKED** with the tool's stated reason (`flutter doctor` currently reports the Android toolchain and Xcode as incomplete, so BLOCKED is an expected, acceptable outcome that goes into the PR notes in T028). A Dart compile error attributable to the icon package or the seam **is** a failure — fix the cause. Afterwards run `git status --short`; if the build touched tracked files under `android/` or `ios/`, restore them with `git checkout -- android ios` (tool-generated changes are not part of this feature). **Result (2026-10-06)**: Android **PASS** — after the owner installed JDK 21 and an emulator, `flutter build apk --debug` (plain and with `--dart-define-from-file=tool/env.json`) succeeds once Flutter uses JDK 21 (the earlier failure was Android Studio's bundled JBR 25.0.3 vs Gradle 8.14, fixed with the user-level setting `flutter config --jdk-dir ~/Library/Java/JavaVirtualMachines/jbr-21.0.11/Contents/Home`); the app runs on the Pixel 10 emulator. iOS **PASS** — after the owner ran `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` (CocoaPods 1.17.0 installed via Homebrew), `flutter build ios --simulator --debug --dart-define-from-file=tool/env.json` succeeds and the app runs on the iPhone 17 Simulator (iOS 26.3); a device build (`--no-codesign`) still needs a Development Team. No Dart compile error from the icon package or the seam on any platform. Tool-generated changes (`android/gradle.properties` migrator flags `android.builtInKotlin=false` / `android.newDsl=false`; `ios/Podfile`, `Podfile.lock`, xcconfig/pbxproj/scheme edits) were restored or removed. Evidence: `verification/README.md`.
- [X] T016 [US1] Run `flutter test` (SC-002). Expect `All tests passed!` with every file loading (2026-10-05 prototype: 508 passed; baseline on `master`: 287 passed with 22 files unloadable). This includes the T005 architecture test, which must now pass. If any test fails to load or fails, fix the import in that file — never edit an assertion to make it pass (FR-002).
- [X] T017 [US1] Scope and idempotence check (SC-005, FR-008): run `flutter pub get` and `flutter analyze` a second time, then `git status --short`. The only changed/new paths must be: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `lib/core/theme/app_icons.dart` (new), `test/unit/architecture/architecture_boundary_test.dart`, the 18 `lib/` and 10 `test/` files edited in T006–T011, plus the already-present Spec Kit files. A second `pub get`/`analyze` must change nothing further, and `git diff -- pubspec.yaml` must show only the one dependency line. Any other modified path means an unintended edit — revert it.
- [X] T018 [US1] Format gate (FR-011, SC-008, US1 Acceptance 5): run `dart format lib test`. It must rewrite **exactly** these 11 pre-existing files and no other pre-existing file: `lib/core/database/app_database.dart`, `lib/core/sync/initial_pull_complete_provider.dart`, `lib/core/sync/pull_service.dart`, `lib/core/sync/remote_row_writer.dart`, `test/unit/core/database/app_database_migration_test.dart`, `test/unit/core/sync/conflict_resolution_test.dart`, `test/unit/core/sync/initial_pull_complete_provider_test.dart`, `test/unit/core/sync/pull_service_provider_test.dart`, `test/unit/core/sync/pull_service_test.dart`, `test/unit/core/sync/remote_row_writer_test.dart`, `test/unit/core/sync/sync_worker_test.dart`. If any *other pre-existing* file changes, an earlier edit broke formatting — revert that file and investigate. If a file *authored in this feature* (`app_icons.dart`, the T005 test) is reformatted, keep that formatting as part of the icon change set (you skipped the Format rule), not the format-only set. Then `dart format --output=none --set-exit-if-changed lib test` must exit 0. These 11 files are whitespace/line-wrapping only (research.md Decision 5); keep them as their own change set (their own commit when committing) so they can be reviewed or dropped independently.
- [X] T019 [US1] After T018 re-run `flutter analyze` (still only the 2 existing infos) and `flutter test` (same pass count as T016, 0 failures) to confirm the reformat changed no behavior, then `flutter pub get` once more and `git status --short` to confirm nothing else was rewritten.

**Checkpoint**: US1 complete, including the format gate the constitution requires before any merge — the app builds, analysis, tests and format are green, and the tree is stable. This is the MVP; it can be reviewed and merged on its own.

---

## Phase 4: User Story 2 - Every icon stays the same recognizable icon (Priority: P2)

**Goal**: No icon is missing, swapped for a different concept, or altered in line style, weight or size; stored icon keys keep resolving; the icon payload stays small.

**Independent Test**: Run the new contract test, check the web icon payload, then do the light/dark visual review against the baseline (quickstart.md Scenarios 4–6).

### Test for User Story 2

- [X] T020 [P] [US2] Create `test/unit/core/widgets/expense_control_icons_test.dart` (new directory `test/unit/core/widgets/`) importing `package:flutter_test/flutter_test.dart`, `package:finance/core/theme/app_icons.dart` and `package:finance/core/widgets/expense_control_icons.dart`. Three tests per contracts/persisted-icon-keys.md: (1) `expenseControlIcons.keys` is exactly the 16 keys `home, family, wallet, piggyBank, heart, utensils, car, shoppingBag, gift, graduationCap, receipt, film, building, shield, plane, moreHorizontal` (use `unorderedEquals`); (2) `resolveExpenseControlIcon(key)` returns the expected constant for each key — `home→LucideIcons.home, family→LucideIcons.users, wallet→LucideIcons.wallet, piggyBank→LucideIcons.piggyBank, heart→LucideIcons.heartPulse, utensils→LucideIcons.utensils, car→LucideIcons.car, shoppingBag→LucideIcons.shoppingBag, gift→LucideIcons.gift, graduationCap→LucideIcons.graduationCap, receipt→LucideIcons.receipt, film→LucideIcons.film, building→LucideIcons.building2, shield→LucideIcons.shield, plane→LucideIcons.plane, moreHorizontal→LucideIcons.moreHorizontal`; (3) an unknown key (`'does-not-exist'`) and the empty string both return `LucideIcons.circle`. This pins the stored-key contract (FR-005); it does not prove glyph shapes — that is the visual review below. Apply the Format rule so the T018 gate stays green.
- [X] T021 [US2] Run `flutter test test/unit/core/widgets/expense_control_icons_test.dart` and `flutter test test/widget/features/expense_control/icon_picker_test.dart`; both must pass. Then `dart format --output=none --set-exit-if-changed lib test` must still exit 0.

### Verification for User Story 2

- [X] T022 [US2] Payload check (SC-007, FR-010, quickstart.md Scenario 4): after the T014 **release** build run `find build/web/assets/packages -name "*.ttf" -exec ls -l {} \;`. The Lucide font(s) must total **< 100 KB** (expected: one file, `assets/packages/lucide_flutter/assets/lucide.ttf`, about 20,000 bytes, and no other Lucide font). This also confirms FR-010: the icon font is bundled with the app as a build asset, so rendering needs no network access. If a second Lucide font or a much larger file appears, stop — the wrong package or a build flag is in play. **Result (2026-10-06)**: `build/web/assets/packages/lucide_flutter/assets/lucide.ttf` = 20,400 bytes, the only Lucide font (total 20,400 B < 100 KB); listed in `FontManifest.json` as family `packages/lucide_flutter/LucideIcons`, i.e. bundled — no network needed (FR-010).
- [X] T023 [US2] Visual review A, light **and** dark (quickstart.md Scenario 5; `flutter run -d chrome` with the Supabase public defines from README.md; apply the Baseline & escalation rule): navigation bar (compact) and rail (≥ 600dp) — `layoutDashboard`, `slidersHorizontal`, `receipt`, `pieChart`, `user`; Sign-in (`fingerprint`, `eye`, `eyeOff`); Sign-up (`userPlus`, `chevronLeft`, `check`, `eye`, `eyeOff`); Hồ sơ (`user`, `bell`, `shieldCheck`, `helpCircle`, `sunMoon`, `languages`, `logOut`, `chevronRight`, `check`); the three Hồ sơ placeholder screens and the Tổng quan bell placeholder (`bell`, `shieldCheck`, `helpCircle`). For each icon: same concept as the baseline, same 2px line style, same size, theme-driven color, tooltip/semantic label unchanged, tap target ≥ 48×48dp (FR-004, FR-007). Record any deviation. If the app cannot be signed in locally, mark this task **BLOCKED** with the reason and rely on the widget tests (`app_shell_nav_bar_test.dart`, `not_available_placeholder_screen_test.dart`). **Result (2026-10-06)**: DONE on the Android emulator (compact light + dark, wide rail light) plus the glyph-level comparison in `verification/`. Seen in the running app: navigation bar and rail icons, sign-in (`eye`, `eyeOff`), sign-up (`userPlus`, `chevronLeft`, `eye`, `check`), Hồ sơ (`user`, `sunMoon`, `languages`, `bell`, `shieldCheck`, `helpCircle`, `logOut`, `chevronRight`, `check` in the language sheet), the three Hồ sơ placeholders and the Tổng quan bell placeholder; colors follow the theme in both appearances. Not exercised in-app: `fingerprint` (needs an enrolled biometric; glyph diff 2.5 %). Visible upstream redraws escalated to the owner: `sunMoon`, `building2`, `car` (`verification/README.md`). Tap targets: covered by the passing widget tests.
- [X] T024 [US2] Visual review B, light **and** dark (Baseline & escalation rule): Tổng quan (`banknote`, `wallet`, `receipt`, `history`, `bell`, `alertTriangle` in the negative-balance banner, `layoutDashboard`); Kiểm soát (`plus`, `pencil`, `trash2`, `gripVertical`, `chevronDown`, `chevronRight`, `check`, `info`, `slidersHorizontal`, allocation banner `pieChart`); the category icon picker — all 16 category icons (`home, users, wallet, piggyBank, heartPulse, utensils, car, shoppingBag, gift, graduationCap, receipt, film, building2, shield, plane, moreHorizontal`). Same acceptance checks as T023; pay particular attention to the renamed-upstream icons `alertTriangle`, `building2`, `home`, `moreHorizontal`, `utensils`, `helpCircle`. **Result (2026-10-06)**: DONE on the Android emulator (light + dark; evidence in `verification/`). Tổng quan (`layoutDashboard`, `bell`, `wallet`, transaction `receipt`/`banknote`), Kiểm soát (`slidersHorizontal`, `info`, `chevronDown`, `gripVertical`, `pencil`, `trash2`) and the category picker with all 16 icons, current icon highlighted. Not exercised in-app: `alertTriangle` (needs a negative balance; glyph diff 1.9 %). Same redraw note as T023.
- [X] T025 [US2] Visual review C, light **and** dark (Baseline & escalation rule): Thu nhập (`chevronLeft`, `briefcase`, `walletCards`, `arrowUpCircle`, `plus`, `trash2`, `check`); Chi tiêu (`chevronLeft`, `camera`, `scanLine`, `delete`, `cornerDownRight`, `check`, `checkCircle2`, `pencil`, `arrowDownCircle`, `walletCards`); Thu chi hub (`arrowUpCircle`, `arrowDownCircle`, `history`, `chevronRight`, `chevronDown`, `walletCards`); Lịch sử giao dịch (`history`, `chevronLeft`, `chevronRight`, `home`, `utensils`, `walletCards`); Báo cáo (`pieChart`, `alertTriangle`, `chevronLeft`, `chevronRight`). Same acceptance checks; pay attention to `arrowDownCircle`, `arrowUpCircle`, `checkCircle2`, `pieChart`, `history`. **Result (2026-10-06)**: DONE on the Android emulator (light + dark; evidence in `verification/`). Thu nhập (`chevronLeft`, `briefcase`, `plus`, `trash2`, `check`), Chi tiêu (`camera`, `scanLine` on the scan tab, `delete`, `pencil`, `cornerDownRight` in the over-balance state), the Thu chi hub (`arrowUpCircle`, `arrowDownCircle`, `history`, `chevronRight`), history with real data (`utensils`, `home`, `walletCards`) and Báo cáo (`pieChart`, chevrons). Not exercised in-app: `checkCircle2` (appears after saving an expense, which would write data; glyph diff 9.7 %) and `alertTriangle`. Nothing was saved.
- [X] T026 [US2] Persisted icons keep resolving (quickstart.md Scenario 6, FR-005): in Kiểm soát every existing group/item shows its previously chosen icon (never the fallback circle for a valid key); open the picker on an existing item — its icon is highlighted and all 16 icons are offered; on a second device/profile with synced data (#23), pulled items render the correct icons. Mark **BLOCKED** with the reason if no second synced device is available, and rely on T020/T021. **Result (2026-10-06)**: DONE. On a fresh app install whose data arrived through the sync pull (i.e. a second device), every item shows its stored icon — `utensils` (An Uong), `car` (Xang xe), `shoppingBag` (Rac), `heartPulse` (Dien), `shield` (Nuoc), `home`, `piggyBank` (Tiet Kiem) — never the fallback circle; the picker highlights the item's current icon and offers all 16; history rows resolve too. Also pinned by the T020 contract tests.

**Checkpoint**: US1 and US2 both verified — build green, contract pinned, payload within budget, icons visually confirmed (or explicitly marked blocked with reasons).

---

## Phase 5: User Story 3 - Project instructions point at the plan being worked on (Priority: P3)

**Goal**: `CLAUDE.md` names this feature's plan, not an already-merged feature's.

**Independent Test**: quickstart.md Scenario 7.

- [X] T027 [US3] Verify the `CLAUDE.md` plan pointer (the edit was already applied by the `/speckit-plan` step; this task confirms it survived and fixes it if not): `sed -n 1,6p CLAUDE.md` shows `specs/20261005-211030-fix-lucide-icons-compat/plan.md` between `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->`; `ls specs/20261005-211030-fix-lucide-icons-compat/plan.md` succeeds; `git diff -- CLAUDE.md` shows exactly one changed line (the plan path) and the Language convention and Asset conventions sections are byte-for-byte unchanged; no plan path of an already-merged feature appears in the file (FR-009, SC-006).

**Checkpoint**: All three user stories independently verified.

---

## Phase 6: Polish & Final Verification

**Purpose**: One last end-to-end pass on the finished tree and preparation of the PR notes.

- [X] T028 Final pass on a tree with everything above applied: re-run quickstart.md Scenarios 1–3 end to end (clean tree after `pub get` + `analyze`; no residual references — the `app_icons.dart` import count is now 29; debug and release web builds, analyze, format check and tests all green). Then list the PR-description call-outs required by the constitution's Development Workflow (plan.md Constitution Check): (a) icons are now imported app-wide through `lib/core/theme/app_icons.dart` — a shared `core/` change; (b) the lock-file and `analysis_options.yaml` drift reconciliation; (c) the format-only change set (T018's 11 files) is separate and droppable; (d) the one-line fallback to `lucide_icons_flutter` (costs about +2.9 MB of unused fonts) if `lucide_flutter` is ever abandoned; (e) the Android/iOS outcomes recorded in T015 and that only Flutter 3.47.5 was verified; (f) any BLOCKED or owner-escalated items from T023–T026. Open follow-ups, none part of this feature: the divergent `_iconFor` in `lib/features/expenses/presentation/transaction_history_screen.dart` (research.md "Observations") and the two `onReorder` deprecation infos. **Result (2026-10-06)**: Scenarios 1–3 all green on the finished tree — `pub get` + `analyze` leave the tree unchanged (2 existing `onReorder` infos only); no `lucide_icons/` references; exactly one file names the new package (`lib/core/theme/app_icons.dart`); 29 files import the seam (28 rewritten + the T020 test); `dart format` check exit 0; debug and release web builds succeed (lucide.ttf tree-shaken 902,460 → 20,400 B); `flutter test` **512 passed**, 0 failed (baseline 287 + 22 unloadable files). **PR call-outs**: (a) icons are imported app-wide through `lib/core/theme/app_icons.dart`, a shared `core/` change; (b) lock-file (`intl`, `matcher`, `meta`, `test_api`, `vector_math`, package swap) and `analysis_options.yaml` (exclude block for `build/android/ios/web`) drift reconciliation; (c) the 11-file format-only change set is separate and droppable; (d) one-line fallback to `lucide_icons_flutter` ^3.1.22 (+≈2.9 MB of unused weight fonts) if `lucide_flutter` is abandoned; (e) Android debug APK builds and runs on the emulator once Flutter uses JDK 21 (`flutter config --jdk-dir`), iOS is BLOCKED until `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` is run (CocoaPods 1.17.0 now installed), only Flutter 3.47.5 verified; Flutter 3.47's Android build also auto-adds `android.builtInKotlin=false` / `android.newDsl=false` to `android/gradle.properties` (restored, not committed); (f) `sunMoon`, `building2`, `car` are visible upstream redraws awaiting owner acknowledgement (`verification/README.md`); (g) two pre-existing app issues found in the running app — fresh-session sign-in does not navigate, and the cold-start lock is racy — documented with evidence in research.md "Observations" and deliberately not fixed here (FR-008). Open follow-ups, none part of this feature: the divergent `_iconFor` in `transaction_history_screen.dart` and the two `onReorder` deprecation infos. **Re-run after US4 (2026-10-06)**: 514 tests passed, format exit 0, analyze 2 existing infos.

---

## Phase 7: User Story 4 - The first sign-in goes straight to the main screen (Priority: P2)

**Goal**: One press of "Đăng nhập" on a fresh session reaches Tổng quan on web, Android and iOS (FR-012, SC-009). Discovered while verifying the icon change; fixed at its root in shared `core/router` code per the constitution (research.md Decision 9).

**Independent Test**: `flutter test test/unit/core/router/app_router_refresh_test.dart` is green, and on a fresh install one sign-in press opens Tổng quan (quickstart.md Scenario 8).

### Test for User Story 4 (written first; it MUST fail before the fix)

- [X] T029 [US4] In `lib/core/router/app_router.dart` turn the private refresh provider into a public `routerRefreshListenableProvider` typed `Provider<Listenable>` with `@visibleForTesting` and a doc comment (no behavior change), so a test can observe when the router is told to re-evaluate. **Result (2026-10-06)**: done; `appRouterProvider` now watches the public provider.
- [X] T030 [US4] Create `test/unit/core/router/app_router_refresh_test.dart` with two tests using `authStateChangesProvider.overrideWith((ref) => controller.stream)`: after a `signedIn` event the last router refresh must observe `isSignedInProvider == true`, and after a `signedOut` event it must observe `false` (the provider is read once beforehand so it is cached, as in the running app). **Result (2026-10-06)**: both tests were RED before the fix (`Expected: true / Actual: false` and `Expected: false / Actual: true`).

### Implementation for User Story 4

- [X] T031 [US4] In `lib/core/router/app_router.dart` replace `ref.listen(authStateChangesProvider, …)` with `ref.listen(isSignedInProvider, (previous, next) => listenable.ping())` and a comment explaining why the derived provider is the right thing to listen to (FR-012). **Result (2026-10-06)**: one-line behavior change; the two tests are now green.
- [X] T032 [US4] Run `dart format`, `flutter analyze` and the full `flutter test`. **Result (2026-10-06)**: format exit 0; analyze 2 existing infos; **514 tests passed** (512 + 2 new), 0 failures.
- [X] T033 [US4] Verify FR-012 / SC-009 in the running app after rebuilding each platform and resetting local state. **Result (2026-10-06)**: web (Playwright on Chrome, release build) — one press → `/overview`; Android emulator (`pm clear`, debug APK) — one press → Tổng quan, then sign-out → sign-in screen → one press → Tổng quan; iOS Simulator (erased, debug build) — one press → Tổng quan with the biometric-enable offer still shown over it, declined with "Để sau". Evidence summary in `verification/README.md`.
- [X] T034 [US4] Document it: spec.md (User Story 4, FR-012, SC-009, FR-008 exception), research.md Decision 9 and the Observations entry, plan.md (Constitution Check, structure), quickstart.md Scenario 8, `verification/README.md`. **Result (2026-10-06)**: done. Not part of this fix and deliberately left alone: the cold-start lock race (research.md Observations) and the timing dependency of the biometric-enable offer on `context.mounted` (Decision 9).

**Checkpoint**: US4 verified on all three platforms; T028's final pass was re-run after it (514 tests).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; BLOCKS all user stories. T004 depends on T002; T003 is independent of T002/T004.
- **US1 (Phase 3)**: depends on Foundational. T005 (test) is written first and must fail; T006–T011 make it pass; T012–T017 are sequential verification gates after the edits; T018–T019 (format gate) follow them and complete US1.
- **US2 (Phase 4)**: T020–T021 depend only on T003 and T006 (the seam and `expense_control_icons.dart` compiling) and can run alongside the rest of US1, but T021's format check needs T018 to have run to be meaningful; T022 needs the T014 release build; T023–T026 need a running app, i.e. all of US1.
- **US3 (Phase 5)**: no code dependency; can be verified at any time after the plan step. T027 can run in parallel with anything.
- **Polish (Phase 6)**: depends on US1 and US2 being done (US3 is independent); T028 is the last pass of the icon work.
- **US4 (Phase 7)**: independent of the icon swap (it only needs the code to compile, i.e. US1); T029→T030→T031 are strictly ordered (test red, then fix), T032–T034 follow.

### User Story Dependencies

- **US1 (P1)**: independent after Foundational — the MVP.
- **US2 (P2)**: its manual checks require US1's working build; its test task does not.
- **US3 (P3)**: fully independent of US1/US2.
- **US4 (P2)**: needs only a compiling app (US1); touches different files from US2/US3.

### Within Each Story

- Test first (T005, T020), then edits, then verification gates.
- Never edit an assertion to make a test pass (FR-002).

### Parallel Opportunities

- T002 ‖ T003 (different files).
- T005 ‖ T006 ‖ T007 ‖ T008 ‖ T009 ‖ T010 ‖ T011 (disjoint files; run T005 first if you want to see it fail).
- T020 ‖ any of T006–T011.
- T027 ‖ everything.
- T023 ‖ T024 ‖ T025 ‖ T026 only if more than one reviewer is available; they all need the same running app.

### Parallel Example: User Story 1

```text
# After T004, in parallel:
T005  test/unit/architecture/architecture_boundary_test.dart   (new seam test — expected to fail)
T006  lib/core/router/app_router.dart + lib/core/widgets/expense_control_icons.dart
T007  lib/features/account/**            (4 files)
T008  lib/features/expense_control/**    (4 files)
T009  lib/features/expenses/**           (8 files)
T010  test/widget/core/**                (3 files)
T011  test/widget/features/**            (7 files)
# Then sequentially: T012 -> T013 -> T014 -> T015 -> T016 -> T017 -> T018 -> T019
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 (T001) → Phase 2 (T002–T004).
2. Phase 3 (T005–T019). **Stop and validate**: build, analyze, full test suite, format check, clean tree. This alone unblocks every other piece of work (including the planned Security screen) and satisfies the constitution's merge gate, so it can ship.

### Incremental Delivery

1. Foundation + US1 → green build, suite and format gate (MVP).
2. + US2 → contract test, payload check, visual confirmation.
3. + US3 → confirm the `CLAUDE.md` pointer.
4. + Phase 6 → final end-to-end pass and PR call-outs.

### Notes

- If `lucide_flutter` proves unsuitable at any point (compile error on a constant, missing glyph, abandoned upstream), the documented fallback is `lucide_icons_flutter` ^3.1.22: change only the `export` line in `lib/core/theme/app_icons.dart` and the dependency line in `pubspec.yaml`, then rerun T004 and T012–T017 (it fails the SC-007 payload budget, so it needs an explicit owner decision).
- If any of the 52 icons turns out to have no same-concept equivalent in the chosen package, do **not** draw or approximate one — report it to the owner, who will commission a designed SVG (spec Clarifications, FR-003).
- Commit only when asked; when committing, keep T018's 11-file reformat separate from the icon change.
