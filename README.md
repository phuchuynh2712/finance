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

### Prerequisites

- Flutter SDK 3.11+ (matches the project configuration)
- Android Studio / Xcode for device emulation if needed
- A working Supabase project and local environment file for app configuration

### Install

```bash
flutter pub get
```

### Configure public runtime values

The app reads its public Supabase URL and publishable key through Dart build
defines. Do not put database passwords or service-role keys in a Flutter app:
web builds can be inspected by every browser user.

Create `tool/env.json` from `tool/env.example.json`, then supply it when
launching or building:

```bash
flutter run --dart-define-from-file=tool/env.json
```

For web development, use a fixed origin and add that origin and any deployed
web origin to the Supabase project's allowed redirect/origin configuration:

```bash
flutter run -d chrome --web-port=5000 --dart-define-from-file=tool/env.json
```

The configuration file contains only `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY`. Keep database passwords, service-role keys, and QA
account passwords outside Flutter build inputs.

### Run the app

```bash
flutter run --dart-define-from-file=tool/env.json
```

### Generate localizations

This project uses generated localization files:

```bash
flutter gen-l10n
```

### Run tests

```bash
flutter test
```

## Configuration

If either required build define is absent or invalid, the app displays a
localized configuration screen instead of failing during Supabase startup.
Biometric sign-in is automatically unavailable on web because browser targets
do not provide the device biometric plugin.

## Notes

- The app is localized in Vietnamese and English.
- Branding currently follows the “Kiểm Soát” name used in the app UI.
- Platform identifiers and core app assets are intentionally kept consistent with current project configuration.

## License

This project is currently configured for local/private use and is not published to a public package registry.
