# Quickstart: Rebrand Theme, App Icon & Icon Library

How to verify this feature once implemented, mapped to the spec's acceptance scenarios.

## Prerequisites

- Canonical SVG sources under `assets/icon/` replaced (`appicon.svg`, `appicon_background.svg`, `appicon_foreground.svg` — the new lotus mark, derived from `reference/app-icon/app-icon-khai-tam.svg`), plus their rasterized PNG counterparts regenerated via `cairosvg` (research.md §3)
- `lib/core/theme/app_colors.dart` and `lib/core/theme/app_theme.dart` replaced with the new palette (`AppTheme.light` / `AppTheme.dark`) per `data-model.md`
- `lucide_icons` added to `pubspec.yaml` dependencies; every `Icons.*` call site listed in research.md §7 replaced with `LucideIcons.*`
- `flutter_launcher_icons` / `flutter_native_splash` config blocks in `pubspec.yaml` re-pointed at the new PNGs and new theme colors

## Generate platform assets

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Confirm generated files exist and are updated (not stale from the previous green icon):

- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (adaptive icon descriptor)
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (all 5 densities)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (regenerated, shows the lotus mark)
- `android/app/src/main/res/drawable-v21/launch_background.xml` + `values-night/styles.xml` updated with new background colors
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` regenerated

## Verify: App Icon (User Story 1)

1. `flutter build apk --debug` (or `flutter run` on an Android device/emulator) → install → check home screen and app drawer show the lotus icon, not the previous green/network icon.
2. View the app switcher → same new icon shown consistently.
3. On an Android emulator, test under **at least two** launcher icon mask shapes (e.g. circle and squircle via the Pixel launcher's icon shape setting) → confirm the lotus motif is fully visible under each, not clipped at the edges (validates the 66×66dp safe-zone scaling from research.md §2 against "all standard mask shapes" per FR-003).
4. `flutter build ios --debug` (or `flutter run` on iOS simulator) → install → confirm the home screen icon shows iOS's standard rounded-corner mask applied automatically (the source asset itself is NOT pre-rounded — FR-004).
5. Uninstall and reinstall the app (simulating an upgrade) → confirm no stale old-icon artifact appears anywhere (FR-015).

## Verify: Light & Dark Theme (User Story 2)

1. Run the app with the OS in light mode → confirm `primary` reads as blue, `warning`/gold accents appear only in banners/icons/large text (not small body text), `success` green and `danger` red appear only in their documented semantic contexts.
2. Switch the OS to dark mode (system settings, or emulator quick-settings toggle) without restarting the app → confirm the app's theme updates to the dark palette (per platform norm — live or on next resume) without needing a reinstall (FR-009).
3. Visually confirm the dark theme's background/surfaces use the palette's own dark tokens (`#1A1714`/`#241F1A`), not a simple dimmed version of the light palette.
4. Trigger a negative balance or a delete-confirmation dialog in both themes → confirm `danger`/red is used, and confirm no other screen uses red decoratively.
5. Run `flutter test test/unit/core/theme/app_theme_test.dart` → confirms all `ColorScheme` role/usage-context pairs meet WCAG AA programmatically per data-model.md's validation rule.

## Verify: Splash Screen (part of User Story 1)

1. Force-stop the app, then cold-start it (not a hot reload/resume) on Android in light mode → splash screen shows the lotus icon centered on the light `bgApp` (`#FAF8F5`) background, then transitions to the main screen with no visible flicker or background-color jump.
2. Repeat in dark mode → splash background is `#1A1714`, matching the dark theme's `bgApp`.
3. Repeat on a tablet-sized emulator (if available) → icon remains centered and proportional, not stretched.

## Verify: Consistent Icon Library (User Story 3)

1. Repository-wide search for `Icons\.` (Material) under `lib/` → zero matches (per data-model.md's Icon Library Set validation rule).
2. Walk every reachable screen (bottom navigation, envelopes, spending, overview) → every icon glyph is a `LucideIcons.*` constant, consistent 2px-stroke line style, no mixed styles on any single screen.
3. Open the category create/edit icon picker → confirm the offered choices are drawn from Lucide and cover at least the `iconsUsedPerCategory` set from `reference/icons-used.json`.
4. Measure a sample of interactive icons (nav bar item, a button icon) with the Flutter Inspector or DevTools layout bounds → confirm tappable hit-area ≥48×48dp (constitution-driven, research.md §8 — stricter than the handoff's 44px).

## Manual accessibility spot-check

Using a contrast-checker (or the automated test above) on the final rendered app:

- White text on a `primary`-colored button (light theme) ≥ 4.5:1
- Body text (`fg1`) on the app background (`bgApp`) ≥ 4.5:1, both themes
- Gold (`warning`) text is used only for large text/banners/icons in the light theme — confirm no light-theme screen uses gold for small body text (research.md §4)
- Dark theme's `onPrimary` (reused `bgApp` token, not white) is legible on primary-filled buttons (research.md §5)
