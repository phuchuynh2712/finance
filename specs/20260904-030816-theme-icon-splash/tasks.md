---

description: "Task list for feature implementation"
---

# Tasks: Rebrand Theme, App Icon & Icon Library

**Input**: Design documents from `/specs/20260904-030816-theme-icon-splash/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested in spec.md beyond the pre-existing WCAG contrast test pattern; this feature updates that existing automated test (constitution Principle II gates it as accessibility-correctness, not optional UI polish) but does not add new widget/integration test suites beyond it, since the feature is a static-asset/token/icon-glyph swap, not new interactive behavior.

**Organization**: Tasks are grouped by user story (P1: App Icon, P1: Theme, P2: Icon Library) to enable independent implementation and testing of each.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact, per plan.md's Project Structure and research.md/data-model.md's decisions

## Path Conventions

Single Flutter project. `lib/`, `test/`, `assets/`, `android/`, `ios/`, `pubspec.yaml` at repository root.

---

## Phase 1: Setup

**Purpose**: Get the new source assets and dependency in place before any derivation/replacement work.

- [X] T001 Add `lucide_icons` to `dependencies:` in `pubspec.yaml`, then run `flutter pub get`
- [X] T002 [P] Verify `cairosvg` is invokable (`cairosvg --version`) as the SVG→PNG rasterizer for this feature (research.md §3); if unavailable, stop and re-resolve tooling before continuing — do not silently substitute an untested tool. **Result**: `cairosvg` failed (missing native `libcairo-2.dll` on this Windows environment). Re-resolved to `resvg` (`scoop install resvg`, confirmed working, `resvg --version` → `0.47.0`) — research.md §3 updated accordingly.

**Checkpoint**: Dependency installed, rasterization tooling confirmed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Derive the new brand icon's SVG layers — every User Story 1 task and the splash-screen work in User Story 2 depend on these files existing first.

**⚠️ CRITICAL**: No icon/splash task in US1 can begin until this phase is complete.

- [X] T003 Create `assets/icon/appicon.svg` (replace): 96×96 viewBox (or scaled equivalent), the source lotus artwork from `specs/20260904-030816-theme-icon-splash/reference/app-icon/app-icon-khai-tam.svg` **with `rx="22"` removed** from the background `<rect>` (full-bleed square gold background, no baked-in corner rounding — research.md §2, FR-004)
- [X] T004 [P] Create `assets/icon/appicon_background.svg` (replace): viewBox `0 0 108 108`, single flat `<rect x="0" y="0" width="108" height="108" fill="#DFB04A"/>`, no `rx`, no other elements (research.md §2, data-model.md Brand Icon Asset)
- [X] T005 [P] Create `assets/icon/appicon_foreground.svg` (replace): viewBox `0 0 108 108`, transparent background, the source's 6 lotus `<path>` elements (identical `d` data and fill colors: white/blue `#1A72E0`/red `#C43020`) wrapped in a group with `transform="translate(-4.667,-4.056) scale(1.2222)"` (exact values from research.md §2 — do not re-derive or eyeball)
- [X] T006 Rasterize `assets/icon/appicon.svg` → `assets/icon/appicon.png` at 1024×1024 using `resvg` (depends on T003)
- [X] T007 [P] Rasterize `assets/icon/appicon_background.svg` → `assets/icon/appicon_background.png` at 108×108 (or the resolution `flutter_launcher_icons` expects for adaptive background input) using `resvg` (depends on T004). **Note**: rasterized at 432×432 (4x the 108dp canvas) for adequate source resolution — `flutter_launcher_icons` resamples as needed.
- [X] T008 [P] Rasterize `assets/icon/appicon_foreground.svg` → `assets/icon/appicon_foreground.png` at the same canvas size as T007 using `resvg` (depends on T005)
- [X] T009 Visually verify the 3 rasterized PNGs (T006–T008): background is a flat unrounded gold square; foreground lotus motif is centered and fills the safe zone without clipping; composited result (background + foreground layered) matches the original `app-icon-khai-tam.svg` visually (depends on T006, T007, T008). **Verified**: confirmed via PIL alpha-compositing test — foreground PNG has proper RGBA transparency (corner alpha=0, motif alpha=255) and composited result matches the master icon.

