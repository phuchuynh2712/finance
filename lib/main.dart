import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/app_lifecycle_observer.dart';
import 'core/database/app_database_provider.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_notifier.dart';
import 'core/network/supabase_client_provider.dart';
import 'core/router/app_router.dart';
import 'core/storage/app_preferences_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FR-010: path-based URLs (no `#`) instead of Flutter Web's default hash
  // strategy. A documented no-op on non-Web platforms — safe unconditionally.
  usePathUrlStrategy();
  try {
    await initSupabase();
  } on Object {
    runApp(const StartupErrorApp(reason: StartupFailureReason.supabaseConfig));
    return;
  }

  // Loaded before runApp() so themeModeProvider starts already holding the
  // persisted value on frame 1 — an async load inside the notifier would
  // flash the default appearance for one frame on every cold start
  // (research.md Decision 2).
  final preferencesStorage = SharedPreferencesAppPreferencesStorage(
    await SharedPreferences.getInstance(),
  );
  final initialThemeMode =
      await preferencesStorage.getThemeMode() ?? ThemeMode.system;
  final initialLocale =
      await preferencesStorage.getLocale() ?? const Locale('vi');

  final container = ProviderContainer(
    overrides: [
      themeModeProvider.overrideWith(
        (ref) => ThemeModeNotifier(preferencesStorage, initialThemeMode),
      ),
      localeProvider.overrideWith(
        (ref) => LocaleNotifier(preferencesStorage, initialLocale),
      ),
    ],
  );

  // Web-only: the local database's Web connection opens lazily, on its
  // first query, not inside AppDatabase()'s constructor (drift_flutter's
  // WasmDatabase.open is wrapped in a delayed Future) — so without this,
  // a total storage failure (every backend blocked) would surface
  // unpredictably wherever a screen first happens to query the database,
  // instead of the single, reliable startup-error screen FR-014 requires.
  // Forcing it to resolve once, here, before any real screen builds,
  // makes that guarantee possible. Not run on other platforms — FR-012
  // requires this feature not to change any existing mobile behavior.
  if (kIsWeb) {
    try {
      await container.read(appDatabaseProvider).customStatement('SELECT 1');
    } on Object {
      container.dispose();
      runApp(const StartupErrorApp(reason: StartupFailureReason.webStorage));
      return;
    }
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const FinanceApp()),
  );
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Instantiates the observer once and keeps it alive for the app's
    // lifetime (FR-020's background-resume threshold).
    ref.watch(appLifecycleObserverProvider);
    return MaterialApp.router(
      title: 'Kiểm Soát',
      routerConfig: ref.watch(appRouterProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
    );
  }
}

/// Distinguishes which localized copy [StartupErrorApp] shows — the two
/// failure points in [main] that occur before a normal [FinanceApp] (and
/// its own error handling) can ever be shown. Not private — constructed
/// directly by widget tests (test/widget/startup_error_app_test.dart).
enum StartupFailureReason { supabaseConfig, webStorage }

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.reason});

  final StartupFailureReason reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final (title, message) = switch (reason) {
            StartupFailureReason.supabaseConfig => (
              l10n.startupConfigurationTitle,
              l10n.startupConfigurationMessage,
            ),
            StartupFailureReason.webStorage => (
              l10n.startupWebStorageTitle,
              l10n.startupWebStorageMessage,
            ),
          };
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
