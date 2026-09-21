import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level, non-financial UI preferences (Appearance, Language) —
/// explicitly NOT the local Drift database, which is reserved for
/// relational/financial data (Constitution: Offline-First Data & Sync).
abstract interface class AppPreferencesStorage {
  Future<ThemeMode?> getThemeMode();
  Future<void> setThemeMode(ThemeMode mode);
  Future<Locale?> getLocale();
  Future<void> setLocale(Locale locale);
}

class SharedPreferencesAppPreferencesStorage implements AppPreferencesStorage {
  SharedPreferencesAppPreferencesStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _themeModeKey = 'pref_theme_mode';
  static const _localeKey = 'pref_locale';

  /// A read failure (malformed stored value) is treated as "never set"
  /// rather than rethrown, so a corrupted preference falls back to the
  /// system default instead of crashing the app at launch (spec.md Edge
  /// Cases).
  @override
  Future<ThemeMode?> getThemeMode() async {
    final stored = _prefs.getString(_themeModeKey);
    if (stored == null) return null;
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) return mode;
    }
    return null;
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  @override
  Future<Locale?> getLocale() async {
    final stored = _prefs.getString(_localeKey);
    if (stored == null) return null;
    if (stored != 'vi' && stored != 'en') return null;
    return Locale(stored);
  }

  @override
  Future<void> setLocale(Locale locale) async {
    await _prefs.setString(_localeKey, locale.languageCode);
  }
}
