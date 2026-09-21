# Feature Specification: Biometric Login & Sign-Up Refactor

**Feature Branch**: `20260904-111850-biometric-login`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Tôi muốn thay đổi refactor lại toàn bộ login và signup page, không còn google authen hay các liên quan khác nữa, mà đổi thành sử dụng vân tay để có thể login nhanh. Hiện tại mockup mới tôi để trong folder \"E:\\Study\\design\\handoff\", sau khi đọc hiểu thì hãy copy lại những cái liên quan để sử dụng refer sau này."

**Supersedes**: The Google Sign-In portions of `specs/20260726-register-login-google-oauth/` (previously shipped email/password + Google OAuth), and that feature's FR-015 (mandatory email confirmation before sign-in). This feature removes Google Sign-In entirely — from the Login screen, the Sign Up screen, and the Account screen's account-linking section — replaces it with device biometric (fingerprint/Face ID) quick login, drops the email confirmation gate so sign-up signs a user in immediately, and rebuilds both screens to match the new "Kiểm Soát" design handoff.

**Reference assets**: Design handoff files copied for planning under `reference/` in this feature directory (`login-signup-spec.md`, `icons.json`, `theme-tokens.json`, `README.md`, `app-icon-khai-tam.svg` + `app-icon-khai-tam-green.svg`).

## Clarifications

### Session 2026-09-04

