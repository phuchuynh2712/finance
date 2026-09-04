# Phase 1 Data Model: Rebrand Theme, App Icon & Icon Library

This feature has no persisted or transactional entities (no database rows, no domain use cases). "Data model" here means the static token/asset structure that `core/theme/` and the icon-library migration expose — the shape every screen consumes via `Theme.of(context)` and `LucideIcons.*`.

## Theme Palette

Two immutable `ColorScheme` instances (`AppTheme.light`/`AppTheme.dark`) plus one `ThemeExtension<AppSemanticColors>` pair (registered in each `ThemeData.extensions`), replacing the current green/gold-only `ColorScheme`s, built from `reference/theme-tokens.json` per research.md §4–§6. Split into two blocks because `ColorScheme` has no native slot for `success`/`warning` (research.md §6).

### ColorScheme mapping

| Field | Type | Light value | Dark value | Constraint |
|---|---|---|---|---|
| `primary` | Color (hex) | `#1A72E0` | `#3B8DF8` | Text/link use restricted to large-text/button/icon contexts (research.md §4) |
| `onPrimary` | Color (hex) | `#FFFFFF` | `#1A1714` (reused `bgApp` token, not white — research.md §5) | Text/icon color drawn on `primary`-filled surfaces; MUST be ≥4.5:1 |
| `error` (= `danger`) | Color (hex) | `#A42619` | `#E07A6D` | Negative amounts/destructive actions/errors — used sparingly, not decoratively (spec FR-008) |
| `onError` | Color (hex) | `#FFFFFF` | `#1A1714` (reused `bgApp` token, not white — white-on-`#E07A6D` measures 2.93:1, fails AA; research.md §6) | Text/icon color drawn on `error`-filled surfaces; MUST be ≥4.5:1 |
| `surface` (= `bgSurface`) | Color (hex) | `#FFFFFF` | `#241F1A` | Card/sheet surfaces |
| `onSurface` (= `fg1`) | Color (hex) | `#1A1714` | `#FAF8F5` | Default body text/icon color |

### AppSemanticColors extension (`lib/core/theme/app_semantic_colors.dart`)

| Field | Light value | Dark value | Constraint |
|---|---|---|---|
| `success` | `#237A50` | `#62BB91` | Income/positive amounts |
| `successSoft` | `#EBF5F0` | `rgba(35,122,80,0.16)` | Banner/chip fill background for success |
| `warning` (gold) | `#AE8015` | `#DFB04A` | Light: non-text/large-UI/banner use only, 3.36:1 max (research.md §4). Dark: safe for text (8.88:1) |
| `warningSoft` | `#FBF3E0` | `rgba(201,151,31,0.16)` | Banner/chip fill background for warning |
| `dangerSoft` | `#FBEDEB` | `rgba(196,48,32,0.16)` | Banner/chip fill background for danger (paired with `ColorScheme.error` above, not duplicated there) |
| `primarySoft` | `#EDF4FF` | `rgba(59,141,248,0.16)` | Banner/chip fill background for primary |
| `successFg` | `#237A50` (same as `success` — see note below) | `#8FD6B0` | Text/icon color for success content drawn on a `successSoft` (or `bgApp`/`bgSurface`) background — dark value verified 10.55:1 on `bgApp`, 9.65:1 on `bgSurface`, both AA pass |
| `warningFg` (gold) | `#AE8015` (same as `warning` — see note below) | `#ECCB7E` | Text/icon color for warning/gold content drawn on a `warningSoft` (or `bgApp`/`bgSurface`) background — dark value verified 11.40:1 on `bgApp`, 10.43:1 on `bgSurface`, AA pass. Light value inherits `warning`'s existing non-text-only restriction (research.md §4) |
| `dangerFg` | `#A42619` (same as `danger` — see note below) | `#F0B3A8` | Text/icon color for danger content drawn on a `dangerSoft` (or `bgApp`/`bgSurface`) background — dark value verified 9.96:1 on `bgApp`, 9.11:1 on `bgSurface`, AA pass |
| `bgApp` | `#FAF8F5` | `#1A1714` | App background (distinct from `ColorScheme.surface`, which is card/sheet level) |
| `fg2` | `#4A443B` | `#B0A696` | Secondary text |
| `fg3` | `#8A8073` | `#8A8073` | Caption/metadata only in light mode (3.66:1, large-text threshold); safe for normal text in dark mode (4.60:1) |
| `border1`/`border2` | `#E7E1D8` / `#D4CCC0` | `#4A443B` | Passive dividers only — interactive element outlines MUST use `fg2` or `ColorScheme.primary` instead (research.md §4) |

**Why the light-mode `*Fg` values just equal their base color**: `reference/theme-tokens.json` defines `successFg`/`goldFg`/`dangerFg` only in its `dark` block — light mode has no distinct equivalent because light-mode `success`/`danger` already pass AA as plain text on light `bgApp`/`bgSurface`/`*Soft` backgrounds (research.md §4), so `*Fg` simply aliases the base token in light mode rather than introducing a new color. `warningFg` in light mode still inherits `warning`'s non-text-only restriction (gold cannot be made AA-safe as text on any of its light backgrounds — research.md §4); giving every field on `AppSemanticColors.light` a defined value (even when it duplicates another field) keeps the class's shape identical between `.light` and `.dark`, which `copyWith`/`lerp` require.