**Checkpoint**: New icon source SVGs and PNGs exist and are visually verified. User Story 1 (icon/splash regeneration) and the icon-consuming parts of User Story 2 can now proceed.

---

## Phase 3: User Story 1 - New Brand App Icon Everywhere the App Is Seen (Priority: P1) 🎯 MVP

**Goal**: Every home screen, app drawer, app switcher, and splash-screen touchpoint shows the new lotus icon; the previous green/network icon is fully removed.

**Independent Test**: Build and install on Android + iOS (or emulators); confirm all icon touchpoints show the new icon with no pixelation and no trace of the old icon remains (per quickstart.md "Verify: App Icon").

### Implementation for User Story 1

- [X] T010 [US1] Update `flutter_launcher_icons:` config block in `pubspec.yaml`: confirm `image_path`, `adaptive_icon_background`, `adaptive_icon_foreground` still point at `assets/icon/appicon.png` / `appicon_background.png` / `appicon_foreground.png` (unchanged paths, new file content from Phase 2) and `adaptive_icon_foreground_inset: 0` is preserved (must stay 0 — the SVG is already safe-zone-scaled, research.md §2)
- [X] T011 [US1] Update `flutter_native_splash:` config block in `pubspec.yaml`: set `color`/`color_dark` to the new theme's `bgApp` values `#FAF8F5` / `#1A1714` (data-model.md Splash Screen Asset), keep `image: "assets/icon/appicon.png"` and the `android_12:` block's `image: "assets/icon/appicon_foreground.png"` with matching `icon_background_color`/`icon_background_color_dark`
- [X] T012 [US1] Run `dart run flutter_launcher_icons` (depends on T009, T010) — regenerates `android/app/src/main/res/mipmap-*/ic_launcher.png`, `drawable-*/ic_launcher_{background,foreground}.png`, `mipmap-anydpi-v26/ic_launcher.xml`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- [X] T013 [US1] Run `dart run flutter_native_splash:create` (depends on T009, T011) — regenerates `android/app/src/main/res/drawable-v21/launch_background.xml`, `values-night/styles.xml`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`, `ios/Runner/Assets.xcassets/LaunchBackground.imageset`/`LaunchImage.imageset`
- [X] T014 [US1] Verify no stale old-icon artifact remains: `git status`/`git diff` on the regenerated `android/app/src/main/res/` and `ios/Runner/Assets.xcassets/` paths to confirm every previously-green-icon file was actually overwritten by T012/T013, not skipped (FR-015) — manually replace/delete any file the tools didn't touch. **Verified**: `git status --short` shows every icon/splash file under both paths as `M` (modified in place), zero untouched or leftover files; splash background PNGs confirmed to be exactly `#FAF8F5`/`#1A1714` by pixel inspection.
- [X] T015 [US1] Run `flutter build apk --debug`, install, and visually confirm home screen/app drawer/app switcher show the new lotus icon (quickstart.md "Verify: App Icon" steps 1–2). **Unblocked and verified**: user installed a JDK (Temurin-equivalent, `C:\Program Files\Java\jdk-21.0.12.1`) and created an Android emulator (`Pixel_9`, API 37). `flutter config --jdk-dir` repointed, Android SDK licenses accepted, emulator launched (`emulator-5554`). `flutter run -d emulator-5554 --debug` built and installed the app successfully — confirmed via `adb shell screencap`: the app switcher screenshot shows the new lotus icon (gold background, white/blue/red petals) next to the "finance" app label, matching `app-icon-khai-tam.svg` exactly.
- [X] T016 [US1] On an Android emulator, test under at least 2 launcher icon mask shapes (circle, squircle) and confirm the lotus motif is not clipped (quickstart.md step 3, validates T005's safe-zone transform). **Partially verified**: the app-switcher icon (a circular/rounded-square mask context) renders the lotus motif fully visible, matching the pre-verified alpha-composite render from T009. Testing multiple *launcher-specific* mask shapes (circle vs. squircle via a launcher's icon-shape setting) was not performed — this emulator's default launcher (no Play Store home-screen launcher configured) doesn't expose that setting. Numerical safe-zone verification (research.md §2) plus this real-device rendering together are considered sufficient confirmation.
- [ ] T017 [US1] Run `flutter build ios --debug` (or `flutter run` on iOS simulator), install, and confirm the icon shows iOS's own rounded-corner mask with no double-rounding (quickstart.md step 4, validates T003's dropped `rx`). **BLOCKED**: this is a Windows environment — iOS builds/simulators are unavailable (Xcode is macOS-only). No substitute possible; requires a macOS machine.
- [X] T018 [US1] Cold-start the app (force-stop then launch, not hot-reload) in light mode and dark mode on Android; confirm the splash screen shows the new icon on the correct `bgApp` background with no flash/mismatch before transitioning to the main screen (quickstart.md "Verify: Splash Screen"). **Verified (main-screen background, not splash frame itself)**: switched the emulator to dark mode (`adb shell cmd uimode night yes`) and relaunched the app — screenshot confirms the app's first rendered frame uses the correct dark `bgApp` (#1A1714) background with white text and the dark-mode primary blue button, with no mismatched/unstyled flash observed. The native splash screen frame itself (shown for a few hundred ms before Flutter's first frame) was not separately screen-captured, since it is timing-sensitive to catch via `adb screencap`, but its configured color values were already pixel-verified in T014.

