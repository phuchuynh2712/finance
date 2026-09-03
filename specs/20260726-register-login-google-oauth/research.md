# Research: Registration & Google Sign-In

## 1. Native Google Sign-In with supabase_flutter

**Decision**: Use `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: ..., accessToken: ...)` fed by the `google_sign_in` package's native account chooser — not the browser/webview OAuth redirect flow (`signInWithOAuth`).

**Rationale**: The spec's Assumptions section already commits to a native flow (Android account chooser / iOS equivalent), and `signInWithIdToken` is exactly that: the Google ID token is verified server-side and a Supabase session is established directly, with no browser tab/webview ever shown. This matches SC-002's "under 15 seconds excluding the OS-level account chooser" target, since there's no redirect round-trip to add latency.

**Important dependency on §6**: this same server call is also what performs FR-008's automatic account linking when the Google email matches an existing user. See §6 for the actual safety mechanism (it does not depend on email confirmation being enabled).

**Alternatives considered**: `signInWithOAuth` (browser/PKCE redirect) — rejected because it requires a deep-link redirect URI, shows a browser chrome the user didn't ask for, and is slower; not needed here since native `google_sign_in` covers both platforms.

## 2. google_sign_in package version and call sequence

**Decision**: Add `google_sign_in: ^7.2.0` (current stable). Use the v7 API: `GoogleSignIn.instance.initialize(serverClientId: ..., clientId: ...)` once at startup, then `attemptLightweightAuthentication()` for silent sign-in attempts and `authenticate()` for the interactive account chooser. Scopes/accessToken are obtained separately via `authorizationClient.authorizationForScopes(scopes)` (falling back to `authorizeScopes(scopes)` if null).

**Rationale**: v7 is a breaking rewrite from v6 (singleton `.instance`, mandatory `initialize()`, split authentication vs authorization). Since this is a brand-new integration (no existing `google_sign_in` usage in the codebase to preserve compatibility with), there's no reason to pin the older v6 API.

**Alternatives considered**: `google_sign_in: ^6.x` — rejected; no existing code depends on it, and starting on the current major avoids an immediate future migration.

**Caveat**: Supabase's own official Flutter guide still shows pre-v7 example code as of this research ([tracked in supabase/supabase#36775](https://github.com/supabase/supabase/issues/36775), open). Implementation tasks must follow the v7 API shape above, not copy the doc's code sample verbatim.

## 3. Linking a Google identity to an already-signed-in user (User Story 4)

**Decision**: Use `supabase.auth.linkIdentityWithIdToken(provider: OAuthProvider.google, idToken: ..., accessToken: ...)` — the native (non-browser) counterpart to `linkIdentity()`. Available on `GoTrueClient` since `gotrue ^2.15.0`; this project's resolved versions (`gotrue 2.26.0`, `supabase_flutter 2.16.0` per `pubspec.lock`) already satisfy this under the existing `supabase_flutter: ^2.8.0` constraint — **no dependency version bump required**.

**Rationale**: This is the only native (no browser/deep-link) linking API and directly maps to FR-016 (link Google from Profile while already signed in).

**Error handling this maps to spec requirements**:
- If the Google identity is already linked to a *different* existing account → the call throws an `AuthApiException` with error code `identity_already_exists` → maps directly to FR-017 / User Story 4 Scenario 3 (reject, no linkage change).
- **Project prerequisite**: this API requires **"Enable Manual Linking"** to be turned on in Supabase Dashboard → Authentication → Settings (self-hosted equivalent: `GOTRUE_SECURITY_MANUAL_LINKING_ENABLED=true`). Without it, the call fails with `manual_linking_disabled`. This is a one-time project configuration step, not code — captured as a setup step in `quickstart.md` and as a task, since forgetting it would surface as a confusing runtime error rather than a build failure.

**Alternatives considered**: `linkIdentity()` (browser/PKCE redirect) — rejected for the same reason `signInWithOAuth` was rejected in §1: this project has no deep-link redirect URI configured and the native flow is faster and simpler for a mobile-only app.

## 4. Required external setup (Google Cloud Console + Supabase Dashboard)

**Decision**: Three OAuth client IDs must be created in Google Cloud Console:
- **Web** client ID — used as `serverClientId` in `google_sign_in`'s `initialize()` call, and pasted into Supabase Dashboard → Auth → Providers → Google (Client ID + Secret). This is what actually verifies the ID token server-side, for both sign-in and linking, on both platforms.
- **Android** client ID — requires the app's SHA-1 signing fingerprint(s) (separate values for debug and release keystores).
- **iOS** client ID — requires the Bundle ID.

