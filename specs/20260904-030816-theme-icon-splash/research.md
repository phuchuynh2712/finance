# Phase 0 Research: Rebrand Theme, App Icon & Icon Library

## 1. Source of truth for all decisions

**Decision**: `reference/theme-tokens.json`, `reference/icons-used.json`, and `reference/app-icon/app-icon-khai-tam.svg` (copied into this feature directory from the design handoff) are treated as authoritative. Hex values, type scale, spacing, icon names, and sizing are read directly from these files, not re-derived, except where a WCAG AA contrast check (below) requires constraining *usage* of an already-authoritative color, or where the project's own constitution overrides a handoff value (touch target size, §5).

**Alternatives considered**: Re-deriving palette values as the prior feature (`20260724-app-icon-theme`) did from a single flat icon — rejected because the new handoff already ships a complete, designed light+dark token set; re-deriving would silently diverge from what the designer produced.

## 2. New brand icon source structure

The source SVG (`reference/app-icon/app-icon-khai-tam.svg`, 96×96 viewBox) is a single flat document with a clean visual split:

| Layer | SVG content | Color(s) |
|---|---|---|
| Background | `<rect width="96" height="96" rx="22" fill="#DFB04A">` | Gold `#DFB04A` |
| Foreground (lotus motif) | 6 `<path>` elements: white outer petals, blue inner petals, white center bud, red base/stem | White `#FFFFFF`, blue `#1A72E0`, red `#C43020` |

**Decision**: Split into two derived SVGs for the Android adaptive icon. Exact transforms below were computed and numerically verified (not eyeballed) from the source path coordinates:

- `appicon_background.svg` — **viewBox `0 0 108 108`** (not 96×96 — this is a new canvas, not a crop of the source). Content: a single flat `<rect x="0" y="0" width="108" height="108" fill="#DFB04A"/>` with **no `rx`/corner-rounding at all** (the source's `rx="22"` MUST NOT be carried over — Android's launcher applies its own mask; baking in rounding here causes double-rounding under non-square masks, the exact failure FR-003/FR-004 exist to prevent). No other elements.
- `appicon_foreground.svg` — **viewBox `0 0 108 108`**, transparent background. Content: the same 6 lotus `<path>` elements from the source (identical `d` data and `fill` colors — white/blue/red), wrapped in a single group with `transform="translate(-4.667,-4.056) scale(1.2222)"`. Derivation: the lotus paths' measured bounding box in the 96×96 source is x:21–75 (width 54), y:27–68 (height 41); scale factor = 66 (safe-zone size) ÷ 54 (bbox longest dimension) = **1.2222**; translate = canvas-center (54,54) minus (bbox-center (48, 47.5) × scale) = **(-4.667, -4.056)**. Applying this transform places the motif's bounding box at exactly x:21–87 (width 66, centered on 54) and y:28.94–79.06 (height ~50.11, centered on 54) — fully inside the 66×66dp safe zone on the 108×108dp canvas, verified by direct computation, not visual estimation.
- `flutter_launcher_icons`' `adaptive_icon_foreground_inset: 0` (already set in `pubspec.yaml` from the prior feature) MUST be kept at `0` — the SVG above is already safe-zone-scaled; the tool's own default 16% inset would double-shrink it.

A flat combined master `appicon.svg`/`appicon.png` (background + foreground composited at 1:1, non-adaptive) is also generated for iOS (which has no adaptive/layered icon concept) and as the `flutter_native_splash` full-icon image. **The master's `rx="22"` MUST also be dropped** (square canvas, full-bleed gold background, no baked-in rounding) — iOS applies its own corner mask on top of whatever the asset contains, so keeping `rx="22"` would double-round the icon into a smaller rounded shape inset from the tile edge, and would literally violate FR-004 ("MUST NOT include platform-specific corner-rounding baked into the asset where the target platform applies its own icon mask"). This matches the prior feature's `20260724-app-icon-theme` choice (its `remove_alpha_ios: true` comment shows the same "let iOS own the masking" reasoning was already applied once in this codebase) and keeps all three derived assets (master, background, foreground) consistently un-rounded — only Android's launcher and iOS's own mask ever apply rounding, never the source art.

