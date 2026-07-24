# Feature Specification: App Icon & Theme

**Feature Branch**: `20260724-app-icon-theme`

**Created**: 2026-07-24

**Status**: Draft

**Input**: User description: "tôi có file icon ở "E:\Study\finance\exports" tôi muốn icon này thành app icon khi cài đặt trong điện thoại và build bộ theme sáng, tối phù hợp với icon này. Icon này cũng thay trong flash screen luôn."

## Clarifications

### Session 2026-07-24

- Q: Dark theme's background color — should it be a neutral dark gray/black, or derived from the icon's green? → A: Darkened/desaturated derivative of the icon's green (#2E8B5E), not a neutral gray, so the dark theme still reads as brand-colored rather than generic.
- Q: The source icon is a single flat layer (green rounded background + network motif + gold center combined). Android adaptive icons require separate foreground/background layers for launcher masking. How should this be handled? → A: Split into two derived layers — a flat green background layer and a foreground layer (network motif + gold center) scaled to fit Android's standard safe zone, so the icon isn't clipped under any launcher mask shape.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - App Icon on Installed App (Priority: P1)

As a user installing the app on my phone, I want to see the provided brand icon (green rounded-square with a network/graph motif) as the app's launcher icon, so the app is instantly recognizable on my home screen and app drawer.

**Why this priority**: The launcher icon is the first visual touchpoint for every user and is required for any release build; without it the app cannot be meaningfully published or tested on a device.

**Independent Test**: Build and install the app on an Android and an iOS device (or emulator/simulator); confirm the home screen, app drawer, and app switcher all show the new icon instead of the default placeholder icon.

**Acceptance Scenarios**:

1. **Given** the app is built for Android, **When** it is installed on a device, **Then** the home screen and app drawer show the provided icon at the correct resolution with no pixelation or default placeholder artwork.
2. **Given** the app is built for iOS, **When** it is installed on a device, **Then** the home screen shows the provided icon with iOS's standard rounded-corner mask applied automatically (no manual corner-rounding baked into the asset).
3. **Given** the app is installed, **When** the user views the recent apps/app switcher screen, **Then** the same icon is shown consistently.

---

### User Story 2 - Light & Dark Theme Matching the Icon (Priority: P2)

As a user of the app, I want the app's light and dark themes to use colors that visually match the brand icon (green primary, gold accent), so the in-app experience feels cohesive with the brand identity regardless of my device's display mode.

**Why this priority**: Theming affects every screen the user interacts with after launch; it is high-value but depends on the icon/brand colors being finalized first (P1), and the app is still usable without it if a temporary default theme exists.

**Independent Test**: Switch the device system setting between light and dark mode with the app open (or app-level theme toggle, if provided) and confirm the app's color scheme updates to a palette derived from the icon's green/gold/cream colors in both modes, with no unreadable text or broken contrast.

**Acceptance Scenarios**:

1. **Given** the device is set to light mode, **When** the app is opened, **Then** the app displays a light theme using the icon's green as the primary brand color and gold as the accent color, with readable text contrast throughout.
2. **Given** the device is set to dark mode, **When** the app is opened, **Then** the app displays a dark theme using a dark background with the icon's green and gold as accent colors, with readable text contrast throughout.
3. **Given** the app is open, **When** the user switches the device's system theme setting, **Then** the app's theme updates to match (live or on next app resume, per platform norm) without requiring a reinstall.
4. **Given** either theme is active, **When** any screen is displayed, **Then** all interactive elements (buttons, links, active states) meet standard accessibility contrast ratios against their background.

---

### User Story 3 - Branded Splash Screen (Priority: P3)

As a user launching the app, I want to see the same brand icon on the splash/launch screen while the app loads, so the loading experience feels consistent with the app icon and overall brand.

**Why this priority**: The splash screen is a short-lived, cosmetic touchpoint; it enhances polish and brand consistency but the app functions correctly without a custom splash screen, making it lower priority than the installable icon and core theming.

**Independent Test**: Launch (cold start) the app on a device and observe the splash screen; confirm it displays the same brand icon, centered, on a background consistent with the app's light/dark theme, before transitioning to the main app screen.

**Acceptance Scenarios**:

1. **Given** the app is cold-started, **When** the splash screen appears, **Then** it displays the same brand icon used for the app icon, not a different or default image.
2. **Given** the device is in light mode, **When** the splash screen appears, **Then** its background is a color consistent with the light theme.
3. **Given** the device is in dark mode, **When** the splash screen appears, **Then** its background is a color consistent with the dark theme.
4. **Given** the splash screen has displayed, **When** the app finishes initializing, **Then** it transitions to the main app screen without a jarring flash of unstyled content or mismatched background color.