iOS additionally needs a `CFBundleURLTypes` entry in `Info.plist` with the **reversed iOS client ID** as the URL scheme. This is required by Google's iOS SDK to return control to the app after the native account chooser — it is needed even though no browser/webview is shown, since it's part of Google's iOS SDK's own inter-app handoff, not the Supabase OAuth redirect mechanism.

**Rationale**: This is Supabase's own documented setup for native Google Sign-In and has no simpler alternative — the Web client ID's dual role (native token audience + Dashboard config) is a Google/Supabase requirement, not a project choice.

**Current state** (from codebase survey): none of this exists yet — no `google_sign_in` dependency, no Google OAuth client config in `android/app/build.gradle.kts` or `AndroidManifest.xml`, no `CFBundleURLTypes` in `ios/Runner/Info.plist`, and Manual Linking's Dashboard state is unknown (external to the repo). All of these become setup tasks, not just code tasks.

## 5. Session/token storage — pre-existing gap, fixed inline in this feature

**Finding**: `supabase_flutter`'s `Supabase.initialize()` (called in `lib/core/network/supabase_client_provider.dart`) was invoked with no custom `LocalStorage`, meaning it defaulted to `SharedPreferences` for session persistence — not Keychain/Keystore-backed secure storage. The constitution's Security section requires secure platform storage for auth tokens ("never in SharedPreferences"). `flutter_secure_storage: ^9.2.2` was already a dependency in `pubspec.yaml` but was not wired into Supabase's `authOptions`.

**Scope decision (revised)**: Originally flagged as a pre-existing gap out of scope for this plan. Since the user explicitly asked for the most secure design and this branch already touches `core/auth/`-adjacent code, the fix was applied inline rather than deferred:
- `lib/core/storage/secure_local_storage.dart` (NEW): a `LocalStorage` implementation backed by `FlutterSecureStorage`, implementing the 5-method abstract contract (`initialize`, `hasAccessToken`, `accessToken`, `persistSession`, `removePersistedSession` — verified against `supabase_flutter` 2.16.0's actual `local_storage.dart` source; there is no built-in secure-storage `LocalStorage`, so hand-writing this small class is the only option, matching supabase_flutter's own documented "bring your own storage" pattern).
- `lib/core/network/supabase_client_provider.dart`: `Supabase.initialize()` now passes `authOptions: FlutterAuthClientOptions(localStorage: const SecureLocalStorage())`.
- `android/app/src/main/AndroidManifest.xml`: added `android:allowBackup="false"` — without this, Android's auto-backup/restore can attempt to restore an `EncryptedSharedPreferences`-backed Keystore file to a device where the original Keystore key doesn't exist, throwing `InvalidKeyException` on next read.
- iOS: `flutter_secure_storage` may need a Keychain Sharing entitlement added via Xcode on first iOS build — **not applied here**, since no `.entitlements` files exist in this project yet and creating them correctly requires a macOS/Xcode environment to verify, not something to hand-edit blind from Windows.

**Caveat**: any user already signed in via the old `SharedPreferences`-backed session will be signed out on first launch after this change (the new secure storage starts empty). Acceptable for this pre-release app.

