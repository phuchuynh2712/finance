# Quickstart: Manual Verification

Run these after implementation, on a real device/emulator, to confirm each user story independently (per spec.md's Independent Test sections).

## Prerequisites

- Signed in with an account that has a `display_name` set, and (separately, for the edge case) one that does not.
- App freshly built with this feature's changes.

## US1: Switch appearance (P1)

1. Open the app while it's showing the light appearance (or force it via device system setting if currently unset/dark).
2. Navigate to the Hồ sơ (Profile) tab.
3. Tap "Tối" in the Giao diện (Appearance) toggle.
4. **Verify**: The entire app — the Profile screen itself, the bottom nav bar, and at least one other tab (e.g. Thu chi) — immediately switches to the dark color scheme. No navigation or reload needed.
5. Fully close the app (swipe away from recents, not just background) and relaunch.
6. **Verify**: The app opens directly in the dark appearance.
7. Tap "Sáng" to switch back; confirm the same immediate, whole-app effect.

## US1 edge case: corrupted preference

1. (Requires dev/debug access) Manually corrupt or clear the `pref_theme_mode` key in the app's local storage.
2. Relaunch the app.
3. **Verify**: The app launches successfully (no crash) and falls back to following the device's system light/dark setting.

## US2: Switch language (P2)

1. Open the app while it's displaying Vietnamese text (default).
2. Navigate to the Hồ sơ tab.
3. Tap the "Ngôn ngữ" row.
4. **Verify**: A dialog opens showing "Tiếng Việt" and "English", with "Tiếng Việt" indicated as current.
5. Select "English".
6. **Verify**: The dialog closes and every visible piece of text — including the Profile screen's own labels ("Hồ sơ" → "Profile", "Giao diện" → "Appearance", etc.) — immediately switches to English.
7. Fully close and relaunch the app.
8. **Verify**: The app opens directly in English.
9. Switch back to Tiếng Việt via the same flow; confirm the same immediate, whole-app effect.

## US3: Account identity, menu rows, sign out (P3)

1. Sign in with an account that has a display name set.
2. Navigate to the Hồ sơ tab.
3. **Verify**: Name and email are shown at the top. If no avatar photo is set, an initial-letter placeholder (first letter of the display name) is shown in its place.
4. Sign out, then sign back in with an account that has **no** display name set (only email).
5. **Verify**: The name area shows a name/initial derived from the email's local part (the part before `@`), not a blank or error state.
6. Tap "Thông báo".
7. **Verify**: Navigates to a placeholder screen with content distinct from the other two menu rows' placeholders (different title/message).
8. Go back, tap "Bảo mật", then "Trợ giúp" — repeat the same check for each.
9. Tap "Đăng xuất".
10. **Verify**: The user is signed out and returned to the sign-in screen.

## Cross-cutting: preferences survive sign-out/sign-in (Edge Case)

1. While signed in as User A, set Appearance to Dark and Language to English.
2. Sign out.
3. Sign in as User B (a different account) on the same device.
4. **Verify**: The app is still in Dark appearance and English — the preference did not reset or follow the account, confirming it is device-level (FR-013).
