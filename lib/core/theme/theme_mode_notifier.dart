import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/storage/app_preferences_storage.dart';

/// Device-level Appearance preference (FR-001–FR-004). Applies the state
/// change in memory before awaiting the storage write, so an app-wide
/// re-theme (SC-001) never waits on disk I/O.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage, ThemeMode initial) : super(initial);

  final AppPreferencesStorage _storage;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.setThemeMode(mode);
    } catch (_) {
      // A persistence failure is an acceptable degraded mode for a UI
      // preference (no financial data involved) — the in-memory choice
      // still applies for this session (spec.md Edge Cases).
    }
  }
}

/// Overridden in `main.dart` with the persisted value loaded before
/// `runApp()`, so the app never flashes the default appearance on cold
/// start (research.md Decision 2). The fallback constructor arguments
/// here only matter if a caller forgets that override (e.g. in a test).
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => throw UnimplementedError(
    'themeModeProvider must be overridden with a loaded initial ThemeMode '
    'before runApp() — see main.dart',
  ),
);
