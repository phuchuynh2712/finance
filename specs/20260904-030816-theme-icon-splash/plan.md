# Implementation Plan: Rebrand Theme, App Icon & Icon Library

**Branch**: `20260904-030816-theme-icon-splash` | **Date**: 2026-09-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/20260904-030816-theme-icon-splash/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Replace the app's currently-shipped green/network-icon brand identity (app icon, splash screen, light/dark theme) with the new "Khai Tâm" lotus-mark brand from the design handoff (blue/gold/red palette), and additionally migrate all in-app iconography from scattered Material `Icons.*` usage to a single consistent icon library (Lucide via `lucide_icons`). Technical approach: derive Android adaptive-icon background/foreground SVG layers from the single lotus source SVG, rasterize to PNG via `cairosvg` for `flutter_launcher_icons`/`flutter_native_splash`, replace `AppColors`/`AppTheme` with WCAG-AA-verified tokens from `theme-tokens.json` (with documented text-usage constraints where a token fails AA in a literal reading), and replace every `Icons.*` call site with its `LucideIcons.*` equivalent. A manual light/dark toggle is explicitly out of scope (deferred to a future Profile/Settings feature per spec Clarifications); theme switching is system-driven only.

## Technical Context

**Language/Version**: Dart 3.11.0 (SDK constraint `^3.11.0`), Flutter 3.41.0 stable

**Primary Dependencies**: `flutter_riverpod` (state mgmt, unaffected by this feature), `go_router` (routing, unaffected), new: `lucide_icons` (icon library). Dev-only: `flutter_launcher_icons` (already present), `flutter_native_splash` (already present)

**Storage**: N/A — this feature introduces no persisted/database entities (compile-time theme constants + static icon assets only)

**Testing**: `flutter_test` (widget/unit), existing `test/unit/core/theme/` pattern from the prior `20260724-app-icon-theme` feature reused for the new palette's WCAG assertions