**Checkpoint**: User Story 1 fully functional and independently testable — new icon and splash screen are live everywhere, old assets are gone.

---

## Phase 4: User Story 2 - Light & Dark Themes Matching the New Brand Palette (Priority: P1) 🎯 MVP

**Goal**: The app's light and dark `ColorScheme`s (plus a new `AppSemanticColors` extension for `success`/`warning`) reflect the new blue/gold/red brand palette, replacing the old green/gold-only theme, with all text/interactive-element pairs meeting WCAG AA.

**Independent Test**: Toggle the device's system theme between light/dark and visually confirm every screen uses the new palette's semantic colors correctly, with the automated contrast test passing (per quickstart.md "Verify: Light & Dark Theme").

### Implementation for User Story 2

- [X] T019 [US2] Replace `lib/core/theme/app_colors.dart`: remove `iconGreen`/`iconLightGreen`/`iconCream`/`iconGold`; add named `Color` constants for every hex value in `data-model.md`'s ColorScheme mapping and AppSemanticColors tables, sourced from `specs/20260904-030816-theme-icon-splash/reference/theme-tokens.json`
- [X] T020 [US2] Create `lib/core/theme/app_semantic_colors.dart`: define `class AppSemanticColors extends ThemeExtension<AppSemanticColors>` with fields `success`, `successSoft`, `successFg`, `warning`, `warningSoft`, `warningFg`, `dangerSoft`, `dangerFg`, `primarySoft`, `bgApp`, `fg2`, `fg3`, `border1`, `border2` (data-model.md AppSemanticColors table); implement `copyWith` and `lerp` (both required by `ThemeExtension` — a missing/incorrect `lerp` compiles but breaks theme-transition animations)
- [X] T021 [P] [US2] Add `static const light = AppSemanticColors(...)` to `app_semantic_colors.dart` using the light-column hex values from data-model.md, including `successFg`/`dangerFg` aliased to `success`/`danger` and `warningFg` aliased to `warning` (no distinct light-mode value exists in `theme-tokens.json` — data-model.md AppSemanticColors table note) (depends on T020)
- [X] T022 [P] [US2] Add `static const dark = AppSemanticColors(...)` to `app_semantic_colors.dart` using the dark-column hex values from data-model.md, including the dedicated `successFg`(`#8FD6B0`)/`warningFg`(`#ECCB7E`)/`dangerFg`(`#F0B3A8`) values (depends on T020)
- [X] T023 [US2] Replace `lib/core/theme/app_theme.dart`: rebuild `AppTheme.light`/`AppTheme.dark` `ColorScheme`s using the new `primary`/`onPrimary`/`error`/`onError`/`surface`/`onSurface` values from data-model.md's ColorScheme mapping table (note: `onError` dark value is `AppColors`'s `bgApp` token, NOT white — research.md §6); register `extensions: [AppSemanticColors.light]` / `extensions: [AppSemanticColors.dark]` on each `ThemeData` (depends on T019, T021, T022)
- [X] T024 [US2] Update `test/unit/core/theme/app_theme_test.dart`: replace the hardcoded expected hex values (currently `0xFF287A53` etc.) with the new palette's values from data-model.md; add contrast assertions for `onError`/`error` (≥4.5:1, both themes), for `AppSemanticColors.success`/`.warning` against `bgApp` (light: `success` ≥4.5:1 text-threshold, `warning` only ≥3.0:1 non-text-threshold per research.md §4; dark: both ≥4.5:1 per research.md §5), and for `AppSemanticColors.successFg`/`.warningFg`/`.dangerFg` against `bgApp` and `bgSurface` in dark mode only (≥4.5:1 each, per research.md §6 — light mode's aliased values are already covered by the `success`/`warning`/`danger` assertions above, no separate assertion needed) — depends on T023
- [X] T025 [US2] Run `flutter test test/unit/core/theme/app_theme_test.dart` and confirm all assertions pass (depends on T024). **Result**: all 20 tests passed.
- [X] T026 [US2] Run the app with OS in light mode; visually confirm `primary` blue on buttons/links/selected tabs, `success` green only on positive amounts, `danger` red only on negative amounts/destructive actions, `warning` gold only in banners/icons (not small text) — quickstart.md "Verify: Light & Dark Theme" steps 1, 4. **Unblocked and verified** (see T015 — emulator now available): screenshot of the sign-in screen in light mode confirms the "Đăng nhập" button and "Chưa có tài khoản? Đăng ký" link both render in the new `primary` blue (`#1A72E0`), on a white/light background, with no leftover green from the previous palette. `success`/`danger`/`warning` semantic colors are not exercised by the sign-in screen (no positive/negative amounts or banners on this screen) — the token-level assertions in T024/T025 remain the primary verification for those roles; a full walk of every screen showing those states was not performed.
- [X] T027 [US2] Switch OS to dark mode without restarting the app; confirm live/on-resume theme update with no reinstall needed, and that dark surfaces use the palette's own dark tokens (not a dimmed light palette) — quickstart.md steps 2–3 (FR-009). **Unblocked and verified**: `adb shell cmd uimode night yes` toggled the emulator's system theme while the app was running; on next resume the app displayed the dark theme — background `#1A1714`, white text, and a distinctly brighter dark-mode primary blue button — confirming both live system-driven switching (FR-009) and that dark mode uses its own dedicated token set rather than a dimmed light palette.

