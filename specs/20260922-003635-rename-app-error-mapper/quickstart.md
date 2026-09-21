# Quickstart: Manual Verification

## App rename (US1)

1. Launch the app fresh, signed out. On the sign-in screen, confirm the app name reads **"Kiểm Soát"** (Vietnamese locale, default) — not "Khai Tâm".
2. Switch to English locale (Hồ sơ → Ngôn ngữ / Profile → Language). Return to sign-in (or restart). Confirm the app name reads **"Budget Control"** — not "Khai Tam".
3. Confirm the app's icon (launcher icon) is visually unchanged — still the lotus mark, same colors.
4. Spot-check 2-3 of the 13 updated `specs/` historical files (e.g. `specs/20260904-030816-theme-icon-splash/spec.md`) — confirm prose now reads "Kiểm Soát" instead of "Khai Tâm", and that the file's own path/filename is unchanged.

## Centralized error mapping (US2, US3)

For each scenario, confirm the message shown is a complete, readable sentence with **no** class names, status codes, or `code:`/`statusCode:` fragments visible.

1. **Wrong password**: On sign-in, enter a valid-format email with an incorrect password. Confirm a friendly "invalid credentials" message appears — not `AuthApiException(...)`.
2. **Duplicate email on sign-up**: Register with an email that's already in use. Confirm the message is unchanged from before this feature (the existing "already registered" text) — this is a regression check (FR-013).
3. **Weak password on sign-up**: Register with a password the backend rejects as too weak (if the backend has this rule enabled). Confirm a friendly "password too weak" message appears.
4. **Reset password failure**: Trigger a reset-password failure (e.g., airplane mode, then submit). Confirm a friendly, non-raw message appears.
5. **Income save failure**: Enable airplane mode, attempt to save an income entry. Confirm the SnackBar shows a friendly "couldn't reach the server"-style message, not raw exception text.
6. **Expense save failure (manual entry)**: Same as above, via "Chi tiêu" → "Nhập tay" → Lưu giao dịch, with airplane mode on.
7. **Expense save failure (scan-receipt entry)**: Same as above, via "Chi tiêu" → "Quét hoá đơn" → Xác nhận & lưu, with airplane mode on.
8. **Expense-control item save failure**: In "Kiểm soát", create or edit a budget item with airplane mode on. Confirm a friendly message now appears (this previously showed nothing at all — FR-012 closes a silent gap, so this is a new visible behavior, not a regression check).
9. **Unrecognized error type (fallback)**: Not practical to trigger organically on-device; covered by an automated unit test instead (`test/unit/core/error/error_mapper_test.dart`) that passes an arbitrary unrecognized exception type and asserts the generic fallback message is returned.

## Dark mode

Repeat scenario 1 (wrong password) with the app in dark mode — confirm the error text remains legible (sufficient contrast against its background), consistent with the rest of the app's existing dark-mode error-state styling.
