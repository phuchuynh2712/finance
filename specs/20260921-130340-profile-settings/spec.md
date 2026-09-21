# Feature Specification: Profile Screen with Theme and Language Settings

**Feature Branch**: `20260921-130340-profile-settings`

**Created**: 2026-09-21

**Status**: Draft

**Input**: User description: "Trao đổi bằng tiếng việt. viết spec, plan,... code bằng tiếng anh. Đọc tất cả nội dung trong folder \"E:\Study\design\ho-so-package\". Lưu giữ những cái liên quan để làm reference về lâu dài. Tôi muốn làm trang hồ sơ để có thể điều chỉnh languages và các settings"

## Clarifications

### Session 2026-09-21

- Q: The current Profile screen (`account_screen.dart`) has an avatar URL text field, a change-password flow, and a biometric-login toggle — none of which appear in the reference mockup. How should these be handled? → A: Drop them entirely; the Profile screen matches the mockup exactly. Any future need for password change or biometric settings is a separate feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switch between light and dark appearance (Priority: P1)

A signed-in user opens the Profile tab and wants the app to look the way they prefer — bright during the day, dark at night. They tap a two-option control to switch the whole app's appearance instantly, and the choice sticks the next time they open the app.

**Why this priority**: This is the single control explicitly designed in the reference mockup and the most frequently used personalization setting. It delivers a complete, demonstrable unit of value on its own — the app currently ignores user preference and always follows the OS setting (`ThemeMode.system`, `lib/main.dart:40`), so this story is the first real personalization capability the app gains.

**Independent Test**: On the Profile screen, tap the inactive option of the "Giao diện" (Appearance) toggle. Confirm every currently visible screen (the Profile screen itself, plus at least one other tab) immediately re-renders with the new color scheme. Close and reopen the app; confirm the chosen appearance is still active.

**Acceptance Scenarios**:

1. **Given** the app is currently showing the light appearance, **When** the user taps "Tối" (Dark) in the Appearance toggle, **Then** the entire app immediately switches to the dark color scheme and the toggle shows "Tối" as the active option.
2. **Given** the user has previously chosen "Tối" (Dark), **When** they fully close and relaunch the app, **Then** the app opens directly in the dark appearance, regardless of the device's own system-wide light/dark setting.
3. **Given** the app has never had an explicit choice made, **When** the user opens it for the first time, **Then** the app follows the device's system appearance setting (current default behavior is preserved until the user makes an explicit choice).

---

### User Story 2 - Switch the app's display language (Priority: P2)

A user wants to use the app in English instead of Vietnamese (or vice versa). They open Profile, tap a "Ngôn ngữ" (Language) row, pick their language from the two available options, and every screen in the app immediately shows text in that language.

**Why this priority**: The app already ships complete Vietnamese and English translations (`app_vi.arb`/`app_en.arb`) but currently hard-codes the display language to Vietnamese (`lib/main.dart:30`), so no user can access the English translations at all today. This is high-value but ranked after appearance because it is not present in the reference mockup and requires slightly more design decision-making (addressed below).

