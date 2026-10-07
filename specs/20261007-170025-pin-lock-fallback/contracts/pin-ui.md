# Contract: PIN Screens

**Stories**: US2–US6 | **Requirements**: FR-006…FR-021 | **Code**: `lib/features/account/presentation/widgets/{pin_keypad,pin_dots}.dart`,
`lib/features/account/presentation/{pin_entry_panel,pin_flow_screen,pin_flow_controller,pin_offer_prompt}.dart`

All screens use the existing tokens (`authContentMaxWidth` 450 dp for the lock screen, the shared column for the flow),
`AdaptiveBody` where content does not scroll, `AppTheme` colors in light and dark, targets of at least 48 dp, and text
from the generated localizations only.

## 1. Shared widgets

| Widget | Contract |
|--------|----------|
| `PinDots(entered, total = 6)` | keys `pin-dot-0…5`; six dots, filled for entered digits; one semantic label "Đã nhập {entered} trên {total} chữ số" (vi) / "{entered} of {total} digits entered" (en); never the digits |
| `PinKeypad(onDigit(String), onBackspace, enabled, autofocus)` | at most 360 dp wide (never more than 450); keys `pin-key-0…9` and `pin-key-backspace`; Ctrl, Meta or Alt held leaves a key alone; a held digit key types once; 3 × 4 grid `1…9`, an empty cell, `0`, `⌫`; keys ≥ 48 dp high, 6–8 dp gaps; each key's label is its digit, `⌫` has a tooltip and label (reuses the Chi tiêu delete-key strings' wording); digit keys and Backspace also work from a hardware keyboard; disabled while a check runs |

## 2. Lock screen (`SignInScreen` as the lock, PIN mode)

Shown when `lockScreenMode == pin`. Layout, top to bottom, in a column of at most 450 dp: the app logo block as today;
title "Nhập mã PIN"; `PinDots`; a live message line; `PinKeypad`; then "Dùng mật khẩu" and "Quên mã PIN" text buttons.

**Loading**: while the PIN status is being read the screen shows the logo block and a progress indicator only, never the password form, so the form does not flash before the PIN panel appears.

| Event | Result |
|-------|--------|
| sixth digit entered | verifies at once (no confirm key); keys disabled while it runs |
| `success` | unlock (as the biometric path does), `appLockProvider.unlock()`, land on Tổng quan |
| `wrong(n)` | entry cleared; message "Mã PIN không đúng. Còn {n} lần thử." (live region) |
| `invalidated` | message "Đã nhập sai 5 lần. Mã PIN đã bị tắt, hãy đăng nhập bằng mật khẩu."; the password form is shown; PIN mode is not offered again |
| "Dùng mật khẩu" | the existing password form; the PIN stays |
| "Quên mã PIN" | the existing password form, remembering `forgotPin = true` |
| password sign-in succeeds with `forgotPin`, or status was `expired` or `invalidated` | `PinLockRepository.clear()`, then the offer to set a new PIN (declinable, never blocking; made even where biometrics are now available, because the account already used a PIN). This is the **only** PIN dialog of that sign-in: it counts as the one-time offer, so the offer marker is set and `maybeShowPinOfferPrompt` is skipped |
| biometric also on | the existing fingerprint button next to the PIN panel (including a PIN set earlier on a device that has since gained biometrics) |
| ordinary sign-in screen (signed out), password sign-in succeeds | `PinLockRepository.clear()` removes any PIN left over from an earlier session of that account (expired or revoked session) |
| the app is restarted between the invalidation and the password sign-in | the screen's memory of the invalidation is gone, so it is an ordinary lock-screen password sign-in: no "new PIN" dialog (the one-time marker was set earlier); the PIN row in Bảo mật is there to set one (observed on the emulator) |

When `status == expired` the screen opens directly in password mode with the message "Mã PIN đã hết hạn sau 12 tháng. Hãy đăng nhập bằng mật khẩu để đặt mã mới."

## 3. Set-up, change, turn-off flow (`PinFlowScreen`, pushed from Bảo mật)

One screen, a `mode`, and a linear list of steps; the controller is a pure state machine (`PinFlowState`).

| Mode | Steps |
|------|-------|
| `setUp` | `confirmPassword` → `newPin` → `repeatPin` → done |
| `change` | `currentPin` → `newPin` → `repeatPin` → done |
| `turnOff` | `currentPin` → done |