**Target Platform**: Android + iOS (mobile app; web/desktop explicitly out of scope per the prior feature's Assumptions, carried forward — `flutter_native_splash` config already has `web: false`)

**Project Type**: Mobile app (single Flutter project, feature-first + Clean Architecture layering per constitution)

**Performance Goals**: N/A beyond constitution defaults (Principle IV: 60fps, <2s cold start) — this feature does not introduce new runtime computation, only static assets and constant `ColorScheme`/icon-glyph swaps, so no feature-specific performance target beyond "does not regress the existing constitution defaults"

**Constraints**: Interactive touch targets ≥48×48dp (constitution Principle III overrides the handoff's 44px figure — research.md §8); WCAG 2.1 AA contrast for all text/interactive-element color pairs (spec FR-010); SVG-first asset sourcing, PNG only as a derived build artifact (spec FR-016, `CLAUDE.md` asset convention); offline-first (constitution) — ruled typography (Lexend/Crimson Pro Google Fonts) out of this feature's scope since it would require either a network fetch or a new bundled-font decision not requested by the user (research.md §9)

**Scale/Scope**: 1 app icon (3 derived layers: master/background/foreground, each SVG+PNG), 2 `ColorScheme`s (light/dark) replacing 2 existing ones, ~13 known `Icons.*` call sites across 4 files migrated to Lucide (research.md §7), 1 new category icon picker UI (~13 category icons minimum)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Applies? | Assessment |
|---|---|---|
| I. Code Quality | Yes | `AppTheme`/`AppColors` stay pure Dart classes with single responsibility (token definitions only, no widget logic); icon migration is a mechanical 1:1 swap, no new abstractions needed. `flutter analyze` must remain zero-warning after the swap (e.g. no now-unused `cupertino_icons` import warnings). |
| II. Testing Standards | Yes | New/updated unit test (`test/unit/core/theme/app_theme_test.dart`) asserting WCAG AA per data-model.md's validation rule — this is business-logic-adjacent (accessibility correctness), not UI polish, so it is gated like the prior feature's equivalent test. Icon-migration completeness (no leftover `Icons.*`) is verified by a repo-wide search per quickstart.md, not a runtime test, since it's a static-composition property. |
| III. UX Consistency | Yes — core focus of this feature | Single centralized `ThemeData`/token source (no screen hardcodes colors), light+dark both supported, single icon library resolves the "may not invent bespoke pattern" concern raised by having two icon styles today. Touch target ≥48×48dp enforced (stricter than handoff's 44px, per research.md §8) — this feature's job *is* to close prior UX-consistency gaps (mixed icon styles, no true dark-palette-per-brand). |
| III. Localization | No new strings | This feature adds no user-facing text (only visual assets/tokens); existing `vi`/`en` ARB files untouched. |
| IV. Performance | Yes, defaults only | Compile-time constant tokens and static icon glyphs impose no additional runtime cost; no new list rendering, no new isolate work. Nothing in this feature needs profiling beyond a sanity check that swapping ~13 icon widgets doesn't introduce unnecessary rebuild scope (it doesn't — same widget shape, different constant). |
| Offline-First / Sync | No | No data, no sync — N/A. |
| Security | No | No secrets, no new network calls, no new tables — N/A. |

**Gate result**: PASS. No violations requiring Complexity Tracking justification. The one place this feature *deviates* from the handoff (touch target 48dp vs. 44px) is the constitution's stricter figure taking precedence per Governance, not a deviation from the constitution itself.

## Project Structure

### Documentation (this feature)

```text
specs/20260904-030816-theme-icon-splash/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── reference/             # Copied design handoff (theme-tokens.json, icons-used.json, README.md, app-icon/)
└── tasks.md               # Phase 2 output (/speckit-tasks command — not created by /speckit-plan)
```

No `contracts/` — this feature exposes no external interface (API, CLI, public library surface); it is entirely internal app theming/asset/UI work, consistent with the prior `20260724-app-icon-theme` feature's plan.

### Source Code (repository root)

```text
lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart              # REPLACED: new palette tokens sourced from reference/theme-tokens.json
│   │   ├── app_theme.dart               # REPLACED: new AppTheme.light / AppTheme.dark ColorSchemes
│   │   └── app_semantic_colors.dart     # NEW: ThemeExtension<AppSemanticColors> (success/warning/*Soft — no ColorScheme slot exists for these, research.md §6)
│   ├── router/
│   │   └── app_router.dart      # MODIFIED: Icons.* → LucideIcons.* (nav destinations, ~4 pairs)
│   └── widgets/                 # (if a shared icon-picker widget is added, lives here — used by ≥2 features)
├── features/
│   ├── envelopes/presentation/
│   │   ├── envelopes_screen.dart   # MODIFIED: Icons.* → LucideIcons.*
│   │   └── overview_screen.dart    # MODIFIED: Icons.* → LucideIcons.*
│   └── expenses/presentation/
│       └── spending_screen.dart    # MODIFIED: Icons.* → LucideIcons.*
└── main.dart                      # unchanged (already wires AppTheme.light/dark + ThemeMode.system)

assets/
└── icon/
    ├── appicon.svg / .png                       # REPLACED: new lotus master icon
    ├── appicon_background.svg / .png            # REPLACED: new gold background layer
    └── appicon_foreground.svg / .png             # REPLACED: new lotus foreground layer, safe-zone scaled

android/app/src/main/res/                # REGENERATED by flutter_launcher_icons / flutter_native_splash
ios/Runner/Assets.xcassets/              # REGENERATED by flutter_launcher_icons / flutter_native_splash
ios/Runner/Base.lproj/LaunchScreen.storyboard  # REGENERATED by flutter_native_splash

pubspec.yaml
├── dependencies: + lucide_icons
└── flutter_launcher_icons / flutter_native_splash config blocks: unchanged paths, new source content

test/
└── unit/core/theme/
    └── app_theme_test.dart      # MODIFIED: WCAG AA assertions updated for new palette + usage-context constraints
```

**Structure Decision**: Single Flutter project (existing structure, no new top-level directories). This feature touches only `core/theme/` (shared, used by all features — correctly lives in `core/` per the constitution's Recommended Architecture) and the handful of `features/*/presentation/` files that currently render `Icons.*`, plus root-level `assets/icon/`, `pubspec.yaml`, and platform-generated asset folders. No new feature module, no new domain/data layers — this is a cross-cutting `core/` + presentation-layer change, matching how the prior `20260724-app-icon-theme` feature was scoped.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

No violations — table intentionally left empty.
