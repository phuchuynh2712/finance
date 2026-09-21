import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/storage/app_preferences_storage.dart';

class _FakeAppPreferencesStorage implements AppPreferencesStorage {
  ThemeMode? storedThemeMode;
  Locale? storedLocale;
  bool throwOnSetLocale = false;

  @override
  Future<ThemeMode?> getThemeMode() async => storedThemeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    storedThemeMode = mode;
  }

  @override
  Future<Locale?> getLocale() async => storedLocale;

  @override
  Future<void> setLocale(Locale locale) async {
    if (throwOnSetLocale) {
      throw Exception('simulated storage write failure');
    }
    storedLocale = locale;
  }
}

void main() {
  test('constructed with an initial value reflects it as state', () {
    final notifier = LocaleNotifier(
      _FakeAppPreferencesStorage(),
      const Locale('en'),
    );
    expect(notifier.state, const Locale('en'));
  });

  test('setLocale updates state and writes through to storage', () async {
    final storage = _FakeAppPreferencesStorage();
    final notifier = LocaleNotifier(storage, const Locale('vi'));

    await notifier.setLocale(const Locale('en'));

    expect(notifier.state, const Locale('en'));
    expect(storage.storedLocale, const Locale('en'));
  });

  test(
    'a storage write failure does not throw and the in-memory state change still applies',
    () async {
      final storage = _FakeAppPreferencesStorage()..throwOnSetLocale = true;
      final notifier = LocaleNotifier(storage, const Locale('vi'));

      await notifier.setLocale(const Locale('en'));

      expect(notifier.state, const Locale('en'));
    },
  );
}