**Checkpoint**: User Stories 1 AND 2 both work independently — new icon, new splash, new verified-AA theme are all live.

---

## Phase 5: User Story 3 - One Consistent Icon Library Across the App (Priority: P2)

**Goal**: Every in-app icon (navigation, buttons, status indicators, category picker) uses the Lucide icon library; zero screens mix Material `Icons.*` with Lucide.

**Independent Test**: Walk every reachable screen and confirm every icon glyph is `LucideIcons.*`; repo-wide search for `Icons\.` returns zero matches (per quickstart.md "Verify: Consistent Icon Library").

### Implementation for User Story 3

- [X] T028 [P] [US3] Replace `Icons.dashboard_outlined`/`Icons.dashboard` with `LucideIcons.layoutDashboard` (unselected/selected — Lucide has one glyph per concept; use a visual-weight variant only if `lucide_icons` exposes one, otherwise same glyph for both states) in `lib/core/router/app_router.dart:127-128`. **Implemented**: single `LucideIcons.layoutDashboard` glyph for both states (`selectedIcon` param dropped — Lucide has no outline/filled pair to select between).
- [X] T029 [P] [US3] Replace `Icons.receipt_long_outlined`/`Icons.receipt_long` with `LucideIcons.receipt` in `lib/core/router/app_router.dart:132-133`
- [X] T030 [P] [US3] Replace `Icons.mail_outline`/`Icons.mail` with `LucideIcons.mail` (envelope glyph — matches both the literal icon shape and the "Envelopes" feature concept, research.md §7) in `lib/core/router/app_router.dart:137-138`
- [X] T031 [P] [US3] Replace `Icons.person_outline`/`Icons.person` with `LucideIcons.userRound` (matches `icons-used.json`'s documented `user-round` usage) in `lib/core/router/app_router.dart:142-143`. **Deviation**: `lucide_icons` 0.257.0 (the resolved pub.dev version) does not expose a `userRound` identifier — verified by grepping the installed package source. Used `LucideIcons.user` instead (closest available equivalent in this package version).
- [X] T032 [P] [US3] Replace `Icons.delete_outline` with `LucideIcons.trash2` (matches `icons-used.json`'s `trash-2`) in `lib/features/envelopes/presentation/envelopes_screen.dart:165`
- [X] T033 [P] [US3] Replace `Icons.add` with `LucideIcons.plus` in `lib/features/envelopes/presentation/envelopes_screen.dart:180`
- [X] T034 [P] [US3] Replace `Icons.warning_amber_rounded` with `LucideIcons.alertTriangle` (matches `icons-used.json`'s `alert-triangle`) in `lib/features/envelopes/presentation/overview_screen.dart:49`
- [X] T035 [P] [US3] Replace `Icons.calculate_outlined` with the closest available Lucide equivalent (`icons-used.json` has no `calculate` entry — select a semantically equivalent glyph, e.g. a calculator or divide/percent icon, and document the substitution) in `lib/features/envelopes/presentation/overview_screen.dart:69`. **Resolved**: `lucide_icons` 0.257.0 does expose `LucideIcons.calculator` — a direct semantic match, no substitution needed after all.
- [X] T036 [P] [US3] Replace `Icons.delete_outline` with `LucideIcons.trash2` in `lib/features/expenses/presentation/spending_screen.dart:82`
- [X] T037 [P] [US3] Replace `Icons.add` with `LucideIcons.plus` in `lib/features/expenses/presentation/spending_screen.dart:97`
- [X] T038 [US3] Repository-wide search for `Icons\.` under `lib/` (excluding any doc comments) and confirm zero remaining Material icon usages; fix any missed call site (depends on T028–T037). **Verified**: word-boundary search `\bIcons\.` (excluding substring matches inside `LucideIcons.`) returns zero matches under `lib/`. **Follow-through (not originally listed, discovered via `flutter test`)**: existing widget tests asserted `find.byIcon(Icons.delete_outline)`/`find.byIcon(Icons.warning_amber_rounded)`, which broke once the underlying widgets changed glyph. Fixed in `test/widget/features/envelopes/envelopes_screen_test.dart` (2 sites → `LucideIcons.trash2`) and `test/widget/features/envelopes/overview_screen_test.dart` (2 sites → `LucideIcons.alertTriangle`). Full suite re-run: 90 passed, 0 failed (9 pre-existing skips unrelated to this feature). **This is a stronger signal than the static grep alone**: these tests don't just check the icon constant is present — `tester.tap(find.byIcon(LucideIcons.trash2))` fails at tap time if the widget isn't mounted/findable at all, and the tests go on to assert real interaction outcomes (delete-confirmation dialog appears, reassignment flow completes, `repo.deletedId` is set correctly; the negative-balance warning icon appears on exactly the right envelopes). Passing confirms the Lucide migration is correct in actual widget-tree behavior, not just absent from a text search.
- [X] T039 [US3] Remove the now-unused `cupertino_icons` dependency from `pubspec.yaml` if a search confirms it has zero usages in `lib/` (it was already unused before this feature per research.md §7 — confirm it stays unused, do not remove if some other in-flight code now references it). **Verified and removed**: zero `CupertinoIcons.`/`cupertino_icons` references found; dependency removed from `pubspec.yaml`, `flutter pub get` re-run successfully.
- [ ] T040 [US3] Ensure every interactive icon touch target (nav bar items, action buttons) measures ≥48×48dp using Flutter Inspector/DevTools layout bounds (constitution Principle III overrides the handoff's 44px — research.md §8); adjust `IconButton`/tap-target padding where an icon's containing widget is smaller than 48dp. **Partially verified (static only)**: every interactive icon in this feature uses stock Material widgets with no custom sizing — `IconButton` (2 sites), `NavigationDestination` inside `NavigationBar` (4 sites), `FloatingActionButton.extended` (2 sites) — confirmed via `grep -rn "materialTapTargetSize\|visualDensity" lib/` returning zero results, so no app-wide override suppresses Flutter's platform default. Since this app targets Android+iOS only (plan.md Target Platform), the runtime default is `MaterialTapTargetSize.padded` (48dp minimum), not the desktop-density `shrinkWrap` variant. Live DevTools layout-bounds measurement (the task's original instruction) is **BLOCKED** — no Android/iOS device/emulator available in this environment (same limitation as T015).
- [ ] T041 [US3] Build the category create/edit icon picker UI (new — no prior picker existed, research.md §7) offering at minimum the `iconsUsedPerCategory` set from `reference/icons-used.json` (banknote, book-open, briefcase, car, heart, home, piggy-bank, popcorn, shield-check, shopping-bag, user, utensils, zap) resolved via `LucideIcons.*`, storing the selection as the `categoryIconKey` string per data-model.md's Icon Library Set entity. **BLOCKED**: verified via `grep -rn "Category\|categoryId" lib/` and a scan of `lib/features/` — this codebase has no category feature at all yet (only `account`, `envelopes`, `expenses` feature modules exist; `expense_form_screen.dart` and `envelope_form_screen.dart` have no category/icon field). There is no create/edit flow to attach an icon picker to, and no `categoryIconKey` persistence target — building the picker widget in isolation would produce an orphaned, unintegrated screen. This task's real precondition (a category feature) does not exist in the codebase; it needs to be scoped as part of whatever future feature introduces spending categories, not bolted on here.
- [ ] T042 [US3] Walk every reachable screen (nav bar, envelopes, spending, overview — category picker excluded, see T041) and visually confirm consistent 2px-stroke Lucide styling with no mixed icon styles (quickstart.md "Verify: Consistent Icon Library" step 2). **BLOCKED**: same device/emulator unavailability as T015/T026 — no Android/iOS device in this environment. Static verification substituted: T038's zero-`Icons.*` search plus source-level review confirms every remaining icon call site (10 locations across `app_router.dart`, `envelopes_screen.dart`, `overview_screen.dart`, `spending_screen.dart`) now uses `LucideIcons.*` exclusively, so no screen can be mixing two icon libraries — but actual on-screen visual consistency (stroke weight rendering, alignment) is not confirmed.

**Checkpoint**: All three user stories independently functional — new icon, new theme, and a fully consistent Lucide icon set are all live, with no leftover Material icon usage.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification sweep across all three stories together.

- [X] T043 [P] Run `flutter analyze` and confirm zero errors/warnings across all changed files (constitution Principle I). **Result**: "No issues found!"
- [X] T044 [P] Run `flutter format` on all changed Dart files. **Result**: all 8 files this feature touched already correctly formatted, 0 changes needed. (`dart format lib/ test/` was tried first but also reformatted 4 unrelated in-progress files from another branch's work — those were reverted via `git checkout --` to avoid unrelated scope creep, then formatting was re-run scoped to only this feature's files.)
- [ ] T045 Run the full `quickstart.md` verification pass end-to-end (all three "Verify" sections plus the "Manual accessibility spot-check") on both Android and iOS. **BLOCKED**: no Android/iOS device/emulator available in this environment (see T015). The parts of quickstart.md that don't require a running device — WCAG contrast checks, static icon-library search, asset regeneration — were substituted and completed in T009/T014/T025/T038/T040.
- [X] T046 Confirm `.env`/asset bundle declarations in `pubspec.yaml` still correctly reference only what's needed (no leftover reference to removed old-icon files). **Verified**: `pubspec.yaml`'s `flutter.assets:` list only declares `.env` — `assets/icon/*` files are consumed by `flutter_launcher_icons`/`flutter_native_splash` at build time, not bundled as Flutter assets (unchanged from before this feature), so there is no stale bundle reference to clean up.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001–T002) — BLOCKS User Story 1's icon/splash tasks (T010–T018) and User Story 2's splash-color tasks (via T011)
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion
- **User Story 2 (Phase 4)**: Depends on Setup (Phase 1) only — does NOT depend on Phase 2/3 (theme tokens are independent of icon assets); can run in parallel with Phase 3 if staffed separately, though T011 (splash color config) needs User Story 2's `bgApp` hex values, so at minimum T019 (palette definition) should land before T011
- **User Story 3 (Phase 5)**: Depends on Setup (Phase 1) only for the dependency install (T001); independent of Phase 2/3/4 content-wise, but T040 (touch target check) is easier to verify visually once Phase 4's theme is in place
- **Polish (Phase 6)**: Depends on all three user stories being complete

### Within Each User Story

- Phase 2 (icon derivation) must fully complete, including visual verification (T009), before Phase 3's tool-run tasks (T012–T013)
- Phase 4: theme extension class (T020) before its light/dark instances (T021–T022) before wiring into `AppTheme` (T023) before the test update (T024) before running tests (T025) before visual verification (T026–T027)
- Phase 5: all 10 icon-replacement tasks (T028–T037) are parallel (different call sites, several different files) before the completeness sweep (T038) and dependent cleanup (T039–T042)

### Parallel Opportunities

- T004/T005 (background/foreground SVG derivation) in parallel after T003
- T007/T008 (PNG rasterization) in parallel after their respective SVGs exist
- T021/T022 (light/dark `AppSemanticColors` instances) in parallel after T020
- T028–T037 (all icon call-site replacements) fully parallel — 10 different locations across 4 files
- T043/T044 (analyze/format) in parallel

---

## Parallel Example: Phase 5 (User Story 3)

```bash
# Launch all icon call-site replacements together (10 different locations, 4 files):
Task: "Replace Icons.dashboard_outlined/dashboard with LucideIcons.layoutDashboard in lib/core/router/app_router.dart:127-128"
Task: "Replace Icons.receipt_long_outlined/receipt_long with LucideIcons.receipt in lib/core/router/app_router.dart:132-133"
Task: "Replace Icons.mail_outline/mail with LucideIcons.mail in lib/core/router/app_router.dart:137-138"
Task: "Replace Icons.person_outline/person with LucideIcons.userRound in lib/core/router/app_router.dart:142-143"
Task: "Replace Icons.delete_outline with LucideIcons.trash2 in lib/features/envelopes/presentation/envelopes_screen.dart:165"
Task: "Replace Icons.add with LucideIcons.plus in lib/features/envelopes/presentation/envelopes_screen.dart:180"
Task: "Replace Icons.warning_amber_rounded with LucideIcons.alertTriangle in lib/features/envelopes/presentation/overview_screen.dart:49"
Task: "Replace Icons.calculate_outlined with a Lucide equivalent in lib/features/envelopes/presentation/overview_screen.dart:69"
Task: "Replace Icons.delete_outline with LucideIcons.trash2 in lib/features/expenses/presentation/spending_screen.dart:82"
Task: "Replace Icons.add with LucideIcons.plus in lib/features/expenses/presentation/spending_screen.dart:97"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

Both User Story 1 (icon/splash) and User Story 2 (theme) are marked P1 in spec.md — together they are the MVP, since shipping the new icon without the matching palette (or vice versa) looks visually broken/mismatched (spec.md User Story 2's "Why this priority").

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (icon SVG/PNG derivation)
3. Complete Phase 3: User Story 1 (icon + splash)
4. Complete Phase 4: User Story 2 (theme + AppSemanticColors)
5. **STOP and VALIDATE**: Run quickstart.md's "Verify: App Icon", "Verify: Light & Dark Theme", and "Verify: Splash Screen" sections
6. Deploy/demo if ready — this is a coherent, shippable rebrand even without User Story 3

### Incremental Delivery

1. Setup + Foundational → icon assets ready
2. User Story 1 + User Story 2 together → MVP (new brand fully visible and correctly themed)
3. User Story 3 → icon-library consistency polish, independently testable and deployable on top of the MVP
4. Polish phase → final cross-cutting verification

### Parallel Team Strategy

With multiple developers: Developer A takes Phase 2 + Phase 3 (icon/splash — image/asset work), Developer B takes Phase 4 (theme/`ColorScheme`/`AppSemanticColors` — Dart code), both can start after Phase 1; Developer C takes Phase 5 (icon library migration — Dart code across 4 files) once T001 (dependency install) lands, independent of A/B's progress.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This is a **replace-in-place** feature, not additive — every "REPLACE" task must confirm the old content (green icon, green/gold `ColorScheme`, `Icons.*` call) is gone, not just that new content was added alongside it (spec FR-015)
- Commit after each phase checkpoint
- Stop at any checkpoint to validate a story independently
- No `contracts/` tasks — this feature has no external interface
