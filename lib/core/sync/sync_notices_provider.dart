import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/database/app_database_provider.dart';
import 'sync_notice.dart';

/// The notices of the sync layer waiting to be shown once (refusals the server
/// made, changes it replaced, balances that do not match its own). Read by the
/// sync services that raise them and by the one `SyncNoticeHost` that shows
/// them.
final syncNoticesProvider = Provider<SyncNotices>((ref) {
  final notices = SyncNotices(ref.watch(appDatabaseProvider));
  ref.onDispose(notices.dispose);
  return notices;
});