- Q: How should the "phone number" field on the new Login/Sign Up screens behave? → A: It is profile data only. Sign-in and sign-up continue to authenticate with email + password exactly as today; the phone number is stored on the user's profile and is never used as a login credential. (Note: this means the Sign Up screen's email field remains functionally *required*, even though the mockup labels it "optional" for phone-first visual layout — see Assumptions.)
- Q: How does a user first turn biometric login on for a device? → A: Both — the app automatically offers to enable it right after the user's first successful password sign-in on that device, **and** a persistent toggle is available on the Account screen so the user can turn it on or off at any later time.
- Q: What happens when the user taps "Forgot password?" on the Login screen? → A: A real flow is built in this feature: the user submits their email, the system sends a password-reset email, and the user sets a new password from that link.
- Q: Is email confirmation (the confirmation link required by `specs/20260726-register-login-google-oauth/` FR-015) still required before a newly registered user can sign in? → A: No — drop it entirely for this feature. Sign-up now signs the user in immediately, with no confirmation step of any kind. Verifying a user's email address is deferred to a future feature, to be offered later from the Account/Profile screen if needed, not blocking sign-up.
- Q: Does the one-time biometric-enable prompt (FR-009) also fire right after a brand-new Sign Up, or only after a password Sign-In on the Login screen? → A: Yes, it also fires after Sign Up — Sign Up counts as the first successful authentication on that device, same as a password Sign-In.
- Q: When a user signs out, does that clear the device's biometric login preference for that account, or leave it enabled for next time? → A: Signing out clears/disables biometric login for that account on that device. The user must sign in with their password again and re-enable biometric login (via the prompt or the Account toggle) before the fingerprint button reappears.
- Q: Do the "Terms of Service" / "Privacy Policy" links in the Sign Up checkbox need to lead to real content in this feature? → A: No — out of scope. The checkbox and link text render per the mockup, but authoring or linking to actual Terms/Privacy content is a separate concern from this login/sign-up refactor.
- Q: On a personal device with a still-valid persisted session, should the app require re-authentication every time it's reopened from a fully-closed state, or keep silently auto-entering the main screen as it does today? → A: Yes — gate it. Every cold start (app launched from a fully closed state) shows the Login screen as a re-entry gate before granting access, with biometric as the fast unlock path when enabled, instead of silently resuming the session as before. Without this, the fingerprint button would almost never appear in normal daily use on a personal (non-shared) device, since sessions persist and explicit sign-outs are rare — this gate is what makes "fast biometric login" meaningful day to day, not just an edge case after sign-out or session expiry. This gate applies only to a full cold start (app opened from fully closed); it does not apply when resuming from the background.
- Q: When the underlying session has fully died server-side (rare — password changed elsewhere, a security event revoked access, etc.), should biometric still get the user in, or should it fall back to requiring the password once? → A: Fall back to requiring the password once. Biometric only ever unlocks a still-valid session; the app does not store the password (or any equivalent long-lived secret) on the device to survive a genuinely dead session, which keeps the on-device attack surface unchanged from today. This case is rare in daily use, since the access token underlying the session refreshes silently in the background on its own and requires no user action; only a true server-side invalidation reaches this fallback.
- Q: The client cannot reliably tell *why* a session died (benign long-absence expiry vs. a real security event elsewhere), so should this feature instead make session invalidation on other devices something the system triggers *on purpose* whenever a password changes? → A: Yes. Add automatic, non-optional session revocation: (1) a successful Forgot Password reset signs the account out of **every** session globally, including the device the reset was completed on; (2) a successful Change Password from the Account screen signs the account out of every **other** device/session but keeps the current device signed in. This is the standard pattern most banking/fintech apps use (Supabase's `signOut(scope: 'global' | 'others')` supports both natively). No user-facing toggle/checkbox to opt out of either — it is always applied, so it can't be defeated by whoever is behind the reset (attacker or account owner) at the moment it matters most.
- Q: The project constitution requires an app-level lock gating access "after launch **or resume from background**," but FR-020 (as drafted) only gates a full cold start, not resuming from the background — how should this be reconciled? → A: Add a background-idle threshold: if the app has been backgrounded for longer than 5 minutes, resuming it triggers the same re-entry gate as a cold start (biometric-first if enabled, else password); resuming sooner than that (a quick app-switch) does not. This satisfies the constitution's "resume from background" requirement in spirit and practice, without gating every brief app-switch, which would otherwise be disruptive to normal use (e.g., copying a 2FA/OTP code from another app).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quick Sign-In With Fingerprint/Face ID (Priority: P1)

As a returning user who previously enabled biometric login on this device, I want to sign in with just my fingerprint or face instead of typing my password, so getting into the app is fast and effortless.

**Why this priority**: This is the core value proposition of the feature ("login nhanh") and the reason Google Sign-In is being replaced. It only delivers real, everyday value together with FR-020's re-entry gate — without that gate, a personal device's session would keep silently auto-resuming as it does today, and the fingerprint button would rarely, if ever, appear in normal use.

**Independent Test**: On a device with biometric login already enabled for an account, fully close the app (cold start, not backgrounding) and reopen it; confirm the Login screen appears as a re-entry gate (FR-020), tap "Log in with fingerprint," complete the device's native biometric prompt, and confirm the user lands signed in without ever typing a password.

**Acceptance Scenarios**:

1. **Given** biometric login is enabled for the current account on this device, **When** the Login screen appears, **Then** a "Log in with fingerprint" button is visible below the password fields.
2. **Given** the "Log in with fingerprint" button is visible, **When** the user taps it and completes the device's native biometric check successfully, **Then** the user is signed in and taken to the app's main screen without entering a password.
3. **Given** the user taps "Log in with fingerprint," **When** the biometric check fails, is cancelled, or times out, **Then** the user remains on the Login screen with the password fields still available and any previously entered data intact.
4. **Given** the device has no biometric hardware or no fingerprint/face enrolled at the OS level, **When** the Login screen appears, **Then** the "Log in with fingerprint" button is not shown.
5. **Given** biometric login was enabled for Account A on this device, **When** a different user signs in with Account B's password on the same device, **Then** the fingerprint button does not grant access to Account A, and Account B must separately opt in to enable biometric login for itself.

---

### User Story 2 - Rebranded Login & Sign Up Screens, No Google Sign-In (Priority: P1)

As a user, I want the Login and Sign Up screens to look and read like the rest of the rebranded app, and I want a simple, focused sign-in experience with only email/password and biometric — not extra third-party sign-in options — so the experience feels coherent and trustworthy.

**Why this priority**: The icon/theme rebrand already shipped elsewhere in the app; leaving the auth screens on the old layout with a Google button would look broken and inconsistent, and is a hard prerequisite for User Story 1 (the fingerprint button has a defined home in the new layout, not the old one).

**Independent Test**: Open the Login screen and the Sign Up screen in both light and dark mode; visually confirm they match the new design (centered logo block, restyled inputs, new button styles) and confirm no Google-branded button or text appears anywhere in either screen or in the Account screen's linked-accounts section.

**Acceptance Scenarios**:

1. **Given** the Login screen is open, **When** it renders, **Then** it shows the centered app logo/title/subtitle block, a phone-or-email field, a password field with a show/hide toggle, a "Forgot password?" link, a primary "Log in" button, a divider, the "Log in with fingerprint" button (per User Story 1's visibility rules), and a footer link to Sign Up — with no Google sign-in option anywhere.
2. **Given** the Sign Up screen is open, **When** it renders, **Then** it shows a header with a back button and title, and a scrollable form with full name, phone number, email, password, confirm password, a Terms of Service checkbox, a primary "Sign Up" button, and a footer link to Login — with no Google sign-in option anywhere.
3. **Given** either screen is open, **When** the device's system theme is light or dark, **Then** all colors come from the app's existing semantic theme tokens (no hardcoded colors) and match the new brand palette in both modes.
4. **Given** the Account screen is open, **When** it renders, **Then** the previous "linked Google account" section is no longer present.
5. **Given** the Sign Up screen's Terms of Service checkbox is unchecked, **When** the user attempts to submit, **Then** the primary "Sign Up" action is blocked until the checkbox is checked.
6. **Given** the Sign Up form is valid and submitted, **When** the account is created, **Then** the user is signed in immediately and taken to the app's main screen, with no email-confirmation step of any kind in between.

---

### User Story 3 - Turn Biometric Login On or Off (Priority: P2)

As a user, I want to be offered biometric login right after I first sign in with my password, and I want to be able to turn it on or off later from my account settings, so I stay in control of this convenience feature.

**Why this priority**: Enables User Story 1 in practice — without an enrollment moment, no user could ever reach the "biometric login enabled" state described in User Story 1. Ranked P2 (not P1) because the *sign-in experience itself* (User Story 1) is the primary value; this story is the supporting on/off mechanism.

**Independent Test**: Sign in with a password on a fresh device for the first time and confirm a one-time prompt offers to enable biometric login; separately, open the Account screen and confirm a toggle exists that enables/disables biometric login independently of that prompt.

**Acceptance Scenarios**:

1. **Given** a user authenticates successfully for the first time on a given device — either by signing up or by signing in with their password, **When** that authentication completes, **Then** the app offers a one-time prompt asking whether to enable biometric login for that device.
2. **Given** the user accepts the enable-biometric prompt, **When** they next reach the Login screen on that device, **Then** the "Log in with fingerprint" button is shown (per User Story 1).
3. **Given** the user declines the enable-biometric prompt, **When** they sign in again later, **Then** the prompt is not shown again automatically, but biometric login can still be turned on manually from the Account screen.
4. **Given** the user opens the Account screen, **When** they toggle biometric login off, **Then** the "Log in with fingerprint" button no longer appears on the Login screen on that device until it is turned back on.
5. **Given** the device's OS-level biometric enrollment is later removed or reset (e.g., all fingerprints deleted in system settings), **When** the user returns to the app, **Then** biometric login is treated as unavailable and the app falls back to password sign-in without error.

---

### User Story 4 - Reset a Forgotten Password (Priority: P2)

As a user who forgot my password, I want to request a password reset from the Login screen, so I can regain access to my account without contacting support.

**Why this priority**: A real, standalone capability the mockup calls for that wasn't previously built; important for account recovery but independent of the biometric/rebrand work, so it can ship and be tested on its own.

**Independent Test**: Tap "Forgot password?" on the Login screen, submit a registered email address, receive a password-reset email, follow it, set a new password, and confirm sign-in works with the new password.

**Acceptance Scenarios**:

1. **Given** the user taps "Forgot password?" on the Login screen, **When** they submit a valid, registered email address, **Then** the system sends a password-reset email and confirms the request on screen.
2. **Given** the user submits an email address that is not registered, **When** the request is processed, **Then** the system shows a generic confirmation (not revealing whether the account exists), consistent with standard account-enumeration protection.
3. **Given** the user follows the reset link from the email, **When** they set a new password, **Then** they can subsequently sign in with the new password and the old password no longer works.
4. **Given** a password reset completes successfully, **When** the account previously had active sessions on other devices, **Then** every one of those sessions (and the device the reset was completed on) is signed out, requiring a fresh sign-in with the new password everywhere.

---

### Edge Cases

- What happens if a user backgrounds the app mid-biometric-prompt and returns later? The prompt should be re-triggerable or safely dismissed without leaving the app in a stuck state.
- What happens if biometric login is enabled but the persisted session has actually died server-side (not just an expired short-lived access token, which refreshes silently on its own — see Clarifications)? Biometric verification succeeds locally but sign-in must still fail gracefully back to the password form, not show a false "signed in" state; the user types their password once, after which biometric login can be re-enabled for next time.
- What happens if a user signs up but abandons the flow before finishing (e.g., app closed after entering some fields but before submitting)? No account or biometric enrollment should be created.
- What happens if a user types a phone number (not an email) into the Login screen's "phone or email" field? Since phone is not a valid credential (see Clarifications), sign-in fails with the same invalid-credentials messaging as any other non-matching input.
- How does the system handle a password-reset request submitted while the user is already signed in? Treated the same as any other reset request; does not need to be gated behind sign-out.
- What happens when the user backgrounds the app briefly (e.g., switches to another app to copy a code) and returns within 5 minutes? Per FR-020, the re-entry gate does not trigger, so the user returns straight to where they left off with no re-authentication prompt.
- What happens when the user backgrounds the app for more than 5 minutes and returns? Per FR-020, this is treated the same as a cold start — the re-entry gate appears, biometric-first if enabled.
- What happens to a device's biometric login preference when its session gets force-revoked by FR-016a/FR-016b (a password reset or change on another device)? It is treated the same as any other dead session: biometric login fails and falls back to the password form (per the session-death Clarification above), and the device's biometric preference is cleared once the user signs back in with the new password, consistent with FR-014a — they must re-enable biometric login for that device again afterward.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST remove Google Sign-In as a sign-in or sign-up method, including its UI entry point, from both the Login and Sign Up screens.
- **FR-002**: System MUST remove the Google account-linking section from the Account screen.
- **FR-003**: Login screen MUST present: a centered logo/title/subtitle block, a phone-or-email input, a password input with a show/hide toggle, a "Forgot password?" link, a primary "Log in" button, a divider, a "Log in with fingerprint" button (shown/hidden per FR-008), and a footer link to Sign Up — matching the new design handoff in both light and dark mode.
- **FR-004**: Sign Up screen MUST present: a header with a back action and title, and a form collecting full name, phone number, email, password, and password confirmation, a Terms of Service checkbox, a primary "Sign Up" button, and a footer link to Login — matching the new design handoff in both light and dark mode.
- **FR-005**: System MUST continue to authenticate sign-in and sign-up using email + password only; the phone number collected on Sign Up is stored as profile data and MUST NOT be usable as a login credential.
- **FR-006**: System MUST require the Sign Up email field to be filled in and valid before the account can be created, since it remains the only supported authentication credential.
- **FR-007**: System MUST require the Sign Up Terms of Service checkbox to be checked before the primary "Sign Up" action can be submitted.
- **FR-008**: System MUST show the "Log in with fingerprint" button on the Login screen only when both (a) the current device has biometric hardware with at least one fingerprint/face enrolled at the OS level, and (b) biometric login has been enabled for an account on this device; otherwise the button MUST be hidden.
- **FR-009**: System MUST, immediately after a user's first successful authentication on a given device — whether via a new Sign Up or a password Sign-In — offer a one-time prompt asking whether to enable biometric login on that device.
- **FR-010**: System MUST provide a toggle on the Account screen that lets the signed-in user enable or disable biometric login for the current device at any time, independent of the first-sign-in prompt.
- **FR-011**: When the user taps "Log in with fingerprint" and completes the device's native biometric verification successfully, System MUST sign the user into the same account for which biometric login was enabled, without requiring the password to be re-entered.
- **FR-012**: When biometric verification fails, is cancelled, or is unavailable at the moment of use, System MUST keep the user on the Login screen with the password fields available and any previously entered form data preserved.
- **FR-013**: System MUST NOT allow biometric login enabled for one account on a device to sign in a different account on that same device.
- **FR-014**: System MUST treat biometric login as unavailable (falling back to password sign-in) if the device's OS-level biometric enrollment is removed or changed after in-app biometric login was enabled, without raising an unhandled error.
- **FR-014a**: When a user signs out, System MUST disable the biometric login preference for that account on that device, so the "Log in with fingerprint" button no longer appears until the user signs in with their password again and re-enables it.
- **FR-015**: System MUST provide a "Forgot password?" flow: the user submits an email address, the system sends a password-reset email for that address if it belongs to a registered account, and shows the same on-screen confirmation regardless of whether the address is registered.
- **FR-016**: System MUST let a user who follows a valid password-reset link set a new password, after which sign-in with the old password no longer succeeds.
- **FR-016a**: On a successful password reset (FR-016), System MUST sign the account out of every active session globally, including the device the reset was completed on — no user-facing option to skip this.
- **FR-016b**: On a successful password change from the Account screen (existing capability, unchanged trigger), System MUST sign the account out of every other active session/device while keeping the current device signed in — no user-facing option to skip this.
- **FR-017**: Every icon used on the Login and Sign Up screens MUST come from the app's existing Lucide icon set, consistent with the rest of the app.
- **FR-018**: Login and Sign Up screens MUST render all colors from the app's existing semantic theme tokens (no hardcoded colors), consistent with the app's light/dark theming system.
- **FR-019**: System MUST NOT require email confirmation before a newly registered user can sign in; sign-up MUST sign the user in immediately upon successful account creation, superseding the mandatory email-confirmation gate from `specs/20260726-register-login-google-oauth/` FR-015.
- **FR-020**: On every cold start (the app launched from a fully closed state) where an already-authenticated session exists on the device, System MUST show the Login screen as a re-entry gate before granting access to the app, instead of silently resuming the session directly to the main screen. System MUST apply this same gate when the app resumes from the background after having been backgrounded for more than 5 minutes; resuming sooner than that MUST NOT trigger the gate.
- **FR-021**: On the cold-start re-entry gate (FR-020), when biometric login is enabled for the current device/account, the "Log in with fingerprint" button MUST be offered as the fast unlock path (per FR-011); when biometric login is not enabled, the user unlocks by entering their password as a normal sign-in.

### Key Entities

- **Biometric Login Preference**: A per-device, per-account on/off setting controlling whether the fingerprint quick-login button appears and functions on that device. Not synced across a user's other devices.
- **User Profile**: Extended to additionally hold full name and phone number collected at sign-up, alongside the existing email and avatar fields. Phone number is descriptive profile data, not a credential.
- **Password Reset Request**: A time-limited, single-use request that lets a user who proves control of their registered email set a new password for their account.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A returning user with biometric login enabled can go from opening the app to being fully signed in within 3 seconds, using only a fingerprint/face check.
- **SC-002**: Zero Google-branded sign-in buttons, links, or account-linking sections remain reachable anywhere in the app after this feature ships.
- **SC-003**: A new user can complete sign-up (all fields, terms acceptance, submission) in under 2 minutes on first attempt.
- **SC-004**: A user who forgets their password can regain account access entirely on their own (request reset email, set new password, sign in) without contacting support.
- **SC-005**: Both Login and Sign Up screens visually match the new brand design in light and dark mode, with no unreadable text and no leftover old-brand styling.
- **SC-006**: A user who resets or changes their password can be confident every other device signed into their account is forced to re-authenticate, with zero manual steps beyond completing the reset/change itself.

## Assumptions

- Email remains the sole authentication credential for this app; the phone number field is collected for profile purposes only, per the Clarifications above. The Sign Up screen's email field is treated as required (not optional as the visual mockup label suggests), since making it optional would remove the only credential the system can authenticate with.
- Biometric login is a per-device convenience layer on top of the app's existing persisted Supabase session (already stored in platform secure storage), not a new identity provider — the device's native biometric check gates access to that already-authenticated session rather than performing authentication itself. The password itself (or any equivalent durable secret) is never stored on the device to make biometric survive a fully dead session; when the session is genuinely invalid, biometric falls back to the password form (see Clarifications and Edge Cases) rather than expanding what's stored on-device.
- Biometric hardware/enrollment is read from the OS; this feature does not include a custom in-app fingerprint-capture UI (the device's native biometric prompt is used as-is).
- No production users exist yet on the previous Google Sign-In flow, so no account-migration path is required when it is removed.
- Password reset uses the existing auth backend's built-in email-based recovery mechanism; no custom SMS/OTP-based reset path is in scope.
- Existing Sign Up field validation (name, password confirmation match, etc.) is extended to cover the new phone number field, following the same inline-error pattern already used elsewhere in the app.
- Email address verification (confirming the user actually owns the address they registered with) is explicitly deferred out of scope for this feature. It may be offered later as an optional, non-blocking action from the Account/Profile screen in a future feature, not as a gate on sign-up.
- FR-019 requires disabling Supabase's "Enable email confirmations" project setting (Dashboard → Authentication → Sign In / Providers → Email) — the same setting `specs/20260726-register-login-google-oauth/` required turning on — so sign-up returns an active session immediately server-side, not just on the client. This is a manual Dashboard change, not something this feature's client code controls. **Already done** — disabled in the Supabase Dashboard as of this session (2026-09-04).
- The Sign Up screen's "Terms of Service" / "Privacy Policy" links render as styled text per the mockup (FR-007's checkbox still gates submission) but do not need to navigate to real legal content in this feature; authoring that content is out of scope.
- FR-020's re-entry gate (cold start, and background-resume past 5 minutes) is a deliberate behavior change from today's app, which silently auto-resumes a valid session with no re-entry screen at all. Users who have not enabled biometric login will now need to type their password on every such re-entry (where they previously typed nothing) — this added friction for non-biometric users is accepted as the trade-off that makes biometric quick login meaningful, and is expected to nudge users toward enabling it via the FR-009 prompt. The 5-minute background threshold is what satisfies the project constitution's Security section requirement that the app-level lock gate access "after launch or resume from background," while still not disrupting brief app-switches (e.g., copying a verification code from another app).
