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

  @override
  String get overviewTitle => 'Overview';

  @override
  String get overviewEmptyState =>
      'No envelopes yet. Create one in the Envelopes tab first.';

  @override
  String get overviewPlanAction => 'Plan';

  @override
  String get planTitle => 'Plan';

  @override
  String get planIncomeLabel => 'Income amount';

  @override
  String get planPreviewHeading => 'Allocation preview';

  @override
  String planOverAllocationWarning(String excess) {
    return 'Total allocation exceeds income by $excess ₫. Please adjust before confirming.';
  }

  @override
  String get planMissingReceiverWarning =>
      'There is leftover after allocation, but no envelope is set to receive it. Please set one in the Envelopes tab.';

  @override
  String get planNegativeBalanceWarning =>
      'One or more envelopes will still be negative after this allocation.';

  @override
  String get planConfirmAction => 'Confirm';

  @override
  String planErrorPrefix(String error) {
    return 'Could not confirm the plan: $error';
  }
}
