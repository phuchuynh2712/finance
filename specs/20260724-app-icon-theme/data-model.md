# Phase 1 Data Model: App Icon & Theme

This feature has no persisted or transactional entities (no database rows, no domain use cases). "Data model" here means the static token structure that `core/theme/` exposes — the shape every future screen consumes via `Theme.of(context)`.

## Theme Palette

Two immutable `ColorScheme` instances, `AppTheme.light` and `AppTheme.dark`, each built from the hex values decided in `research.md` §2–§3.

| Field | Type | Light value | Dark value | Constraint |
|---|---|---|---|---|
| `primary` | Color (hex) | `#287A53` | `#8FD3AB` | MUST be ≥4.5:1 against its paired `onPrimary` (verified in research.md) |
| `onPrimary` | Color (hex) | `#FFFFFF` | `#0C2318` | Text/icon color drawn on `primary`-filled surfaces |
| `secondary` | Color (hex) | `#DFB04A` | `#DFB04A` | Accent color. Light theme: non-text/large-UI use only (3.56:1 max on light bg, below 4.5:1 text threshold). Dark theme: safe for text (8.23:1) |
| `onSecondary` | Color (hex) | `#153F2A` | `#0C2318` | Text/icon color drawn on `secondary`-filled surfaces |
| `surface` | Color (hex) | `#EBF5F0` | `#0C2318` | App background. Dark value is a darkened derivative of `iconGreen`, not neutral gray (per Clarifications) |
| `onSurface` | Color (hex) | `#153F2A` | `#FFFFFF` | Default body text/icon color. MUST be ≥4.5:1 against `surface` |
| `error` | Color (hex) | `#BA1A1A` (Material default) | `#FFB4AB` (Material default) | No brand-specific error color was specified; standard Material 3 semantic red reused in both modes |

**Validation rule**: every `on*` / paired-surface combination in the table above MUST measure ≥4.5:1 (WCAG AA, normal text) except where explicitly scoped to non-text/large-UI use (see `secondary` light-mode note) — those instead meet the ≥3:1 non-text/large-text threshold. This is enforced by the automated test at `test/unit/core/theme/app_theme_test.dart` (see Testing in plan.md), not by convention alone.

**State/lifecycle**: None — these are compile-time constants, not runtime-mutable state. The active scheme (light vs. dark) is selected by Flutter's `ThemeMode.system` at the `MaterialApp` level, driven entirely by the OS; the app itself holds no theme-selection state to persist or transition.

## App Icon Asset

Not a data entity — a set of static files. Documented here only to name its parts, since FR-002a introduces structure beyond "one icon file". Each part exists in two forms: a hand-authored **SVG source** (canonical, scalable, the file to edit for any future icon revision — per this project's SVG-first asset convention in `CLAUDE.md`) and a **rasterized PNG** (a generated build artifact, required only because `flutter_launcher_icons` accepts PNG input exclusively — see research.md §4–§5):

| Part | SVG source (canonical) | Rasterized PNG (generated, 1024×1024) | Purpose |
|---|---|---|---|
| Master icon | `exports/appicon.svg` (existing) | `assets/icon/appicon.png` | Feeds the legacy Android `ic_launcher.png` set and the full iOS `AppIcon.appiconset` (iOS applies its own corner mask — FR-009) |
| Adaptive background layer | `assets/icon/appicon_background.svg` | `assets/icon/appicon_background.png` | Flat `iconGreen`, no motif — Android adaptive icon background |
| Adaptive foreground layer | `assets/icon/appicon_foreground.svg` | `assets/icon/appicon_foreground.png` | Network motif + gold center, scaled to fit the 66×66dp safe-zone square (centered in the 108×108dp canvas, per Android's official adaptive icon guide), transparent background — Android adaptive icon foreground |

## Splash Screen Asset

Not a data entity — a per-theme static configuration consumed by `flutter_native_splash` at build time. The configuration has two variants because Android 12+ uses a fundamentally different splash mechanism (OS-managed, icon clipped to a circle) than Android <12/iOS (a full-screen image the app controls directly):

| Field | Light value | Dark value |
|---|---|---|
| Legacy/iOS icon image | `assets/icon/appicon.png` (rasterized from `exports/appicon.svg`, same master icon, both modes) | Same |
| Legacy/iOS background color | `#EBF5F0` (light theme `surface`) | `#0C2318` (dark theme `surface`) |
| Android 12+ icon image | `assets/icon/appicon_foreground.png` (the same motif-only, safe-zone-scaled asset used for the adaptive launcher icon foreground — reused here because Android 12+ clips the splash icon to a circle, which the same safe-zone scaling already fits) | Same |
| Android 12+ icon background color | `#EBF5F0` (light theme `surface`) | `#0C2318` (dark theme `surface`) |

The splash background intentionally reuses the exact `surface` token from the corresponding `ColorScheme` in both variants, so the native splash screen and the first in-app frame share an identical background color — this is what prevents the "flash of mismatched background" failure mode called out in FR-008/SC-004 and User Story 3's acceptance scenario 4.
