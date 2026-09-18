import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// The title of the application
  ///
  /// In vi, this message translates to:
  /// **'Quản lý tài chính'**
  String get appTitle;

  /// Bottom navigation tab label for the Overview screen
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get tabOverview;

  /// Bottom navigation tab label for the Spending screen (renamed from "Chi tiêu" to "Thu chi" per FR-020)
  ///
  /// In vi, this message translates to:
  /// **'Thu chi'**
  String get tabSpending;

  /// Bottom navigation tab label for the Expense Control screen (FR-020)
  ///
  /// In vi, this message translates to:
  /// **'Kiểm soát'**
  String get tabExpenseControl;

  /// Bottom navigation tab label for the History/Report placeholder screen (FR-020)
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử/Báo cáo'**
  String get tabHistory;

  /// Bottom navigation tab label for the Account screen (renamed from "Cá nhân" to "Hồ sơ" per FR-020)
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get tabAccount;

  /// Brand name shown in the Login screen's logo block (FR-003)
  ///
  /// In vi, this message translates to:
  /// **'Khai Tâm'**
  String get signInAppName;

  /// Subtitle shown under the brand name on the Login screen (FR-003)
  ///
  /// In vi, this message translates to:
  /// **'Quản lý thu chi thông minh'**
  String get signInAppSubtitle;

  /// Title of the sign-in screen (app bar / page title, not shown on the redesigned screen body itself)
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get signInTitle;

  /// Label for the phone-or-email identifier field (FR-003). Only email is ever a valid credential (FR-005) — a phone number typed here fails sign-in with the same message as any other invalid credential.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại hoặc email'**
  String get signInIdentifierLabel;

  /// Label for the password input field on the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get signInPasswordLabel;

  /// Accessibility label for the icon button that reveals the password
  ///
  /// In vi, this message translates to:
  /// **'Hiện mật khẩu'**
  String get signInShowPasswordSemantic;

  /// Accessibility label for the icon button that hides the password
  ///
  /// In vi, this message translates to:
  /// **'Ẩn mật khẩu'**
  String get signInHidePasswordSemantic;

  /// Link on the sign-in screen navigating to the forgot-password flow (FR-015)
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu?'**
  String get signInForgotPasswordAction;

  /// Submit button label on the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get signInSubmit;

  /// Shown when sign-in fails, for any reason (wrong password, unregistered/non-email identifier per FR-005, network error)
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thất bại: {error}'**
  String signInError(String error);

  /// Divider text between the password sign-in button and the biometric sign-in button (FR-003)
  ///
  /// In vi, this message translates to:
  /// **'hoặc'**
  String get signInOrDivider;

  /// Button to sign in via device biometric (fingerprint/Face ID), shown only per FR-008's visibility rules
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập bằng vân tay'**
  String get signInWithBiometricAction;

  /// Title of the Overview screen
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get overviewTitle;

  /// Shown on Overview when the user has no envelopes yet
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản nào. Hãy tạo khoản trong tab Kiểm soát trước.'**
  String get overviewEmptyState;

  /// Button/action on Overview that opens the income allocation (Plan) flow
  ///
  /// In vi, this message translates to:
  /// **'Lập kế hoạch'**
  String get overviewPlanAction;

  /// Title of the Plan (income allocation) screen
  ///
  /// In vi, this message translates to:
  /// **'Lập kế hoạch'**
  String get planTitle;

  /// Label for the income amount input field on the Plan screen
  ///
  /// In vi, this message translates to:
  /// **'Số tiền thu nhập'**
  String get planIncomeLabel;

  /// Heading above the per-envelope allocation preview list
  ///
  /// In vi, this message translates to:
  /// **'Xem trước phân bổ'**
  String get planPreviewHeading;

  /// Shown when combined fixed+percentage allocations exceed the income entered (FR-011a)
  ///
  /// In vi, this message translates to:
  /// **'Tổng phân bổ vượt quá thu nhập {excess} ₫. Vui lòng điều chỉnh trước khi xác nhận.'**
  String planOverAllocationWarning(String excess);

  /// Shown when a nonzero leftover exists but no envelope is flagged as the rounding-remainder receiver (FR-013)
  ///
  /// In vi, this message translates to:
  /// **'Còn dư sau khi phân bổ nhưng chưa có khoản nào được đặt làm nơi nhận phần dư. Vui lòng đặt một khoản trong tab Kiểm soát.'**
  String get planMissingReceiverWarning;

  /// Shown when any envelope's resulting balance would still be negative after this allocation (FR-011)
  ///
  /// In vi, this message translates to:
  /// **'Một hoặc nhiều khoản sẽ vẫn bị âm sau khi phân bổ.'**
  String get planNegativeBalanceWarning;

  /// Button to confirm and apply the allocation event
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get planConfirmAction;

  /// Shown when confirming the allocation event fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể xác nhận kế hoạch: {error}'**
  String planErrorPrefix(String error);

  /// Title of the Spending screen
  ///
  /// In vi, this message translates to:
  /// **'Chi tiêu'**
  String get spendingTitle;

  /// Shown on Spending when no expenses exist yet
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản chi nào.'**
  String get spendingEmptyState;

  /// Action to open the expense entry form
  ///
  /// In vi, this message translates to:
  /// **'Thêm khoản chi'**
  String get spendingAddAction;

  /// Shown instead of the add-expense action when the user has zero envelopes (FR-030)
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản nào. Hãy tạo khoản trong tab Kiểm soát trước khi ghi chi tiêu.'**
  String get spendingNoEnvelopesWarning;

  /// Title of the confirmation dialog before deleting an expense entry
  ///
  /// In vi, this message translates to:
  /// **'Xóa khoản chi?'**
  String get spendingDeleteConfirmTitle;

  /// Confirm button in the delete-expense dialog
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get spendingDeleteConfirmAction;

  /// Generic cancel button label
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancelAction;

  /// Title of the expense form screen when creating a new entry
  ///
  /// In vi, this message translates to:
  /// **'Ghi khoản chi'**
  String get expenseFormTitleCreate;

  /// Title of the expense form screen when editing an existing entry
  ///
  /// In vi, this message translates to:
  /// **'Sửa khoản chi'**
  String get expenseFormTitleEdit;

  /// Label for the amount input field on the expense form
  ///
  /// In vi, this message translates to:
  /// **'Số tiền'**
  String get expenseFormAmountLabel;

  /// Label for the envelope selector on the expense form
  ///
  /// In vi, this message translates to:
  /// **'Khoản'**
  String get expenseFormEnvelopeLabel;

  /// Label for the optional note field on the expense form
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú (không bắt buộc)'**
  String get expenseFormNoteLabel;

  /// Save button on the expense form
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get expenseFormSaveAction;

  /// Shown when saving the expense fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu khoản chi: {error}'**
  String expenseFormErrorPrefix(String error);

  /// Title of the covering-envelope prompt shown on overspend
  ///
  /// In vi, this message translates to:
  /// **'Chọn khoản để bù'**
  String get coveringPromptTitle;

  /// Body text of the covering-envelope prompt, showing the shortfall
  ///
  /// In vi, this message translates to:
  /// **'Khoản chi này vượt quá số dư {shortfall} ₫. Chọn một khoản khác để bù phần thiếu.'**
  String coveringPromptMessage(String shortfall);

  /// Title of the Envelopes CRUD screen
  ///
  /// In vi, this message translates to:
  /// **'Khoản'**
  String get envelopesTitle;

  /// Shown on the Envelopes screen when no envelopes exist yet
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản nào. Nhấn nút bên dưới để tạo khoản đầu tiên.'**
  String get envelopesEmptyState;

  /// Action to open the envelope creation form
  ///
  /// In vi, this message translates to:
  /// **'Thêm khoản'**
  String get envelopesAddAction;

  /// Badge shown on the envelope currently flagged as the rounding-remainder receiver
  ///
  /// In vi, this message translates to:
  /// **'Nhận phần dư'**
  String get envelopesReceiverBadge;

  /// Title of the envelope form screen when creating a new envelope
  ///
  /// In vi, this message translates to:
  /// **'Tạo khoản'**
  String get envelopeFormTitleCreate;

  /// Title of the envelope form screen when editing an existing envelope
  ///
  /// In vi, this message translates to:
  /// **'Sửa khoản'**
  String get envelopeFormTitleEdit;

  /// Label for the envelope name input field
  ///
  /// In vi, this message translates to:
  /// **'Tên khoản'**
  String get envelopeFormNameLabel;

  /// Label for the allocation method selector (percentage or fixed)
  ///
  /// In vi, this message translates to:
  /// **'Cách phân bổ'**
  String get envelopeFormMethodLabel;

  /// Option label for percentage-based allocation
  ///
  /// In vi, this message translates to:
  /// **'Theo phần trăm'**
  String get envelopeFormMethodPercentage;

  /// Option label for fixed-amount allocation
  ///
  /// In vi, this message translates to:
  /// **'Số tiền cố định'**
  String get envelopeFormMethodFixed;

  /// Label for the allocation value field when method is percentage
  ///
  /// In vi, this message translates to:
  /// **'Phần trăm (%)'**
  String get envelopeFormValueLabelPercentage;

  /// Label for the allocation value field when method is fixed
  ///
  /// In vi, this message translates to:
  /// **'Số tiền cố định'**
  String get envelopeFormValueLabelFixed;

  /// Toggle label for flagging this envelope as the rounding-remainder receiver
  ///
  /// In vi, this message translates to:
  /// **'Nhận phần dư khi làm tròn'**
  String get envelopeFormReceiverToggle;

  /// Save button on the envelope form
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get envelopeFormSaveAction;

  /// Shown when saving the envelope fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu khoản: {error}'**
  String envelopeFormErrorPrefix(String error);

  /// Title of the delete-envelope confirmation dialog
  ///
  /// In vi, this message translates to:
  /// **'Xóa khoản \"{name}\"?'**
  String envelopeDeleteConfirmTitle(String name);

  /// Warning shown when deleting an envelope with a non-zero balance (FR-027)
  ///
  /// In vi, this message translates to:
  /// **'Khoản này vẫn còn số dư {balance} ₫. Xóa sẽ ảnh hưởng đến số dư và lịch sử giao dịch liên quan.'**
  String envelopeDeleteNonZeroWarning(String balance);

  /// Confirm button in the delete-envelope dialog
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get envelopeDeleteConfirmAction;

  /// Title of the dialog requiring a new rounding-remainder receiver before deleting the current one (FR-028)
  ///
  /// In vi, this message translates to:
  /// **'Chọn khoản nhận phần dư mới'**
  String get envelopeReassignReceiverTitle;

  /// Title of the Account screen
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get accountTitle;

  /// Label for the avatar URL input field
  ///
  /// In vi, this message translates to:
  /// **'Đường dẫn ảnh đại diện'**
  String get accountAvatarUrlLabel;

  /// Button to save the avatar URL
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật ảnh đại diện'**
  String get accountAvatarSaveAction;

  /// Confirmation shown after the avatar is saved
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật ảnh đại diện.'**
  String get accountAvatarSavedMessage;

  /// Shown when saving the avatar fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật ảnh đại diện: {error}'**
  String accountAvatarErrorPrefix(String error);

  /// Label for the new password input field
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get accountNewPasswordLabel;

  /// Button to change the password
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get accountPasswordSaveAction;

  /// Confirmation shown after the password is changed (FR-016b: other devices/sessions are signed out, this one is not)
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu. Các thiết bị khác đã đăng nhập sẽ bị đăng xuất.'**
  String get accountPasswordSavedMessage;

  /// Shown when changing the password fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể đổi mật khẩu: {error}'**
  String accountPasswordErrorPrefix(String error);

  /// Label for the Account screen's biometric login on/off toggle (FR-010)
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập bằng vân tay'**
  String get accountBiometricToggleLabel;

  /// Button to sign out of the account
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get accountSignOutAction;

  /// Header title of the Sign Up screen (FR-004)
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get signUpTitle;

  /// Accessibility label for the Sign Up screen's back action
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get signUpBackSemantic;

  /// Label for the required email input field on the Sign Up screen (FR-006 — required despite the design mockup's visual optional-style label, see spec.md Assumptions)
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get signUpEmailLabel;

  /// Label for the password input field on the Sign Up screen
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get signUpPasswordLabel;

  /// Label for the confirm-password input field on the Sign Up screen
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu'**
  String get signUpConfirmPasswordLabel;

  /// Label for the full-name input field on the Sign Up screen (FR-004)
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get signUpNameLabel;

  /// Label for the phone-number input field on the Sign Up screen — profile data only, never a login credential (FR-005)
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get signUpPhoneLabel;

  /// Inline error shown when the entered email fails format validation
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ.'**
  String get signUpEmailInvalidError;

  /// Inline error shown when the entered password is shorter than the minimum length
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu phải có ít nhất 6 ký tự.'**
  String get signUpPasswordTooShortError;

  /// Inline error shown when the confirm-password field doesn't match the password field
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận không khớp.'**
  String get signUpConfirmPasswordMismatchError;

  /// Text immediately before the Terms of Service link in the Sign Up checkbox label (FR-007)
  ///
  /// In vi, this message translates to:
  /// **'Tôi đồng ý với '**
  String get signUpTermsPrefix;

  /// Terms of Service link text in the Sign Up checkbox label — styled text only, no real destination in this feature (spec.md Assumptions)
  ///
  /// In vi, this message translates to:
  /// **'Điều khoản dịch vụ'**
  String get signUpTermsOfServiceLink;

  /// Text between the Terms of Service and Privacy Policy links in the Sign Up checkbox label
  ///
  /// In vi, this message translates to:
  /// **' và '**
  String get signUpTermsMiddle;

  /// Privacy Policy link text in the Sign Up checkbox label — styled text only, no real destination in this feature (spec.md Assumptions)
  ///
  /// In vi, this message translates to:
  /// **'Chính sách bảo mật'**
  String get signUpPrivacyPolicyLink;

  /// Submit button label on the Sign Up screen
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get signUpSubmit;

  /// Generic (retryable) error shown when registration fails
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thất bại: {error}'**
  String signUpError(String error);

  /// Shown when the entered email is already registered (FR-003)
  ///
  /// In vi, this message translates to:
  /// **'Email này đã được đăng ký. Hãy đăng nhập bằng mật khẩu.'**
  String get signUpDuplicateEmailError;

  /// Link on the Sign Up screen navigating back to the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? Đăng nhập'**
  String get signUpNavigateToSignIn;

  /// Link on the sign-in screen navigating to the Sign Up screen (FR-003)
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký ngay'**
  String get signInNavigateToSignUp;

  /// Title of the one-time prompt offering to enable biometric login, shown after first Sign Up/Sign In on a device (FR-009)
  ///
  /// In vi, this message translates to:
  /// **'Bật đăng nhập vân tay?'**
  String get biometricEnablePromptTitle;

  /// Body text of the enable-biometric prompt
  ///
  /// In vi, this message translates to:
  /// **'Lần sau bạn có thể vào ứng dụng nhanh hơn chỉ bằng vân tay, không cần gõ mật khẩu.'**
  String get biometricEnablePromptMessage;

  /// Accept button on the enable-biometric prompt
  ///
  /// In vi, this message translates to:
  /// **'Bật'**
  String get biometricEnablePromptAcceptAction;

  /// Decline button on the enable-biometric prompt
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get biometricEnablePromptDeclineAction;

  /// Title of the Forgot Password screen (FR-015)
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu'**
  String get forgotPasswordTitle;

  /// Instructional text on the Forgot Password screen
  ///
  /// In vi, this message translates to:
  /// **'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết đặt lại mật khẩu.'**
  String get forgotPasswordInstructions;

  /// Label for the email input field on the Forgot Password screen
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get forgotPasswordEmailLabel;

  /// Submit button on the Forgot Password screen
  ///
  /// In vi, this message translates to:
  /// **'Gửi liên kết đặt lại'**
  String get forgotPasswordSubmitAction;

  /// Generic confirmation shown after submitting the Forgot Password form, identical regardless of whether the email is registered (FR-015, account-enumeration protection)
  ///
  /// In vi, this message translates to:
  /// **'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu trong ít phút.'**
  String get forgotPasswordConfirmationMessage;

  /// Link on the Forgot Password screen navigating back to the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Quay lại đăng nhập'**
  String get forgotPasswordBackToSignIn;

  /// Title of the Set New Password screen, reached via the password-recovery deep link (FR-016)
  ///
  /// In vi, this message translates to:
  /// **'Đặt mật khẩu mới'**
  String get resetPasswordTitle;

  /// Label for the new-password input field on the Set New Password screen
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get resetPasswordNewPasswordLabel;

  /// Label for the confirm-new-password input field on the Set New Password screen
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu mới'**
  String get resetPasswordConfirmPasswordLabel;

  /// Submit button on the Set New Password screen
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại mật khẩu'**
  String get resetPasswordSubmitAction;

  /// Shown after confirmPasswordReset succeeds (FR-016), before the router's signed-out redirect takes the user to Login
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt lại mật khẩu. Vui lòng đăng nhập lại bằng mật khẩu mới.'**
  String get resetPasswordSuccessMessage;

  /// Inline error shown when the confirm-password field doesn't match the new password field
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận không khớp.'**
  String get resetPasswordMismatchError;

  /// Shown when confirming the password reset fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể đặt lại mật khẩu: {error}'**
  String resetPasswordError(String error);

  /// Header title of the Expense Control screen
  ///
  /// In vi, this message translates to:
  /// **'Kiểm soát chi tiêu'**
  String get expenseControlScreenTitle;

  /// Guidance banner shown at the top of the Expense Control list
  ///
  /// In vi, this message translates to:
  /// **'Bấm tên các khoản để đóng/mở.'**
  String get expenseControlBannerHint;

  /// FR-023: shown when no items/groups exist yet
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản nào. Hãy thêm khoản đầu tiên để bắt đầu kiểm soát chi tiêu.'**
  String get expenseControlEmptyStateMessage;

  /// Button to create a new top-level expense control item (FR-001)
  ///
  /// In vi, this message translates to:
  /// **'Thêm khoản mới'**
  String get expenseControlAddItemAction;

  /// Button to add a child item under a group (FR-002)
  ///
  /// In vi, this message translates to:
  /// **'Thêm khoản trong {groupName}'**
  String expenseControlAddChildAction(String groupName);

  /// FR-010: informational (non-blocking) note shown when configuring a fixed-amount item
  ///
  /// In vi, this message translates to:
  /// **'Khoản cố định không giới hạn ở đây, nhưng nếu thu nhập thực tế không đủ, khoản này có thể không được phân bổ đầy đủ khi thu nhập thực sự được phân bổ.'**
  String get expenseControlFixedNote;

  /// Label for the item/group name input field
  ///
  /// In vi, this message translates to:
  /// **'Tên khoản'**
  String get expenseControlNameLabel;

  /// Label for the optional description field (FR-022)
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú (không bắt buộc)'**
  String get expenseControlDescriptionLabel;

  /// Label for the formula value input field
  ///
  /// In vi, this message translates to:
  /// **'Giá trị'**
  String get expenseControlValueLabel;

  /// Allocation mode toggle option: percentage of income
  ///
  /// In vi, this message translates to:
  /// **'Phần trăm'**
  String get expenseControlModePercentage;

  /// Allocation mode toggle option: fixed amount
  ///
  /// In vi, this message translates to:
  /// **'Số tiền cố định'**
  String get expenseControlModeFixed;

  /// Label above the icon picker grid
  ///
  /// In vi, this message translates to:
  /// **'Chọn biểu tượng'**
  String get expenseControlIconPickerLabel;

  /// Semantics label for one selectable icon in the icon picker
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng {name}'**
  String expenseControlIconSemanticLabel(String name);

  /// Save/submit button inside the create-item and edit-item dialogs
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get expenseControlDialogSaveAction;

  /// FR-017: shown when the name field is left blank
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên khoản.'**
  String get expenseControlNameRequiredError;

  /// FR-017: shown when the formula value is zero, negative, or blank
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập giá trị lớn hơn 0.'**
  String get expenseControlValueRequiredError;

  /// FR-007/FR-008/FR-012: shown when a candidate save would violate the percentage budget
  ///
  /// In vi, this message translates to:
  /// **'Tổng phần trăm là {total}%, vượt quá giới hạn cho phép. Vui lòng điều chỉnh.'**
  String expenseControlOverBudgetError(String total);

  /// FR-011: first line of the running allocation summary banner
  ///
  /// In vi, this message translates to:
  /// **'Đã phân bổ {percent}% + {fixedCount} khoản cố định'**
  String allocationSummaryAllocatedLine(String percent, int fixedCount);

  /// FR-011: second line of the running allocation summary banner
  ///
  /// In vi, this message translates to:
  /// **'Còn {percent}% tự do'**
  String allocationSummaryFreeLine(String percent);

  /// Semantics label for a group card's drag handle (FR-014)
  ///
  /// In vi, this message translates to:
  /// **'Sắp xếp nhóm {name}'**
  String expenseControlReorderSemantic(String name);

  /// Semantics label for an item/group row's edit (pencil) button
  ///
  /// In vi, this message translates to:
  /// **'Sửa {name}'**
  String expenseControlEditSemantic(String name);

  /// Semantics label for an item/group row's delete (trash) button
  ///
  /// In vi, this message translates to:
  /// **'Xoá {name}'**
  String expenseControlDeleteSemantic(String name);

  /// Semantics label for a group's chevron when collapsed (tap to expand)
  ///
  /// In vi, this message translates to:
  /// **'Mở rộng {name}'**
  String expenseControlExpandSemantic(String name);

  /// Semantics label for a group's chevron when expanded (tap to collapse)
  ///
  /// In vi, this message translates to:
  /// **'Thu gọn {name}'**
  String expenseControlCollapseSemantic(String name);

  /// Title of the edit dialog (name/icon/description only — research.md §9)
  ///
  /// In vi, this message translates to:
  /// **'Sửa khoản'**
  String get expenseControlEditItemTitle;

  /// Title of the group-delete confirmation dialog (FR-016)
  ///
  /// In vi, this message translates to:
  /// **'Xoá nhóm \"{name}\"?'**
  String expenseControlDeleteGroupTitle(String name);

  /// Cascading-removal warning body text in the group-delete confirmation dialog (FR-016)
  ///
  /// In vi, this message translates to:
  /// **'Các khoản con trong nhóm này cũng sẽ bị xoá.'**
  String get expenseControlDeleteGroupWarning;

  /// Confirm button in the group-delete confirmation dialog
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get expenseControlDeleteGroupConfirmAction;

  /// Primary button that commits pending inline formula edits (research.md §9, FR-012)
  ///
  /// In vi, this message translates to:
  /// **'Lưu công thức'**
  String get expenseControlSaveFormulaAction;

  /// FR-012: shown when "Lưu công thức" is blocked because the pending plan violates the percentage budget
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu: tổng phần trăm là {total}%, vượt quá giới hạn cho phép.'**
  String expenseControlSaveFormulaBlockedMessage(String total);

  /// Placeholder message on the Lịch sử/Báo cáo screen (out of scope for this feature)
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang được phát triển.'**
  String get historyPlaceholderMessage;

  /// Title of the confirmation prompt shown when switching tabs with unsaved pending edits (FR-009, US3)
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi?'**
  String get expenseControlDiscardPromptTitle;

  /// Body text of the tab-switch confirmation prompt (FR-009, US3)
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thay đổi chưa lưu trong Kiểm soát chi tiêu. Bạn có muốn lưu trước khi rời đi không?'**
  String get expenseControlDiscardPromptMessage;

  /// Button that saves pending edits then navigates away (FR-010, US3 Scenario 2)
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get expenseControlDiscardPromptSaveAction;

  /// Button that discards pending edits then navigates away (FR-011, US3 Scenario 3)
  ///
  /// In vi, this message translates to:
  /// **'Không lưu'**
  String get expenseControlDiscardPromptDiscardAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