---

### Edge Cases

- What happens on devices/OS versions with adaptive icon requirements (e.g., Android adaptive icons with separate foreground/background layers, or masking shapes like circle/squircle/rounded-square applied by the launcher)? Resolved: the source icon is decomposed into a flat green background layer and a foreground layer (network motif + gold center) scaled to the standard safe zone, so it remains legible and correctly framed under all standard mask shapes (see FR-002a).
- What happens if the source icon file is a vector format not natively supported by a target platform's packaging tools? It must be converted to the resolution/format set each platform requires without visible quality loss.
- How does the splash screen behave on very small or very large screens (phones vs. tablets) — does the icon stay proportionally centered without stretching or distortion?
- What happens if a user has an OS-level "high contrast" or accessibility color mode enabled — do the derived theme colors still meet contrast requirements?
- How does the app handle a device OS version that does not support automatic light/dark switching (falls back to a single default theme, defined as the light theme)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST use the provided icon artwork (green rounded-square background, network/graph motif, gold center) as its installed application icon on every supported platform.
- **FR-002**: The app icon MUST be generated at all resolutions/densities required by each target platform's packaging requirements, derived from the single source icon file.
- **FR-002a**: For Android adaptive icons, the source icon MUST be decomposed into a flat background layer (icon's green) and a foreground layer (network motif + gold center) scaled to fit within Android's standard safe zone, so no part of the icon is clipped under any launcher mask shape (circle, squircle, rounded-square, etc.).
- **FR-003**: The app MUST provide a light theme whose primary color is derived from the icon's green background color and whose accent color is derived from the icon's gold center color.
- **FR-004**: The app MUST provide a dark theme whose background is a darkened/desaturated derivative of the icon's green (not a neutral gray/black), with the icon's green and gold used as brand/accent colors, distinct from the light theme's color values.
- **FR-005**: The app MUST automatically switch between the light and dark theme based on the device's system-level theme setting.
- **FR-006**: All text and interactive elements in both themes MUST meet standard accessibility contrast guidelines (WCAG AA or equivalent) against their respective backgrounds.
- **FR-007**: The app MUST display the same brand icon artwork on its splash/launch screen shown during app startup.
- **FR-008**: The splash screen background MUST match the active theme (light or dark) determined by the device's system setting at launch time.
- **FR-009**: The app icon artwork MUST NOT include platform-specific corner-rounding baked into the asset where the target platform applies its own icon mask (e.g., iOS), to avoid double-rounding or visual artifacts.
- **FR-010**: The generated icon and splash assets MUST render without pixelation, blurring, or distortion across the range of supported device screen densities and sizes.

### Key Entities

- **App Icon Asset**: The single source icon image and its set of generated platform-specific/resolution-specific outputs used for the installed app icon, including the Android adaptive icon's separate background layer (flat green) and foreground layer (network motif + gold center, scaled to the safe zone).
- **Theme Palette**: A named set of colors (primary, accent, background, surface, text, etc.) derived from the app icon's colors, with one variant for light mode and one for dark mode.
- **Splash Screen Asset**: The icon image and background color configuration shown during app startup, tied to the active theme.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of supported target platforms (as defined by the current project setup) display the new brand icon, with no default/placeholder icon visible after installation.
- **SC-002**: Users can visually distinguish the app's light and dark themes as clearly derived from the same brand icon (same green/gold color family) in a side-by-side comparison.
- **SC-003**: All text/background color combinations in both themes pass a standard accessibility contrast check (WCAG AA, 4.5:1 for normal text) with zero failing combinations.
- **SC-004**: The splash screen displays the brand icon and theme-matched background on 100% of cold app launches, with the transition to the main screen completing without visible flicker or mismatched backgrounds.
- **SC-005**: Icon and splash assets display at full visual sharpness (no pixelation) on the highest-density screen size supported by the project.

## Assumptions

- The source icon file (`E:\Study\finance\exports\appicon.svg`) is the final, approved brand artwork and its green/gold/cream color values are the intended brand colors to derive the theme from.
- The project targets mobile platforms consistent with the existing Flutter app scaffold (Android and iOS); other platforms (web, desktop) are out of scope for this feature unless already part of the existing app build targets.
- "Theme" refers to the app's in-app color scheme (Material/Cupertino-style theming), not a full visual redesign of layouts or components.
- Automatic light/dark switching follows the device's system-level setting; no in-app manual theme override toggle is required unless already present in the app.
- Standard accessibility contrast guidance (WCAG AA) is an acceptable bar for contrast validation since no specific compliance standard was provided.
- The existing default app icon and splash screen (from the Flutter scaffold) are placeholders to be fully replaced, not preserved as an alternate option.
