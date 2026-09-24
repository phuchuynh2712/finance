import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth/app_lifecycle_observer.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_notifier.dart';
import 'core/network/supabase_client_provider.dart';
import 'core/router/app_router.dart';
import 'core/storage/app_preferences_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } on Object {
    runApp(const _StartupErrorApp());
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

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (ref) => ThemeModeNotifier(preferencesStorage, initialThemeMode),
        ),
        localeProvider.overrideWith(
          (ref) => LocaleNotifier(preferencesStorage, initialLocale),
        ),
      ],
      child: const FinanceApp(),
    ),
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
      title: 'Finance',
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

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

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
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      l10n.startupConfigurationTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.startupConfigurationMessage,
                      textAlign: TextAlign.center,
                    ),
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
