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

### Run the app

```bash
flutter run
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

The app depends on a local environment file such as `.env` for runtime configuration. Ensure your local setup matches the Supabase and app settings required by this project before starting the app.

## Notes

- The app is localized in Vietnamese and English.
- Branding currently follows the “Kiểm Soát” name used in the app UI.
- Platform identifiers and core app assets are intentionally kept consistent with current project configuration.

## License

This project is currently configured for local/private use and is not published to a public package registry.