Consumed as `Theme.of(context).extension<AppSemanticColors>()!.success` etc. — never as bare hex literals in a screen, per constitution Principle III.

**Validation rule**: every `on*`/paired-surface text combination (in both blocks) MUST measure ≥4.5:1 (WCAG AA normal text) except where explicitly scoped to large-text/non-text/icon use per research.md §4–§6 — those instead meet the ≥3:1 non-text/large-text threshold. Enforced by an automated test at `test/unit/core/theme/app_theme_test.dart`, not by convention alone.

**State/lifecycle**: None — compile-time constants. The active scheme is selected by `ThemeMode.system` at the `MaterialApp` level, driven entirely by the OS (per spec Clarifications: no manual override in this feature).

## Brand Icon Asset

Not a data entity — a set of static files, hand-authored **SVG source** (canonical, per `CLAUDE.md`'s SVG-first convention) plus **rasterized PNG** (generated build artifact, required only because `flutter_launcher_icons`/`flutter_native_splash` accept PNG input exclusively — research.md §3):

| Part | SVG source (canonical) | Rasterized PNG (generated) | Purpose |
|---|---|---|---|
| Master icon | `assets/icon/appicon.svg` (replaced, from `reference/app-icon/app-icon-khai-tam.svg` with the source's `rx="22"` **dropped** — square full-bleed canvas, no baked-in rounding, per research.md §2/FR-004) | `assets/icon/appicon.png` (1024×1024) | Feeds legacy Android `ic_launcher.png` and the full iOS `AppIcon.appiconset` (iOS applies its own corner mask — FR-004) |
| Adaptive background layer | `assets/icon/appicon_background.svg` (replaced) — viewBox `0 0 108 108`, single flat `<rect x="0" y="0" width="108" height="108" fill="#DFB04A"/>`, **no `rx`** (source's `rx="22"` dropped — Android applies its own mask) | `assets/icon/appicon_background.png` | Flat gold `#DFB04A` rect, no motif — Android adaptive icon background |
| Adaptive foreground layer | `assets/icon/appicon_foreground.svg` (replaced) — viewBox `0 0 108 108`, transparent background, the source's 6 lotus `<path>` elements wrapped in `transform="translate(-4.667,-4.056) scale(1.2222)"` (exact values computed in research.md §2 from the measured source bounding box; not to be re-eyeballed) | `assets/icon/appicon_foreground.png` | Lotus motif (white/blue petals, red base), scaled to fit the 66×66dp safe zone centered in the 108×108dp canvas, transparent background — Android adaptive icon foreground |

## Splash Screen Asset

Not a data entity — a per-theme static configuration consumed by `flutter_native_splash` at build time:

| Field | Light value | Dark value |
|---|---|---|
| Legacy/iOS icon image | `assets/icon/appicon.png` (both modes, same master icon) | Same |
| Legacy/iOS background color | `#FAF8F5` (light theme `bgApp`) | `#1A1714` (dark theme `bgApp`) |
| Android 12+ icon image | `assets/icon/appicon_foreground.png` (same safe-zone-scaled motif asset reused from the adaptive launcher icon) | Same |
| Android 12+ icon background color | `#FAF8F5` | `#1A1714` |

The splash background reuses the exact `bgApp` token from the corresponding `ColorScheme` in both variants, so the native splash screen and the first in-app frame share an identical background color — this is what satisfies FR-006/SC-006 and User Story 1's acceptance scenario 3 (no unstyled flash or mismatched background).

## Icon Library Set

Not a persisted entity — the mapping from every in-app icon usage to a single glyph source (Lucide, via the `lucide_icons` package), replacing scattered `Icons.*` (Material) usage. New for this feature (the prior `20260724-app-icon-theme` feature did not touch in-app iconography).

| Field | Description |
|---|---|
| `usageSite` | A file:line location in `lib/` where an icon is rendered (e.g. navigation destination, action button, status indicator) |
| `previousGlyph` | The `Icons.*` constant currently used at that site (from research.md §7's inventory) |
| `lucideGlyph` | The `LucideIcons.*` constant it is replaced with — 1:1 semantic equivalent, not necessarily the same shape |
| `context` | One of: navigation, action/button, status/alert, category picker |

| Field (category icon picker only) | Description |
|---|---|
| `categoryIconKey` | A stable string key identifying the chosen icon for a user-created/edited spending category (e.g. `"utensils"`) |
| `availableSet` | The offered choices in the picker — at minimum `icons-used.json`'s `iconsUsedPerCategory` list (banknote, book-open, briefcase, car, heart, home, piggy-bank, popcorn, shield-check, shopping-bag, user, utensils, zap), all resolved via `LucideIcons.*` |

**Validation rule**: after migration, a repository-wide search for `Icons\.` (Material) in `lib/` outside of any files explicitly exempted (none are — spec FR-012 covers 100% of in-app iconography) MUST return zero matches. Enforced by the tasks-phase migration checklist, not a runtime check (this is a static-composition constraint, not app behavior).

**Touch target constraint**: every interactive icon (button, nav item, tappable status chip) MUST have a tappable hit-area ≥48×48dp per this project's constitution (Principle III), which supersedes the design handoff's 44px figure — see research.md §8. Decorative/non-interactive icons (e.g. an icon inside read-only status text) have no minimum hit-area but MUST remain visually legible at the handoff's documented default sizes (24px default, 20px in buttons/inputs, 16px minimum).
