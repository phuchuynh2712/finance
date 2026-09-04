# Phase 0 Research: Biometric Login & Sign-Up Refactor

## 1. Biometric authentication package

**Decision**: `local_auth: ^3.0.2` (the `flutter.dev`-published, federated package). No need to add `local_auth_android`/`local_auth_darwin` explicitly — they're pulled in transitively as endorsed platform implementations.

**Rationale**: It's the standard, official Flutter biometric package (no credible alternative for cross-platform Face ID + Android biometric in one API). Version 3.0.2 requires Flutter 3.38 / Dart 3.10, compatible with this project's `sdk: ^3.11.0`.

**Critical API facts** (3.x is a breaking rewrite versus older tutorials/any prior team knowledge — do not use the pre-3.0 API shape):

- Capability checks: `canCheckBiometrics` (getter), `isDeviceSupported()`, `getAvailableBiometrics()`.
- Prompt: `authenticate({required String localizedReason, bool biometricOnly = false, bool sensitiveTransaction = true, bool persistAcrossBackgrounding = false, Iterable<AuthMessages> authMessages = ...})` — returns `Future<bool>`. The old `AuthenticationOptions` object, `stickyAuth` (renamed `persistAcrossBackgrounding`), and `useErrorDialogs` (removed, no replacement — this app must build its own fallback UI, which the spec's FR-012 already requires) are gone.
- Errors: throws `LocalAuthException` (not `PlatformException`) with a typed `LocalAuthExceptionCode` enum: `noBiometricHardware`, `noBiometricsEnrolled`, `noCredentialsSet`, `temporaryLockout`, `biometricLockout`, `userCanceled`, `userRequestedFallback`, `timeout`, `deviceError`, `unknownError`, etc.

**Error → spec behavior mapping** (drives FR-008/FR-012/FR-014):

| `LocalAuthExceptionCode` | Spec behavior |
|---|---|
| `noBiometricHardware`, `noBiometricsEnrolled`, `noCredentialsSet` | Device incapable/unenrolled → FR-008 hides the fingerprint button entirely; if it was previously enabled and enrollment was since removed, FR-014 clears the preference |
| `temporaryLockout`, `biometricLockout` | Too many failed OS-level attempts → FR-012 fallback to password fields, no app-level lockout on top of the OS's own |
| `userCanceled`, `userRequestedFallback`, `timeout` | User backed out → FR-012 fallback to password fields, preserve any typed form data |
| `deviceError`, `unknownError` | Treat as a failed attempt → FR-012 fallback, no crash |

**Platform setup**:

- **Android**: `MainActivity` currently extends `FlutterActivity` (`android/app/src/main/kotlin/com/finance/finance/MainActivity.kt`) — **must change to `FlutterFragmentActivity`** (`local_auth_android` requirement; a `BiometricPrompt` needs a `FragmentActivity`). **Confirmed during implementation (T003)**: this project's activity theme did NOT inherit `Theme.AppCompat.*` (all 4 `styles.xml` variants used plain `@android:style/Theme.Light/Black.NoTitleBar`) — `local_auth_android`'s `BiometricPrompt` throws `IllegalStateException` without it on Android 8 and below (`flutter/flutter#47602`, `#55638`). Fixed by changing all 4 files' `LaunchTheme`/`NormalTheme` parents to `Theme.AppCompat.Light.NoActionBar`/`Theme.AppCompat.NoActionBar`, and adding `androidx.appcompat:appcompat:1.7.0` to `android/app/build.gradle.kts` (no explicit androidx dependency existed before). Add `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>` to `AndroidManifest.xml`. `local_auth` 3.x requires **Android API 24+**; **confirmed during implementation**: this installed Flutter SDK (3.41.0)'s own default `minSdkVersion` is already `24` (`flutter_tools/gradle/.../FlutterExtension.kt`), so no `build.gradle.kts` override is needed.
- **iOS**: add `NSFaceIDUsageDescription` to `ios/Runner/Info.plist`. No entitlements needed.

**Alternatives considered**: rolling a custom platform-channel biometric bridge — rejected, reinventing a well-maintained official package for no benefit. `flutter_secure_storage`'s own Android `EncryptedSharedPreferences` biometric-gated variant — rejected; conflates "gate access to a stored secret" with "prompt for biometric," and this feature explicitly does *not* store a secret behind biometric (see §5), it just needs a prompt + boolean result, which `local_auth` provides directly.

---

## 2. Multi-device / multi-session sign-out scopes

**Decision**: `supabase.auth.signOut({SignOutScope scope = SignOutScope.local})`, using:
- `SignOutScope.global` for FR-016a (password reset → sign out everywhere, including the device that completed the reset).
- `SignOutScope.others` for FR-016b (password change from Account screen → sign out every other device, keep the current one signed in).
- `SignOutScope.local` (the existing default, unchanged) for the ordinary sign-out button (FR-014a's trigger).

**Rationale**: This is `supabase_flutter`'s current, stable, built-in API (`^2.8.0`, matching the project's pinned version) — no custom session-tracking table or Edge Function needed.

**Important caveat for implementation**: per the Supabase docs, `SignOutScope.others` does **not** fire an `AuthChangeEvent.signedOut` event on the *current* session (only the other sessions are affected server-side). FR-016b's "keep current device signed in" behavior is therefore automatic/no-op on the calling device — the calling device's `authStateChangesProvider` stream should NOT be expected to emit anything from this call, and the Account screen's "password changed" success UI must not wait on an auth-state event to confirm it worked.

**Alternatives considered**: Supabase Admin API (`auth.admin.signOut(userId, scope)`) — rejected, requires a service-role key that must never ship in a mobile client; the user-scoped `signOut(scope:)` on the client SDK is the correct, safe mechanism here since the acting user is always signing themselves out, not an admin acting on another user.

---

## 3. Password reset (Forgot Password) with a mobile deep link

**Decision**: `supabase.auth.resetPasswordForEmail(email, redirectTo: 'com.finance.finance://reset-callback')`, relying on `supabase_flutter`'s built-in deep-link handling (`FlutterAuthClientOptions.detectSessionInUri` — defaults to `true`, no extra package needed) and listening for `AuthChangeEvent.passwordRecovery` on `onAuthStateChange` to navigate to a new "Set New Password" screen, which then calls `supabase.auth.updateUser(UserAttributes(password: newPassword))`.

**Rationale**: This is Supabase's own documented, current pattern for Flutter — no `app_links`/`uni_links` dependency needed since `supabase_flutter` owns the platform channel itself. `AuthFlowType.pkce` (already the current default) is what makes the emailed link safe to open directly in the app without a fragment-stripping risk from email clients.

**New platform registration required** (net-new — this app has zero deep-link infrastructure today, confirmed by search):
- **Android** `AndroidManifest.xml`: add an `<intent-filter>` to the existing `MainActivity` with `android:scheme="com.finance.finance"` (reverse-domain custom scheme, following Supabase's own quickstart convention), `action.VIEW` + `category.DEFAULT`/`category.BROWSABLE`.
- **iOS** `Info.plist`: add a `CFBundleURLTypes` entry with the same scheme.
- The exact `redirectTo` URL must also be added to the Supabase project's **Auth → URL Configuration → Redirect URLs** allow-list (Dashboard change, same category as the "Enable email confirmations" toggle already flipped for this feature) — an `[EXT]` task, not a code change.
- Custom URL scheme chosen over Android App Links / iOS Universal Links: simpler (no domain hosting of `apple-app-site-association`/`assetlinks.json`, no Associated Domains entitlement), acceptable for a first implementation; the only user-visible cost is a one-time OS "open in app?" style prompt on some platforms/link-open contexts, not a functional gap against FR-015/FR-016.

**Known rough edge to test explicitly during implementation** (flagged by Supabase's own issue tracker, not fully resolved upstream as of this research): the `passwordRecovery` event can be unreliable specifically when the app is **cold-started** by tapping the recovery link (vs. already running in the background) — quickstart.md's manual verification MUST include both cases (app already open vs. app fully closed) rather than assuming the stream-listener approach alone is sufficient; if the cold-start case proves unreliable in practice, a fallback is checking `Supabase.instance.client.auth.currentSession` state directly on app start for a recovery-type session as a backstop.

**Alternatives considered**: OTP-code-based reset (email a 6-digit code instead of a link) — rejected per spec Assumptions, which explicitly scoped this to the existing auth backend's built-in email-link mechanism, not a custom OTP path.

---

## 4. Background-resume lock threshold

**Decision**: Track background duration with `WidgetsBindingObserver.didChangeAppLifecycleState`, persisting a single `APP_LAST_BACKGROUNDED_AT` timestamp via the existing `flutter_secure_storage` instance (reuse, no new dependency) whenever the app transitions to `AppLifecycleState.paused`. On `AppLifecycleState.resumed`, compare `DateTime.now()` against that timestamp; if more than 5 minutes elapsed AND a session exists, set the in-memory lock state to `true` (same as a cold start).

**Rationale**: This is a safety net on top of — not a replacement for — the free, automatic case where the OS has fully killed the app process while backgrounded (in which case `main()` reruns from scratch and FR-020's cold-start gate already fires with zero extra code, since there is no in-memory state to resume at all). The explicit timer exists specifically for the case where the process survives in memory past 5 minutes (varies by device/OS memory pressure, not guaranteed), which is required to satisfy the project constitution's Security section ("app-level lock gating access ... after launch **or resume from background**") deterministically rather than hoping the OS reclaims memory in time.

**Alternatives considered**: rely solely on OS process eviction (discussed and explicitly rejected by the user during clarification — not guaranteed, some devices/memory conditions could leave the app resumable for a long time with no gate); a shorter/longer threshold than 5 minutes — 5 minutes was chosen as a reasonable, common mobile-banking-app default balancing security against not disrupting a brief app-switch (e.g., copying a 2FA code from another app), consistent with the spec's Clarifications.

---

## 5. Where biometric-related state lives on-device

**Decision**: Two new keys in the existing `flutter_secure_storage` instance (no new dependency):
- `BIOMETRIC_ENABLED_<userId>` (boolean, per-account) — the Biometric Login Preference (spec Key Entities). Scoped by `userId` so switching to a different account on the same device can't inherit a stale "enabled" flag left by a previous account (this directly implements FR-013's "no cross-account biometric" requirement without needing extra logic — the check is simply "does a key for *this* signed-in user's id say enabled").
- `APP_LAST_BACKGROUNDED_AT` (timestamp, device-global, not per-account) — supports §4's threshold check.

**Explicitly NOT stored anywhere**: the user's password, or any other durable secret that would let biometric survive a fully-dead session. This is a direct implementation of the spec's Clarifications/Assumptions decision (session-death always falls back to password) and keeps the on-device attack surface unchanged from what `SecureLocalStorage` already stores today (just the Supabase session token, which was already the case before this feature).

**Rationale**: Reuses the one storage mechanism already in the codebase (`flutter_secure_storage`, already a dependency, already the constitution-mandated choice for anything auth-adjacent) rather than introducing `shared_preferences` for a couple of small values — keeps all auth-device-state in one place, one dependency, one mental model.

**Alternatives considered**: a new Drift table for device/session preferences — rejected, this is non-relational, non-financial device-local UI-preference state and the constitution explicitly says such data does not need to go through the relational/offline-sync path; `shared_preferences` (unencrypted) — rejected in favor of reusing the already-present secure storage, avoiding a new dependency for no real benefit (the values are small and infrequent, no performance reason to prefer plain prefs).

---

## 6. App-lock state modeling and router integration

**Decision**: A new Riverpod `StateNotifierProvider` (e.g. `appLockProvider`) holds an in-memory `bool isLocked`, initialized `true` whenever `isSignedInProvider` is true at cold start (i.e., a session already exists), and flipped:
- `true` on `AppLifecycleState.resumed` when the §4 threshold is exceeded.
- `false` the moment biometric succeeds (`local_auth.authenticate()` returns `true`) — no network call, purely local, per the spec's "biometric only unlocks a still-valid session" decision.
- `false` after a normal password sign-in completes successfully (the existing `signInWithPassword` call, unchanged — used as the fallback path on the same reused Login screen, per FR-021).

The existing pure function `computeAuthRedirect({required bool isSignedIn, required String matchedLocation})` in `app_router.dart` gains a third input, `isLocked`, and a corresponding branch: `isSignedIn && isLocked && !isSigningIn` → redirect to `/sign-in` (same route/screen as an ordinary sign-in — the spec explicitly calls for reusing the Login screen as the re-entry gate, not a separate screen/route).

**Rationale**: Keeps the existing, already-unit-tested redirect-logic pattern (`test/unit/core/router/app_router_test.dart`) intact and extends it rather than introducing a parallel gating mechanism; matches the constitution's "widgets MUST only rebuild in response to state they actually depend on" (Principle IV) since `isLocked` is a narrow, independently-watchable provider.

**Alternatives considered**: a separate `/unlock` route with its own screen — rejected, the spec is explicit that the same Login screen serves as the gate, and a second nearly-identical screen would violate the constitution's "a new screen MUST NOT invent a bespoke pattern where an existing one applies" (Principle III).

---

## 7. Removing Google Sign-In — deletion scope

**Decision**: Confirmed via direct code inspection (not guessed) that `kGoogleSignInEnabled` (in `lib/features/account/presentation/google_sign_in_feature_flag.dart`) is already hardcoded `false` — Google Sign-In was never actually turned on for real users despite being built in the prior feature. Deletion scope:
- `lib/features/account/presentation/google_sign_in_feature_flag.dart` — delete file.
- `AuthRepository`: delete `signInWithGoogle()`, `linkGoogleAccount()`, `linkedGoogleEmail`, the private `_authenticateWithGoogle()` helper, and the `google_sign_in` import; remove `linkGoogleAccount`/`linkedGoogleEmail` from the `AccountAuthActions` interface.
- `AccountController`/`AccountState`: delete `isLinkingGoogle`, `linkGoogleErrorMessage`, `linkGoogleAccount()`, `linkedGoogleEmail` passthroughs.
- `AccountScreen`: delete the entire `if (kGoogleSignInEnabled) ...` block and its import.
- `SignInScreen`/`SignUpScreen`: delete `_signInWithGoogle()` and the conditional Google button; `SignUpScreen`'s duplicate-email error message text must be reworded (it currently mentions a Google sign-in fallback that will no longer exist).
- `main.dart`: delete `_initGoogleSignIn()` and its call site.
- `pubspec.yaml`: remove `google_sign_in` dependency.
- iOS: no `Info.plist`/`Runner.entitlements` Google-specific entries were found to need removal (native Google Sign-In on iOS typically needs a `CFBundleURLTypes` reversed-client-ID entry, but the earlier codebase scan found no `CFBundleURLTypes` in `Info.plist` at all — meaning that iOS-side wiring was apparently never completed either, consistent with the flag having always been `false`; nothing to remove there beyond what's already absent).
- `app_vi.arb`/`app_en.arb`: remove now-unused Google-related string keys (button label, error messages, Profile linking section strings) — exact key names to enumerate during implementation by grepping for `google` in both ARB files.

**Rationale**: Since the feature flag was always off, this removal is almost entirely deleting dead/never-shipped-active code paths, not turning off something real users depend on — lower risk than it might otherwise sound, consistent with spec Assumptions ("no production users exist yet on the previous Google Sign-In flow").

---

## 8. New screens' font (Lexend) and asset handling

**Decision**: Bundle Lexend as a local asset declared in `pubspec.yaml`'s `fonts:` section, rather than adding the `google_fonts` package. **Implementation note (confirmed during T002, supersedes the original static-4-files assumption)**: the upstream `google/fonts` source repo only ships Lexend as a single variable font (`ofl/lexend/Lexend[wght].ttf`) — there is no `static/` subfolder for this family (verified via the GitHub API directory listing). One asset entry (`assets/fonts/Lexend-VariableFont_wght.ttf`, no `weight:` pinned) is therefore correct and sufficient: Flutter/Skia resolves `FontWeight.w400/600/700/800` from the font's own `wght` variable axis at render time, covering every weight the mockup spec uses (400/600/700/800) from one file.

**Rationale**: `google_fonts`'s default behavior fetches font files over the network on first use (with a local cache after that) — inconsistent with this being a personal finance app whose constitution mandates offline-first behavior and whose UI is shown immediately at every cold start (including the new re-entry gate from §6, which must never be blocked or visually broken by a missing/unfetched font on a offline first launch). Lexend is an open-source (SIL Open Font License) Google Font — freely downloadable and safe to commit as a binary asset, consistent with this project's existing convention of committing generated/binary assets (icons, splash images) rather than fetching them at runtime.

**Alternatives considered**: `google_fonts` package with `GoogleFonts.config.allowRuntimeFetching = false` plus manually bundling the same files anyway — rejected as strictly more complex than just declaring the fonts directly, for no benefit once the files are being bundled either way.

---

## 9. Existing Sign Up capacity already covers new fields

**Finding (not a decision — a scope-reducing discovery)**: `AuthRepository.signUp()` already accepts optional `displayName`/`phoneNumber` parameters (added in the prior `register-login-google-oauth` feature, stored via Supabase's `data:` user-metadata parameter — the same mechanism `updateAvatar()` uses for `avatar_url`), and the current `SignUpScreen` already has 5 text controllers including name and phone. This feature's Sign Up work is therefore a **visual/layout rebuild and field-requirement adjustment** (email required per this feature's Clarifications, matching mockup order/styling, dropping the confirmation-pending view per FR-019) — not new backend capability, and not a new data model entity beyond what data-model.md documents for completeness.
