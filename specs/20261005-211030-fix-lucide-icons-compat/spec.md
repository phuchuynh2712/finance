# Feature Specification: Restore Buildability — Fix Icon Library Incompatibility

**Feature Branch**: `20261005-211030-fix-lucide-icons-compat`

**Created**: 2026-10-05

**Status**: Implemented — US1, US2 and US3 complete; verified on web, Android emulator and iOS Simulator

**Input**: User description: "sửa lucide_icons trước nhé, và cập nhật claude.md luôn nhé." (fix `lucide_icons` first, and update CLAUDE.md as well)

## Background

While reviewing the project's state on 2026-10-05 (after resetting `master` to `origin/master` at `8333269`), the following was observed on the installed stable toolchain (Flutter 3.47.5 / Dart 3.13.4):

- The app **does not compile at all** — a debug web build fails with `The class 'IconData' can't be extended outside of its library because it's a final class`, raised from inside the icon library (`lucide_icons 0.257.0`).
- 22 automated test files **fail to load** for the same reason (every test that transitively imports the icon library, including router, app shell and screen tests); the remaining 287 tests pass.
- `lucide_icons 0.257.0` is already the newest published release (last published June 2023), so the problem **cannot be fixed by upgrading**; the dependency is effectively unmaintained and the toolchain has moved past it.
- 52 distinct icons from this library are referenced across 18 source files; 10 test files reference the library directly as well (9 distinct icons, all among the 52).
- Running the toolchain on a clean checkout also rewrites tracked files: the dependency lock file (`intl` 0.20.2→0.20.3, `matcher` 0.12.18→0.12.20, and others) and the analysis configuration (`analysis_options.yaml` gains exclusions for generated/platform directories). The committed files are out of sync with the supported toolchain.
- The code-format check (`dart format --set-exit-if-changed`, required by the constitution's Development Workflow) already fails on `master` under the current formatter for 11 files, all in sync/database code (`lib/core/database/app_database.dart`, `lib/core/sync/*`, and 7 test files); none are icon-related.
- While verifying the fix on web, Android and iOS (2026-10-06) the owner confirmed an existing app defect: the first press of "Đăng nhập" on a fresh session shows the spinner and then nothing happens; only a second press reaches Tổng quan. The same behavior reproduced on the Android emulator and the iOS Simulator.
- `CLAUDE.md` points at the plan of `supabase-realtime-pull`, a feature already merged in #23, not at the feature now in progress (this one).

## Clarifications

### Session 2026-10-05

- Q: FR-004 originally required every icon to look "exactly as today", but the current library is a June 2023 snapshot of Lucide and a maintained replacement tracks current upstream Lucide, which has slightly redrawn some glyphs and renamed some icons. How much visual difference is acceptable? → A: Same icon, minor upstream redraws allowed — each icon must remain the same recognizable Lucide icon (same concept and name lineage, same line style/weight/size), and small stroke-level differences that come from upstream Lucide updates are accepted. Pixel-identical glyphs are not required. Owner refinement: icons are used directly from the maintained package exactly as published; the team MUST NOT draw, trace, edit or freeze glyphs itself ("redraw" above refers only to upstream Lucide's own changes). If a custom in-repo icon set ever proves necessary for an icon the package lacks, the owner will commission it from a designer and supply it as SVG; the team will not substitute a hand-made approximation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The app builds and the full test suite runs again (Priority: P1) 🎯 MVP

The project owner pulls the latest code on a machine with the current stable Flutter, builds the app for any supported platform, and runs the full automated test suite. Today the build stops with a compile error inside the icon library and 22 test files cannot even be loaded, which blocks all further work (no new screen can be built or verified, and no regression can be detected).

**Why this priority**: Nothing else can ship while the app does not compile. This is a hard blocker for every upcoming feature, including the next planned screen (Security), and for verifying that already-merged features (#21–#23) still work.

**Independent Test**: On a clean checkout with the current stable Flutter, run a debug web build and the complete test suite. The build must succeed and every test file must load and pass, with no test excluded or skipped to make this true.

**Acceptance Scenarios**:

1. **Given** a clean checkout and the current stable toolchain, **When** the app is built for the web target, **Then** the build completes with zero compile errors.
2. **Given** the same checkout, **When** the full automated test suite is run, **Then** all test files load (including the 22 that currently fail to load) and all tests pass.
3. **Given** the same checkout, **When** static analysis is run, **Then** it reports no new issues compared with today's baseline (2 pre-existing informational deprecation notices, unrelated to icons).
4. **Given** a clean checkout, **When** dependencies are resolved and static analysis is run with the supported toolchain, **Then** no tracked file is modified (no uncommitted churn from the lock file or the analysis configuration).
5. **Given** the same checkout, **When** the code-format check is run, **Then** it reports 0 files needing changes.

---

### User Story 2 - Every icon stays the same recognizable icon (Priority: P2)

A person using the app sees the same icons they saw before this change — navigation bar, headers, buttons, category pickers, empty states, dialogs — recognizably the same icon in the same line style, weight and size, in both light and dark appearance. Small stroke-level differences that come from the maintained icon package's own upstream Lucide updates are acceptable; a missing, swapped or differently styled icon is not. For the person using the app, the fix is effectively invisible.

**Why this priority**: A compiling app that shows wrong, missing or differently styled icons would be a regression of the design system the previous features were built to match. It depends on Story 1 (nothing can be inspected until the app builds) and is the acceptance gate that proves the fix did not change the product.

**Independent Test**: Open every screen that shows an icon (all five navigation tabs, the sign-in and sign-up screens, income, expense, transaction history, Hồ sơ rows, the not-available placeholder screens, the category icon picker, and banners) in light and dark appearance, and compare each icon against its baseline. The pre-fix app cannot be built on the current toolchain, so the baseline is not a running "before" build: it is the design references' icon lists (`specs/*/reference/icons.json`, which pin 27 of the 52 icons) and, for the other 25, the intended Lucide concept implied by the icon's existing name in the Icon usage inventory (Key Entities). No icon may be missing, swapped for a different concept, or visibly different in line style, weight or size. When a reviewer is unsure whether a difference is an acceptable upstream stroke-level redraw or a changed line style/weight, the reviewer records it and the owner decides.

**Acceptance Scenarios**:

1. **Given** the app after the fix, **When** the user opens any screen that previously showed an icon, **Then** the same Lucide icon (same concept) is shown, in the same position, size and color as before; minor stroke-level redraws from upstream Lucide are acceptable.
2. **Given** the category icon picker (which offers the full set of selectable category icons), **When** the user opens it, **Then** every previously offered icon is still offered and any icon already saved on an existing budget item still displays correctly.
3. **Given** a screen with an icon-only control, **When** it is inspected with a screen reader or hovered, **Then** its accessible label/tooltip is unchanged and its touch target is still at least 48×48dp.
4. **Given** light and dark appearance, **When** icons are shown, **Then** they continue to follow the theme's icon colors with no hard-coded color regressions.

---

### User Story 3 - Project instructions point at the plan being worked on (Priority: P3)

Anyone (or any assistant) starting a session reads `CLAUDE.md` to find the current technical plan. Today it directs them to the plan of the most recently merged feature (`supabase-realtime-pull`, #23), not the one now in progress, so context is wrong from the first step. After this change it directs them to the plan of the feature currently in progress.

**Why this priority**: Low risk and low effort, but it prevents every future session from starting with stale context. It does not affect product behavior, so it ranks after the build fix and the visual-parity gate.

**Independent Test**: Open `CLAUDE.md`, follow the plan reference, and confirm the file exists and belongs to the feature currently in progress (this one), while the language and asset convention sections are byte-for-byte unchanged.

**Acceptance Scenarios**:

1. **Given** this feature has a plan, **When** `CLAUDE.md` is read, **Then** its plan reference points to this feature's plan file, and that file exists.
2. **Given** `CLAUDE.md` before and after this change, **When** the two are compared, **Then** only the plan reference differs (the Language convention and Asset conventions sections are unchanged).
3. **Given** the plan reference, **When** it is followed, **Then** it does not point to the plan of any already-merged feature.

---

### User Story 4 - The first sign-in goes straight to the main screen (Priority: P2)

A person on the sign-in screen enters valid credentials and presses "Đăng nhập" once. After the spinner finishes, the app opens Tổng quan. Today the screen stays on sign-in with no sign of what happened, and the person has to press the button a second time.

**Why this priority**: It was found while verifying this feature on every platform, the owner asked for it to be fixed, and it makes the very first impression of the app look broken. The constitution requires a bug found in shared code (`core/`) to be fixed at its root in the feature where it was discovered, which is why it is part of this feature rather than a separate one. It does not depend on the icon change.

**Independent Test**: On a fresh install (no stored session) on web, Android or iOS, sign in once with valid credentials and observe that Tổng quan opens without a second press; then sign out and sign in again once more.

**Acceptance Scenarios**:

1. **Given** a signed-out app on the sign-in screen, **When** the person signs in once with valid credentials, **Then** the app navigates to Tổng quan without any further press.
2. **Given** a signed-in app, **When** the person signs out, **Then** the app shows the sign-in screen, and signing in once again reaches Tổng quan.
3. **Given** the app is showing the biometric-enable offer after a first sign-in on a capable device, **When** the person answers it, **Then** the offer still appears (over Tổng quan) and the person stays on Tổng quan.
4. **Given** a stored session with the lock screen shown, **When** the person unlocks it with their password or biometrics, **Then** behavior is unchanged from today.
5. **Given** an invalid password, **When** the person signs in, **Then** the error message is shown and no navigation happens (unchanged).

---

### Edge Cases

- **Renamed icons**: icon libraries rename icons between releases (for example `alert-triangle` became `triangle-alert` in upstream Lucide). A renamed icon must still resolve to the *same icon* (same concept); a rename is acceptable, a different concept is not.
- **Upstream redraws**: current Lucide has slightly redrawn some glyphs since the 2023 snapshot the app uses today. Such stroke-level differences, shipped by the package as published, are accepted (see Clarifications); a change of concept, line style, weight or size is not. The team never edits a package glyph to "fix" a redraw.
- **Icon missing from the replacement package**: if any of the 52 icons in use has no equivalent of the same concept in the maintained package (under any name), the team MUST NOT draw, trace or approximate one, nor silently swap in a different-concept icon. The gap is reported to the owner, who decides how to proceed and, if a custom icon is needed, commissions a designed SVG from a designer; only then is that icon added as an owner-supplied asset.
- **Persisted icon choices**: budget items store the user's chosen icon; existing saved choices (local database and synced remote rows from #23) must keep resolving to the same icon with no data migration visible to the user and no rewriting of synced data.
- **Web bundle size**: the web build tree-shakes unused icons, and the icon source must not bundle extra unused icon fonts (for example additional stroke-weight variants) that ship untouched; the web payload is bounded by SC-007.
- **Tests referencing icons directly**: tests that assert on specific icon identities must keep asserting the same intent after the fix, not be deleted or weakened to pass.
- **Older toolchains**: the project's declared minimum SDK must not be raised unless the replacement genuinely requires it; if it does, that raise must be explicit and documented.
- **Offline and platform parity**: icons must render identically on every supported platform (mobile, web) without any network fetch at runtime.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The application MUST compile for every platform target the project supports on the current stable Flutter toolchain, with zero compile errors originating from third-party packages (verification scope per Assumptions: web verified, Android/iOS attempted and recorded).
- **FR-002**: The full automated test suite MUST load every test file and pass completely; no test may be skipped, deleted or weakened to achieve this.
- **FR-003**: The icon source used by the app MUST be a maintained third-party Lucide package with a release within the last 12 months and no known incompatibility with the current stable toolchain, used directly as published. An in-repo icon set is permitted only for an icon the package cannot provide, and only from an SVG designed and supplied by the owner (per the project's Asset conventions). The choice of package MUST be justified in the plan under the constitution's dependency-hygiene rule.
- **FR-004**: Every one of the 52 distinct icons currently used MUST remain the same recognizable Lucide icon — same concept, same 2px line style and weight, same default size — with consistent presentation in light and dark appearance. Minor stroke-level redraws that come from the package's upstream Lucide updates are acceptable; pixel-identical output is not required. Glyphs MUST be taken from the package exactly as published: the team MUST NOT draw, trace, edit or otherwise alter any glyph.
- **FR-005**: The category icon picker MUST continue to offer the same set of icons, and every icon identifier already persisted on existing items (locally and synced) MUST continue to resolve to the same icon without requiring a data migration.
- **FR-006**: Resolving dependencies and running static analysis on a clean checkout with the supported toolchain MUST leave every tracked file unchanged; any toolchain-induced drift present on `master` (lock-file entries such as `intl` and `matcher`, and the analysis configuration the toolchain rewrites) MUST be reconciled and committed as part of this feature.
- **FR-007**: Existing accessibility behavior MUST be preserved: semantic labels, tooltips on icon-only controls, and the ≥48×48dp touch-target minimum are unchanged by this feature.
- **FR-008**: The change MUST NOT alter any screen layout, copy, navigation, data model, or sync behavior, with the single exception of the sign-in redirect defect in FR-012; it is limited to the icon source, the references to it, toolchain-drift reconciliation (FR-006, FR-011), that redirect fix, and the project instructions file.
- **FR-009**: `CLAUDE.md` MUST reference the plan of the feature currently in progress (this feature's `plan.md`) instead of the plan of an already-merged feature, and MUST leave its Language convention and Asset conventions sections unchanged.
- **FR-010**: Icons MUST be bundled with the app and render without any runtime network access.
- **FR-011**: The code-format check MUST pass on the supported toolchain. The files the current formatter would change (11 today, none icon-related) MUST be reformatted mechanically with no behavior change, in a change set separate from the icon change so it can be reviewed or dropped independently.
- **FR-012**: A single successful sign-in on a signed-out app MUST navigate to the main screen without a second attempt, on every supported platform. The router MUST re-evaluate its redirect only once the signed-in state it reads is current (it listens to the state the redirect reads, not to an upstream stream that updates earlier), and a test MUST fail if that ordering regresses. Sign-out, the lock-screen unlock, the biometric-enable offer and error handling MUST behave as before.

### Key Entities *(include if feature involves data)*

- **Icon usage inventory**: the set of 52 distinct icons referenced by the app (and its tests), each with the screens where it appears. It is the checklist FR-004 and FR-005 are verified against.
- **Persisted icon identifier**: the short text key (for example, one naming a utensils or car icon) stored on a budget item locally and in synced remote rows, and on transaction history snapshots as a display icon key. It is independent of the icon library's own naming, must not change, and must keep resolving to the same icon across this change.
- **Project instructions file (`CLAUDE.md`)**: holds the pointer to the active plan plus the language and asset conventions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A debug web build of the app completes with 0 compile errors (today: fails).
- **SC-002**: 100% of test files load (today: 22 fail to load), and the full suite finishes with 0 failures (today: 287 pass / 22 files unloadable).
- **SC-003**: Static analysis reports no more than the current 2 informational issues, and none relate to icons.
- **SC-004**: A review of all 52 icons across every screen in light and dark appearance, against the design references' icon lists, finds 0 missing icons, 0 icons swapped for a different concept, 0 icons with a changed line style, weight or size, and 0 glyphs drawn or edited by the team. The baseline is the design references' icon lists (27 of the 52 icons) plus, for the rest, the intended Lucide concept per the Icon usage inventory; reviewer doubts are escalated to the owner (see User Story 2).
- **SC-005**: Running dependency resolution and static analysis on a clean checkout produces 0 changes to tracked files.
- **SC-006**: The plan reference in `CLAUDE.md` resolves to an existing file belonging to this feature, and 0 references to plans of already-merged features remain.
- **SC-007**: The web build ships only the icons actually used: the total icon-font payload contributed by the icon source is under 100 KB (the full, unreduced font is roughly 900 KB, and some packages additionally bundle several unused weight variants totalling about 3 MB, which this criterion rules out).
- **SC-008**: The code-format check reports 0 files needing changes (today: 11).
- **SC-009**: On web, Android and iOS, one press of "Đăng nhập" on a fresh session reaches Tổng quan (today: needs two presses), and the new regression test fails when the router listens to the upstream auth stream instead of the signed-in state the redirect reads.

## Assumptions

- **Target toolchain**: the stable Flutter currently installed (3.47.5 / Dart 3.13.4) is the supported baseline. The project's declared SDK floor stays as is unless the chosen icon source strictly requires raising it.
- **No version bump is possible**: `lucide_icons 0.257.0` is the latest published release and was last published in June 2023, so this feature replaces the icon source rather than upgrading it. Maintained alternatives exist on pub.dev (three were evaluated; see `research.md`). Which one to use is a planning decision (`/speckit-plan`), judged on FR-003, coverage of the 52 icons (under their current Lucide names), and shipped icon-font payload (SC-007).
- **Icon names may differ in code** between packages; only the visual result is contractual, and minor upstream redraws are accepted (see Clarifications and Edge Cases). The default and expected outcome is that all 52 icons exist in the maintained package, so no in-repo icon set is needed. If one proves necessary, it is an owner-commissioned design, not something this feature produces.
- **Preliminary coverage check (2026-10-05)**: all 52 icons used in `lib/` were found by name in `lucide_icons_flutter` 3.1.22 and in `lucide_flutter` 1.47.0, so the expected outcome above looks achievable. Confirming each resolves to the same Lucide concept (via shared codepoints with upstream renames) is recorded in the plan's research and verified visually under SC-004.
- **Build verification scope**: FR-001 and SC-001 are verified on the web target, which is buildable in the current environment. Android and iOS builds are attempted and their outcome recorded (success, or blocked with the tool's stated reason, since the development machine's Android toolchain and Xcode are incomplete); a blocked mobile build is reported, not treated as a defect of this feature. Only the installed Flutter (3.47.5) is verified; older versions within the declared Dart floor are not re-verified, and no incompatibility is expected because the replacement uses plain `const IconData`. Device verification follows the same limits as earlier features (open manual tasks in earlier specs are not reopened here).
- **`CLAUDE.md` plan pointer**: this project's convention is that the pointer names the feature in progress, so it is expected to change with each feature. The update here sets it to this feature's plan once `plan.md` exists; the plan workflow normally rewrites it automatically and that satisfies FR-009.

## Out of Scope

- Making the cold-start lock deterministic (a related but separate race observed during verification; recorded in `research.md` Observations).
- Building the Security, Notifications or Help screens (the next planned work, a separate feature).
- Upgrading any other outdated dependency (`drift`, `go_router`, `flutter_riverpod`, `flutter_secure_storage`, etc.) — these are tracked separately under the constitution's routine `pub outdated` review and are not required for the app to compile.
- Fixing the 2 pre-existing `onReorder` deprecation notices.
- Redesigning, re-sizing or re-styling any icon.
- Drawing, tracing, editing or freezing any icon glyph, and designing a custom icon set (owner-led via a designer, only if a package gap is ever found).
- Raising manual verification tasks left open in earlier specs (iOS builds, quickstart walkthroughs).
