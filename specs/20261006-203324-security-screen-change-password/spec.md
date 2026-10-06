# Feature Specification: Security Screen, Change Password, and Platform Config Normalization

**Feature Branch**: `20261006-203324-security-screen-change-password`

**Created**: 2026-10-06

**Status**: Implemented (verified on web, Android and iOS; see `verification/README.md` for what is left open)

**Input**: User description: "chuẩn hóa config và triển khai màn bảo mật và đổi mật khẩu nhé." (normalize the config, and implement the Security screen and change password)

## Background

Observed on `master` (`4e1db0f`) on 2026-10-06:

- The **Bảo mật** (Security) row on the Hồ sơ (Profile) screen opens a "not available yet" placeholder. The Profile redesign (#10) deliberately removed the old password-change flow and the biometric toggle from Hồ sơ and left "reintroducing them" to a separate feature — this one.
- A signed-in person **cannot change their password**. The only path is "Quên mật khẩu?" from the sign-in screen, which sends a reset email and then signs the account out of every device.
- **Biometric login** can currently only be switched on through the one-time offer that appears right after the first sign-in on a device, and can only be switched off by signing out. There is no place to turn it on later (after answering "Để sau") or off without signing out.
- Password length is enforced only on sign-up (6-character minimum, plus a matching confirmation). The email reset screen checks only that the confirmation matches and relies on the service's own minimum, and sign-in checks no length at all.
- Getting iOS and Android to build on a developer machine required steps that are written down nowhere: Android needs a JDK compatible with Gradle 8.14 (the Android Studio bundled JDK 25 is not, so Flutter must be pointed at JDK 17–24), iOS needs `xcode-select` pointed at a full Xcode and CocoaPods installed, and the runtime Supabase values must be supplied from `tool/env.json`. The README says only "Flutter SDK 3.11+" (there is no such Flutter version; the project requires Dart ^3.11 and was verified on Flutter 3.47.5) and "Android Studio / Xcode if needed".
- Building for iOS or Android on the current toolchain rewrites files that are tracked in the repository, so a clean checkout is dirty after the first build: on iOS the Flutter xcconfig files (a standard `Pods` include line is added), the Xcode project file (which also raises the iOS deployment target from 13.0 to 15.0 on every build, because the project's plugins and Flutter 3.47 require it), the shared scheme and the workspace data; on Android `android/gradle.properties` (two Gradle flags added by Flutter 3.47's migrator). Untracked tool output (`Podfile`, `Podfile.lock`, SwiftPM state, `.DS_Store`) is already ignored as of #27.

## Clarifications

### Session 2026-10-06

- Q: What does "chuẩn hóa config" cover — only the tracked iOS/Android platform files, those plus the app's environment configuration, or something else? → A: The whole configuration needed to build and run on every platform (iOS, Android and web): the tracked platform files in their canonical, toolchain-stable form (iOS and Android; a web build must also leave the tree clean), plus one documented, verifiable setup — toolchain prerequisites and the runtime values — so that a new machine can build and run all three platforms with no undocumented step.
- Q: After a successful password change, what happens to the account's sessions on other devices? → A: They are signed out; the device where the password was changed stays signed in (no opt-out checkbox).
- Q: The toolchain forces the iOS deployment target from 13.0 to 15.0 on every build; should the canonical config accept 15.0? → A: Yes. The owner accepted it on 2026-10-06; the app is unreleased, so no user on iOS 13 or 14 is affected.
- Q: What minimum password length should apply? → A: At least 8 characters everywhere a password is set — sign-up, the email reset and the new change-password flow (revised by the owner on 2026-10-06 from an earlier "keep 6" answer, because 6 is too weak for a finance app). The app is not released yet, so no account has a shorter password and no compatibility or migration handling is needed; sign-in is unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open the Security screen and change my password (Priority: P1) 🎯 MVP

A signed-in person opens Hồ sơ, taps **Bảo mật**, and sees a real Security screen instead of a placeholder. From it they choose **Đổi mật khẩu**, enter their current password, a new password and its confirmation, and submit. The password is changed, they stay signed in on this device, and they see a clear confirmation. The next time they sign in (here or elsewhere) only the new password works.

**Why this priority**: Changing a password is the core security action a finance app owes its users — today it is impossible without a reset email and a forced sign-out everywhere. It is also what turns the placeholder row into a working screen, so it is the smallest slice that delivers value on its own.

**Independent Test**: Sign in, open Hồ sơ → Bảo mật → Đổi mật khẩu, change the password with the correct current password, sign out, and sign in with the new password (the old one must be rejected).

**Acceptance Scenarios**:

1. **Given** a signed-in person on Hồ sơ, **When** they tap Bảo mật, **Then** the Security screen opens (not the "not available" placeholder), with the app's navigation still visible and Back returning to Hồ sơ.
2. **Given** the change-password form, **When** they enter the correct current password, a valid new password and a matching confirmation and submit, **Then** the password is changed, a confirmation is shown, the form is cleared, and they remain signed in on this device.
3. **Given** a successful change, **When** the person signs in again, **Then** the new password works and the old password is rejected.
4. **Given** the form, **When** the current password is wrong, **Then** a clear message says so, nothing is changed, and the person can correct and retry.
5. **Given** the form, **When** the new password is shorter than the minimum, equals the current password, or does not match its confirmation, **Then** a specific inline message explains the problem and the change is not attempted.
6. **Given** a submit in progress, **When** the person presses submit again, **Then** only one change is attempted.
7. **Given** no network or a server error, **When** the person submits, **Then** a friendly message is shown, the password is unchanged, and the entered values are kept so they can retry.
8. **Given** the password was changed on this device, **When** the same account is signed in on another device, **Then** that device is signed out (immediately where the service allows, at the latest when its current session period ends).
9. **Given** the password was changed but signing out the other devices did not succeed (for example the connection dropped at that moment), **When** the person is back on the Security screen, **Then** they are told plainly that other devices may still be signed in and can retry that one step with a single action, without changing the password again; when the retry succeeds they see a confirmation and the notice disappears.
10. **Given** this device's own sign-in has expired or been revoked (for example by a password change on another device), **When** the person submits the form, **Then** the password is not changed, they are told their session has ended, and they are taken to sign in.

---

### User Story 2 - Turn biometric login on or off whenever I want (Priority: P2)

On the same Security screen the person sees **Đăng nhập bằng vân tay** as a switch showing the real current state on this device. They can turn it on later (even if they once chose "Để sau") or off without signing out. Turning it on asks for one successful biometric check to confirm it works; turning it off takes effect immediately. If the device or browser cannot do biometrics, the switch is disabled with a short explanation instead of failing silently.

**Why this priority**: It closes the gap that biometric login can only be enabled once and disabled by signing out. It is valuable but depends on the Security screen existing (Story 1) and does not block changing a password.

**Independent Test**: On a biometric-capable device, switch it on (confirm with a biometric check), lock the app and see the biometric button on the lock screen; switch it off and confirm the button is gone. On web, confirm the switch is disabled with an explanation.

**Acceptance Scenarios**:

1. **Given** biometric login is off on a capable device, **When** the person turns the switch on and passes the biometric check, **Then** it shows on, and the lock screen offers biometric sign-in from then on.
2. **Given** the person turns the switch on, **When** the biometric check fails or is cancelled, **Then** the switch stays off and nothing is enabled.
3. **Given** it is on, **When** the person turns it off, **Then** it takes effect immediately with no extra check, and the lock screen no longer offers the biometric button.
4. **Given** the person previously answered "Để sau" to the post-sign-in offer, **When** they open the Security screen, **Then** the switch is off and can be turned on.
5. **Given** a device with no biometric hardware or no enrolled biometrics, or the web, **When** the Security screen opens, **Then** the switch is disabled and a localized note explains why.
6. **Given** biometric login is on, **When** the person changes their password, **Then** the biometric setting is unchanged.

---

### User Story 3 - A stronger minimum password length everywhere a password is set (Priority: P2)

Whenever a person sets a password — creating an account, finishing a reset by email, or changing it from the Security screen — the app requires at least 8 characters, says so up front, and explains clearly when a password is too short. Sign-in itself is unchanged.

**Why this priority**: A 6-character minimum is weak for a finance app, and the owner asked for at least 8. It is independent of the Security screen (it also changes sign-up and the email reset), so it is its own story, ranked after the change-password MVP.

**Independent Test**: Try 7 and 8 characters in sign-up, in the email reset and in change password (7 rejected with a clear message, 8 accepted).

**Acceptance Scenarios**:

1. **Given** the sign-up form, **When** the password has 7 characters or fewer, **Then** a specific message says at least 8 characters are required and no account is created; with 8 characters sign-up proceeds.
2. **Given** the "set new password" screen reached from a reset email, **When** the new password has 7 characters or fewer, **Then** the same message is shown before any attempt and the password is not changed.
3. **Given** the change-password form, **When** the new password has 7 characters or fewer, **Then** the same message is shown before any attempt.
4. **Given** each of those forms, **When** the person looks at them before typing, **Then** the 8-character requirement is visible, in Vietnamese or English.
5. **Given** the service still accepts shorter passwords, **When** an attempt reaches it with fewer than 8 characters, **Then** it must not be possible from the app (the client check stops it) — and the service-side minimum is raised to match so the rule cannot be bypassed.

---

### User Story 4 - Build and run every platform from one documented, stable configuration (Priority: P3)

A maintainer (or a new contributor on a fresh machine) follows the documented setup, then builds and runs the app on web, Android and iOS. Every step they need — which toolchain versions and settings, which runtime values to supply — is written down, the example runtime-values file is complete, and building leaves `git status` clean because the tracked platform configuration files already contain exactly what the toolchain wants.

**Why this priority**: It is repository and onboarding hygiene with no product behavior, but today the first mobile build needs undocumented steps (JDK choice, `xcode-select`, CocoaPods) and then dirties tracked files, which invites accidental commits of tool churn. It is independent of the product stories.

**Independent Test**: On a clean checkout, follow only the documented setup, build for web, the Android emulator and the iOS Simulator, run `git status`, and confirm no tracked file is modified and nothing outside the documentation was needed.

**Acceptance Scenarios**:

1. **Given** a clean checkout on the supported toolchain, **When** the app is built for the iOS Simulator, **Then** no tracked file is modified (the Flutter xcconfig files, the Xcode project, the shared scheme and the workspace data included).
2. **Given** a clean checkout, **When** the app is built for Android, **Then** no tracked file is modified (`android/gradle.properties` included).
3. **Given** a clean checkout, **When** the app is built for web, **Then** no tracked file is modified.
4. **Given** the documented setup, **When** a developer follows it on a machine whose default tools are not suitable (for example an IDE-bundled JDK that Gradle cannot use), **Then** the documentation tells them the supported versions and exactly how to select them, and the build then succeeds.
5. **Given** the example runtime-values file and the setup documentation, **When** a developer copies the example and fills in their values, **Then** every value the app needs on every platform is present in the example, and the documentation says for each one what it is and which platforms use it (the example is plain JSON, which has no comments, so the explanation lives in the documentation).
6. **Given** the normalized configuration, **When** the app is built and run on web, Android and iOS, **Then** it behaves exactly as before: same bundle identifier, signing settings and permissions, with the iOS deployment target at the toolchain's required 15.0 (see Assumptions).

---

### Edge Cases

- **Session no longer valid**: if this device's sign-in has expired or been revoked while the person is on the Security screen (including by a password change made on another device), the password change is not attempted and must not appear to succeed; the person is told their session has ended and is taken to sign in. Turning biometric login on or off is a setting stored on this device and does not depend on the session.
- **Signing out other devices fails after the password changed**: the password change stands (telling the person it failed would make them retry with a current password that no longer works); they are told that other devices may still be signed in and can retry just that step from the Security screen.
- **Offline**: changing the password needs the network; offline the person gets a clear message and no partial change. Turning biometric login off works offline; turning it on only needs the device check.
- **Leaving mid-way**: leaving the change-password form discards typed values; nothing is stored, and the Security screen never shows a password.
- **Accidental repeat**: double-taps and pressing Enter twice must not trigger two changes.
- **Biometric enrollment removed later**: if the person removes their enrolled biometrics after turning the switch on, the switch must reflect that the feature is no longer usable (and the existing sign-in behavior that turns it off stays valid).
- **Password managers and keyboards**: the three password fields must be recognizable to password managers (current vs new) and operable by keyboard on web and desktop-sized windows.
- **Language and theme**: every message exists in Vietnamese and English; the screen is correct in light and dark appearance and at compact and wide window sizes.
- **Length counting**: length is counted in characters (Unicode code points, so an accented Vietnamese letter or an emoji counts as one) exactly as typed — no trimming, no composition rules such as digits or symbols.
- **Client and service disagree**: if the service rejects a password the app accepted (for example a different server minimum), the person sees a friendly localized message, never a raw error.
- **Never logged**: current, new and confirmation passwords never appear in logs, error reports or analytics.
- **Platform config changes must not alter product behavior**: normalizing config files must not change bundle identifiers, signing, permissions or the web build; the only intended product-level change is the iOS deployment target moving to the toolchain's required 15.0.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Bảo mật row on Hồ sơ MUST open a real Security screen (replacing the "not available" placeholder), reachable at its own addressable location, keeping the app's navigation chrome visible, with Back returning to Hồ sơ.
- **FR-002**: The Security screen MUST offer two things: **Đổi mật khẩu** (change password) and the **Đăng nhập bằng vân tay** switch, grouped and labelled consistently with the rest of Hồ sơ.
- **FR-003**: The change-password form MUST collect the current password, the new password and its confirmation, each with a show/hide control, and MUST validate before any attempt: the new password meets the app-wide minimum length (8 characters), differs from the current password, and matches its confirmation, with a specific localized message for each failure.
- **FR-004**: The system MUST verify the current password before changing it; a wrong current password MUST leave the account unchanged and show a clear message, and repeated failures MUST surface the service's throttling message rather than hang.
- **FR-005**: On success the system MUST change the password, show a confirmation, clear the form, keep the person signed in on this device, and sign the account out of every other device (immediately where the service supports it, otherwise no later than the end of that device's current session period). Before changing anything it MUST confirm that this device's own sign-in is still valid; if it is not, nothing is changed and the person is taken to sign in. If signing out the other devices fails after the password was changed, the person MUST be told plainly and MUST be able to retry that step alone, from the Security screen, without changing the password again.
- **FR-006**: Errors (wrong current password, weak or rejected password, expired session, offline, server failure) MUST map to friendly localized messages through the app's shared error handling; entered values MUST be kept on retryable failures; submission MUST be single-flight.
- **FR-007**: The biometric switch MUST reflect the real stored preference for this account on this device. Turning it on MUST require one successful biometric check; turning it off MUST take effect immediately; the preference MUST remain per account and per device and MUST stay consistent with the post-sign-in offer and the lock screen's biometric button.
- **FR-008**: Where biometrics are unavailable (no hardware, none enrolled, or web), the switch MUST be disabled with a localized explanation and MUST never fail silently.
- **FR-009**: Changing the password MUST NOT change the biometric preference.
- **FR-010**: All new text MUST exist in Vietnamese (default) and English; the screen MUST support light and dark appearance and the adaptive layouts (compact bottom bar, rail and capped content width at wider sizes), follow the existing design tokens, offer ≥ 48×48dp touch targets, semantic labels, hover/tooltip/keyboard operability, and use autofill-friendly roles for the password fields.
- **FR-011**: Passwords MUST NOT be written to logs, crash reports or analytics, and MUST NOT be retained after the form is left.
- **FR-012**: The tracked iOS and Android platform configuration files that the toolchain rewrites on every build MUST be committed in the toolchain's canonical form, and a web build MUST also leave every tracked file unchanged, so a clean checkout stays unmodified after building for web, Android and iOS; the change MUST NOT alter bundle identifiers, signing settings, permissions, or the behavior of any platform; the single exception is the iOS deployment target, which becomes the toolchain's required 15.0 (research Decision 10).
- **FR-013**: Existing behavior MUST be preserved: sign-in, sign-up, "Quên mật khẩu?" reset by email, the lock screen, sign-out and the Hồ sơ rows other than Bảo mật.
- **FR-014**: The repository MUST document, in one place, everything needed to build and run on web, Android and iOS: the supported Flutter/Dart versions (stated correctly), the Android JDK requirement and how to select a compatible JDK, the iOS requirements (full Xcode selected, CocoaPods) and the runtime values — a complete example file whose keys match exactly what the app reads, with every key described in that documentation (what it is and which platforms use it). A developer MUST NOT need any step that is not in that documentation.
- **FR-015**: Every flow that sets a password — sign-up, completing the email reset, and change password — MUST require at least 8 characters, state the requirement on the form, and reject shorter passwords before any attempt with a specific localized message (Vietnamese and English). Sign-in is unchanged. The service-side minimum MUST be raised to at least 8 so the rule cannot be bypassed outside the app.

### Key Entities *(include if feature involves data)*

- **Password policy**: a single app-wide minimum (8 characters) applied wherever a password is set, never when signing in.
- **Account credentials**: the person's password, changed through this feature; never displayed or stored by the app.
- **Biometric preference**: a per-account, per-device on/off setting that already exists; this feature adds a place to read and change it.
- **Other sessions**: the same account signed in on other devices; they are ended when the password changes.
- **Platform configuration files**: the tracked iOS and Android files listed in Background; they hold build configuration only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A signed-in person can change their password from Hồ sơ in under 60 seconds with three fields and one confirmation.
- **SC-002**: 100% of attempts with a wrong current password leave the password unchanged, and 100% of invalid inputs are stopped before any attempt with a specific message.
- **SC-003**: After a successful change, the new password signs in and the old one is rejected on web, Android and iOS.
- **SC-004**: After a change, every other signed-in device of the account ends up signed out; none stays signed in past its current session period. If that step fails, the person is told within the same flow and can retry it with one action; the app never reports it as done when it was not.
- **SC-005**: The biometric switch matches reality in 100% of a test matrix (capable device on/off, cancelled check, "Để sau" earlier, no enrollment, web): the lock screen offers the biometric button exactly when the switch is on.
- **SC-006**: The "not available" placeholder is gone for Bảo mật, and every string on the new screens exists in both languages with 0 hard-coded text; light and dark and compact and wide layouts are verified.
- **SC-007**: After building for web, Android and iOS on the supported toolchain from a clean checkout, `git status` reports 0 modified tracked files, and the apps run unchanged on all three platforms.
- **SC-008**: A person following only the documented setup on a clean checkout builds and runs web, Android and iOS with 0 undocumented steps, and the example runtime-values file has 0 missing or undocumented keys compared with what the app reads.
- **SC-009**: In sign-up, email reset and change password, 100% of passwords with 7 characters or fewer are rejected with the specific message before any attempt and 8-character passwords are accepted.

## Assumptions

- **No mockup exists** for the Security screen (the original Profile design left the destination undefined). The screen follows the existing design system and Profile patterns; icons come from the maintained icon package exactly as published (no new or hand-drawn glyphs), and any custom artwork would be supplied by the owner.
- **iOS deployment target 15.0** (planning finding, 2026-10-06): every iOS build rewrites 13.0 to 15.0 because the project's plugins and Flutter 3.47 require it, so the toolchain does not let a 13.0 value stand. The app is unreleased, so no user on iOS 13 or 14 is affected; accepted by the owner on 2026-10-06.
- **"Chuẩn hóa config"** means the whole configuration needed to build and run on iOS, Android and web (clarified 2026-10-06): the tracked platform files in canonical form plus one documented setup. It does not mean changing Flutter, Gradle or plugin versions beyond what is needed to remove the churn; whether the Android Gradle version should be raised so the Android Studio bundled JDK works is a planning decision (default: document the JDK requirement instead).
- **Password policy** is a minimum of 8 characters with no composition rules (owner decision, 2026-10-06). Supabase, the service that holds the accounts, has its own password-length rule (default 6) that is set in its web dashboard, not in this repository. The app's check stops short passwords before sending them, but the service would still accept a 6- or 7-character password from any other client, so the owner must also set the service's minimum to 8 in the dashboard (done and verified on 2026-10-06: a 7-character sign-up request is rejected with HTTP 422 `weak_password`) (Authentication → email sign-in settings → Minimum password length; the label can differ slightly between dashboard versions). The app is not released, so no account has a shorter password and nothing needs migrating (owner, 2026-10-06). A strength meter and breached-password checks are not part of this feature.
- **Current-password check** is required before a change, even for a signed-in person, because a finance app should not let an unattended unlocked device change the credential silently; the service-side setting for secure password change may add its own recent-sign-in requirement, handled in planning.
- **Other devices are signed out** after a change and this device stays signed in (confirmed by the owner on 2026-10-06; no opt-out option).
- **Enabling biometric login confirms with a check** so a person cannot switch on something that cannot work; the existing post-sign-in offer keeps its current behavior.
- **Web**: biometrics are unavailable, so the switch is shown disabled with an explanation. The constitution's requirement of a PIN fallback for the app-level lock on platforms without biometrics is a pre-existing gap and not part of this feature.
- **Verification** follows the previous feature's practice: web, Android emulator and iOS Simulator with the QA test account, light and dark, compact and wide.

## Out of Scope

- A PIN code or any other new app-lock method, multi-factor authentication, a list of active sessions with per-device sign-out, changing the email address, deleting the account.
- Building the Notifications and Help screens (their placeholders stay).
- Fixing the pre-existing cold-start lock race recorded in `specs/20261005-211030-fix-lucide-icons-compat/research.md`, and the `maybeShowBiometricEnablePrompt` timing dependency noted there. The race sits in the app-lock initialization that every sign-in path shares, was recorded as unconfirmed, and needs its own reproduction and tests; this feature neither changes the lock nor depends on its cold-start behavior. The reasoning and the pointer for whoever picks it up are in `plan.md` Complexity Tracking.
- Password composition rules (uppercase, digits, symbols), a strength meter, breached-password checks; sign-up and the email reset change only by the length rule.
- Committing `ios/Podfile.lock` or reproducible pod versions (they are ignored by #27), CI configuration, and upgrading Flutter, Gradle or plugin versions beyond what removing the churn requires.
