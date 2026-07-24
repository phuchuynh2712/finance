# Phase 0 Research: App Icon & Theme

## 1. Source icon palette (extracted from `exports/appicon.svg`)

| Token | Hex | Role in source SVG |
|---|---|---|
| `iconGreen` | `#2E8B5E` | Rounded-square background, network-line strokes |
| `iconLightGreen` | `#8FD3AB` | Six network node dots |
| `iconCream` | `#EBF5F0` | Center circle behind the graph glyph |
| `iconGold` | `#DFB04A` | Center node (focal point) |

**Decision**: These four hex values are the canonical source palette; all derived theme colors below are computed from them, not chosen freehand. This directly satisfies the spec's Assumption ("green/gold/cream color values are the intended brand colors to derive the theme from") and FR-003/FR-004.

## 2. Light theme `ColorScheme` — derivation and WCAG AA verification

**Decision**:

| Role | Hex | Derivation |
|---|---|---|
| `primary` | `#287A53` | `iconGreen` darkened ~12% toward black — raw `#2E8B5E` only reaches 4.22:1 against white text (fails AA's 4.5:1 normal-text minimum); darkening to `#287A53` reaches 5.25:1 |
| `onPrimary` | `#FFFFFF` | White text on `primary` — 5.25:1 (AA pass) |
| `secondary` (accent) | `#DFB04A` (`iconGold`, unchanged) | Used only as a non-text accent (icons, chips, selected-state fills, large-scale UI) — raw gold on light backgrounds does not clear AA for *text* (see below), so it is scoped to non-text/large-UI use per WCAG's 3:1 non-text threshold |
| `onSecondary` | `#153F2A` (dark green) | Text/icon drawn on top of a gold-filled surface (e.g. FAB icon) — verified ≥4.5:1 |
| `surface` | `#EBF5F0` (`iconCream`, unchanged) | App background |
| `onSurface` | `#153F2A` | `iconGreen` darkened ~55% toward black — 10.61:1 against `surface` (AA pass with large margin) |
| `error` | Material default red (`#BA1A1A`) | No brand-specific error color specified; standard Material 3 semantic color reused |

**Rationale for excluding raw gold from text roles**: computed contrast of `#DFB04A` on `#EBF5F0` is 1.80:1; even darkened 30% toward black (`#9C7B34`) it only reaches 3.56:1 — clears WCAG's 3:1 bar for large text (≥24px) and UI components/graphics, but not the 4.5:1 bar for normal body text. **Constraint carried into data-model.md**: gold MUST NOT be used for small/body text in the light theme; it is an accent (icons, highlight fills, borders, large headlines) only. This is a real design constraint, not an oversight — it is documented so implementation doesn't silently reach for gold text and fail a contrast check later. **Implementation note for the tasks phase**: this constraint should be pinned with a one-line dartdoc comment on the `secondary` field in `app_theme.dart` (not just left in this research doc), since Constitution III's "consume only via `Theme.of(context)`" rule prevents ad hoc gold hex use but doesn't by itself warn a future screen author against passing `secondary` into a small `Text` widget.

**Alternatives considered**: Using raw `#2E8B5E` as `primary` unmodified — rejected because it fails AA for its own most common use case (white text/icons on a primary-colored button, 4.22:1 < 4.5:1). A 12% darken was the minimum adjustment needed to clear the threshold while staying visually recognizable as "the icon's green."

## 3. Dark theme `ColorScheme` — derivation and WCAG AA verification

**Decision** (per clarification: dark background is a darkened/desaturated derivative of the icon's green, not a neutral gray):

| Role | Hex | Derivation |
|---|---|---|
| `surface` (background) | `#0C2318` | `iconGreen` mixed 75% toward black — dark enough for a dark theme while retaining a visible green cast |
| `onSurface` | `#FFFFFF` | 16.55:1 against `surface` (AA pass with large margin) |
| `primary` | `#8FD3AB` (`iconLightGreen`, unchanged) | The SVG's existing light-green node-dot color reads naturally as the "bright brand color" against a dark background — 9.51:1 against `surface` |
| `onPrimary` | `#0C2318` (`surface` value) | Dark text/icon on a light-green-filled control — 9.51:1 |
| `secondary` (accent) | `#DFB04A` (`iconGold`, unchanged) | Raw gold reaches 8.23:1 against `surface` — unlike the light theme, gold is safe for text/icons directly in dark mode, no darkening needed |
| `onSecondary` | `#0C2318` | Dark text on a gold-filled surface |
| `error` | Material default dark-mode red (`#FFB4AB`) | Standard Material 3 dark-mode semantic color reused |

**Alternatives considered**: A neutral dark gray/black background (Material 3's typical dark-surface convention) — rejected per the explicit clarification answer; the user wants the dark theme to still read as brand-colored rather than a generic dark UI. A lighter background mix (e.g., 50% toward black) was rejected because at that lightness `iconGold` and `iconLightGreen` no longer clear 4.5:1 comfortably; 75% toward black was the point where all three foreground colors (white, light-green, gold) clear AA with headroom.

## 4. Android adaptive icon: layer decomposition strategy

**Decision**: Manually author two derived **SVG** sources from the single flat `exports/appicon.svg`, per the clarification answer — SVG (not PNG) is the hand-authored/canonical form for both layers, per this project's asset convention (see `CLAUDE.md` "Asset conventions"): source art stays as SVG in the repo, and any raster format a downstream tool requires is generated from it, never hand-edited directly.

1. **Background layer** (`assets/icon/appicon_background.svg`): the flat rounded-square green fill only (`#2E8B5E`, full 108×108dp adaptive-icon canvas, no rounding needed — Android applies its own mask), no motif.
2. **Foreground layer** (`assets/icon/appicon_foreground.svg`): the network motif (six nodes + connecting lines + polygon + gold center), transparent background, scaled and centered to fit within Android's **66×66dp safe-zone square**, centered inside the 108×108dp canvas — this is the exact figure from Google's official adaptive icon guide ("the inner 66x66 dp of the icon appears within the masked viewport... never clipped by a shaped mask defined by an OEM"), not an approximation. **Correction from an earlier draft of this document**: the safe zone is a 66×66dp *square*, not "66%"/72×72dp (that larger figure is Android's outer *keyline* bound — content is allowed out to there but is NOT guaranteed to survive every mask shape) and not a 66dp-diameter *circle* (a stricter guess considered and rejected once the square figure was verified against the primary source). Computed precisely: the source motif's bounding box in the original 88×88 viewBox is x:[12.5, 75.5] (width 63), y:[12, 76] (height 64), centered at (44, 44). Fitting the longer dimension (64) exactly into 66 gives scale factor `66/64 = 1.0313`, landing the bounding box precisely on the safe-zone boundary at [21, 87] with **zero margin** for anti-aliasing spill. **Correction — safety margin added**: an exact-fit scale leaves no room for the 0.5–1px anti-aliasing bleed that occurs at raster edges, risking sub-pixel clipping under strict masks. The final scale instead targets 95% of the safe zone: scale factor `(66×0.95)/64 = 0.9797`, translate `(10.8938, 10.8938)`, landing the bounding box at [22.65, 85.35] on the height axis and [23.14, 84.86] on the width axis — a uniform ~1.65-unit margin (≈15.6px at the final 1024px raster resolution) on every side, comfortably absorbing anti-aliasing without perceptibly shrinking the motif.

This satisfies FR-002a and the corresponding Edge Case. **Important constraint discovered during implementation**: `flutter_launcher_icons`' `adaptive_icon_background`/`adaptive_icon_foreground` config keys (and `image_path`) accept **PNG only** — the package's underlying raster library (`image` on pub.dev) does not parse SVG, and this is confirmed in the package's own documentation (every example uses `.png`). The three `assets/icon/*.svg` files above remain the canonical, hand-edited sources; a one-time rasterization step (§5) produces the PNG files the package actually consumes, so the SVGs are never bypassed or discarded — they are the thing a future icon revision would edit, with PNGs regenerated from them.

**Alternatives considered**: Using the single flat icon as both layers (background = flat icon, foreground = same icon on transparent) — rejected because it does not solve the actual masking problem: launchers would still crop the motif at the mask boundary since the full icon (not just the motif) would sit in the foreground layer at full size. Auto-generating the split via a tool (e.g., an automated foreground-extraction script) — rejected as unnecessary complexity; the source SVG has only 4 flat shape types (rect, circles, path, polygon) and splitting it into two hand-edited SVGs is a five-minute manual task with a precise, verifiable output, versus writing/maintaining a bespoke extraction script for one asset.

## 5. Tooling: icon and splash generation packages

**Decision**: Add `flutter_launcher_icons` and `flutter_native_splash` as `dev_dependencies` in `pubspec.yaml`, each configured via their standard YAML block (either inline in `pubspec.yaml` or a dedicated `flutter_launcher_icons.yaml` / `flutter_native_splash.yaml`).

- `flutter_launcher_icons`: generates all Android mipmap densities (legacy `ic_launcher.png` + adaptive `mipmap-anydpi-v26/ic_launcher.xml`) and the full iOS `AppIcon.appiconset` image set from three **rasterized PNG** copies of the source SVGs (§4), satisfying FR-001, FR-002, FR-002a, FR-009 (iOS gets the flat un-rounded source; the tool does not bake in a mask, since iOS applies its own), FR-010. **Verified against the package's official README/pub.dev metadata**: `image_path`, `adaptive_icon_background`, and `adaptive_icon_foreground` all require PNG input — SVG is not supported.
- `flutter_native_splash`: generates Android `drawable`/`drawable-v21/launch_background.xml` (plus `-night`/`-night-v21` dark-mode variants and, on newer Flutter/Android target versions, `values-v31`/`values-night-v31` styles) and regenerates iOS launch assets — all from a single config specifying the icon image plus separate `color` (light) and `color_dark` (dark) background hex values (from §2/§3's `surface` tokens). Satisfies FR-007, FR-008. **Verified against the package's official README**: the `image` field's documentation states explicitly "it must be a png file" — SVG is not supported. **Discovered during implementation**: the package generates **web** splash assets by default even when only `android`/`ios` are set to `true` — `web: false` must be set explicitly, or it silently modifies `web/index.html` and creates `web/splash/`, which is out of scope per spec.md's Assumptions (web/desktop excluded from this feature).
- **Rasterization step**: since both packages require PNG but this project's canonical source format is SVG (see `CLAUDE.md`), a one-time rasterization from `assets/icon/*.svg` → `assets/icon/*.png` (1024×1024, 4x density per `flutter_native_splash`'s guidance) is required before running either generator. The exact rasterization tool is an implementation-time choice based on what's available in the environment (e.g., a headless SVG-to-PNG renderer) — not a fixed dependency pinned in this document, per the project's asset-conventions guidance to pick the concrete approach based on what's actually available rather than a prescribed method. The rasterized PNGs are build artifacts, not hand-maintained files: if `assets/icon/*.svg` changes, the PNGs are regenerated, never edited directly.
- **Discovered during implementation — `adaptive_icon_foreground_inset`**: `flutter_launcher_icons` applies its own foreground inset (default 16%) via `android:inset` in the generated `mipmap-anydpi-v26/ic_launcher.xml`, independent of whatever safe-zone margin the source foreground image already has. Since `appicon_foreground.svg` already precisely scales the motif to Android's 66×66dp safe zone (§4) with transparent padding baked directly into its 108×108 canvas, leaving the tool's default 16% inset in place would double-shrink the motif on top of that. `adaptive_icon_foreground_inset: 0` is set explicitly to avoid this.
- **Discovered during implementation — iOS alpha channel**: `flutter_launcher_icons` warns that an alpha channel in the 1024×1024 iOS marketing icon violates Apple App Store requirements. Since the source SVG has no transparent regions (the background rect fills the full canvas), `remove_alpha_ios: true` removes the alpha channel with no visual loss.

**Rationale**: Both are the de facto standard Flutter-ecosystem packages for this exact problem (actively maintained, used across the vast majority of production Flutter apps for icon/splash generation), and both already understand each platform's density/format/masking requirements in detail — reimplementing that logic by hand (manually resizing to 15+ target files) would be slower and more error-prone with no benefit, since neither package requires any runtime dependency (they only run at build/dev time). Keeping SVG as the source of truth (rather than hand-editing PNGs) preserves scalability and easy re-editing for any future icon revision, while still satisfying each package's hard PNG-input requirement via a thin, regeneratable rasterization step.

**Alternatives considered**: Hand-placing every resolution manually — rejected as needlessly time-consuming and error-prone for a fully solved problem (SC-005's "no pixelation" requirement is exactly what these tools are built to guarantee via correct per-density scaling). A third-party online icon generator web service — rejected to avoid uploading unreleased brand artwork to an external third party and to keep icon generation reproducible/scriptable within the repo. Hand-authoring the PNGs directly instead of SVGs — rejected because it would make the icon non-scalable and hard to revise (every future edit would mean re-drawing a 1024×1024 raster by hand instead of editing simple SVG shapes), contrary to the project's SVG-first asset convention.

## 6. Theme wiring in `main.dart`

**Decision**: Extend the existing `MaterialApp` in `lib/main.dart` with `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode: ThemeMode.system` (new fields), where `AppTheme.light`/`AppTheme.dark` are built in the new `lib/core/theme/app_theme.dart` from the `ColorScheme`s in §2/§3. All other existing `MaterialApp` fields (`locale`, `supportedLocales`, `localizationsDelegates`, `title`, `home`) are left unmodified — this feature only touches theme-related fields, per the plan's Technical Context constraint.

**Alternatives considered**: A `Provider`/`Riverpod`-driven manual theme toggle — rejected; the spec's Assumptions explicitly state no in-app manual override is required, and `ThemeMode.system` is the simplest mechanism that satisfies FR-005 (automatic switching driven by device setting) with zero additional state management.

## Outstanding NEEDS CLARIFICATION

None. All Technical Context fields are resolved; no unknowns remain for Phase 1 design.
