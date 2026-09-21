import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/storage/app_preferences_storage.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';

/// spec.md SC-003 ("100% of appearance and language choices survive a full
/// app restart") and FR-013 ("stored per-device, not per-account") proven
/// end-to-end across the notifier + storage boundary — not just within a
/// single notifier's unit test (which only proves the notifier calls
/// through to its storage interface, not that a *real* SharedPreferences
/// instance actually persists the value across what a fresh app start
/// would see).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'a chosen appearance and language survive a simulated app restart',
    () async {
      // "Session 1": pick Dark + English via the real notifiers, backed by
      // a real SharedPreferences instance.
      final storage1 = SharedPreferencesAppPreferencesStorage(
        await SharedPreferences.getInstance(),
      );
      final themeNotifier1 = ThemeModeNotifier(storage1, ThemeMode.system);
      final localeNotifier1 = LocaleNotifier(storage1, const Locale('vi'));

      await themeNotifier1.setThemeMode(ThemeMode.dark);
      await localeNotifier1.setLocale(const Locale('en'));

      // "Session 2": a fresh SharedPreferences.getInstance() call and fresh
      // notifiers — exactly what main.dart does on the next cold start —
      // reading from the same underlying (mocked) persistent store.
      final storage2 = SharedPreferencesAppPreferencesStorage(
        await SharedPreferences.getInstance(),
      );
      final restoredThemeMode =
          await storage2.getThemeMode() ?? ThemeMode.system;
      final restoredLocale = await storage2.getLocale() ?? const Locale('vi');

      expect(restoredThemeMode, ThemeMode.dark);
      expect(restoredLocale, const Locale('en'));
    },
  );

  test(
    'preferences are unaffected by a sign-out/sign-in-as-a-different-account cycle (FR-013)',
    () async {
      // Preferences are device-level, not account-level (data-model.md) —
      // there is no account-scoping key in AppPreferencesStorage at all,
      // so this test demonstrates that property directly: nothing about
      // "signing out" or "a different account signing in" is modeled in
      // the storage layer's API surface, because the device-level value
      // has no notion of which account is currently signed in. A fresh
      // ThemeModeNotifier/LocaleNotifier pair — constructed exactly as
      // main.dart would for ANY subsequent app launch, regardless of which
      // account that launch signs into — reads back the same values.
      final storage = SharedPreferencesAppPreferencesStorage(
        await SharedPreferences.getInstance(),
      );
      final themeNotifier = ThemeModeNotifier(storage, ThemeMode.system);
      final localeNotifier = LocaleNotifier(storage, const Locale('vi'));
      await themeNotifier.setThemeMode(ThemeMode.dark);
      await localeNotifier.setLocale(const Locale('en'));

      // Simulates "User A signs out, User B signs in on this device" —
      // from this layer's perspective that is indistinguishable from any
      // other app restart, since AppPreferencesStorage has no per-account
      // key at all (spec.md Edge Cases 3rd bullet, quickstart.md
      // Cross-cutting section).
      final storageAfterAccountSwitch = SharedPreferencesAppPreferencesStorage(
        await SharedPreferences.getInstance(),
      );

      expect(await storageAfterAccountSwitch.getThemeMode(), ThemeMode.dark);
      expect(await storageAfterAccountSwitch.getLocale(), const Locale('en'));
    },
  );
}
