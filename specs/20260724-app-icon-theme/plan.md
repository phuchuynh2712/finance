# Implementation Plan: App Icon & Theme

**Branch**: `20260724-app-icon-theme` | **Date**: 2026-07-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/20260724-app-icon-theme/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the Flutter scaffold's default app icon, launch/splash screen, and single placeholder `ThemeData` with brand assets derived from `exports/appicon.svg` (green rounded-square, network/graph motif, gold center node). Deliver: (1) generated Android/iOS launcher icons — including a decomposed adaptive-icon foreground/background pair for Android — from the single source SVG; (2) a `core/theme/` light and dark `ColorScheme` pair whose colors are derived from the icon's palette and verified against WCAG AA contrast; (3) a native splash screen (Android `launch_background.xml` + `values-night` variant, iOS `LaunchScreen.storyboard`) showing the same icon on a theme-matched background, wired to `MaterialApp.theme` / `darkTheme` / `themeMode: ThemeMode.system`.

## Technical Context

**Language/Version**: Dart 3.11 (Flutter, `environment.sdk: ^3.11.0` per `pubspec.yaml`)

**Primary Dependencies**: Flutter Material 3 (`useMaterial3: true`, existing in `main.dart`); `flutter_launcher_icons` and `flutter_native_splash` (new dev_dependencies) to generate platform icon/splash assets from source SVG/PNG exports; no new runtime dependency required

**Storage**: N/A — this feature reads only the local source asset (`exports/appicon.svg`) and writes generated static assets + Dart theme constants; no database/network involvement

**Testing**: `flutter analyze` (zero warnings, Principle I); a widget test asserting `ThemeData`/`ColorScheme` values and WCAG AA contrast ratios for the light/dark palettes (see `research.md` for the exact hex values under test); manual on-device verification of installed icon, adaptive-icon masking, and splash screen per the spec's Independent Test steps (automated screenshot testing of native OS chrome — home screen, splash — is out of reach of Flutter's test harness)

**Target Platform**: Android (adaptive icon, API 26+ launcher masking) and iOS (Human Interface Guidelines icon masking), matching the existing Flutter scaffold's only configured platforms

**Project Type**: mobile-app (existing Flutter Clean-Architecture + feature-first scaffold, per constitution)

**Performance Goals**: N/A beyond Principle IV's general cold-start budget (<2s) — this feature does not add runtime computation; theme objects are static `const`/module-level values built once at app start, not derived at runtime

**Constraints**: Generated icon/splash assets MUST render pixel-sharp on the highest-density supported screen (SC-005); no in-app manual theme toggle required (system-driven `ThemeMode.system` only, per spec Assumptions); existing `locale: const Locale('vi')` and localization delegates in `main.dart` MUST NOT be altered by this feature — only theme-related `MaterialApp` fields change

**Scale/Scope**: One source icon asset → ~15 generated files (5 Android mipmap densities × legacy icon, 2 Android adaptive-icon layers × densities, iOS `AppIcon.appiconset` image set, Android `drawable`/`drawable-v21`/`values-night` splash resources, iOS `LaunchScreen.storyboard` update) + 1 new `core/theme/app_theme.dart` (or equivalent small module) defining 2 `ColorScheme`s; no new screens, no new features/ directories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Section | Applies? | Assessment |
|---|---|---|
| I. Code Quality | Yes | Theme colors live in `core/theme/` as named tokens (no screen hardcodes hex values); `flutter analyze` must stay clean; the small `core/theme/app_theme.dart` module has a single responsibility (build the two `ColorScheme`/`ThemeData` objects) |
| II. Testing Standards | Partial | No financial/business logic is introduced, so the 80% domain-coverage gate does not apply to this feature. A widget/unit test for the derived `ColorScheme` values and WCAG AA contrast checks IS in scope and required (see Testing above) — this is the one automated test this feature must ship |
| III. User Experience Consistency | Yes — core gate | Single centralized `ThemeData` (light + dark) that all screens will consume via `Theme.of(context)`; both modes supported and contrast-verified (WCAG AA); no screen-level hardcoded colors introduced. Localization fields in `main.dart` are left untouched (out of scope, not regressed) |
| IV. Performance Requirements | N/A | No lists, animations, or per-frame work added; theme objects are constructed once, not per-build |
| Recommended Architecture (feature-first + Clean Architecture) | Yes, minimal | New code is infrastructure (`core/theme/`), not a feature — correctly placed since it's shared across all future features, not owned by one. No `domain/`/`data/` layers needed (no entities, no repository) |
| Offline-First Data & Sync | N/A | No relational or syncable data involved |
| Security | N/A | No secrets, tokens, or user data touched; static public-facing brand assets only |
| Development Workflow | Yes | Feature branch already in use (`20260724-app-icon-theme`); `flutter format` / `flutter analyze` apply to the new theme module as with any Dart file |

