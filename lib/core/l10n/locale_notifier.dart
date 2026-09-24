import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/storage/app_preferences_storage.dart';

/// Device-level Language preference (FR-005–FR-008). Applies the state
/// change in memory before awaiting the storage write, so an app-wide
/// re-render of all text (SC-002) never waits on disk I/O.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage, Locale initial) : super(initial);

  final AppPreferencesStorage _storage;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      await _storage.setLocale(locale);
    } catch (_) {
      // A persistence failure is an acceptable degraded mode for a UI
      // preference (no financial data involved) — the in-memory choice
      // still applies for this session (spec.md Edge Cases).
    }
  }
}

/// Overridden in `main.dart` with the persisted value loaded before
/// `runApp()`, so the app never flashes the default language on cold start
/// (research.md Decision 2, mirroring themeModeProvider).
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => throw UnimplementedError(
    'localeProvider must be overridden with a loaded initial Locale before '
    'runApp() — see main.dart',
  ),
);
