# Feature Specification: Rebrand Theme, App Icon & Icon Library

**Feature Branch**: `20260904-030816-theme-icon-splash`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Cần điều chỉnh theme và app icon, cũng như icon ở splash screen, hỗ trợ light và dark mode, cũng có sử dụng icons lib để dùng nên cần kiểm tra lại để sử dụng cho đồng nhất. Tất cả những điểm cần thiết đã được lưu trong design handoff package. Ưu tiên sử dụng SVG là tốt nhất, khi không được thì dùng các hình ảnh type khác để sử dụng."

**Supersedes**: `specs/20260724-app-icon-theme/` (previously shipped a green/network-motif icon and a green/gold-only theme). This feature replaces that brand identity end-to-end with the new "Khai Tâm" design handoff (lotus icon; blue/gold/red palette) and additionally standardizes the app's icon set, which the prior feature did not address.

**Reference assets**: Design handoff files copied for planning under `reference/` in this feature directory (`theme-tokens.json`, `icons-used.json`, `README.md`, `app-icon/` source SVG + exported PNGs).

## Clarifications

### Session 2026-09-04

- Q: The design handoff shows a manual light/dark toggle on a Profile screen, but the app has no Profile/Settings screen yet. Should this feature build one to host the toggle? → A: Defer the manual toggle entirely — this feature ships system-driven theme switching only. The toggle will be tested and built when the Profile screen is implemented in a future feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - New Brand App Icon Everywhere the App Is Seen (Priority: P1)

As a user who installs or already has the app installed, I want the home screen, app drawer, app switcher, and splash screen to show the new brand icon (lotus mark) instead of the previous one, so the app I open matches the identity shown in the store listing and marketing.

**Why this priority**: The icon is the most visible, most frequently seen brand asset and is required before any release; an inconsistent or stale icon undermines trust and store approval.

**Independent Test**: Build and install the app on an Android and an iOS device (or emulator/simulator); confirm home screen, app drawer, recents/app-switcher, and the cold-start splash screen all display the new lotus icon at full resolution with no pixelation, and that no trace of the previous green/network icon remains anywhere in the built app.

**Acceptance Scenarios**:

1. **Given** the app is built for Android, **When** it is installed, **Then** the home screen and app drawer show the new icon at the correct resolution, correctly filling the adaptive-icon safe zone under any launcher mask shape (circle, squircle, rounded-square).
2. **Given** the app is built for iOS, **When** it is installed, **Then** the home screen shows the new icon with iOS's own rounded-corner mask applied automatically (the source art contains no baked-in corner rounding).
3. **Given** the app is cold-started on either platform, **When** the splash screen appears, **Then** it shows the same new icon, centered, on a background that matches the active light/dark theme, before transitioning cleanly to the main app screen.
4. **Given** an existing install of the app is upgraded, **When** the update completes, **Then** the previous icon is fully replaced — no stale icon appears in any launcher cache after a normal reinstall/rebuild.

---

### User Story 2 - Light & Dark Themes Matching the New Brand Palette (Priority: P1)

As a user, I want the app's light and dark color themes to reflect the new brand palette (blue primary, gold accent, red for danger/destructive actions) instead of the old green/gold palette, so every screen looks and feels consistent with the new brand identity in both display modes.

**Why this priority**: Theming touches every screen and is the second-most visible brand element after the icon; shipping the new icon without the matching palette would look broken/mismatched, so both must land together as the P1 core of this feature.

**Independent Test**: Toggle the device's system theme setting between light and dark mode and visually confirm every screen uses the new palette's semantic colors — blue for primary actions/links, gold for informational accents, green for success/income, red used sparingly for danger/destructive/negative-balance — with no leftover green-primary or old gold-only styling, and no unreadable text.

**Acceptance Scenarios**:

