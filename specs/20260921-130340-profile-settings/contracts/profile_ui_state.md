# UI State Contract: Profile Screen

## Read side — what the Profile screen renders

| Element | Source | Behavior |
|---|---|---|
| Header title/icon | Static (localized string + `LucideIcons.user` badge) | Always shown. |
| Avatar | `AuthRepository.currentAvatarUrl` | Photo if present; otherwise a circular initial-letter placeholder. Initial derived from `currentDisplayName`'s first character, falling back to `currentEmail`'s local-part first character if no display name is set (spec.md Edge Cases). |
| Name | `AuthRepository.currentDisplayName` | Falls back to `currentEmail`'s local part (substring before `@`) if no display name is set. |
| Email | `AuthRepository.currentEmail` | Always shown as-is. |
| Appearance toggle | `ref.watch(themeModeProvider)` | Two options, Light/Dark. Highlights whichever matches the current `ThemeMode`; if current value is `ThemeMode.system`, the toggle shows neither option as active until the user makes an explicit choice (spec.md Acceptance Scenario 1.3). |
| Language row | `ref.watch(localeProvider)` | Shows "Tiếng Việt" or "English" as the current value's label. |
| Menu rows | Static | "Thông báo", "Bảo mật", "Trợ giúp" — always shown, always tappable. |
| Sign out row | Static | Always shown, always tappable. |

## Write side — user actions

| Action | Trigger | Effect |
|---|---|---|
| Tap "Sáng"/"Tối" | Appearance toggle option tap | `ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light | ThemeMode.dark)`. Notifier updates state (triggers immediate app-wide rebuild via `main.dart`'s `ref.watch`) AND persists to `AppPreferencesStorage` in the same call — write-through, not fire-and-forget-then-separately-persisted, so a crash immediately after the tap cannot leave the in-memory state and persisted state diverging. |
| Tap "Ngôn ngữ" row | Row tap | Opens `showDialog` → `SimpleDialog` listing Tiếng Việt / English, current selection indicated (e.g. a check icon or bold label — implementation detail, not contract-relevant). |
| Select a language option in the dialog | `SimpleDialogOption` tap | Dialog closes. `ref.read(localeProvider.notifier).setLocale(Locale('vi' | 'en'))`. Same write-through persistence guarantee as Appearance. |
| Tap "Thông báo" / "Bảo mật" / "Trợ giúp" | Row tap | `Navigator.push` to `NotAvailablePlaceholderScreen` with a title/icon/message distinct per row (research.md's reuse of the existing placeholder widget — no new screen class). |
| Tap "Đăng xuất" | Row tap | Calls the existing sign-out action (`AccountController.signOut` → `AuthRepository.signOut()`, unchanged). On success, the app's existing auth-state-driven routing returns the user to the sign-in flow (no explicit navigation call needed here — this already works today and is unchanged by this feature). |

## Notifier contract

```dart
// lib/core/theme/theme_mode_notifier.dart
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage, ThemeMode initial) : super(initial);
  final AppPreferencesStorage _storage;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.setThemeMode(mode);
  }
}
```

```dart
// lib/core/l10n/locale_notifier.dart
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage, Locale initial) : super(initial);
  final AppPreferencesStorage _storage;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _storage.setLocale(locale);
  }
}
```

Both notifiers apply the in-memory state change **before** awaiting the persistence write, so the UI/app-wide rebuild (SC-001/SC-002's <1s requirement) never waits on disk I/O — persistence happens in the background of the same call. A persistence failure (rare, e.g. disk full) is swallowed at this layer per spec.md's edge case ("corrupted or unreadable... MUST fall back... rather than failing to launch") — the in-memory choice still applies for the current session even if it fails to persist; this is an acceptable degraded mode, not a silent data-loss risk, since no financial data is involved (Constitution's Offline-First guarantees are scoped to financial data, not UI prefs).

## `AppPreferencesStorage` contract

```dart
// lib/core/storage/app_preferences_storage.dart
abstract interface class AppPreferencesStorage {
  Future<ThemeMode?> getThemeMode(); // null = never set
  Future<void> setThemeMode(ThemeMode mode);
  Future<Locale?> getLocale(); // null = never set
  Future<void> setLocale(Locale locale);
}
```

A `SharedPreferencesAppPreferencesStorage` implementation wraps `SharedPreferences`. Read failures (malformed stored value, plugin error) MUST be caught and treated as "never set" (returns `null`), not rethrown — this is what backs the Edge Case requirement that a corrupted preference falls back to the system default rather than crashing the app at launch.
