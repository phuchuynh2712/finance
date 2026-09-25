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
  String get tabSpending => 'My Wallet';

  @override
  String get tabExpenseControl => 'Plan';

  @override
  String get tabHistory => 'History';

  @override
  String get tabAccount => 'Profile';

  @override
  String get signInAppName => 'Budget Control';

  @override
  String get signInAppSubtitle => 'Smart income & expense management';

  @override
  String get signInTitle => 'Sign In';

  @override
  String get signInIdentifierLabel => 'Phone number or email';

  @override
  String get signInPasswordLabel => 'Password';

  @override
  String get signInShowPasswordSemantic => 'Show password';

  @override
  String get signInHidePasswordSemantic => 'Hide password';

  @override
  String get signInForgotPasswordAction => 'Forgot password?';

  @override
  String get signInSubmit => 'Sign In';

  @override
  String signInError(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get signInOrDivider => 'or';

  @override
  String get signInWithBiometricAction => 'Log in with fingerprint';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get accountTitle => 'Profile';

  @override
  String get accountAppearanceLabel => 'Appearance';

  @override
  String get accountAppearanceLightOption => 'Light';

  @override
  String get accountAppearanceDarkOption => 'Dark';

  @override
  String get accountLanguageLabel => 'Language';

  @override
  String get accountLanguageDialogTitle => 'Select language';

  @override
  String get accountLanguageVietnamese => 'Tiếng Việt';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountSignOutAction => 'Sign out';

  @override
  String get signUpTitle => 'Create Account';

  @override
  String get signUpBackSemantic => 'Back';

  @override
  String get signUpEmailLabel => 'Email';

  @override
  String get signUpPasswordLabel => 'Password';

  @override
  String get signUpConfirmPasswordLabel => 'Confirm Password';

  @override
  String get signUpNameLabel => 'Full Name';

  @override
  String get signUpPhoneLabel => 'Phone Number';

  @override
  String get signUpEmailInvalidError => 'Enter a valid email address.';

  @override
  String get signUpPasswordTooShortError =>
      'Password must be at least 6 characters.';

  @override
  String get signUpConfirmPasswordMismatchError => 'Passwords do not match.';

  @override
  String get signUpTermsPrefix => 'I agree to the ';

  @override
  String get signUpTermsOfServiceLink => 'Terms of Service';

  @override
  String get signUpTermsMiddle => ' and ';

  @override
  String get signUpPrivacyPolicyLink => 'Privacy Policy';

  @override
  String get signUpSubmit => 'Sign Up';

  @override
  String signUpError(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get signUpDuplicateEmailError =>
      'This email is already registered. Sign in with your password.';

  @override
  String get signUpNavigateToSignIn => 'Already have an account? Sign in';

  @override
  String get signInNavigateToSignUp => 'Don\'t have an account? Sign up now';

  @override
  String get biometricEnablePromptTitle => 'Enable fingerprint login?';

  @override
  String get biometricEnablePromptMessage =>
      'Next time you can get in faster with just your fingerprint — no password needed.';

  @override
  String get biometricEnablePromptAcceptAction => 'Enable';

  @override
  String get biometricEnablePromptDeclineAction => 'Later';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordInstructions =>
      'Enter your registered email and we\'ll send you a password reset link.';

  @override
  String get forgotPasswordEmailLabel => 'Email';

  @override
  String get forgotPasswordSubmitAction => 'Send reset link';

  @override
  String get forgotPasswordConfirmationMessage =>
      'If this email is registered, you\'ll receive a password reset link shortly.';

  @override
  String get forgotPasswordBackToSignIn => 'Back to sign in';

  @override
  String get resetPasswordTitle => 'Set New Password';

  @override
  String get resetPasswordNewPasswordLabel => 'New password';

  @override
  String get resetPasswordConfirmPasswordLabel => 'Confirm new password';

  @override
  String get resetPasswordSubmitAction => 'Reset password';

  @override
  String get resetPasswordSuccessMessage =>
      'Password reset. Please sign in again with your new password.';

  @override
  String get resetPasswordMismatchError => 'Passwords do not match.';

  @override
  String resetPasswordError(String error) {
    return 'Could not reset the password: $error';
  }

  @override
  String get expenseControlScreenTitle => 'Expense Control';

  @override
  String get expenseControlBannerHint =>
      'Tap an item\'s name to expand/collapse.';

  @override
  String get expenseControlEmptyStateMessage =>
      'No items yet. Add your first one to start controlling your spending.';

  @override
  String get expenseControlAddItemAction => 'Add new item';

  @override
  String expenseControlAddChildAction(String groupName) {
    return 'Add item in $groupName';
  }

  @override
  String get expenseControlFixedNote =>
      'Fixed amounts have no limit here, but if actual income is insufficient, this item may not be fully funded when income is actually allocated.';

  @override
  String get expenseControlNameLabel => 'Item name';

  @override
  String get expenseControlDescriptionLabel => 'Description (optional)';

  @override
  String get expenseControlValueLabel => 'Value';

  @override
  String get expenseControlModePercentage => 'Percentage';

  @override
  String get expenseControlModeFixed => 'Fixed amount';

  @override
  String get expenseControlIconPickerLabel => 'Choose an icon';

  @override
  String expenseControlIconSemanticLabel(String name) {
    return '$name icon';
  }

  @override
  String get expenseControlDialogSaveAction => 'Save';

  @override
  String get expenseControlNameRequiredError => 'Please enter an item name.';

  @override
  String get expenseControlValueRequiredError =>
      'Please enter a value greater than 0.';

  @override
  String expenseControlOverBudgetError(String total) {
    return 'Total is $total%, over the allowed limit. Please adjust.';
  }

  @override
  String allocationSummaryAllocatedLine(String percent, int fixedCount) {
    return '$percent% allocated + $fixedCount fixed item(s)';
  }

  @override
  String allocationSummaryFreeLine(String percent) {
    return '$percent% free';
  }

  @override
  String expenseControlReorderSemantic(String name) {
    return 'Reorder group $name';
  }

  @override
  String expenseControlEditSemantic(String name) {
    return 'Edit $name';
  }

  @override
  String expenseControlDeleteSemantic(String name) {
    return 'Delete $name';
  }

  @override
  String expenseControlExpandSemantic(String name) {
    return 'Expand $name';
  }

  @override
  String expenseControlCollapseSemantic(String name) {
    return 'Collapse $name';
  }

  @override
  String get expenseControlEditItemTitle => 'Edit item';

  @override
  String expenseControlDeleteGroupTitle(String name) {
    return 'Delete group \"$name\"?';
  }

  @override
  String get expenseControlDeleteGroupWarning =>
      'Child items in this group will also be removed.';

  @override
  String get expenseControlDeleteGroupConfirmAction => 'Delete';

  @override
  String get expenseControlSaveFormulaAction => 'Save formula';

  @override
  String expenseControlSaveFormulaBlockedMessage(String total) {
    return 'Can\'t save: total is $total%, over the allowed limit.';
  }

  @override
  String get historyPlaceholderMessage => 'Coming soon.';

  @override
  String get expenseControlDiscardPromptTitle => 'Save changes?';

  @override
  String get expenseControlDiscardPromptMessage =>
      'You have unsaved changes in Expense Control. Do you want to save before leaving?';

  @override
  String get expenseControlDiscardPromptSaveAction => 'Save';

  @override
  String get expenseControlDiscardPromptDiscardAction => 'Don\'t save';

  @override
  String get spendingBalanceListLabel => 'Balance per item';

  @override
  String get spendingBalanceEmptyState =>
      'No items yet. Set them up in Expense Control first.';

  @override
  String get spendingIncomeAction => 'Income';

  @override
  String get spendingExpenseAction => 'Expense';

  @override
  String get spendingHistoryAction => 'View transaction history';

  @override
  String get notAvailablePlaceholderMessage =>
      'This feature is under development.';

  @override
  String get incomePlaceholderTitle => 'Income';

  @override
  String get expensePlaceholderTitle => 'Expense';

  @override
  String get transactionHistoryPlaceholderTitle => 'Transaction History';

  @override
  String get overviewPlaceholderTitle => 'Overview';

  @override
  String get accountNotificationsRowLabel => 'Notifications';

  @override
  String get accountSecurityRowLabel => 'Security';

  @override
  String get accountHelpRowLabel => 'Help';

  @override
  String get incomeScreenTitle => 'Income';

  @override
  String get incomeTotalLabel => 'Total income';

  @override
  String get incomeSourcesEyebrow => 'Income sources';

  @override
  String get incomeSourceNameLabel => 'Income source name';

  @override
  String get incomeSourceAmountLabel => 'Amount';

  @override
  String incomeSourceDeleteSemantic(String name) {
    return 'Delete income source $name';
  }

  @override
  String get incomeAddSourceAction => 'Add another income source';

  @override
  String get incomeSaveAction => 'Save income';

  @override
  String get incomeEmptyStateMessage =>
      'No items yet. Set them up in Expense Control first.';

  @override
  String get incomeErrorInvalidTotal =>
      'Please enter a total income amount greater than 0.';

  @override
  String get incomeErrorMissingRowName => 'Please name this income source.';

  @override
  String get incomeErrorMissingRowAmount =>
      'Please enter an amount for this income source.';

  @override
  String incomeErrorWriteFailedPrefix(String error) {
    return 'Could not save the income: $error';
  }

  @override
  String get savingsReceiverToggleLabel => 'Receives leftover income';

  @override
  String get savingsReceiverBlockedError =>
      'Only one item can be marked as the savings receiver. Unmark the other item first.';

  @override
  String get savingsReceiverAutoClearWarning =>
      'This item currently receives leftover income. Adding a child item will automatically clear that mark.';

  @override
  String get expenseScreenTitle => 'Expense';

  @override
  String get expenseTabManual => 'Manual entry';

  @override
  String get expenseTabScan => 'Scan receipt';

  @override
  String get expenseAmountLabel => 'Amount';

  @override
  String get expensePickItemEyebrow => 'DEDUCT FROM WHICH ITEM';

  @override
  String get expenseSaveAction => 'Save transaction';

  @override
  String get expenseEmptyStateMessage =>
      'No items yet. Set them up in Expense Control first.';

  @override
  String get expenseErrorInvalidAmount =>
      'Please enter an amount greater than 0.';

  @override
  String get expenseErrorMissingItem =>
      'Please pick which item to deduct from.';

  @override
  String expenseErrorWriteFailedPrefix(Object error) {
    return 'Could not save the expense: $error';
  }

  @override
  String expenseItemPickedSemantic(Object name) {
    return 'Deduct from $name';
  }

  @override
  String get expenseScanFrameHint => 'Fit the receipt in the frame';

  @override
  String get expenseScanCaptureAction => 'Capture receipt';

  @override
  String expenseScanRecognizedLabel(Object amount, Object merchant) {
    return 'Recognized: $amount · $merchant';
  }

  @override
  String get expenseScanConfirmAction => 'Confirm & save';

  @override
  String get errorMapperInvalidCredentials =>
      'Wrong email or password. Please try again.';

  @override
  String get errorMapperEmailExists =>
      'This email is already registered. Sign in with your password.';

  @override
  String get errorMapperWeakPassword =>
      'This password isn\'t strong enough. Please choose another one.';

  @override
  String get errorMapperRateLimited =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get errorMapperNetworkFailure =>
      'Couldn\'t reach the server. Please check your connection and try again.';

  @override
  String get errorMapperGeneric => 'Something went wrong. Please try again.';

  @override
  String get transactionHistoryTitle => 'Transaction History';

  @override
  String get transactionHistoryAllFilter => 'All';

  @override
  String get transactionHistoryIncomeFilter => 'Income';

  @override
  String transactionHistoryExpenseTotal(String amount) {
    return 'Total expenses this month: $amount';
  }

  @override
  String get transactionHistoryEmpty => 'No transactions match this selection.';

  @override
  String get transactionHistoryLoadError =>
      'Couldn\'t load transaction history.';

  @override
  String get transactionHistoryRetry => 'Try again';

  @override
  String get transactionHistoryBackSemantic => 'Back to spending';

  @override
  String get transactionHistoryPreviousMonthSemantic => 'Previous month';

  @override
  String get transactionHistoryNextMonthSemantic => 'Next month';

  @override
  String get transactionHistoryArchivedItem => 'Archived Item';

  @override
  String get transactionHistoryIncomeClassification => 'Income';

  @override
  String get startupConfigurationTitle => 'Configuration required';

  @override
  String get startupConfigurationMessage =>
      'Set the public Supabase URL and publishable key before launching the app.';

  @override
  String get startupWebStorageTitle => 'Couldn\'t open local storage';

  @override
  String get startupWebStorageMessage =>
      'Your browser is blocking the local storage this app needs to run. Please check your browser\'s privacy settings, then reload the page.';

  @override
  String get overviewTotalBalanceLabel => 'Total remaining · all accounts';

  @override
  String overviewNegativeBalanceWarning(String name) {
    return 'Account \"$name\" is negative';
  }

  @override
  String get overviewSeeDetailAction => 'See detail →';

  @override
  String get overviewLoadError => 'Couldn\'t load overview data.';

  @override
  String get overviewRetry => 'Try again';

  @override
  String overviewAccountsSectionTitle(int count) {
    return 'Accounts ($count)';
  }

  @override
  String get overviewSeeAllAction => 'See all';

  @override
  String get overviewSeeAllAccountsSemantic => 'See all accounts';

  @override
  String get overviewAccountsEmpty => 'No accounts yet.';

  @override
  String get overviewRecentTransactionsSectionTitle => 'Recent transactions';

  @override
  String get overviewSeeAllTransactionsSemantic =>
      'See all recent transactions';

  @override
  String get overviewTransactionsEmpty => 'No transactions yet.';

  @override
  String get overviewToday => 'Today';

  @override
  String get overviewYesterday => 'Yesterday';

  @override
  String overviewDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String overviewGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get overviewNotificationSemantic => 'Notifications';

  @override
  String get reportIncomeLabel => 'INCOME';

  @override
  String get reportExpenseLabel => 'EXPENSE';

  @override
  String get reportLoadError => 'Couldn\'t load the report.';

  @override
  String get reportRetry => 'Retry';

  @override
  String get reportPreviousMonthSemantic => 'Previous month';

  @override
  String get reportNextMonthSemantic => 'Next month';

  @override
  String get reportBreakdownSectionTitle => 'SPENDING BY ITEM';

  @override
  String get reportNotAllocatedLabel => 'Not allocated this month';

  @override
  String get reportBreakdownEmpty =>
      'No income or expense activity this month.';

  @override
  String reportUsagePercentValue(String percent) {
    return '$percent%';
  }
}
