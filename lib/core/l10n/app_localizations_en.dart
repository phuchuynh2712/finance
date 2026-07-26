// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Finance Manager';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabSpending => 'Spending';

  @override
  String get tabEnvelopes => 'Envelopes';

  @override
  String get tabAccount => 'Account';

  @override
  String get signInTitle => 'Sign In';

  @override
  String get signInEmailLabel => 'Email';

  @override
  String get signInPasswordLabel => 'Password';

  @override
  String get signInSubmit => 'Sign In';

  @override
  String signInError(String error) {
    return 'Sign-in failed: $error';
  }
}