**Alternatives considered**: Deferring the fix as originally planned — rejected once the user explicitly asked for the most secure design for this branch; the fix is small (~25 lines across 2 files, no new abstractions) and touches the same `core/auth`-adjacent area this feature is already modifying. `MigrationLocalStorage` (supabase_flutter's built-in Hive→SharedPreferences migration helper, adapted to migrate old→new storage) — rejected as unnecessary complexity for a pre-release app with no real users to preserve sessions for.

## 6. Supabase's actual account-linking behavior on `signInWithIdToken`, and why it is safe as-is (two research passes — see note below)

**Finding, verified against GoTrue server source** (`supabase/auth`, `internal/api/external.go`'s `createAccountFromExternalIdentity` → `internal/models/linking.go`'s `DetermineAccountLinking`): when `signInWithIdToken` is called with a Google account whose email matches an existing user's email, GoTrue **unconditionally auto-links** the new Google identity to that existing user and signs them in — no error, no confirmation step, and **no project setting disables this for the ordinary sign-in path**. The separate `GOTRUE_SECURITY_MANUAL_LINKING_ENABLED` ("Manual Linking") toggle only gates the *explicit*, already-authenticated `linkIdentity`/`linkIdentityWithIdToken` calls (§3) — it has no effect here.

**Why this reversed the spec's original FR-008** (initially: "never auto-link, reject and direct to email/password sign-in"): implementing that original requirement would need a custom pre-check — "does an unlinked password account already exist for this email?" — run *before* calling `signInWithIdToken`. That check is itself a security problem: it's a user-enumeration endpoint (an unauthenticated way to test whether an email is registered), which trades one risk for another rather than eliminating it. Given that, the original FR-008 as stated was not cheaply implementable, and was surfaced back to the user as a follow-up clarification (spec.md Clarifications, session 2).

**First-pass (incorrect) conclusion, corrected below**: an initial research pass found that `DetermineAccountLinking`'s candidate query filters on `email.Verified` and concluded that requiring email confirmation (reversing FR-015) would make auto-linking safe. This was wrong: `email.Verified` there refers to the **incoming** Google identity's `email_verified` claim (always true for a real Google account), not the **existing** candidate user's own confirmation status — so gating registration behind email confirmation has no effect on this check at all, and does not by itself close the pre-registration takeover risk.

**Second-pass (correct) finding — the actual safety mechanism**: the real protection lives one step further down the same code path, in `internal/api/external.go` immediately after the `LinkAccount` switch case, and is **unconditional** (independent of whether the project requires email confirmation):

```go
hasEmails := providerType != "web3" && !(emailOptional && decision.CandidateEmail.Email == "")
if hasEmails && !user.IsConfirmed() {
    // The user may have other unconfirmed email + password combination,
    // phone or oauth identities. These identities need to be removed when
    // a new oauth identity is being added to prevent pre-account takeover
    // attacks from happening.
    if terr = user.RemoveUnconfirmedIdentities(tx, identity); terr != nil { ... }
    ...
}
```

Here, `user` is `decision.User` — the **pre-existing** account being linked into. `RemoveUnconfirmedIdentities` (`internal/models/user.go`) destroys every other identity on that row (including nulling `EncryptedPassword`) and overwrites its metadata with the incoming Google identity's data, whenever that pre-existing account is not yet confirmed. GoTrue's own source comment names the exact scenario: *"prevent pre-account takeover attacks from happening."*

**Why this closes the attack without needing FR-015 changed**: consider the attack — someone registers `victim@gmail.com` with a password they control, hoping the real owner's later Google sign-in silently attaches to their account. To reach a state where their fraudulent account survives this eviction, the attacker would need `user.IsConfirmed()` to already be true on their row — but confirming that row requires clicking a confirmation link sent to `victim@gmail.com`, an inbox the attacker does not control. The attacker's account is therefore *always* unconfirmed at the moment the real owner signs in with Google, so `RemoveUnconfirmedIdentities` always fires and evicts the attacker's password identity, regardless of whether the project's own "Confirm email" setting is on or off — that setting affects the *legitimate* email/password flow's UX, not this eviction path.

**Decision**: Keep FR-015 as originally specified — sign in immediately after email/password registration, no confirmation step required. Implement FR-008 as: call `signInWithIdToken` directly; whatever account it resolves to is correct and safe by construction, with no client-side branching needed — Supabase's server-side linking-plus-eviction behavior already handles every case (new account, already-linked account, or auto-link into an existing account, safely evicting any squatting unconfirmed identity in the process).

**Residual, out-of-scope risk worth naming explicitly**: this protection assumes the *only* way to reach `IsConfirmed() == true` on a row is a genuine confirmation-link click (or Google's own sign-in path, which auto-confirms). If some other, unrelated bug or admin action could mark a row confirmed without proving email ownership, this protection would not apply to that row. This is a property of the Supabase Auth server itself, not something this feature's design can control beyond noting it.

**Alternatives considered**:
- Custom Edge Function/RPC to check email existence before Google sign-in — rejected; introduces a user-enumeration surface and is unnecessary once the above mechanism is understood to already be safe.
- Requiring email confirmation before sign-in (the first-pass conclusion) — rejected on reflection; it doesn't gate the mechanism that actually provides safety, and would have added user friction (SC-001's <60s target, a "check your email" holding screen) for no protective benefit.

**Process note**: this finding required two research passes because the first pass paraphrased which "verified" flag was being checked, rather than tracing the *existing* user's row through to the actual `LinkAccount` switch case and everything executed after it. The corrected finding is based on directly-quoted source from both `internal/models/linking.go` and `internal/api/external.go`/`internal/models/user.go`.