**Rationale**: Matches spec FR-002/FR-003 (adaptive icon safe zone) exactly and reuses the same tooling pattern already proven in this codebase (`pubspec.yaml` comments document the prior feature's identical approach).

## 3. Rasterization tooling (SVG → PNG)

**Decision (superseded during implementation — see note)**: Originally planned to use `cairosvg` (Python package installed in this environment). At implementation time, `cairosvg` was confirmed non-functional here: it depends on the native `libcairo-2.dll`, which is not present on this Windows environment (`OSError: no library called "cairo-2" was found`), and per tasks.md T002's own instruction ("if unavailable, stop and re-resolve tooling before continuing — do not silently substitute an untested tool") this was re-resolved rather than worked around. **`resvg`** (Rust-based SVG rasterizer, no native-library dependency issue, installed via `scoop install resvg`, confirmed working — `resvg --version` → `0.47.0`) is used instead: `resvg input.svg output.png -w <width> -h <height>`.

**Alternatives considered**: `inkscape`/ImageMagick's SVG delegate — neither was installed in this environment (only Windows' built-in `convert.exe`, the unrelated disk-conversion utility); `resvg` was chosen over installing `inkscape`/ImageMagick because it is a small, single-purpose, dependency-free static binary well-suited to a flat-shape SVG with no filters/gradients (this icon), avoiding a heavier install for a one-off build step.

## 4. Light theme — palette usage and WCAG AA verification

**Decision**: Use `reference/theme-tokens.json`'s `light` block verbatim for token values. Contrast-checked (WCAG 2.1, sRGB relative luminance formula) against the roles each color is actually used for:

