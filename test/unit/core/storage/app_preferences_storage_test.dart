import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance/core/storage/app_preferences_storage.dart';

void main() {
  late SharedPreferencesAppPreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SharedPreferencesAppPreferencesStorage(
      await SharedPreferences.getInstance(),
    );
  });

  group('ThemeMode', () {
    test('returns null when never set', () async {
      expect(await storage.getThemeMode(), isNull);
    });

    test('round-trips a set value', () async {
      await storage.setThemeMode(ThemeMode.dark);
      expect(await storage.getThemeMode(), ThemeMode.dark);
    });

    test('a malformed stored value is treated as null, not thrown', () async {
      SharedPreferences.setMockInitialValues({
        'pref_theme_mode': 'not-a-real-theme-mode',
      });
      storage = SharedPreferencesAppPreferencesStorage(
        await SharedPreferences.getInstance(),
      );
      expect(await storage.getThemeMode(), isNull);
    });
  });

  group('Locale', () {
    test('returns null when never set', () async {
      expect(await storage.getLocale(), isNull);
    });

    test('round-trips a set value', () async {
      await storage.setLocale(const Locale('en'));
      expect(await storage.getLocale(), const Locale('en'));
    });

    test('a malformed stored value is treated as null, not thrown', () async {
      SharedPreferences.setMockInitialValues({'pref_locale': 'fr'});
      storage = SharedPreferencesAppPreferencesStorage(
        await SharedPreferences.getInstance(),
      );
      expect(await storage.getLocale(), isNull);
    });
  });
}
