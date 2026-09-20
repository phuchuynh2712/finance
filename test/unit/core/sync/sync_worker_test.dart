import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FR-019, spec.md US5 Acceptance Scenario 5 — `SyncWorker` no longer reads
/// the (now-deleted) Supabase `envelope_balances` view or reconciles any
/// Envelope-related balance. `SupabaseClient` is a concrete class with no
/// repository interface in front of it here (a pre-existing gap, not
/// introduced by this feature), so a real Supabase connection would be
/// needed to exercise this behaviorally; a source-level assertion is the
/// direct, honest way to verify the reconciliation call path is gone
/// entirely, not merely unreachable.
void main() {
  test(
    'sync_worker.dart makes no reference to envelope_balances or Envelope-related reconciliation',
    () {
      final lines = File('lib/core/sync/sync_worker.dart').readAsLinesSync();
      // Doc comments are allowed to mention "Envelope" in prose explaining
      // the removal (FR-019's rationale) — only executable code lines must
      // have zero reference to the deleted view/method/stream.
      final codeLines = lines.where((line) => !line.trim().startsWith('///'));
      final code = codeLines.join('\n');

      expect(code.contains('envelope_balances'), isFalse);
      expect(code.contains('Envelope'), isFalse);
      expect(code.contains('_reconcileBalances'), isFalse);
      expect(code.contains('reconciliationWarnings'), isFalse);
    },
  );
}