**Independent Test**: On the Profile screen, open the "Ngôn ngữ" row, select the language that is not currently active, and confirm every piece of translated text on screen (including the Profile screen's own labels) switches immediately. Relaunch the app and confirm the chosen language persists.

**Acceptance Scenarios**:

1. **Given** the app is currently displaying Vietnamese text, **When** the user opens the "Ngôn ngữ" row and selects "English", **Then** all screens immediately display English text, and the row now shows "English" as the current selection.
2. **Given** the user has previously chosen English, **When** they fully close and relaunch the app, **Then** the app opens directly in English.
3. **Given** the app has never had an explicit language choice made, **When** the user opens it for the first time, **Then** the app defaults to Vietnamese (preserving today's behavior until the user makes an explicit choice).

---

### User Story 3 - View account identity and access other settings (Priority: P3)

A signed-in user opens Profile to confirm which account they're using (name, email) and see the entry points for Notifications, Security, and Help, plus a way to sign out.

**Why this priority**: This is mostly presentational and reuses data/behavior that already exists elsewhere in the app (current user identity, sign-out). It rounds out the screen to match the reference design but does not block the value delivered by Stories 1 and 2.

**Independent Test**: Open the Profile screen while signed in. Confirm the signed-in user's name and email are visible, the avatar shows a placeholder built from the user's initial, and the "Đăng xuất" (Sign out) action successfully signs the user out and returns them to the sign-in flow. Confirm the "Thông báo", "Bảo mật", and "Trợ giúp" rows are present and tappable.

**Acceptance Scenarios**:

1. **Given** a user is signed in with a display name and email, **When** they open the Profile screen, **Then** their name, email, and an avatar (initial-letter placeholder, or their photo if one is set) are shown at the top of the screen.
2. **Given** the user is on the Profile screen, **When** they tap "Đăng xuất" (Sign out), **Then** they are signed out and returned to the sign-in screen.
3. **Given** the user is on the Profile screen, **When** they tap "Thông báo", "Bảo mật", or "Trợ giúp", **Then** the app navigates to that section's placeholder screen (each section's real content is out of scope for this feature — see Out of Scope).

---

### Edge Cases

- What happens if the user rapidly taps both options of the Appearance toggle in succession? The final tap's choice MUST be the one that is applied and persisted; no visual flicker or crash should result.
- What happens if the persisted appearance or language preference is corrupted or unreadable (e.g., storage error) on launch? The app MUST fall back to the system default appearance and to Vietnamese, rather than failing to launch.
- What happens if the user signs out and a different user signs in on the same device? The previously chosen appearance and language are device-level preferences, not tied to a specific account, and MUST persist across sign-out/sign-in on the same device (see Assumptions).
- What happens if the signed-in user has no display name set (only an email)? The avatar initial and name display MUST fall back to deriving an initial/name from the email's local part.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Profile screen MUST display an "Appearance" ("Giao diện") control with exactly two mutually exclusive options — Light ("Sáng") and Dark ("Tối") — reflecting which one is currently active.
- **FR-002**: Selecting an Appearance option MUST immediately re-render the entire app (not just the Profile screen) in the corresponding light or dark color scheme.
- **FR-003**: The selected Appearance choice MUST persist across app restarts.
- **FR-004**: When no explicit Appearance choice has ever been made, the app MUST follow the device's system-level light/dark setting (preserving current behavior).
- **FR-005**: The Profile screen MUST display a "Language" ("Ngôn ngữ") row showing the currently active language, that opens a selector with exactly two options — Tiếng Việt and English.
- **FR-006**: Selecting a Language option MUST immediately re-render all text in the app in the corresponding language.
- **FR-007**: The selected Language choice MUST persist across app restarts.
- **FR-008**: When no explicit Language choice has ever been made, the app MUST default to Vietnamese (preserving current behavior).
- **FR-009**: The Profile screen MUST display the signed-in user's display name and email.
- **FR-010**: The Profile screen MUST display an avatar: the user's photo if one is set, otherwise a placeholder showing the first letter of their display name (or of their email if no display name is set).
- **FR-011**: The Profile screen MUST display three navigation rows — "Thông báo" (Notifications), "Bảo mật" (Security), "Trợ giúp" (Help) — each navigating to a distinct destination when tapped.
- **FR-012**: The Profile screen MUST display a "Đăng xuất" (Sign out) action that signs the current user out and returns them to the sign-in flow, reusing the app's existing sign-out capability.
- **FR-013**: Appearance and Language preferences MUST be stored per-device, not per-account, so they survive sign-out and apply to whichever account subsequently signs in on that device.
- **FR-014**: The Profile screen's own visual style (colors, spacing, icons, typography) MUST follow the existing design token system already implemented in the app (`AppColors`/`AppSemanticColors`), matching the reference mockup's intent even where an exact token name differs.
- **FR-015**: All Profile screen icons MUST use the app's existing icon package; where the reference mockup names an icon not present in that package, the closest equivalent already available MUST be used.
- **FR-016**: The Profile screen MUST NOT retain the previous ad hoc avatar-URL text entry, password-change flow, or biometric-login toggle — these are removed as part of this redesign (see Clarifications and Out of Scope).

### Out of Scope

- Building real destination content for "Thông báo" (Notifications), "Bảo mật" (Security), or "Trợ giúp" (Help) — these rows navigate to placeholder screens only (Assumptions).
- Password change and biometric-login settings — removed from the Profile screen by this feature (Clarifications) and not replaced with an equivalent here; reintroducing them is a separate future feature.
- Avatar photo upload/editing — the avatar remains a read-only display of the existing photo (if any) or an initial-letter placeholder; no upload/crop/remove flow is introduced.
- Any third language beyond Vietnamese and English.
- Syncing Appearance or Language preferences across a user's multiple devices.

### Key Entities

- **Appearance Preference**: A single device-level setting representing the user's chosen `ThemeMode` (Light, Dark, or "unset/follow system"). Not tied to any user account.
- **Language Preference**: A single device-level setting representing the user's chosen display language (Vietnamese or English, or "unset/default to Vietnamese"). Not tied to any user account.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can switch the app's appearance and see every visible screen update in under 1 second, with zero navigation steps beyond the Profile screen itself.
- **SC-002**: A user can switch the app's language and see every visible screen's text update in under 1 second, with zero navigation steps beyond the Profile screen itself.
- **SC-003**: 100% of appearance and language choices survive a full app restart (close and relaunch), verified across at least one restart cycle per choice.
- **SC-004**: A signed-in user can identify their own account (name and email) within 2 seconds of opening the Profile screen, with no additional taps.
- **SC-005**: A user can sign out in a single tap from the Profile screen.

## Assumptions

- Appearance and Language preferences are device-level, not account-level: they are not synced to the backend and are not part of the user's account data. This matches how most mobile apps treat these settings and avoids adding sync/conflict-resolution complexity for a low-stakes preference.
- "Thông báo" (Notifications), "Bảo mật" (Security), and "Trợ giúp" (Help) navigate to placeholder destinations for this feature — the reference design package itself notes these have no defined destination screen yet (see `reference/README.md`). Building out their real content is a separate, future feature.
- The existing sign-out capability (`AuthRepository.signOut`) is reused as-is; no changes to sign-out behavior itself are in scope.
- The reference mockup's `sun-moon` (Appearance) and `circle-help` (Help) icons are not available under those exact names in the app's current icon package version; the closest available equivalents are used instead, with no visible difference in user-facing meaning.
- The existing Profile screen (`lib/features/account/presentation/account_screen.dart`) is being redesigned to match the reference mockup and incorporate the new Appearance/Language controls. Its current ad hoc fields — avatar URL text entry, password change, and the biometric-login toggle — are removed entirely; they are not present in the reference mockup and are explicitly out of scope for this feature (see Clarifications). Re-exposing password change or biometric settings, if needed later, is a separate future feature.