1. **Given** light mode is active, **When** any screen is displayed, **Then** primary actions, links, selected tabs, and positive balances use the new palette's blue primary color, and backgrounds/surfaces/text use the new palette's light-mode neutral values.
2. **Given** dark mode is active, **When** any screen is displayed, **Then** the same semantic roles (primary, success, danger, warning, neutrals) are rendered using the new palette's dedicated dark-mode values (not simply a dimmed light palette).
3. **Given** either theme is active, **When** any interactive element (button, input, chip, tab) is displayed, **Then** it meets standard accessibility contrast guidelines against its background.
4. **Given** either theme is active, **When** a negative/destructive state is shown (negative balance, delete action, error), **Then** it uses the new palette's danger/red color, used only for that purpose and not decoratively.
5. **Given** the device's system theme setting changes while the app is open, **When** the change occurs, **Then** the app's theme updates to match, consistent with platform norms (live or on next resume).

---

### User Story 3 - One Consistent Icon Library Across the App (Priority: P2)

As a user navigating the app, I want every in-app icon (navigation, buttons, category pickers, status indicators) to come from a single, consistent icon style, so the interface feels coherent rather than mixing different visual languages.

**Why this priority**: Icon consistency is a polish/coherence concern that affects perceived quality but does not block core functionality; it depends on the new palette (P1) being in place first so icon colors read correctly, and the app remains usable with mismatched icons in the interim.

**Independent Test**: Walk through every screen currently reachable in the app (navigation bar, envelopes, spending, overview, category pickers, status/alert indicators) and confirm every icon glyph belongs to the single chosen icon set at the specified stroke/weight style, with no screen mixing two different icon styles.

**Acceptance Scenarios**:

1. **Given** any screen in the app, **When** it renders icons, **Then** every icon belongs to the single designated icon library and visual style (consistent stroke width and weight) — no screen mixes icons from two different libraries or styles.
2. **Given** the navigation bar, buttons, and status indicators used throughout the app today, **When** they are inventoried, **Then** each has an equivalent available in the designated icon library and is updated to use it.
3. **Given** a user is creating or editing a custom spending category, **When** they open the icon picker, **Then** the available choices are drawn from the same designated icon library (at minimum, the category-relevant icon set identified in the design handoff).
4. **Given** any icon is displayed, **When** measured, **Then** it meets the minimum tappable/touch target size for interactive icons and the minimum legible size for decorative/status icons, per the design handoff's sizing guidance.

---

### Edge Cases

- What happens to icon caches on devices/launchers that aggressively cache the old app icon after an in-place update? Expected: a normal app update/reinstall must show the new icon; this is bounded by platform launcher behavior outside the app's control.
- What happens on an Android adaptive-icon safe zone when the new lotus artwork's foreground layer is not pre-split from its background? It must be decomposed into background/foreground layers sized to the safe zone so no part is clipped under any launcher mask shape.
- What happens if the source icon or in-app icon glyphs are only available as SVG and a target platform tool requires a raster format? The SVG remains the source of truth; a raster (e.g. PNG) is derived from it as a build step, not requested from the user again.
- How does the splash screen behave across a range of screen sizes (small phones vs. tablets) — does the icon stay proportionally centered without stretching?
- What happens if a device OS version does not support automatic light/dark switching? It falls back to a single default theme (light).
- What happens to any leftover generated assets (icons, splash images) from the previous green/network-icon brand after this feature ships? They must be removed/replaced, not left alongside the new assets, to avoid confusion or accidental reuse.
- Manual in-app theme toggling is out of scope for this feature (see Clarifications); the app follows the device's system theme setting exclusively until a future feature adds a Profile/Settings screen with a manual override.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST use the new brand icon artwork (lotus mark) as its installed application icon on every supported platform, replacing the previously shipped icon entirely.
- **FR-002**: The app icon MUST be generated at all resolutions/densities required by each target platform's packaging requirements, derived from the single SVG source.
- **FR-003**: For Android adaptive icons, the source icon MUST be decomposed into a background layer and a foreground layer scaled to fit Android's standard safe zone, so no part is clipped under any launcher mask shape.
- **FR-004**: The app icon artwork MUST NOT include platform-specific corner-rounding baked into the asset where the target platform applies its own icon mask (e.g., iOS).
- **FR-005**: The app MUST display the new brand icon on its splash/launch screen shown during app startup, replacing the previous splash icon.
- **FR-006**: The splash screen background MUST match the active theme (light or dark) determined at launch time.
- **FR-007**: The app MUST provide a light theme and a dark theme, each using the new brand palette's dedicated color values for that mode (not one mode derived by simply dimming the other).
- **FR-008**: The app MUST use the palette's semantic color roles consistently: primary (blue) for main actions/links/selected states, success (green) for income/positive amounts, danger (red) for negative amounts/destructive actions/errors, warning (gold) for informational/allocation banners — matching the semantic usage documented in the design handoff.
- **FR-009**: The app MUST switch between light and dark theme automatically based on the device's system-level theme setting. (A manual in-app toggle is explicitly out of scope for this feature — see Clarifications — and is deferred to a future feature that introduces a Profile/Settings screen.)
- **FR-010**: All text and interactive elements in both themes MUST meet standard accessibility contrast guidelines (WCAG AA or equivalent) against their respective backgrounds.
- **FR-011**: The app MUST adopt a single icon library for all in-app iconography (navigation, buttons, category pickers, status/alert indicators) as specified in the design handoff.
- **FR-012**: Every icon currently rendered in the app MUST be replaced with the equivalent glyph from the newly adopted icon library; no screen may mix icons from two different icon libraries or visual styles after this feature ships.
- **FR-013**: The category icon picker MUST offer choices from the newly adopted icon library, covering at minimum the per-category icon set identified in the design handoff.
- **FR-014**: All interactive icons MUST meet the minimum tappable touch target size, and all icons MUST meet the minimum legible size, as specified in the design handoff.
- **FR-015**: Generated icon, splash, and theme assets belonging to the previous brand identity (the green/network-motif icon and green/gold-only palette) MUST be removed from the codebase and build outputs, not left alongside the new assets.
- **FR-016**: All new visual source assets MUST be sourced as SVG where available; a non-SVG format MUST be used only where a target platform or packaging tool does not accept SVG input, in which case the non-SVG asset is derived from the SVG rather than authored separately.

