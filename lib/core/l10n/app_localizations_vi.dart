// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Quản lý tài chính';

  @override
  String get tabOverview => 'Tổng quan';

  @override
  String get tabSpending => 'Thu chi';

  @override
  String get tabExpenseControl => 'Kế hoạch';

  @override
  String get tabHistory => 'Báo cáo';

  @override
  String get tabAccount => 'Hồ sơ';

  @override
  String get signInAppName => 'Kiểm Soát';

  @override
  String get signInAppSubtitle => 'Quản lý thu chi thông minh';

  @override
  String get signInTitle => 'Đăng nhập';

  @override
  String get signInIdentifierLabel => 'Số điện thoại hoặc email';

  @override
  String get signInPasswordLabel => 'Mật khẩu';

  @override
  String get signInShowPasswordSemantic => 'Hiện mật khẩu';

  @override
  String get signInHidePasswordSemantic => 'Ẩn mật khẩu';

  @override
  String get signInForgotPasswordAction => 'Quên mật khẩu?';

  @override
  String get signInSubmit => 'Đăng nhập';

  @override
  String signInError(String error) {
    return 'Đăng nhập thất bại: $error';
  }

  @override
  String get signInOrDivider => 'hoặc';

  @override
  String get signInWithBiometricAction => 'Đăng nhập bằng vân tay';

  @override
  String get cancelAction => 'Hủy';

  @override
  String get accountTitle => 'Hồ sơ';

  @override
  String get accountAppearanceLabel => 'Giao diện';

  @override
  String get accountAppearanceLightOption => 'Sáng';

  @override
  String get accountAppearanceDarkOption => 'Tối';

  @override
  String get accountLanguageLabel => 'Ngôn ngữ';

  @override
  String get accountLanguageDialogTitle => 'Chọn ngôn ngữ';

  @override
  String get accountLanguageVietnamese => 'Tiếng Việt';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountSignOutAction => 'Đăng xuất';

  @override
  String get signUpTitle => 'Tạo tài khoản';

  @override
  String get signUpBackSemantic => 'Quay lại';

  @override
  String get signUpEmailLabel => 'Email';

  @override
  String get signUpPasswordLabel => 'Mật khẩu';

  @override
  String get signUpConfirmPasswordLabel => 'Xác nhận mật khẩu';

  @override
  String get signUpNameLabel => 'Họ và tên';

  @override
  String get signUpPhoneLabel => 'Số điện thoại';

  @override
  String get signUpEmailInvalidError => 'Email không hợp lệ.';

  @override
  String get signUpPasswordTooShortError => 'Mật khẩu phải có ít nhất 6 ký tự.';

  @override
  String get signUpConfirmPasswordMismatchError =>
      'Mật khẩu xác nhận không khớp.';

  @override
  String get signUpTermsPrefix => 'Tôi đồng ý với ';

  @override
  String get signUpTermsOfServiceLink => 'Điều khoản dịch vụ';

  @override
  String get signUpTermsMiddle => ' và ';

  @override
  String get signUpPrivacyPolicyLink => 'Chính sách bảo mật';

  @override
  String get signUpSubmit => 'Đăng ký';

  @override
  String signUpError(String error) {
    return 'Đăng ký thất bại: $error';
  }

  @override
  String get signUpDuplicateEmailError =>
      'Email này đã được đăng ký. Hãy đăng nhập bằng mật khẩu.';

  @override
  String get signUpNavigateToSignIn => 'Đã có tài khoản? Đăng nhập';

  @override
  String get signInNavigateToSignUp => 'Chưa có tài khoản? Đăng ký ngay';

  @override
  String get biometricEnablePromptTitle => 'Bật đăng nhập vân tay?';

  @override
  String get biometricEnablePromptMessage =>
      'Lần sau bạn có thể vào ứng dụng nhanh hơn chỉ bằng vân tay, không cần gõ mật khẩu.';

  @override
  String get biometricEnablePromptAcceptAction => 'Bật';

  @override
  String get biometricEnablePromptDeclineAction => 'Để sau';

  @override
  String get forgotPasswordTitle => 'Quên mật khẩu';

  @override
  String get forgotPasswordInstructions =>
      'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết đặt lại mật khẩu.';

  @override
  String get forgotPasswordEmailLabel => 'Email';

  @override
  String get forgotPasswordSubmitAction => 'Gửi liên kết đặt lại';

  @override
  String get forgotPasswordConfirmationMessage =>
      'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu trong ít phút.';

  @override
  String get forgotPasswordBackToSignIn => 'Quay lại đăng nhập';

  @override
  String get resetPasswordTitle => 'Đặt mật khẩu mới';

  @override
  String get resetPasswordNewPasswordLabel => 'Mật khẩu mới';

  @override
  String get resetPasswordConfirmPasswordLabel => 'Xác nhận mật khẩu mới';

  @override
  String get resetPasswordSubmitAction => 'Đặt lại mật khẩu';

  @override
  String get resetPasswordSuccessMessage =>
      'Đã đặt lại mật khẩu. Vui lòng đăng nhập lại bằng mật khẩu mới.';

  @override
  String get resetPasswordMismatchError => 'Mật khẩu xác nhận không khớp.';

  @override
  String resetPasswordError(String error) {
    return 'Không thể đặt lại mật khẩu: $error';
  }

  @override
  String get expenseControlScreenTitle => 'Kiểm soát chi tiêu';

  @override
  String get expenseControlBannerHint => 'Bấm tên các khoản để đóng/mở.';

  @override
  String get expenseControlEmptyStateMessage =>
      'Chưa có khoản nào. Hãy thêm khoản đầu tiên để bắt đầu kiểm soát chi tiêu.';

  @override
  String get expenseControlAddItemAction => 'Thêm khoản mới';

  @override
  String expenseControlAddChildAction(String groupName) {
    return 'Thêm khoản trong $groupName';
  }

  @override
  String get expenseControlFixedNote =>
      'Khoản cố định không giới hạn ở đây, nhưng nếu thu nhập thực tế không đủ, khoản này có thể không được phân bổ đầy đủ khi thu nhập thực sự được phân bổ.';

  @override
  String get expenseControlNameLabel => 'Tên khoản';

  @override
  String get expenseControlDescriptionLabel => 'Ghi chú (không bắt buộc)';

  @override
  String get expenseControlValueLabel => 'Giá trị';

  @override
  String get expenseControlModePercentage => 'Phần trăm';

  @override
  String get expenseControlModeFixed => 'Số tiền cố định';

  @override
  String get expenseControlIconPickerLabel => 'Chọn biểu tượng';

  @override
  String expenseControlIconSemanticLabel(String name) {
    return 'Biểu tượng $name';
  }

  @override
  String get expenseControlDialogSaveAction => 'Lưu';

  @override
  String get expenseControlNameRequiredError => 'Vui lòng nhập tên khoản.';

  @override
  String get expenseControlValueRequiredError =>
      'Vui lòng nhập giá trị lớn hơn 0.';

  @override
  String expenseControlOverBudgetError(String total) {
    return 'Tổng phần trăm là $total%, vượt quá giới hạn cho phép. Vui lòng điều chỉnh.';
  }

  @override
  String allocationSummaryAllocatedLine(String percent, int fixedCount) {
    return 'Đã phân bổ $percent% + $fixedCount khoản cố định';
  }

  @override
  String allocationSummaryFreeLine(String percent) {
    return 'Còn $percent% tự do';
  }

  @override
  String expenseControlReorderSemantic(String name) {
    return 'Sắp xếp nhóm $name';
  }

  @override
  String expenseControlEditSemantic(String name) {
    return 'Sửa $name';
  }

  @override
  String expenseControlDeleteSemantic(String name) {
    return 'Xoá $name';
  }

  @override
  String expenseControlExpandSemantic(String name) {
    return 'Mở rộng $name';
  }

  @override
  String expenseControlCollapseSemantic(String name) {
    return 'Thu gọn $name';
  }

  @override
  String get expenseControlEditItemTitle => 'Sửa khoản';

  @override
  String expenseControlDeleteGroupTitle(String name) {
    return 'Xoá nhóm \"$name\"?';
  }

  @override
  String get expenseControlDeleteGroupWarning =>
      'Các khoản con trong nhóm này cũng sẽ bị xoá.';

  @override
  String get expenseControlDeleteGroupConfirmAction => 'Xoá';

  @override
  String get expenseControlSaveFormulaAction => 'Lưu công thức';

  @override
  String expenseControlSaveFormulaBlockedMessage(String total) {
    return 'Không thể lưu: tổng phần trăm là $total%, vượt quá giới hạn cho phép.';
  }

  @override
  String get historyPlaceholderMessage => 'Tính năng đang được phát triển.';

  @override
  String get expenseControlDiscardPromptTitle => 'Lưu thay đổi?';

  @override
  String get expenseControlDiscardPromptMessage =>
      'Bạn có thay đổi chưa lưu trong Kiểm soát chi tiêu. Bạn có muốn lưu trước khi rời đi không?';

  @override
  String get expenseControlDiscardPromptSaveAction => 'Lưu';

  @override
  String get expenseControlDiscardPromptDiscardAction => 'Không lưu';

  @override
  String get spendingBalanceListLabel => 'Số dư từng khoản';

  @override
  String get spendingBalanceEmptyState =>
      'Chưa có khoản nào. Hãy tạo khoản trong tab Kiểm soát chi tiêu trước.';

  @override
  String get spendingIncomeAction => 'Thu nhập';

  @override
  String get spendingExpenseAction => 'Chi tiêu';

  @override
  String get spendingHistoryAction => 'Xem lịch sử giao dịch';

  @override
  String get notAvailablePlaceholderMessage =>
      'Tính năng đang được phát triển.';

  @override
  String get incomePlaceholderTitle => 'Thu nhập';

  @override
  String get expensePlaceholderTitle => 'Chi tiêu';

  @override
  String get transactionHistoryPlaceholderTitle => 'Lịch sử giao dịch';

  @override
  String get overviewPlaceholderTitle => 'Tổng quan';

  @override
  String get accountNotificationsRowLabel => 'Thông báo';

  @override
  String get accountSecurityRowLabel => 'Bảo mật';

  @override
  String get accountHelpRowLabel => 'Trợ giúp';

  @override
  String get incomeScreenTitle => 'Thu nhập';

  @override
  String get incomeTotalLabel => 'Tổng thu nhập';

  @override
  String get incomeSourcesEyebrow => 'Các nguồn thu nhập';

  @override
  String get incomeSourceNameLabel => 'Tên nguồn thu nhập';

  @override
  String get incomeSourceAmountLabel => 'Số tiền';

  @override
  String incomeSourceDeleteSemantic(String name) {
    return 'Xóa nguồn thu nhập $name';
  }

  @override
  String get incomeAddSourceAction => 'Thêm nguồn thu nhập khác';

  @override
  String get incomeSaveAction => 'Lưu thu nhập';

  @override
  String get incomeEmptyStateMessage =>
      'Chưa có khoản nào. Hãy tạo khoản trong tab Kiểm soát chi tiêu trước.';

  @override
  String get incomeErrorInvalidTotal =>
      'Vui lòng nhập số tiền thu nhập lớn hơn 0.';

  @override
  String get incomeErrorMissingRowName =>
      'Vui lòng đặt tên cho nguồn thu nhập này.';

  @override
  String get incomeErrorMissingRowAmount =>
      'Vui lòng nhập số tiền cho nguồn thu nhập này.';

  @override
  String incomeErrorWriteFailedPrefix(String error) {
    return 'Không thể lưu thu nhập: $error';
  }

  @override
  String get savingsReceiverToggleLabel => 'Nhận phần dư thu nhập';

  @override
  String get savingsReceiverBlockedError =>
      'Chỉ một khoản được đánh dấu nhận phần dư. Hãy bỏ đánh dấu khoản kia trước.';

  @override
  String get savingsReceiverAutoClearWarning =>
      'Khoản này đang nhận phần dư thu nhập. Thêm khoản con sẽ tự động bỏ đánh dấu này.';

  @override
  String get expenseScreenTitle => 'Chi tiêu';

  @override
  String get expenseTabManual => 'Nhập tay';

  @override
  String get expenseTabScan => 'Quét hoá đơn';

  @override
  String get expenseAmountLabel => 'Số tiền';

  @override
  String get expensePickItemEyebrow => 'TRỪ VÀO KHOẢN NÀO';

  @override
  String get expenseSaveAction => 'Lưu giao dịch';

  @override
  String get expenseEmptyStateMessage =>
      'Chưa có khoản nào. Hãy thiết lập ở Kiểm soát chi tiêu trước.';

  @override
  String get expenseErrorInvalidAmount => 'Vui lòng nhập số tiền lớn hơn 0.';

  @override
  String get expenseErrorMissingItem => 'Vui lòng chọn khoản để trừ tiền.';

  @override
  String expenseErrorWriteFailedPrefix(Object error) {
    return 'Không thể lưu giao dịch chi tiêu: $error';
  }

  @override
  String expenseItemPickedSemantic(Object name) {
    return 'Trừ vào khoản $name';
  }

  @override
  String get expenseScanFrameHint => 'Đưa hoá đơn vào khung hình';

  @override
  String get expenseScanCaptureAction => 'Chụp hoá đơn';

  @override
  String expenseScanRecognizedLabel(Object amount, Object merchant) {
    return 'Đã nhận diện: $amount · $merchant';
  }

  @override
  String get expenseScanConfirmAction => 'Xác nhận & lưu';

  @override
  String get errorMapperInvalidCredentials =>
      'Sai email hoặc mật khẩu. Vui lòng thử lại.';

  @override
  String get errorMapperEmailExists =>
      'Email này đã được đăng ký. Hãy đăng nhập bằng mật khẩu.';

  @override
  String get errorMapperWeakPassword =>
      'Mật khẩu chưa đủ mạnh. Vui lòng chọn mật khẩu khác.';

  @override
  String get errorMapperRateLimited =>
      'Bạn đã thử quá nhiều lần. Vui lòng đợi một chút rồi thử lại.';

  @override
  String get errorMapperNetworkFailure =>
      'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.';

  @override
  String get errorMapperGeneric => 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get transactionHistoryTitle => 'Lịch sử giao dịch';

  @override
  String get transactionHistoryAllFilter => 'Tất cả';

  @override
  String get transactionHistoryIncomeFilter => 'Thu nhập';

  @override
  String transactionHistoryExpenseTotal(String amount) {
    return 'Tổng chi tháng này: $amount';
  }

  @override
  String get transactionHistoryEmpty => 'Không có giao dịch phù hợp.';

  @override
  String get transactionHistoryLoadError => 'Không thể tải lịch sử giao dịch.';

  @override
  String get transactionHistoryRetry => 'Thử lại';

  @override
  String get transactionHistoryBackSemantic => 'Quay lại Thu chi';

  @override
  String get transactionHistoryPreviousMonthSemantic => 'Tháng trước';

  @override
  String get transactionHistoryNextMonthSemantic => 'Tháng sau';

  @override
  String get transactionHistoryArchivedItem => 'Mục đã lưu trữ';

  @override
  String get transactionHistoryIncomeClassification => 'Thu nhập';

  @override
  String get startupConfigurationTitle => 'Cần cấu hình ứng dụng';

  @override
  String get startupConfigurationMessage =>
      'Hãy thiết lập URL Supabase và publishable key trước khi khởi động ứng dụng.';

  @override
  String get overviewTotalBalanceLabel => 'Tổng còn lại · tất cả các khoản';

  @override
  String overviewNegativeBalanceWarning(String name) {
    return 'Khoản \"$name\" đã âm quỹ';
  }

  @override
  String get overviewSeeDetailAction => 'Xem chi tiết →';

  @override
  String get overviewLoadError => 'Không thể tải dữ liệu tổng quan.';

  @override
  String get overviewRetry => 'Thử lại';

  @override
  String overviewAccountsSectionTitle(int count) {
    return 'Các khoản ($count)';
  }

  @override
  String get overviewSeeAllAction => 'Xem tất cả';

  @override
  String get overviewSeeAllAccountsSemantic => 'Xem tất cả các khoản';

  @override
  String get overviewAccountsEmpty => 'Chưa có khoản nào.';

  @override
  String get overviewRecentTransactionsSectionTitle => 'Giao dịch gần đây';

  @override
  String get overviewSeeAllTransactionsSemantic =>
      'Xem tất cả giao dịch gần đây';

  @override
  String get overviewTransactionsEmpty => 'Chưa có giao dịch nào.';

  @override
  String get overviewToday => 'Hôm nay';

  @override
  String get overviewYesterday => 'Hôm qua';

  @override
  String overviewDaysAgo(int days) {
    return '$days ngày trước';
  }

  @override
  String overviewGreeting(String name) {
    return 'Xin chào, $name';
  }

  @override
  String get overviewNotificationSemantic => 'Thông báo';
}
