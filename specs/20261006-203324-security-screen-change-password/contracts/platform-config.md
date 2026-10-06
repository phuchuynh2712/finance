# Contract: Platform Configuration (US4)

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

The tracked files below are committed in the form the toolchain produces, so a
clean checkout is unmodified after building. Measured on 2026-10-06 (Flutter
3.47.5, Xcode 26.3, CocoaPods 1.17.0, AGP/Gradle 8.14, JDK 21).

## Files and canonical content

| File | Canonical change vs today |
|------|---------------------------|
| `ios/Flutter/Debug.xcconfig` | + `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"` |
| `ios/Flutter/Release.xcconfig` | + `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"` |
| `ios/Runner.xcodeproj/project.pbxproj` | CocoaPods integration (Pods frameworks, "[CP] Check Pods Manifest.lock", "[CP] Embed Pods Frameworks"), SwiftPM integration (`FlutterGeneratedPluginSwiftPackage`), `IPHONEOS_DEPLOYMENT_TARGET` **13.0 → 15.0** (three build configurations) |
| `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` | + `PreActions` "Run Prepare Flutter Framework Script" |
| `ios/Runner.xcworkspace/contents.xcworkspacedata` | + `group:Pods/Pods.xcodeproj` |
| `android/gradle.properties` | + `android.builtInKotlin=false`, `android.newDsl=false` (with the migrator's comment lines) |
| `web/*` | unchanged (a web build already leaves the tree clean) |

Not committed (ignored by #27): `ios/Podfile`, `ios/Podfile.lock`, `ios/Pods/`,
SwiftPM state, `.DS_Store`. Flutter regenerates the Podfile and runs `pod install`
on every iOS build.

## What must not change

Bundle identifier, signing settings (`DEVELOPMENT_TEAM`, `CODE_SIGN_*`),
Info.plist permissions, Android `applicationId`, permissions and signing, web
`manifest.json`/`index.html`. The single deliberate product-level change is the
iOS deployment target 13.0 → 15.0 (research Decision 10), accepted by the
owner on 2026-10-06.

## Idempotence check (SC-007)

On a clean clone, with only the documented prerequisites installed:

```bash
flutter pub get
flutter build web --debug   --dart-define-from-file=tool/env.json   && git status --short   # empty
flutter build apk --debug   --dart-define-from-file=tool/env.json   && git status --short   # empty
flutter build ios --simulator --debug --dart-define-from-file=tool/env.json && git status --short  # empty
```

`git status --short` must print nothing after each build.

## README contract (FR-014, SC-008)

One "Getting started" section containing, in this order: supported versions
(Flutter ≥ 3.41, Dart ^3.11, verified on 3.47.5); prerequisites per platform
with the exact commands (JDK 17–24 and `flutter config --jdk-dir`,
`xcode-select --switch`, `brew install cocoapods`); the runtime-values table
(`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `WEB_PASSWORD_RESET_REDIRECT_URL`:
meaning, platforms that use it); run commands for web (fixed port), Android
emulator and iOS Simulator; the three known error messages with their fix; and
the final `git status` check. A unit test keeps the README table and
`tool/env.example.json` aligned with `AppEnvironment.keys`.
