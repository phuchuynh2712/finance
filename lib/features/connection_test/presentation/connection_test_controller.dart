import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client_provider.dart';
import '../data/connection_test_repository_impl.dart';
import '../domain/connection_status.dart';
import '../domain/connection_test_repository.dart';

final connectionTestRepositoryProvider = Provider<ConnectionTestRepository>((
  ref,
) {
  return ConnectionTestRepositoryImpl(ref.watch(supabaseClientProvider));
});

final connectionStatusProvider =
    FutureProvider.autoDispose<ConnectionStatus>((ref) async {
      final repository = ref.watch(connectionTestRepositoryProvider);
      try {
        await repository.checkConnection();
        return const ConnectionSuccess();
      } catch (e) {
        return ConnectionFailure(e.toString());
      }
    });
