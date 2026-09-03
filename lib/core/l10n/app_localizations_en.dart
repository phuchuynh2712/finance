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
  String get signInEmailNotConfirmedError =>
      'This email hasn\'t been confirmed yet. Please check your inbox and click the confirmation link before signing in.';

  @override
  String get signInResendConfirmationAction => 'Resend confirmation email';

  @override
  String get signInResendConfirmationSuccess => 'Confirmation email resent.';

  @override
  String signInResendConfirmationError(String error) {
    return 'Could not resend the confirmation email: $error';
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

  @override
  String get spendingTitle => 'Spending';

  @override
  String get spendingEmptyState => 'No expenses yet.';

  @override
  String get spendingAddAction => 'Add expense';

  @override
  String get spendingNoEnvelopesWarning =>
      'No envelopes yet. Create one in the Envelopes tab before recording an expense.';

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
  String get accountPasswordSavedMessage => 'Password changed.';

  @override
  String accountPasswordErrorPrefix(String error) {
    return 'Could not change the password: $error';
  }

  @override
  String get accountSignOutAction => 'Sign out';

  @override
  String get signUpTitle => 'Sign Up';

  @override
  String get signUpEmailLabel => 'Email';

  @override
  String get signUpPasswordLabel => 'Password';

  @override
  String get signUpConfirmPasswordLabel => 'Confirm Password';

  @override
  String get signUpNameLabel => 'Name';

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
  String get signUpSubmit => 'Sign Up';

  @override
  String signUpError(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get signUpDuplicateEmailError =>
      'This email is already registered. Sign in with your password, or use \"Sign in with Google\" below if you registered via Google.';

  @override
  String signUpCheckEmailMessage(String email) {
    return 'Please check $email and click the confirmation link to finish registering before you can sign in.';
  }

  @override
  String get signUpResendConfirmationAction => 'Resend confirmation email';

  @override
  String get signUpResendConfirmationSuccess => 'Confirmation email resent.';

  @override
  String signUpResendConfirmationError(String error) {
    return 'Could not resend the confirmation email: $error';
  }

  @override
  String get signUpNavigateToSignIn => 'Already have an account? Sign in';

  @override
  String get signInNavigateToSignUp => 'Don\'t have an account? Sign up';

  @override
  String get signInWithGoogleAction => 'Sign in with Google';

  @override
  String signInWithGoogleError(String error) {
    return 'Google sign-in failed: $error';
  }

  @override
  String get accountLinkGoogleTitle => 'Link Google Account';

  @override
  String get accountLinkGoogleAction => 'Link Google account';

  @override
  String accountLinkedGoogleEmail(String email) {
    return 'Linked: $email';
  }

  @override
  String accountLinkGoogleErrorPrefix(String error) {
    return 'Could not link the Google account: $error';
  }

  @override
  String get accountLinkGoogleAlreadyExistsError =>
      'This Google account is already linked to a different account.';
}
