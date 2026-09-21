import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/storage/app_preferences_storage.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';

class _FakeAppPreferencesStorage implements AppPreferencesStorage {
  ThemeMode? storedThemeMode;
  Locale? storedLocale;
  bool throwOnSetThemeMode = false;

  @override
  Future<ThemeMode?> getThemeMode() async => storedThemeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    if (throwOnSetThemeMode) {
      throw Exception('simulated storage write failure');
    }
    storedThemeMode = mode;
  }

  @override
  Future<Locale?> getLocale() async => storedLocale;

  @override
  Future<void> setLocale(Locale locale) async {
    storedLocale = locale;
  }
}

void main() {
  test('constructed with an initial value reflects it as state', () {
    final notifier = ThemeModeNotifier(
      _FakeAppPreferencesStorage(),
      ThemeMode.dark,
    );
    expect(notifier.state, ThemeMode.dark);
  });

  test('setThemeMode updates state and writes through to storage', () async {
    final storage = _FakeAppPreferencesStorage();
    final notifier = ThemeModeNotifier(storage, ThemeMode.system);

    await notifier.setThemeMode(ThemeMode.light);

    expect(notifier.state, ThemeMode.light);
    expect(storage.storedThemeMode, ThemeMode.light);
  });

  test(
    'a storage write failure does not throw and the in-memory state change still applies',
    () async {
      final storage = _FakeAppPreferencesStorage()..throwOnSetThemeMode = true;
      final notifier = ThemeModeNotifier(storage, ThemeMode.system);

      await notifier.setThemeMode(ThemeMode.dark);

      expect(notifier.state, ThemeMode.dark);
    },
  );
}
