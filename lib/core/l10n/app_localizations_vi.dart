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
}
