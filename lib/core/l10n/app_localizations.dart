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

  /// Bottom navigation tab label for the Spending screen
  ///
  /// In vi, this message translates to:
  /// **'Chi tiêu'**
  String get tabSpending;

  /// Bottom navigation tab label for the Envelopes screen
  ///
  /// In vi, this message translates to:
  /// **'Khoản'**
  String get tabEnvelopes;

  /// Bottom navigation tab label for the Account screen
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get tabAccount;

  /// Title of the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get signInTitle;

  /// Label for the email input field on the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get signInEmailLabel;

  /// Label for the password input field on the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get signInPasswordLabel;

  /// Submit button label on the sign-in screen
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get signInSubmit;

  /// Shown when sign-in fails
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thất bại: {error}'**
  String signInError(String error);

  /// Title of the Overview screen
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get overviewTitle;

  /// Shown on Overview when the user has no envelopes yet
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản nào. Hãy tạo khoản trong tab Khoản trước.'**
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
  /// **'Còn dư sau khi phân bổ nhưng chưa có khoản nào được đặt làm nơi nhận phần dư. Vui lòng đặt một khoản trong tab Khoản.'**
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
  /// **'Chưa có khoản nào. Hãy tạo khoản trong tab Khoản trước khi ghi chi tiêu.'**
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

  /// Confirmation shown after the password is changed
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu.'**
  String get accountPasswordSavedMessage;

  /// Shown when changing the password fails
  ///
  /// In vi, this message translates to:
  /// **'Không thể đổi mật khẩu: {error}'**
  String accountPasswordErrorPrefix(String error);

  /// Button to sign out of the account
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get accountSignOutAction;
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
