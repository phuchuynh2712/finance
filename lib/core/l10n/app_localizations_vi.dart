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
}