### Key Entities

- **Brand Icon Asset**: The new lotus-mark SVG source and its generated platform-specific outputs (app icon at all required resolutions, Android adaptive-icon background/foreground layers, splash-screen image).
- **Theme Palette**: The new brand's named set of semantic colors (primary, success, danger, warning, neutrals/backgrounds/borders/text) with one variant for light mode and one for dark mode, applied automatically based on the device's system theme setting.
- **Icon Library Set**: The single designated icon set used across the app's UI, and the mapping from every in-app icon usage (navigation, actions, categories, status) to its glyph in that set.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of app-icon and splash-screen touchpoints (home screen, app drawer, app switcher, cold-start splash) show the new brand icon with no pixelation across all supported device densities.
- **SC-002**: 100% of screens in the app render using only the new brand palette's light/dark color values — zero occurrences of the previous green-primary palette remain.
- **SC-003**: 100% of in-app icons belong to the single designated icon library; zero screens mix two different icon styles.
- **SC-004**: All text/interactive-element color combinations across both themes pass a standard accessibility contrast check (WCAG AA or equivalent) — zero failing combinations.
- **SC-005**: A user's device system theme setting (light or dark) is correctly reflected in the app every time it is opened, in 100% of launch scenarios.
- **SC-006**: Switching the device's system theme setting between light and dark mode updates the entire visible screen with no unstyled flash or mismatched background.

## Assumptions

- The design handoff package (palette, typography, spacing, icon list, app-icon source) is authoritative and complete enough to proceed without further design input; no additional design clarification is required beyond what is documented there.
- "Icons lib" refers to the single icon library named in the design handoff (line-style icon set), to be used for all in-app iconography going forward, replacing the current default platform icon glyphs.
- The manual theme toggle shown in the handoff's Profile-screen mockup is explicitly out of scope for this feature (see Clarifications); it will be implemented together with the Profile/Settings screen in a future feature.
- Font/typography and spacing/motion tokens included in the design handoff are treated as supporting detail for planning, not separately called out as functional requirements here, since the user's request focused on theme, app icon, splash icon, and icon-library consistency.
- Removal of superseded brand assets (FR-015) applies to generated build artifacts and source asset files within this project; it does not require any action on already-published app store listings or already-installed devices beyond a normal app update.
