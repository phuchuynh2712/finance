# Contract: New and Changed Localization Keys

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

Every key exists in `app_vi.arb` (primary, default) and `app_en.arb`, with an
`@key` description, and is read only through `AppLocalizations`.

## Changed

| Key | vi | en |
|-----|----|----|
| `signUpPasswordTooShortError` → renamed `passwordTooShortError` | Mật khẩu phải có ít nhất 8 ký tự. | Password must be at least 8 characters. |
| `errorMapperWeakPassword` (copy only; today "Mật khẩu chưa đủ mạnh. Vui lòng chọn mật khẩu khác.") | Mật khẩu chưa đủ mạnh. Hãy dùng ít nhất 8 ký tự. | That password is not strong enough. Use at least 8 characters. |

`errorMapperRateLimited` already reads "Bạn đã thử quá nhiều lần. Vui lòng đợi một chút rồi thử lại.", so only the *mapping* is extended to `over_request_rate_limit` (no copy change). The shared mapper also gains `same_password` (→ `changePasswordSameAsCurrentError`) and the session codes (→ `errorMapperSessionExpired`); sign-in, sign-up and the email reset benefit from them too.

## New — Security screen

| Key | vi | en |
|-----|----|----|
| `securityScreenTitle` | Bảo mật | Security |
| `securityChangePasswordRow` | Đổi mật khẩu | Change password |
| `securityBiometricRow` | Đăng nhập bằng vân tay | Fingerprint sign-in |
| `securityBiometricReasonWeb` | Đăng nhập bằng vân tay chưa hỗ trợ trên web. | Fingerprint sign-in is not supported on the web. |
| `securityBiometricReasonNoHardware` | Thiết bị này không hỗ trợ đăng nhập bằng vân tay. | This device does not support fingerprint sign-in. |
| `securityBiometricReasonNotEnrolled` | Hãy thêm vân tay hoặc khuôn mặt trong cài đặt thiết bị để bật tính năng này. | Add a fingerprint or face in the device settings to turn this on. |
| `securityBiometricPromptReason` | Xác nhận để bật đăng nhập bằng vân tay | Confirm to turn on fingerprint sign-in |
| `securityBiometricEnableFailed` | Chưa bật được đăng nhập bằng vân tay. | Fingerprint sign-in was not turned on. |
| `securityPasswordChangedNotice` | Đã đổi mật khẩu. | Password changed. |
| `securityPasswordChangedOthersNotEnded` | Đã đổi mật khẩu, nhưng chưa đăng xuất được các thiết bị khác. | Password changed, but other devices could not be signed out. |
| `securityOthersRetryAction` | Thử lại | Try again |
| `securityOthersSignedOutNotice` | Đã đăng xuất các thiết bị khác. | Other devices were signed out. |

## New — Change-password screen

| Key | vi | en |
|-----|----|----|
| `changePasswordTitle` | Đổi mật khẩu | Change password |
| `changePasswordCurrentLabel` | Mật khẩu hiện tại | Current password |
| `changePasswordNewLabel` | Mật khẩu mới | New password |
| `changePasswordConfirmLabel` | Nhập lại mật khẩu mới | Confirm new password |
| `passwordRequirementHint` | Tối thiểu 8 ký tự | At least 8 characters |
| `changePasswordCurrentRequiredError` | Nhập mật khẩu hiện tại. | Enter your current password. |
| `changePasswordSameAsCurrentError` | Mật khẩu mới phải khác mật khẩu hiện tại. | The new password must differ from the current one. |
| `changePasswordWrongCurrentError` | Mật khẩu hiện tại không đúng. | The current password is incorrect. |
| `changePasswordSubmit` | Đổi mật khẩu | Change password |
| `errorMapperSessionExpired` | Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại. | Your session has expired. Please sign in again. |

Reused unchanged: `resetPasswordMismatchError`, `errorMapperNetworkFailure`,
`errorMapperGeneric`, `signInShowPasswordSemantic`, `signInHidePasswordSemantic`, `accountSecurityRowLabel`.
`passwordRequirementHint` is also shown under the sign-up and reset password
fields.

## Parity check

A unit test asserts that the set of keys in `app_vi.arb` equals the set in
`app_en.arb` and that every key has an `@key` entry with a description. That
no new user-visible string is a literal in the new screens is checked by a
documented `grep` in the final verification task (patterns such as `Text('`,
`label: '`, `tooltip: '`, `helperText: '`, `errorText: '`), because a reliable
literal scan cannot be expressed as a unit test without false positives.