**Result**: PASS. No violations requiring Complexity Tracking justification — this feature is additive infrastructure (assets + one small theme module) that fits the existing `core/` convention exactly as designed.

**Post-Phase-1 re-check**: `research.md` and `data-model.md` introduced no new dependencies, data flows, or architectural elements beyond what this table already covers (two dev-only generator packages, one `core/theme/` module, static assets). Gate result unchanged: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/20260724-app-icon-theme/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command) — theme token structure
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No `contracts/` directory: this feature exposes no API, CLI, or external interface — it is internal app theming and static platform assets consumed only by the app's own widget tree and OS packaging tools. Per the plan template's own guidance ("Skip if project is purely internal"), contracts are skipped.

### Source Code (repository root)

```text
lib/
├── core/
│   └── theme/                       # NEW
│       ├── app_colors.dart          # Named color tokens derived from exports/appicon.svg
│       └── app_theme.dart           # Light + dark ThemeData/ColorScheme built from app_colors.dart
└── main.dart                        # MODIFIED — wire theme/darkTheme/themeMode:.system

assets/
└── icon/                            # NEW — SVG sources (canonical, hand-edited) + rasterized PNGs (generated)
    ├── appicon.svg                  # Verbatim copy of exports/appicon.svg (legacy icon + iOS source)
    ├── appicon_foreground.svg       # Motif + gold center only, transparent bg, scaled to Android safe zone
    ├── appicon_background.svg       # Flat icon green, no motif (Android adaptive background layer)
    ├── appicon.png                  # GENERATED — 1024x1024 raster of appicon.svg (flutter_launcher_icons/
    │                                 # flutter_native_splash require PNG input; SVG not supported — see research.md §4-5)
    ├── appicon_foreground.png       # GENERATED — raster of appicon_foreground.svg
    └── appicon_background.png       # GENERATED — raster of appicon_background.svg

android/app/src/main/res/
├── mipmap-*/ic_launcher.png                    # REGENERATED by flutter_launcher_icons
├── mipmap-anydpi-v26/ic_launcher.xml            # NEW — adaptive icon descriptor
├── drawable{,-night,-v21,-night-v21}/launch_background.xml  # REGENERATED by flutter_native_splash
├── values{,-night,-v31,-night-v31}/styles.xml   # MODIFIED/NEW by flutter_native_splash (per-density/
│                                                 # API-level dark-mode + Android 12+ style variants)
└── drawable-v21/launch_image.png (etc.)         # GENERATED splash bitmap variants

ios/Runner/
├── Assets.xcassets/AppIcon.appiconset/          # REGENERATED by flutter_launcher_icons
└── Base.lproj/LaunchScreen.storyboard           # REGENERATED by flutter_native_splash

pubspec.yaml                                      # MODIFIED — add flutter_launcher_icons,
                                                   # flutter_native_splash dev_dependencies + their
                                                   # config blocks (dev-time only; the packages read
                                                   # assets/icon/ directly by path — no runtime
                                                   # AssetImage() use, so NOT registered under
                                                   # flutter.assets: to avoid bundle bloat)

test/
└── unit/core/theme/app_theme_test.dart          # NEW — WCAG AA contrast assertions for both ColorSchemes
```

**Structure Decision**: New theme code goes under `lib/core/theme/`, matching the constitution's explicit `core/theme/` convention (shared across all features, not owned by one). No `features/` directory is added since this is infrastructure, not a user-facing feature module. Icon/splash generation uses the standard Flutter-ecosystem packages (`flutter_launcher_icons`, `flutter_native_splash`) driven by three prepared source images under `assets/icon/`, rather than hand-editing every platform resource file — the packages already know each platform's exact density/format requirements (FR-002, FR-002a, FR-010) and both support per-theme splash backgrounds (FR-008) out of the box, including writing into the scaffold's existing `values-night/styles.xml` for the dark splash variant.

## Complexity Tracking

> Not applicable — Constitution Check passed with no violations.
