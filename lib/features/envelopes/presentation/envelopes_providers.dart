import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state_provider.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/allocation_repository_impl.dart';
import '../data/envelope_repository_impl.dart';
import '../domain/allocation_repository.dart';
import '../domain/envelope.dart';
import '../domain/envelope_repository.dart';

final envelopeRepositoryProvider = Provider<EnvelopeRepository>((ref) {
  return EnvelopeRepositoryImpl(
    ref.watch(appDatabaseProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});

final allocationRepositoryProvider = Provider<AllocationRepository>((ref) {
  return AllocationRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Reactive list of the current user's envelopes, for Overview, Plan, and
/// the Envelopes CRUD screen.
final envelopesStreamProvider = StreamProvider<List<Envelope>>((ref) {
  return ref.watch(envelopeRepositoryProvider).watchAll();
});
