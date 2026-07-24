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
  String get connectionTestTitle => 'Connection Test';

  @override
  String get connectionStatusChecking => 'Checking connection...';

  @override
  String get connectionStatusSuccess => 'Supabase connection succeeded';

  @override
  String connectionStatusFailure(String error) {
    return 'Supabase connection failed: $error';
  }
}
