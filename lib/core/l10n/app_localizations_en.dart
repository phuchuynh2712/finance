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
  String get tabSpending => 'Income & Expense';

  @override
  String get tabExpenseControl => 'Control';

  @override
  String get tabHistory => 'History';

  @override
  String get tabAccount => 'Profile';

  @override
  String get signInAppName => 'Khai Tam';

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
  String get overviewTitle => 'Overview';

  @override
  String get overviewEmptyState =>
      'No envelopes yet. Create one in the Control tab first.';

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
      'There is leftover after allocation, but no envelope is set to receive it. Please set one in the Control tab.';

  @override
  String get planNegativeBalanceWarning =>
      'One or more envelopes will still be negative after this allocation.';

  @override
  String get planConfirmAction => 'Confirm';

  @override
  String planErrorPrefix(String error) {
    return 'Could not confirm the plan: $error';
  }

  @override
  String get spendingTitle => 'Spending';

  @override
  String get spendingEmptyState => 'No expenses yet.';

  @override
  String get spendingAddAction => 'Add expense';

  @override
  String get spendingNoEnvelopesWarning =>
      'No envelopes yet. Create one in the Control tab before recording an expense.';

  @override
  String get spendingDeleteConfirmTitle => 'Delete this expense?';

  @override
  String get spendingDeleteConfirmAction => 'Delete';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get expenseFormTitleCreate => 'Add Expense';

  @override
  String get expenseFormTitleEdit => 'Edit Expense';

  @override
  String get expenseFormAmountLabel => 'Amount';

  @override
  String get expenseFormEnvelopeLabel => 'Envelope';

  @override
  String get expenseFormNoteLabel => 'Note (optional)';

  @override
  String get expenseFormSaveAction => 'Save';

  @override
  String expenseFormErrorPrefix(String error) {
    return 'Could not save the expense: $error';
  }

  @override
  String get coveringPromptTitle => 'Choose a covering envelope';

  @override
  String coveringPromptMessage(String shortfall) {
    return 'This expense exceeds the balance by $shortfall ₫. Choose another envelope to cover the shortfall.';
  }

  @override
  String get envelopesTitle => 'Envelopes';

  @override
  String get envelopesEmptyState =>
      'No envelopes yet. Tap the button below to create your first one.';

  @override
  String get envelopesAddAction => 'Add envelope';

  @override
  String get envelopesReceiverBadge => 'Receives leftover';

  @override
  String get envelopeFormTitleCreate => 'Create Envelope';

  @override
  String get envelopeFormTitleEdit => 'Edit Envelope';

  @override
  String get envelopeFormNameLabel => 'Envelope name';

  @override
  String get envelopeFormMethodLabel => 'Allocation method';

  @override
  String get envelopeFormMethodPercentage => 'Percentage';

  @override
  String get envelopeFormMethodFixed => 'Fixed amount';

  @override
  String get envelopeFormValueLabelPercentage => 'Percentage (%)';

  @override
  String get envelopeFormValueLabelFixed => 'Fixed amount';

  @override
  String get envelopeFormReceiverToggle => 'Receives the rounding leftover';

  @override
  String get envelopeFormSaveAction => 'Save';

  @override
  String envelopeFormErrorPrefix(String error) {
    return 'Could not save the envelope: $error';
  }

  @override
  String envelopeDeleteConfirmTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String envelopeDeleteNonZeroWarning(String balance) {
    return 'This envelope still has a balance of $balance ₫. Deleting it will affect that balance and its related transaction history.';
  }

  @override
  String get envelopeDeleteConfirmAction => 'Delete';

  @override
  String get envelopeReassignReceiverTitle =>
      'Choose a new rounding-remainder receiver';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountAvatarUrlLabel => 'Avatar URL';

  @override
  String get accountAvatarSaveAction => 'Update avatar';

  @override
  String get accountAvatarSavedMessage => 'Avatar updated.';

  @override
  String accountAvatarErrorPrefix(String error) {
    return 'Could not update the avatar: $error';
  }

  @override
  String get accountNewPasswordLabel => 'New password';

  @override
  String get accountPasswordSaveAction => 'Change password';

  @override
  String get accountPasswordSavedMessage =>
      'Password changed. Other signed-in devices have been signed out.';

  @override
  String accountPasswordErrorPrefix(String error) {
    return 'Could not change the password: $error';
  }

  @override
  String get accountBiometricToggleLabel => 'Log in with fingerprint';

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
}