| Pair | Ratio | Verdict | Usage constraint |
|---|---|---|---|
| `primary` (#1A72E0) white text, on-primary button fill | 4.64:1 | AA pass (normal text) | Safe for button labels/icons on primary fill |
| `primary` as text/link directly on `bgApp` (#FAF8F5) | 4.38:1 | **Fails** AA normal-text (4.5:1) by a hair; passes large-text/UI (3:1) | `primary` MUST NOT be used for small body-text links on `bgApp`; use it for buttons (fill), large headline links (≥18pt/24px), selected-tab indicators, and icons — body-copy links use `fg1` with an underline or icon affordance instead |
| `fg1` (#1A1714) on `bgApp` / `bgSurface` | 16.84:1 / 17.85:1 | AA pass, large margin | Default body text color |
| `fg2` (#4A443B) on `bgApp` | 9.08:1 | AA pass | Secondary text |
| `fg3` (#8A8073) on `bgApp` | 3.66:1 | Passes large-text/UI (3:1) only | Caption/metadata text only (≥18pt or non-text icon use), never small body text |
| `danger` (#A42619) on white / `bgApp` / `dangerSoft` | 7.32:1 / 6.90:1 / 6.42:1 | AA pass | Safe for text in all documented danger contexts |
| `success` (#237A50) on `bgApp` / `successSoft` | 4.99:1 / 4.75:1 | AA pass | Safe for text |
| `warning`/gold (#AE8015) on `bgApp` / `warningSoft` | 3.36:1 / 3.22:1 | **Fails** AA normal-text in both its documented contexts; passes large-text/UI (3:1) | Gold text MUST be large-text (≥18pt/24px), an icon, or a filled banner background (not gold text on any of its documented backgrounds) — matches the handoff's own guidance ("banner thông tin phân bổ %, không dùng cho lỗi") which already implies banner/icon use, not small-text use |
| `border2` (#D4CCC0) on `bgApp` | 1.50:1 | N/A — decorative divider, not interactive | Fine as a passive divider; interactive element outlines (input borders, focus rings) MUST use `fg2` or `primary`, not `border1`/`border2`, to meet the 3:1 non-text/UI-component threshold |

**Rationale**: The handoff palette is accepted as-is (per §1), but two roles (`primary`-as-link-text, `warning`/gold-as-text) have a real, measured AA gap in their most literal reading ("primary = links", "warning = informational text"). Rather than altering the handoff's hex values, the constraint is scoped to *where* each color is allowed to carry text, which resolves the gap without deviating from the authoritative tokens — the same technique the prior feature (`20260724-app-icon-theme`) used for its gold accent.

## 5. Dark theme — palette usage and WCAG AA verification

**Decision**: Use `reference/theme-tokens.json`'s `dark` block verbatim. The dark block has no `onPrimary` defined (only `primary: #3B8DF8`); the app needs one for text/icons on primary-filled surfaces (buttons, selected chips).

| Pair | Ratio | Verdict |
|---|---|---|
| `fg1` (#FAF8F5) on `bgApp`/`bgSurface` | 16.84:1 | AA pass |
| `fg2` (#B0A696) on `bgApp` | 7.43:1 | AA pass |
| `fg3` (#8A8073) on `bgApp` | 4.60:1 | AA pass (unlike light mode, dark `fg3` clears normal-text AA) |
| `danger` (#E07A6D) on `bgApp` | 6.10:1 | AA pass |
| `success` (#62BB91) on `bgApp` | 7.68:1 | AA pass |
| `gold` (#DFB04A) on `bgApp` | 8.88:1 | AA pass — dark gold is brighter/higher-contrast than light-mode gold, no text restriction needed in dark mode |
| Candidate `onPrimary` = `#FFFFFF` on `primary` (#3B8DF8) | 3.31:1 | Fails normal-text AA |
| Candidate `onPrimary` = `heroPanel` (#052555) on `primary` | 4.53:1 | Borderline pass |
| Candidate `onPrimary` = `bgApp` (#1A1714) on `primary` | 5.40:1 | AA pass, comfortable margin |

**Decision**: Use the palette's own `bgApp` (#1A1714) as `onPrimary` in the dark theme (dark near-black text/icons on the bright blue primary fill) rather than white — this reuses an already-authoritative token instead of inventing a new color, and clears AA with margin (5.40:1 vs. white's failing 3.31:1).

## 6. Semantic color role mapping (spec FR-008) and exposure mechanism

**Finding**: Flutter's `ColorScheme` has a fixed set of slots (`primary`, `secondary`, `tertiary`, `error`, `surface`, etc.) — it has no native `success`/`warning` slot. Only `danger` has a natural `ColorScheme` home (`error`).

**Decision**:
- `danger` → `ColorScheme.error` (light `#A42619` / dark `#E07A6D`), `onError` → `onError` (light `#FFFFFF`; dark **`#1A1714`, the reused `bgApp` token, not white** — white-on-`#E07A6D` measures 2.93:1, badly failing AA, while `#1A1714`-on-`#E07A6D` measures 6.10:1, the same "reuse `bgApp` as the dark on-color" fix already applied to `onPrimary` in §5). This is a real, verified finding, not a stylistic choice.
- `primary` → main actions/links/selected states (large-text/button/icon contexts per §4), stays on `ColorScheme.primary`/`onPrimary`.
- `success` and `warning` (gold) have no `ColorScheme` slot and MUST NOT be force-fit into `secondary`/`tertiary` (which would make their semantic meaning implicit/undocumented). **Decision**: expose both via a `ThemeExtension<AppSemanticColors>` (`lib/core/theme/app_semantic_colors.dart`), registered in `ThemeData.extensions` for both `AppTheme.light`/`AppTheme.dark`, consumed as `Theme.of(context).extension<AppSemanticColors>()!.success` / `.warning` (plus `.successSoft`/`.warningSoft`/`.dangerSoft`/`.primarySoft` background-tint variants already present in `theme-tokens.json`, needed for banner/chip fills). A `ThemeExtension` is the framework-supported mechanism for exactly this case (named colors with no built-in slot) and keeps `Theme.of(context)` as the single consumption path per constitution Principle III ("no screen may hardcode colors... bypass the theme").
- `success` → income/positive amounts; `warning`(gold) → informational/allocation banners (icon or filled-banner presentation, not small text, per §4). This mirrors `theme-tokens.json`'s own `meta`/README semantic notes verbatim.
- **On-color variants for filled banners**: `theme-tokens.json`'s `dark` block additionally defines `successFg` (`#8FD6B0`), `goldFg` (`#ECCB7E`), and `dangerFg` (`#F0B3A8`) — text/icon colors meant to sit on top of the corresponding `*Soft` tint or on `bgApp`/`bgSurface`, distinct from the base `success`/`warning`/`danger` values used for icons/large text directly on a neutral background. Verified: `successFg`/`goldFg`/`dangerFg` on dark `bgApp` measure 10.55:1/11.40:1/9.96:1 (all AA pass); on dark `bgSurface` measure 9.65:1/10.43:1/9.11:1 (all AA pass). These three fields belong on `AppSemanticColors` alongside `success`/`warning`/`successSoft`/`warningSoft`/`dangerSoft` (data-model.md's AppSemanticColors table) — light mode has no distinct token for them in `theme-tokens.json`, so `AppSemanticColors.light` sets `successFg`/`dangerFg` equal to `success`/`danger` (already AA-safe as light-mode text per §4) and `warningFg` equal to `warning` (inheriting its existing non-text-only restriction), so every field is defined in both `.light` and `.dark` instances.

**Alternatives considered**: Cramming `success`/`warning` into `ColorScheme.tertiary`/`ColorScheme.secondary` — rejected, because a screen author reading `Theme.of(context).colorScheme.tertiary` has no way to know it means "success green" without cross-referencing this doc; an explicitly named `AppSemanticColors.success` is self-documenting at the call site.

## 7. Icon library selection

**Decision**: Adopt **Lucide** via the `lucide_icons` pub.dev package (line icons, 2px stroke, round caps/joins), per `reference/icons-used.json`. `flutter pub add lucide_icons` as a runtime dependency. If `lucide_icons` proves incompatible with the project's Dart/Flutter SDK constraint (`^3.11.0`) at implementation time, `lucide_icons_flutter` is the documented fallback (same icon set, different API surface) named in the handoff itself.

**Migration scope**: every current `Icons.*` (Material) call site must be replaced with the Lucide equivalent. Known call sites from current codebase survey:
- `lib/core/router/app_router.dart` (bottom navigation icons — dashboard, receipt/mail, person, ~4 destinations ×2 states)
- `lib/features/envelopes/presentation/envelopes_screen.dart`
- `lib/features/envelopes/presentation/overview_screen.dart`
- `lib/features/expenses/presentation/spending_screen.dart`

No per-category icon picker exists yet in the codebase (no persisted per-category icon field found), so FR-013 (category icon picker) is new UI, not a migration of existing picker UI — it should be built directly against Lucide from the start, using at minimum the `iconsUsedPerCategory` set in `icons-used.json` (banknote, book-open, briefcase, car, heart, home, piggy-bank, popcorn, shield-check, shopping-bag, user, utensils, zap).

**Alternatives considered**: Keeping Material icons and only adding Lucide for new UI — rejected, directly contradicts spec FR-012/FR-013 ("no screen mixes two different icon libraries").

## 8. Touch target size — constitution vs. handoff

**Finding**: The design handoff (`theme-tokens.json` → `touchTargetMinPx: 44`, README §3) specifies a 44px minimum touch target ("Apple HIG 44pt minimum, gần với Material 48dp"). This project's constitution (Principle III, User Experience Consistency) mandates interactive elements meet **≥48×48dp**, which is stricter.

**Decision**: The constitution supersedes the handoff per its own Governance section ("This constitution supersedes all other project practices"). All interactive icon touch targets in this feature MUST be ≥48×48dp, not 44px. This is not a deviation requiring Complexity Tracking justification — it is simply following the stricter of two documented minimums, and does not conflict with the handoff's visual sizing guidance (icon glyph size within the tappable area is unaffected; only the tappable hit-area minimum changes).

**Action carried to spec**: FR-014's phrasing ("as specified in the design handoff") should be read as "meeting or exceeding" — implementation targets 48dp per constitution, and this note documents why 48 (not 44) is the enforced number.

## 9. Typography (Lexend / Crimson Pro) vs. offline-first constraint

**Finding**: The handoff specifies Google Fonts "Lexend" (UI/body) and "Crimson Pro" (large display, not currently used anywhere in this app's screens). Neither is currently a project dependency; no `google_fonts` package, no bundled font files.

**Decision**: This feature's spec (Assumptions) explicitly scopes typography as "supporting detail for planning, not a separate functional requirement" — the user's request was theme/icon/icon-library, not a font swap. **Typography changes are out of scope for this feature's implementation** (no FR requires it); this research note exists only to flag the tradeoff for whoever picks up a future typography feature: the constitution's offline-first principle (app MUST work fully offline, including cold start) means a runtime-fetched `google_fonts` call is disallowed unless its "download once, cache" behavior is proven safe for a true offline first-launch — bundling `.ttf` files under `assets/fonts/` (declared in `pubspec.yaml`) is the constitution-compliant approach if/when Lexend adoption is scheduled. No action taken in this feature.

## 10. Migration/removal scope (spec FR-015)

**Decision**: This is an in-place rebrand, not additive work. The following existing files/values are superseded and MUST be deleted or overwritten, not left alongside the new assets:
- `assets/icon/appicon.svg`, `appicon.png`, `appicon_background.{svg,png}`, `appicon_foreground.{svg,png}` (old green icon) → replaced by the new lotus-derived equivalents at the same paths.
- `lib/core/theme/app_colors.dart` (iconGreen/iconLightGreen/iconCream/iconGold) → replaced with tokens sourced from `theme-tokens.json`.
- `lib/core/theme/app_theme.dart` (`AppTheme.light`/`AppTheme.dark`, currently green/gold-only `ColorScheme`s) → replaced with the new palette's light/dark `ColorScheme`s per §4/§5/§6.
- All `Icons.*` call sites listed in §7 → replaced with `LucideIcons.*` equivalents.
- Android/iOS generated icon and splash assets (`android/app/src/main/res/mipmap-*/`, `drawable-*/ic_launcher_*.png`, `mipmap-anydpi-v26/ic_launcher.xml`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `ios/Runner/Assets.xcassets/LaunchBackground.imageset`/`LaunchImage.imageset`) → regenerated by re-running `flutter pub run flutter_launcher_icons` and `flutter pub run flutter_native_splash:create` against the new source PNGs; the tools overwrite these paths in place, satisfying FR-015 without manual per-file deletion, but MUST be verified (git diff / visual check) after regeneration to confirm no stale old-icon file remains where the tool doesn't overwrite (e.g. if a resolution bucket differs between old and new config).

**Rationale**: Prevents FR-015 (no leftover superseded assets) from being silently missed by treating this as new-file addition instead of replacement — the same file paths are reused wherever the tooling supports it, and explicit deletion is called out where it does not.
