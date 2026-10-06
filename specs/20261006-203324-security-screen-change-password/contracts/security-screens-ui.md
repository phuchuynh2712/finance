# Contract: Security and Change-Password Screens (UI)

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

## Routes

| Path | Screen | Parent | Notes |
|------|--------|--------|-------|
| `/account/security` | Security screen | `/account` branch (shell chrome kept) | opened by the Bảo mật row via `context.go` (so the address bar shows `/account/security` on web — `push` leaves it on `/account`); it is a child of `/account`, so Back → Hồ sơ |
| `/account/security/change-password` | Change-password screen | `/account/security` | pushed sub-screen; Back → Security screen |
| `/account/placeholder/notifications`, `/account/placeholder/help` | unchanged placeholders | `/account` | `AccountPlaceholderFeature.security` is **removed** |

Auth guard: both new routes sit behind the existing signed-in redirect; a
signed-out or locked session never reaches them.

## Security screen

| Element | Behavior |
|---------|----------|
| App bar | back button (`chevronLeft`, label `Quay lại`), title "Bảo mật" with a `shieldCheck` badge, like other Hồ sơ sub-screens |
| Card (grouped, same style as Hồ sơ menu card) | two rows, built from the shared `AccountMenuCard(children)` / `AccountMenuRow(trailing, caption)` extracted from Hồ sơ (the card is a generic container; the row's trailing widget defaults to the chevron and takes a `Switch` here) |
| Other-devices notice (above the card) | hidden by default. After the change-password screen pops with `changedOthersNotEnded`: inline notice `security-others-notice` (text `securityPasswordChangedOthersNotEnded`, warning styling from theme tokens, live-region semantics) with a **Thử lại** button `security-others-retry` (≥ 48 dp). Tap → spinner and disabled while retrying (single-flight); success → the notice disappears and a `SnackBar` shows `securityOthersSignedOutNotice`; failure → the notice stays **and** a `SnackBar` shows the mapped error text (`mapErrorToMessage`: offline → `errorMapperNetworkFailure`, otherwise `errorMapperGeneric`) so the tap is never silent. It lives as long as the Security screen is open. |
| Row 1 — **Đổi mật khẩu** | `keyRound` icon, chevron; tap → change-password route; ≥ 48 dp; semantic label = text |
| Row 2 — **Đăng nhập bằng vân tay** | `fingerprint` icon, trailing `Switch`; caption line only when disabled (reason) or on error |
| Caption when `webUnsupported` | "Đăng nhập bằng vân tay chưa hỗ trợ trên web." |
| Caption when `noHardware` | "Thiết bị này không hỗ trợ đăng nhập bằng vân tay." |
| Caption when `notEnrolled` | "Hãy thêm vân tay hoặc khuôn mặt trong cài đặt thiết bị để bật tính năng này." |
| Loading | availability + stored preference are read on open; show the switch disabled until known (no flash of a wrong state) |
| Switch interaction | on → system biometric prompt (reason string localized); success → on; cancel/failure → stays off + brief localized notice; off → immediate |
| Layout | `AdaptiveBody` content cap; compact: single column under the app bar; expanded: centered capped column; both appearances |

## Change-password screen

| Element | Behavior |
|---------|----------|
| Fields | current, new, confirm; labels "Mật khẩu hiện tại", "Mật khẩu mới", "Nhập lại mật khẩu mới"; each with show/hide `IconButton` (`eye`/`eyeOff`) with tooltip and semantic label |
| Autofill | `AutofillGroup`; current = `AutofillHints.password`; new and confirm = `AutofillHints.newPassword`; `autocorrect: false`, `enableSuggestions: false` |
| Helper text | under the new-password field: `passwordRequirementHint` ("Tối thiểu 8 ký tự") — visible before typing |
| Errors | inline, per field, in the validation order of `data-model.md` §2; banner for network/server/rate-limit; never a raw exception text |
| Submit | primary button "Đổi mật khẩu"; disabled with a spinner while `submitting`; Enter on the last field submits; single-flight |
| Success | the screen pops back to the Security screen with the outcome: `changed` ⇒ a `SnackBar` "Đã đổi mật khẩu."; `changedOthersNotEnded` ⇒ the Security screen's other-devices notice with the **Thử lại** action (see above) |
| Session expired | a banner `errorMapperSessionExpired`; nothing was changed. The screen does **not** navigate itself: when the service rejects this device's refresh token gotrue emits `signedOut` and the app's existing auth-state redirect goes to sign-in (proved by quickstart Scenario 3, revoked-device step); typed values are discarded when the screen is left |
| Leaving | controllers disposed and cleared (re-opening the screen shows three empty fields); nothing persisted; no value is logged |
| Keyboard order | current → new → confirm → submit; `FocusTraversalGroup` |

## Accessibility and theming (both screens)

- Every interactive element ≥ 48×48 dp; hover feedback + tooltips on icon-only
  controls; visible focus; works with a screen reader (`Semantics` labels on
  the switch, show/hide buttons and the success/error messages as live regions).
- Colors, spacing and typography only from the existing theme tokens
  (`AppSemanticColors`, `AppLayoutTokens`); light and dark; no hard-coded colors.
- Compact (< 600 dp) and expanded (≥ 840 dp) widget tests exist for both screens, each in light and dark appearance.

## Test keys (stable `ValueKey`s used by widget tests)

`security-change-password-row`, `security-biometric-switch`,
`security-biometric-caption`, `security-others-notice`, `security-others-retry`,
`change-password-current`, `change-password-new`, `change-password-confirm`,
`change-password-submit`.
