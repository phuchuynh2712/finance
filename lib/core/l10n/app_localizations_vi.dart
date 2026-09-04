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
  String get tabSpending => 'Chi tiêu';

  @override
  String get tabEnvelopes => 'Khoản';

  @override
  String get tabAccount => 'Cá nhân';

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
  String get overviewTitle => 'Tổng quan';

  @override
  String get overviewEmptyState =>
      'Chưa có khoản nào. Hãy tạo khoản trong tab Khoản trước.';

  @override
  String get overviewPlanAction => 'Lập kế hoạch';

  @override
  String get planTitle => 'Lập kế hoạch';

  @override
  String get planIncomeLabel => 'Số tiền thu nhập';

  @override
  String get planPreviewHeading => 'Xem trước phân bổ';

  @override
  String planOverAllocationWarning(String excess) {
    return 'Tổng phân bổ vượt quá thu nhập $excess ₫. Vui lòng điều chỉnh trước khi xác nhận.';
  }

  @override
  String get planMissingReceiverWarning =>
      'Còn dư sau khi phân bổ nhưng chưa có khoản nào được đặt làm nơi nhận phần dư. Vui lòng đặt một khoản trong tab Khoản.';

  @override
  String get planNegativeBalanceWarning =>
      'Một hoặc nhiều khoản sẽ vẫn bị âm sau khi phân bổ.';

  @override
  String get planConfirmAction => 'Xác nhận';

  @override
  String planErrorPrefix(String error) {
    return 'Không thể xác nhận kế hoạch: $error';
  }

  @override
  String get spendingTitle => 'Chi tiêu';

  @override
  String get spendingEmptyState => 'Chưa có khoản chi nào.';

  @override
  String get spendingAddAction => 'Thêm khoản chi';

  @override
  String get spendingNoEnvelopesWarning =>
      'Chưa có khoản nào. Hãy tạo khoản trong tab Khoản trước khi ghi chi tiêu.';

  @override
  String get spendingDeleteConfirmTitle => 'Xóa khoản chi?';

  @override
  String get spendingDeleteConfirmAction => 'Xóa';

  @override
  String get cancelAction => 'Hủy';

  @override
  String get expenseFormTitleCreate => 'Ghi khoản chi';

  @override
  String get expenseFormTitleEdit => 'Sửa khoản chi';

  @override
  String get expenseFormAmountLabel => 'Số tiền';

  @override
  String get expenseFormEnvelopeLabel => 'Khoản';

  @override
  String get expenseFormNoteLabel => 'Ghi chú (không bắt buộc)';

  @override
  String get expenseFormSaveAction => 'Lưu';

  @override
  String expenseFormErrorPrefix(String error) {
    return 'Không thể lưu khoản chi: $error';
  }

  @override
  String get coveringPromptTitle => 'Chọn khoản để bù';

  @override
  String coveringPromptMessage(String shortfall) {
    return 'Khoản chi này vượt quá số dư $shortfall ₫. Chọn một khoản khác để bù phần thiếu.';
  }

  @override
  String get envelopesTitle => 'Khoản';

  @override
  String get envelopesEmptyState =>
      'Chưa có khoản nào. Nhấn nút bên dưới để tạo khoản đầu tiên.';

  @override
  String get envelopesAddAction => 'Thêm khoản';

  @override
  String get envelopesReceiverBadge => 'Nhận phần dư';

  @override
  String get envelopeFormTitleCreate => 'Tạo khoản';

  @override
  String get envelopeFormTitleEdit => 'Sửa khoản';

  @override
  String get envelopeFormNameLabel => 'Tên khoản';

  @override
  String get envelopeFormMethodLabel => 'Cách phân bổ';

  @override
  String get envelopeFormMethodPercentage => 'Theo phần trăm';

  @override
  String get envelopeFormMethodFixed => 'Số tiền cố định';

  @override
  String get envelopeFormValueLabelPercentage => 'Phần trăm (%)';

  @override
  String get envelopeFormValueLabelFixed => 'Số tiền cố định';

  @override
  String get envelopeFormReceiverToggle => 'Nhận phần dư khi làm tròn';

  @override
  String get envelopeFormSaveAction => 'Lưu';

  @override
  String envelopeFormErrorPrefix(String error) {
    return 'Không thể lưu khoản: $error';
  }

  @override
  String envelopeDeleteConfirmTitle(String name) {
    return 'Xóa khoản \"$name\"?';
  }

  @override
  String envelopeDeleteNonZeroWarning(String balance) {
    return 'Khoản này vẫn còn số dư $balance ₫. Xóa sẽ ảnh hưởng đến số dư và lịch sử giao dịch liên quan.';
  }

  @override
  String get envelopeDeleteConfirmAction => 'Xóa';

  @override
  String get envelopeReassignReceiverTitle => 'Chọn khoản nhận phần dư mới';

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
}