- `confirmPassword`: a password field (`PasswordField`, extracted from the change-password screen, key `pin-flow-password`) with the existing show/hide toggle; calls `passwordChangeGatewayProvider.verifyCurrentPassword` and
  closes the temporary session; the "Tiếp tục" button is `pin-flow-continue`, the message line `pin-flow-message`; the field takes the focus by itself only on a desktop platform. Wrong password → the sign-in error message, nothing saved, same step. No connection → the
  existing "no connection" message; the flow cannot continue.
- `newPin`: `PinDots` + `PinKeypad`; an easy PIN → "Mã PIN quá dễ đoán, hãy chọn mã khác" and the entry clears.
- `repeatPin`: a mismatch → "Hai lần nhập chưa khớp" and **only this step restarts** (the first PIN is kept in memory
  until leaving); a match calls `PinLockRepository.set`.
- `currentPin`: verified with `verify`; the five-try limit and its messages are the lock screen's; `invalidated` ends the flow
  with the invalidation message.
- Leaving the screen at any point (back, Escape) discards everything typed; nothing is written before the last step succeeds.
- `change` and `turnOff` end early (step `ended`, the screen pops with `false` and says why on the screen below) when the fifth wrong current PIN invalidates the PIN, or the PIN expired meanwhile. A finished set-up or change pops with `true` and shows "Đã đặt mã PIN"; turning it off shows nothing (the row says it).
- The route is `/account/security/pin/:mode` with `setUp`, `change` or `turnOff`.
- A step's message is a live region; focus moves to the new step's first control.

## 4. Bảo mật row

`AccountMenuRow` key `security-pin-row`, below the biometric row, shown when `pinAvailable` or a PIN is in use (`pinInUse`):

| State | Row |
|-------|-----|
| no PIN | label "Khóa bằng mã PIN", caption "Mở app nhanh bằng 6 số", switch off → opens `setUp` |
| active | switch on (`security-pin-switch`), caption "Đang bật" (`security-pin-caption`); switching it off → `turnOff`; a separate row `security-pin-change-row` "Đổi mã" appears below it → `change` (a row, not an inline button, so it never crowds a 320 dp row at 130 % text) |
| expired | switch off, caption "Mã PIN đã hết hạn" → `setUp` |

When neither holds (the web, or biometrics available and no PIN set) the row is absent and the biometric row is exactly as today. The state is `PinRowState` (`hidden`, `off`, `active`, `expired`), from `pinRowStateProvider` in `security_controller.dart`; the screen re-reads `pinAvailable` and the status when the app resumes.

## 5. One-time offer

`maybeShowPinOfferPrompt(navigator, container)` (the root `NavigatorState` and the app's `ProviderContainer`, taken by the caller before it awaits anything: the sign-in or sign-up screen is already gone when the biometric dialog before it is answered) is called after `maybeShowBiometricEnablePrompt` on every successful sign-in or sign-up, **except** after the sign-in that just offered a new PIN (forgot PIN, expired or invalidated): that offer counts as the one-time offer, so the marker is set and no second dialog follows.
It does nothing unless `pinAvailable` and `status == none` and the marker is absent; it marks the offer shown
**before** showing it; the dialog has a decline button and a primary "Đặt mã PIN" button with the initial focus; closing
it is declining; accepting pushes `PinFlowScreen(setUp)` (`offerPinSetUp` = `showPinOfferDialog(navigator)` + the push of `/account/security/pin/setUp`). The function never throws: a failing offer must not disturb a sign-in that worked.

## 6. Strings (all in `vi` and `en`; keys in `app_*.arb`, parity test extended)

`pinLockRow`, `pinLockRowCaptionOff`, `pinLockRowCaptionOn`, `pinLockRowCaptionExpired`, `pinChangeAction`,
`pinEnterTitle`, `pinDotsSemantic(entered,total)`, `pinKeypadDeleteSemantic`, `pinWrongTries(count)`, `pinInvalidated`,
`pinExpired`, `pinUsePasswordAction`, `pinForgotAction`, `pinSetupConfirmPasswordTitle`, `pinSetupNewTitle`,
`pinSetupRepeatTitle`, `pinChangeCurrentTitle`, `pinTurnOffTitle`, `pinTooEasy`, `pinMismatch`, `pinSetDone`,
`pinOfferTitle`, `pinOfferMessage`, `pinOfferAcceptAction`, `pinOfferDeclineAction`, `pinSetupContinueAction`.

## 7. Layout and accessibility checks

At 320, 412, 600, 840, 1200 and 2560 dp wide, 500 dp high, 130 % text, light and dark: no overflow; the keypad never
exceeds 450 dp wide; the dots and live messages are reachable by a screen reader; the whole flow is completable from a
hardware keyboard where one exists (digits, Backspace, Tab to the buttons, Enter, Escape to leave).
