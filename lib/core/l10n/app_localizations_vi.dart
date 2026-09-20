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
  String get tabExpenseControl => 'Kiểm soát';

  @override
  String get tabHistory => 'Báo cáo';

  @override
  String get tabAccount => 'Hồ sơ';

  @override
  String get signInAppName => 'Khai Tâm';

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
  String get accountTitle => 'Cá nhân';

  @override
  String get accountAvatarUrlLabel => 'Đường dẫn ảnh đại diện';

  @override
  String get accountAvatarSaveAction => 'Cập nhật ảnh đại diện';

  @override
  String get accountAvatarSavedMessage => 'Đã cập nhật ảnh đại diện.';

  @override
  String accountAvatarErrorPrefix(String error) {
    return 'Không thể cập nhật ảnh đại diện: $error';
  }

  @override
  String get accountNewPasswordLabel => 'Mật khẩu mới';

  @override
  String get accountPasswordSaveAction => 'Đổi mật khẩu';

  @override
  String get accountPasswordSavedMessage =>
      'Đã đổi mật khẩu. Các thiết bị khác đã đăng nhập sẽ bị đăng xuất.';

  @override
  String accountPasswordErrorPrefix(String error) {
    return 'Không thể đổi mật khẩu: $error';
  }

  @override
  String get accountBiometricToggleLabel => 'Đăng nhập bằng vân tay';

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
}
