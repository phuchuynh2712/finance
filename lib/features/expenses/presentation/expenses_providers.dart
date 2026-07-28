import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/expense_repository_impl.dart';
import '../domain/expense_entry.dart';
import '../domain/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(
    ref.watch(appDatabaseProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});

final expensesStreamProvider = StreamProvider<List<ExpenseEntry>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});
