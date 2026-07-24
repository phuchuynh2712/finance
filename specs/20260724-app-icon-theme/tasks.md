---

description: "Task list template for feature implementation"
---

# Tasks: App Icon & Theme

**Input**: Design documents from `E:\Study\finance\specs\20260724-app-icon-theme\`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Spec does not request TDD; the plan requires exactly one automated test (WCAG AA contrast assertions for the theme `ColorScheme`s — Constitution Principle I/II gate). No contract/integration tests are generated since this feature has no external interface (contracts/ was skipped in planning) and no domain business logic.

**Organization**: Tasks are grouped by user story (US1 App Icon P1, US2 Light/Dark Theme P2, US3 Splash Screen P3) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in every task description

## Path Conventions

Existing Flutter mobile-app scaffold at repository root: `lib/`, `android/`, `ios/`, `assets/`, `test/`, `pubspec.yaml` — per plan.md's Project Structure.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Author the three canonical SVG sources, rasterize them to the PNG format the generator packages require, and register the two generator dev_dependencies.

- [X] T001 Copy `exports/appicon.svg` verbatim to `assets/icon/appicon.svg` (no edits — same 88×88 viewBox, same four source colors: `#2E8B5E`, `#8FD3AB`, `#EBF5F0`, `#DFB04A`), so the master icon source lives inside the standard `assets/icon/` tree alongside T002/T003's derived layers rather than being referenced from outside it (per CLAUDE.md "Asset conventions" — SVG is the hand-edited source of truth; per research.md §4, data-model.md "App Icon Asset")
- [X] T002 [P] Create `assets/icon/appicon_background.svg` — flat `#2E8B5E` rounded-square fill only, no motif, no rounding needed beyond the source (Android applies its own mask) — per research.md §4 "Background layer"
- [X] T003 [P] Create `assets/icon/appicon_foreground.svg` (108×108 viewBox, transparent background) — the network motif (six node dots, connecting lines, center polygon, gold `#DFB04A` center) from `exports/appicon.svg`, isolated from the green background rect, scaled by `0.9797` and translated `(10.8938, 10.8938)` so its bounding box fits within Android's official 66×66dp safe-zone square (centered in the 108×108dp canvas — the authoritative figure per Android's adaptive icon guide, not the looser 72×72dp keyline bound) with a ~1.65-unit margin on every side (not an exact edge-to-edge fit — that leaves zero room for anti-aliasing spill at raster edges) so no part of the glyph is clipped under any launcher mask shape — per research.md §4 "Foreground layer"
- [X] T004 Rasterize `appicon.svg` → `assets/icon/appicon.png`, `appicon_background.svg` → `assets/icon/appicon_background.png`, and `appicon_foreground.svg` → `assets/icon/appicon_foreground.png`, each at 1024×1024 (4x density, per `flutter_native_splash`'s sizing guidance). These PNGs are **generated build artifacts**, not hand-edited — required only because `flutter_launcher_icons` and `flutter_native_splash` accept PNG input exclusively and do not parse SVG (verified against both packages' official documentation — see research.md §4–§5). Pick the concrete rasterization tool based on what's available in the environment at implementation time, per CLAUDE.md "Asset conventions". If any of T001–T003 is later revised, re-run this task to regenerate the corresponding PNG rather than hand-editing it. (depends on T001–T003)
- [X] T005 Add `flutter_launcher_icons` and `flutter_native_splash` to `dev_dependencies` in `pubspec.yaml` (do NOT add `assets/icon/` under `flutter.assets:` — both packages read source images directly by path at dev/build time only, no runtime `AssetImage()` use, per plan.md Project Structure note)
- [X] T006 Configure `flutter_launcher_icons` in `pubspec.yaml` (or a dedicated `flutter_launcher_icons.yaml`): `image_path: assets/icon/appicon.png`, `android: true`, `ios: true`, `adaptive_icon_background: assets/icon/appicon_background.png`, `adaptive_icon_foreground: assets/icon/appicon_foreground.png`, `adaptive_icon_foreground_inset: 0` (the tool's default 16% inset would double-shrink the motif on top of the precise safe-zone scaling already baked into `appicon_foreground.svg` — see research.md §4), `remove_alpha_ios: true` (the source has no transparent regions; Apple rejects an alpha-channel 1024×1024 marketing icon) — per research.md §5 (depends on T004, T005)
- [X] T007 Configure `flutter_native_splash` in `pubspec.yaml` (or a dedicated `flutter_native_splash.yaml`): `image: assets/icon/appicon.png`, `color: "#EBF5F0"` (light `surface`), `color_dark: "#0C2318"` (dark `surface`), `android: true`, `ios: true`, `web: false` (web is out of scope per spec.md Assumptions; the package defaults `web` to enabled unless explicitly disabled — omitting this key silently generates unwanted `web/splash/` assets and modifies `web/index.html`), plus a nested `android_12:` block using `image: assets/icon/appicon_foreground.png` (Android 12+ clips the splash icon to a circle — reuse the motif-only, safe-zone-scaled foreground asset rather than the full flat icon) with `icon_background_color: "#EBF5F0"` / `icon_background_color_dark: "#0C2318"` — per research.md §5, data-model.md "Splash Screen Asset" (depends on T004, T005)

**Checkpoint**: SVG sources, rasterized PNGs, and generator config all exist; ready to run either generator independently.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: None required — this feature has no shared code or schema that multiple stories depend on. US1 (icon generation) and US3 (splash generation) depend only on Phase 1's prepared assets; US2 (theme) is entirely self-contained Dart code with no dependency on Phase 1.

**⚠️ No tasks in this phase** — all three user stories can start immediately after Phase 1 (US1, US3) or immediately in parallel with Phase 1 (US2).

**Checkpoint**: N/A — proceed directly to user story phases.

---

## Phase 3: User Story 1 - App Icon on Installed App (Priority: P1) 🎯 MVP

**Goal**: Every supported platform (Android, iOS) displays the brand icon as the installed app icon, including correct Android adaptive-icon masking, with no default placeholder visible.

**Independent Test**: Build and install the app on an Android and an iOS device/emulator; confirm the home screen, app drawer, and app switcher all show the new icon (not the Flutter default), and that the Android adaptive icon is not clipped under a circular launcher mask.

### Implementation for User Story 1

- [X] T008 [US1] Run `dart run flutter_launcher_icons` from repository root to generate all Android mipmap densities (`android/app/src/main/res/mipmap-*/ic_launcher.png`), the adaptive icon descriptor (`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`), and the iOS `ios/Runner/Assets.xcassets/AppIcon.appiconset/` image set — satisfies FR-001, FR-002, FR-002a, FR-009, FR-010
- [X] T009 [US1] Verify no other `android:icon` or `CFBundleIconFile` reference in `android/app/src/main/AndroidManifest.xml` / iOS `Info.plist` still points at a stale/default asset (the existing manifest already references `@mipmap/ic_launcher`, which T008 regenerates in place — confirm no path change is needed)
- [X] T010 [US1] Build and install a debug APK (`flutter build apk --debug` or `flutter run`) on an Android device/emulator; visually confirm the network motif is fully visible and not clipped under at least two different launcher icon mask shapes (e.g. circle and squircle — a squircle can clip corners a circle wouldn't, so circular alone is not sufficient evidence), validating the 66×66dp safe-zone scaling from T003/T004 against "all standard mask shapes" per FR-002a and the spec's Edge Cases — **Verified on `emulator-5554` (API 37)**: no icon-shape overlay available on this system image, so verified via (1) a pixel-level scan of the generated `ic_launcher_foreground.png` confirming opaque content bounds sit within [92,339]×[90,341] against the safe-zone boundary [84,348] — 6-9px margin on every side, well within the 66×66dp square regardless of mask shape — and (2) a home-screen screenshot showing the icon rendered cleanly under the default circular mask
- [ ] T011 [US1] Build and install on an iOS simulator/device (`flutter build ios --debug` or `flutter run`); visually confirm the home screen icon shows iOS's standard rounded-corner mask applied automatically (the source asset in T001 is not pre-rounded)
- [X] T012 [US1] Confirm the app switcher/recent-apps view shows the same new icon on both platforms (per spec Acceptance Scenario 1.3) — **Verified on Android** (`emulator-5554`): app-switcher card header shows the same brand icon; iOS not verified (see T011)

**Checkpoint**: User Story 1 is fully functional and independently verifiable — the app installs with the correct brand icon on both platforms.

---

## Phase 4: User Story 2 - Light & Dark Theme Matching the Icon (Priority: P2)

**Goal**: The app's light and dark themes use colors derived from the icon's palette (green primary, gold accent), automatically switching with the device's system theme setting, meeting WCAG AA contrast throughout.

**Independent Test**: Switch the device system setting between light and dark mode with the app open; confirm the app's color scheme updates to the derived palette in both modes with no unreadable text or broken contrast.

### Tests for User Story 2

- [X] T013 [P] [US2] Write `test/unit/core/theme/app_theme_test.dart` asserting WCAG AA contrast (≥4.5:1) for every text-role pair in both `AppTheme.light` and `AppTheme.dark`: `onPrimary`/`primary`, `onSecondary`/`secondary` (dark theme only — light theme `secondary` is exempted, see T015), `onSurface`/`surface` — using the exact hex values from data-model.md's Theme Palette table — satisfies FR-006. This test MUST fail until T014–T015 exist (no `AppTheme` class yet).

### Implementation for User Story 2

- [X] T014 [P] [US2] Create `lib/core/theme/app_colors.dart` defining the four source tokens as `Color` constants: `iconGreen = Color(0xFF2E8B5E)`, `iconLightGreen = Color(0xFF8FD3AB)`, `iconCream = Color(0xFFEBF5F0)`, `iconGold = Color(0xFFDFB04A)` — per research.md §1
- [X] T015 [US2] Create `lib/core/theme/app_theme.dart` defining `AppTheme.light` and `AppTheme.dark` as two `ThemeData`/`ColorScheme` instances built from `app_colors.dart` plus the additional derived hex values from data-model.md's Theme Palette table (`primary: #287A53` / `#8FD3AB`, `onPrimary: #FFFFFF` / `#0C2318`, `secondary: #DFB04A` / `#DFB04A`, `onSecondary: #153F2A` / `#0C2318`, `surface: #EBF5F0` / `#0C2318`, `onSurface: #153F2A` / `#FFFFFF`, Material default `error` colors for both) — satisfies FR-003, FR-004. Add a one-line dartdoc comment directly above the `secondary:` argument inside the `ColorScheme.light(...)` constructor call documenting that in the light theme it is accent/non-text use only (max 3.56:1 against light backgrounds, below the 4.5:1 text threshold) — per research.md §2's implementation note. (depends on T014)
- [X] T016 [US2] Wire `lib/main.dart`'s `MaterialApp` with `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode: ThemeMode.system` — satisfies FR-005. Do NOT modify the existing `locale`, `supportedLocales`, `localizationsDelegates`, `title`, or `home` fields (depends on T015)
- [X] T017 [US2] Run `flutter test test/unit/core/theme/app_theme_test.dart` and confirm it now passes (depends on T013, T015)
- [X] T018 [US2] Run `flutter analyze` and confirm zero errors/warnings on the new `core/theme/` files (Constitution Principle I)
- [X] T019 [US2] Manually toggle the device/emulator system theme between light and dark with the app open/resumed; confirm the app's colors switch accordingly without reinstall (per spec Acceptance Scenario 2.3) — **Verified on `emulator-5554`** via `adb shell cmd uimode night yes/no` + force-stop/relaunch: light mode confirmed cream (`#EBF5F0`) background with dark-green text/FAB; dark mode confirmed dark-green-tinted (`#0C2318`) background with white text and light-green FAB — both screenshotted and match `AppTheme.light`/`AppTheme.dark` exactly

**Checkpoint**: User Stories 1 AND 2 both work independently — app installs with the correct icon (US1) and now also displays a brand-derived, contrast-verified, system-driven light/dark theme (US2).

---

## Phase 5: User Story 3 - Branded Splash Screen (Priority: P3)

**Goal**: The splash/launch screen shows the same brand icon on a background matching the active theme, transitioning cleanly to the main screen with no flicker or background mismatch.

**Independent Test**: Cold-start the app and observe the splash screen; confirm it displays the same brand icon on a theme-matched background before transitioning to the main app screen.

### Implementation for User Story 3

- [X] T020 [US3] Run `dart run flutter_native_splash:create` from repository root to generate/update `android/app/src/main/res/drawable/launch_background.xml`, `android/app/src/main/res/drawable-v21/launch_background.xml`, `android/app/src/main/res/values-night/styles.xml` (dark background color), and `ios/Runner/Base.lproj/LaunchScreen.storyboard` — satisfies FR-007, FR-008
- [X] T021 [US3] Force-stop and cold-start the app on Android in light mode; confirm the splash screen shows the brand icon centered on the `#EBF5F0` background, then transitions to the main screen with no visible flicker or background-color jump (per spec Acceptance Scenario 3.4) — **Verified on `emulator-5554`**: screenshot captured mid-transition shows the Android 12+ circular splash icon on the cream background, with the app content behind it using the identical `#EBF5F0` background — no color jump
- [X] T022 [US3] Repeat T021 with the device in dark mode; confirm the splash background is `#0C2318` (dark green-tinted, not neutral gray/black), matching `AppTheme.dark`'s `surface` value — **Verified on `emulator-5554`**: screenshot confirms the dark-green-tinted splash background matches `AppTheme.dark`'s `surface` exactly, with the app content underneath using the same color
- [ ] T023 [US3] Cold-start the app on iOS in both light and dark mode; confirm the same icon-on-theme-matched-background behavior as Android
- [ ] T024 [US3] If a tablet-sized emulator/device is available, cold-start and confirm the splash icon remains proportionally centered without stretching or distortion (per spec Edge Cases) — **DEFERRED**: a `Pixel_Tablet` AVD (API 37, 2560×1600) was created and three boot attempts were made in this environment. Attempt 1 wedged indefinitely in adb's "offline" transport state (process alive, adbd handshake never completed) even after an explicit `adb reconnect`. Attempt 2 (clean cold boot, no snapshot) crashed outright with a host-side rendering fault (`UpdateLayeredWindowIndirect failed ... device not functioning`), traced to the AVD's `hw.gpu.enabled=no` + 2GB RAM config. Attempt 3, after fixing that config (GPU host-accelerated, RAM 4096MB), hit the identical `UpdateLayeredWindowIndirect` fault again during window creation and never progressed to boot — indicating a host Windows display/driver-level fault specific to this AVD's skin window, not an AVD-config issue further tuning would fix. Per this task's own conditional wording ("if a tablet-sized emulator/device is available"), no such device is reliably available in this environment. Tablet-specific proportional/centering behavior is unverified; however, the splash mechanism itself (Android 12+ `android_12:` block, foreground-only motif asset, theme-matched background) is identical code/config across all screen sizes and was verified working on the phone emulator in T021/T022 — the risk this task guards against (stretching/distortion at a different aspect ratio) is inherently a rendering-engine concern, not one specific to the assets or config authored in this feature. User confirmed Android phone verification is sufficient and declined further tablet retry attempts (e.g. lower-resolution AVD, `-gpu swiftshader_indirect`) — this deferral is final, not pending.

**Checkpoint**: All three user stories are independently functional — icon, theme, and splash screen all reflect the brand artwork consistently across both platforms.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation spanning all three stories together.

- [X] T025 [P] Run `flutter analyze` across the full changed file set (`lib/core/theme/`, `lib/main.dart`) one final time — zero errors/warnings (Constitution Principle I)
- [X] T026 [P] Run `dart format` (or `flutter format`) on all new/modified Dart files
- [ ] T027 Execute the full `quickstart.md` verification walkthrough end-to-end (icon → theme → splash, both platforms, both light/dark) as a final combined check — **PARTIAL**: an Android phone emulator (`emulator-5554`, API 37) was created and used to run all Android on-device steps (icon on home screen, app switcher, live theme toggle, splash in both modes) — all confirmed via screenshot. Tablet-form-factor verification (T024) was attempted but the `Pixel_Tablet` AVD proved unable to reliably boot in this environment (see T024's deferral note) — deferred, not a defect in the feature's assets/config. iOS steps remain unverified: this environment has no Xcode/Mac, so no iOS simulator/build is possible on Windows; user explicitly decided to keep iOS in config-verified-only state (no CI setup) rather than pursue a workaround
- [ ] T028 Confirm SC-001 through SC-005 are all satisfiable from the completed work: 100% platform icon coverage (SC-001), visually distinguishable but clearly related light/dark themes (SC-002), zero failing WCAG AA contrast pairs per T013's test (SC-003), 100% cold-launch splash/theme match with no flicker (SC-004), pixel-sharp assets on the highest-density supported screen (SC-005) — **PARTIAL**: SC-002/SC-003 fully confirmed (T017's automated test suite + on-device theme-toggle screenshots). SC-001/SC-004/SC-005 confirmed on Android phone form factor (pixel-bounds scan + screenshots); tablet form factor unverified per T024's deferral (environment-specific AVD instability, not an asset/config issue); iOS portion of each remains config-verified only, not visually confirmed — accepted by user as the final state for this feature

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately. T002/T003 can run in parallel with each other and with T001 (different files); T004 (rasterization) depends on T001–T003 existing; T005 (dev_dependencies) depends on nothing; T006/T007 (generator config) depend on T004 (PNGs must exist to reference) and T005 (dev_dependencies must be declared first).
- **Foundational (Phase 2)**: Empty — no blocking prerequisites exist for this feature.
- **User Story 1 (Phase 3)**: Depends on Phase 1 (T001–T007) — needs the prepared/rasterized source images and generator config. Independent of US2 and US3.
- **User Story 2 (Phase 4)**: No dependency on Phase 1 or on US1/US3 — pure Dart code. Can start in parallel with Phase 1.
- **User Story 3 (Phase 5)**: Depends on Phase 1 (T001, T004, T007) — needs the master icon SVG, its rasterized PNG, and splash config. Independent of US1 and US2 (does not need `AppTheme` Dart code — the color values it needs are already pinned as literal hex in T007's config).
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Depends only on Setup — no dependency on US2 or US3.
- **User Story 2 (P2)**: No dependency on Setup, US1, or US3 — fully independent, could be implemented first if desired.
- **User Story 3 (P3)**: Depends only on Setup (specifically T001, T004, T007) — no dependency on US1 or US2.

### Parallel Opportunities

- T002 and T003 (Setup) can run in parallel — different files, both derived independently from `exports/appicon.svg`.
- Once Setup (T001–T007) completes, US1 (Phase 3) and US3 (Phase 5) can both start in parallel — they touch entirely different platform resources (Android/iOS icon files vs. Android/iOS splash files) via two independent generator commands (T008 vs. T020).
- US2 (Phase 4) can run at any time, in parallel with Setup, US1, and US3 — it has zero file overlap with either (only `lib/core/theme/*.dart` and `lib/main.dart`).
- T013 and T014 (US2) can run in parallel — the test file and the color-constants file are independent until T015 wires them together.
- T025 and T026 (Polish) can run in parallel.

---

## Parallel Example: Setup + User Story 2 running together

```bash
# Once the feature starts, these can all run in parallel (no shared files):
Task: "Create assets/icon/appicon_background.svg (T002)"
Task: "Create assets/icon/appicon_foreground.svg (T003)"
Task: "Write test/unit/core/theme/app_theme_test.dart (T013)"
Task: "Create lib/core/theme/app_colors.dart (T014)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T007)
2. Complete Phase 3: User Story 1 (T008–T012)
3. **STOP and VALIDATE**: Install on both platforms, confirm the brand icon appears correctly (including adaptive-icon masking) with no clipping
4. This alone is a shippable improvement over the Flutter default icon — deploy/demo if ready

### Incremental Delivery

1. Setup (Phase 1) → SVG sources, rasterized PNGs, and generator config ready
2. Add User Story 1 (Phase 3) → Test independently → Deploy/Demo (MVP — real brand icon on install)
3. Add User Story 2 (Phase 4) → Test independently → Deploy/Demo (brand-derived, accessible light/dark theme)
4. Add User Story 3 (Phase 5) → Test independently → Deploy/Demo (branded splash screen completes the experience)
5. Phase 6 Polish → final combined validation across all three

### Parallel Team Strategy

With multiple developers, since all three user stories are mutually independent after Setup:

1. One developer completes Phase 1 (Setup) first — this unblocks US1 and US3 (US2 needs no unblocking).
2. Once Setup is done:
   - Developer A: User Story 1 (icon generation + platform verification)
   - Developer B: User Story 2 (theme code + test) — could have started even earlier, in parallel with Setup
   - Developer C: User Story 3 (splash generation + platform verification)
3. All three stories complete and integrate without touching each other's files.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This feature has no Foundational phase (Phase 2) — an unusual but correct outcome for a pure-assets/theming feature with no shared domain code
- All specific hex values are embedded directly in task descriptions above (sourced from research.md/data-model.md) so no task requires re-reading those documents to execute
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently
