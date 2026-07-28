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
  String get signInTitle => 'Đăng nhập';

  @override
  String get signInEmailLabel => 'Email';

  @override
  String get signInPasswordLabel => 'Mật khẩu';

  @override
  String get signInSubmit => 'Đăng nhập';

  @override
  String signInError(String error) {
    return 'Đăng nhập thất bại: $error';
  }

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
  String get accountPasswordSavedMessage => 'Đã đổi mật khẩu.';

  @override
  String accountPasswordErrorPrefix(String error) {
    return 'Không thể đổi mật khẩu: $error';
  }

  @override
  String get accountSignOutAction => 'Đăng xuất';
}
