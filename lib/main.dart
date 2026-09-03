import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/l10n/app_localizations.dart';
import 'core/network/supabase_client_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initSupabase();
  await _initGoogleSignIn();
  runApp(const ProviderScope(child: FinanceApp()));
}

/// Initializes the shared `GoogleSignIn.instance` (research.md §2) once at
/// startup, so `authenticate()`/`attemptLightweightAuthentication()` can be
/// called from any screen afterwards. Uses the Web client ID as
/// `serverClientId` (required on both platforms to obtain a Supabase-
/// verifiable ID token) and the iOS client ID as `clientId` (unused on
/// Android). Both are optional here — until Google Cloud Console setup
/// (tasks.md T002) is done, the app runs fine without them; only the
/// Google-sign-in buttons would fail if tapped.
Future<void> _initGoogleSignIn() async {
  await GoogleSignIn.instance.initialize(
    serverClientId: dotenv.env['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'],
    clientId: dotenv.env['GOOGLE_SIGN_IN_IOS_CLIENT_ID'],
  );
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Finance',
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}
