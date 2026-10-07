# Kiểm Soát

A Flutter personal finance application focused on budgeting, expense control, and spending visibility. The app combines a local-first data layer with Supabase-backed authentication and sync patterns to help users manage income, spending, and long-term budget habits in one place.

## Overview

Kiểm Soát is designed around a practical budgeting workflow:

- manage daily spending and recurring expense inputs
- control category-based budgeting and allocation flows
- review spending balance and budget health at a glance
- keep the experience localized for Vietnamese and English users
- persist user preferences, theme, and app state across sessions
- support secure sign-in flows, including biometric login options

## Core Features

- Budget and expense management
- Income / spending tracking screens
- Expense control workflow with validation and unsaved-change guards
- Local persistence using Drift and SQLite
- Supabase-backed authentication and account flows
- Theme and locale switching with persisted preferences
- Responsive, app-shell navigation using Go Router

## Tech Stack

- Flutter + Dart
- Riverpod for state management
- Drift + sqlite3 for local persistence
- Supabase Flutter for backend/auth integration
- Go Router for navigation
- Intl for localization and formatting
- flutter_secure_storage and SharedPreferences for app state and secure data
- Material 3 styling with a custom brand theme and Lexend font

## Project Structure

```text
lib/
├── core/
│   ├── auth/
│   ├── database/
│   ├── error/
│   ├── l10n/
│   ├── network/
│   ├── router/
│   ├── storage/
│   └── theme/
├── features/
│   ├── account/
│   ├── expenses/
│   └── ...
├── main.dart
└── ...
test/
├── unit/
├── widget/
└── integration/
```

## Getting Started

One setup builds and runs the app on **web, Android and iOS**. Follow the
steps in order; nothing else is required.

### Supported toolchain

| Tool | Requirement |
|------|-------------|
| Flutter | **3.41 or newer** (the first release that ships Dart 3.11). `pubspec.yaml` enforces `flutter: ">=3.41.0"`. Verified on Flutter 3.47.5 / Dart 3.13.4. |
| Dart | `^3.11.0` (comes with Flutter) |
| Android | Android Studio (SDK + emulator) and **JDK 17–24** (21 recommended) — Gradle 8.14 cannot run on a newer JDK |
| iOS | **Full Xcode** (not only the Command Line Tools) selected with `xcode-select`, and **CocoaPods** |
| Web | Chrome (or another Chromium browser) |

Run `flutter doctor` first and fix what it reports for the platforms you want.

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure the runtime values

The app reads its public Supabase values through Dart build defines. Do not put
database passwords, service-role keys or QA account passwords in a Flutter app
or in this file: web builds can be inspected by every browser user.

Copy the example and fill in your own values (`tool/env.json` is git-ignored):

```bash
cp tool/env.example.json tool/env.json
```

Every key below must be present in the file. `tool/env.example.json` is plain
JSON (no comments), so this table is where each key is explained:

| Key | What it is | Used by |
|-----|------------|---------|
| `SUPABASE_URL` | The project URL, `https://<project-ref>.supabase.co`. | Web, Android, iOS |
| `SUPABASE_PUBLISHABLE_KEY` | The project's public (publishable) API key, `sb_publishable_…`. Safe to ship; never use the service-role key. | Web, Android, iOS |
| `WEB_PASSWORD_RESET_REDIRECT_URL` | The fixed URL a web password-reset email links to. Must be `https://`, or `http://localhost` / `127.0.0.1` for local development, and must be on the Supabase project's allowed redirect list. The example value matches `--web-port=5000` below. | Web (required there; ignored on Android and iOS, which use their own deep link) |
| `INACTIVITY_LOCK_SECONDS` | Optional, for manual verification only: seconds of inactivity before the app locks itself. `0` or absent means the product's 5 minutes. Ignored in release builds, so a shipped app can never use a shorter period. | Web, Android, iOS (debug and profile builds) |

If a required value is missing or invalid, the app shows a localized
configuration screen instead of failing during Supabase startup.

### 3. Platform setup

#### Web

Nothing beyond Chrome. Use a fixed port so the origin matches the Supabase
redirect configuration (add that origin, and any deployed one, to the project's
allowed redirect/origin list).

#### Android

1. Install Android Studio, the Android SDK and create an emulator.
2. Gradle 8.14 needs a **JDK between 17 and 24**. Android Studio's bundled JDK
   can be newer (25 at the time of writing), and then the build stops with a
   message that the Java version is incompatible with Gradle 8.14. Point Flutter
   at a compatible JDK (find installed ones with `/usr/libexec/java_home -V`):

   ```bash
   flutter config --jdk-dir "/path/to/jdk-21"
   ```

#### iOS

1. Install **Xcode** from the App Store, open it once, and select it:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

   If this is skipped the build stops with *"Xcode installation is incomplete"*
   or *SDK "iphonesimulator" cannot be located*.
2. Install **CocoaPods**:

   ```bash
   brew install cocoapods
   ```

   Flutter generates `ios/Podfile`, runs `pod install` and writes `ios/Pods/`
   on every iOS build; those files are git-ignored on purpose.
3. The minimum iOS version is **15.0** (the project's plugins and Flutter 3.47
   require it).

### 4. Run the app

```bash
# Web (fixed port, see above)
flutter run -d chrome --web-port=5000 --dart-define-from-file=tool/env.json

# Android emulator (list devices with `flutter devices`)
flutter run -d <emulator-id> --dart-define-from-file=tool/env.json

# iOS Simulator (open one with `open -a Simulator`)
flutter run -d <simulator-id> --dart-define-from-file=tool/env.json
```

Biometric sign-in is automatically unavailable on web because browsers do not
provide the device biometric plugin; the Security screen says so.

### 5. Check the tree is still clean

The tracked platform configuration (`ios/`, `android/gradle.properties`) is
committed in the form the toolchain produces, so building must not modify any
tracked file:

```bash
flutter build web   --debug --dart-define-from-file=tool/env.json
flutter build apk   --debug --dart-define-from-file=tool/env.json
flutter build ios   --simulator --debug --dart-define-from-file=tool/env.json
git status --short   # prints nothing
```

### Generate localizations

This project uses generated localization files (kept in the repository):

```bash
flutter gen-l10n
```

### Run tests

```bash
flutter test
```

## Notes

- The app is localized in Vietnamese and English.
- Branding currently follows the “Kiểm Soát” name used in the app UI.
- Platform identifiers and core app assets are intentionally kept consistent with current project configuration.

## License

This project is currently configured for local/private use and is not published to a public package registry.
