import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/database/app_database.dart';

/// Shared Drift database instance, injected via Riverpod per the
/// constitution's Dependency Injection rule.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
