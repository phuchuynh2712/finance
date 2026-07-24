# Quickstart: App Icon & Theme

How to verify this feature once implemented, mapped to the spec's acceptance scenarios.

## Prerequisites

- Canonical SVG sources exist under `assets/icon/` (`appicon.svg`, `appicon_background.svg`, `appicon_foreground.svg`) plus their rasterized PNG counterparts (`appicon.png`, `appicon_background.png`, `appicon_foreground.png`) — the PNGs are generated build artifacts, required because `flutter_launcher_icons`/`flutter_native_splash` accept PNG input only (see `research.md` §4–§5)
- `flutter_launcher_icons` and `flutter_native_splash` added to `pubspec.yaml` dev_dependencies, each with a config block pointing at the PNG files above and the hex values from `data-model.md`
- `lib/core/theme/app_theme.dart` defines `AppTheme.light` / `AppTheme.dark`

## Generate platform assets

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Confirm generated files exist:

- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (adaptive icon descriptor)
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (all 5 densities)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (regenerated, non-placeholder)
- `android/app/src/main/res/drawable-v21/launch_background.xml` + `values-night/styles.xml` updated with dark background color
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` regenerated

## Verify: App Icon (User Story 1)

1. `flutter build apk --debug` (or `flutter run` on an Android device/emulator) → install → check home screen and app drawer show the brand icon, not the Flutter default.
2. Long-press the icon / view app switcher → same icon shown consistently.
3. On an Android emulator, test under **at least two** launcher icon mask shapes (e.g. circle and squircle via the Pixel launcher's icon shape setting) → confirm the network motif is fully visible under each, not clipped at the edges. A squircle can clip corners a circle wouldn't, so circular alone is not sufficient evidence (validates the 66×66dp safe-zone scaling from `research.md` §4 against "all standard mask shapes" per FR-002a).
4. `flutter build ios --debug` (or `flutter run` on iOS simulator) → install → confirm the home screen icon shows iOS's standard rounded-corner mask applied automatically (the source asset itself is NOT pre-rounded — FR-009).

## Verify: Light & Dark Theme (User Story 2)

1. Run the app with the OS in light mode → confirm `primary` color reads as the icon's green family, `secondary`/accent reads as gold, background is the cream tone.
2. Switch the OS to dark mode (system settings, or emulator quick-settings toggle) without restarting the app → confirm the app's theme updates to the dark palette (per platform norm — live or on next resume) without needing a reinstall.
3. Visually confirm the dark theme's background is a **dark green-tinted** tone (`#0C2318`), not neutral gray/black — this is the clarified behavior, distinct from typical Material dark-surface defaults.
4. Run `flutter test test/unit/core/theme/app_theme_test.dart` → confirms all `ColorScheme` role pairs meet WCAG AA programmatically (this is the automated proxy for "meets accessibility contrast ratios" across the whole app, since Flutter's test harness cannot screenshot-diff every screen).

## Verify: Splash Screen (User Story 3)

1. Force-stop the app, then cold-start it (not a hot reload/resume) on Android in light mode → splash screen shows the brand icon centered on a cream (`#EBF5F0`) background, then transitions to the main screen with no visible flicker or background-color jump.
2. Repeat in dark mode → splash background is dark green-tinted (`#0C2318`), matching the dark theme's `surface`.
3. Repeat on a tablet-sized emulator (if available) → icon remains centered and proportional, not stretched.

## Manual accessibility spot-check

Using a contrast-checker (or the automated test in step 4 above) on the final rendered app:

- White text on a `primary`-colored button (light theme) ≥ 4.5:1
- Body text (`onSurface`) on the app background (`surface`) ≥ 4.5:1, both themes
- Gold (`secondary`) is used only for icons/large UI elements/accents in the light theme — confirm no light-theme screen uses gold for small body text (per the constraint documented in `research.md` §2)
