import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';

/// FR-020, spec.md US5 Acceptance Scenario 1, SC-007 — exercises the REAL
/// `AppDatabase.migration.onUpgrade` `if (from == 2)` branch against an
/// actual v2-schema SQLite file seeded with real `Envelope`/`ExpenseEntry`
/// rows, not an in-memory DB created fresh at the latest schema (which
/// never runs `onUpgrade` at all). This is the highest-risk uncovered path
/// in this feature: `PRAGMA foreign_keys = ON` means the drop order
/// (`envelope_coverages` → `allocation_event_lines` → `allocation_events`
/// → `expense_entries` → `envelopes`) must be exactly right or the upgrade
/// throws on a real device.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('finance_migration_test');
    dbFile = File('${tempDir.path}/finance_v2.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Builds a v2-schema database on disk (schema matching what shipped
  /// before this feature: `ExpenseControlItems` without `balance`, plus
  /// every Envelope-era table), seeded with one real row per table so the
  /// migration's drop order is exercised against actual FK-linked data,
  /// not just empty tables.
  void seedV2Database() {
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE expense_control_items (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        parent_id TEXT NULL,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        description TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        allocation_method TEXT NULL,
        allocation_value REAL NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE sync_outbox (
        id TEXT NOT NULL PRIMARY KEY,
        entity_table TEXT NOT NULL,
        row_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        synced_at INTEGER NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE envelopes (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        allocation_method TEXT NOT NULL,
        allocation_value REAL NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        is_rounding_receiver INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE expense_entries (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        envelope_id TEXT NOT NULL REFERENCES envelopes (id),
        amount INTEGER NOT NULL,
        entry_date INTEGER NOT NULL,
        note TEXT NULL,
        entry_method TEXT NOT NULL DEFAULT 'manual',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE envelope_coverages (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        expense_entry_id TEXT NOT NULL REFERENCES expense_entries (id),
        source_envelope_id TEXT NOT NULL REFERENCES envelopes (id),
        covering_envelope_id TEXT NOT NULL REFERENCES envelopes (id),
        amount INTEGER NOT NULL,
        covered_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE allocation_events (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        event_date INTEGER NOT NULL,
        income_amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      CREATE TABLE allocation_event_lines (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        allocation_event_id TEXT NOT NULL REFERENCES allocation_events (id),
        envelope_id TEXT NOT NULL REFERENCES envelopes (id),
        amount INTEGER NOT NULL,
        is_rounding_remainder_line INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      );
      PRAGMA user_version = 2;
    ''');

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO expense_control_items
        (id, user_id, parent_id, name, icon_key, sort_order, allocation_method, allocation_value, created_at, updated_at)
      VALUES ('item1', 'u1', NULL, 'Rent', 'home', 0, 'fixed', 5000000, $now, $now);

      INSERT INTO envelopes (id, user_id, name, allocation_method, allocation_value, balance, created_at, updated_at)
      VALUES ('env1', 'u1', 'Groceries', 'percentage', 20, 150000, $now, $now);

      INSERT INTO expense_entries (id, user_id, envelope_id, amount, entry_date, created_at, updated_at)
      VALUES ('exp1', 'u1', 'env1', 50000, $now, $now, $now);

      INSERT INTO envelopes (id, user_id, name, allocation_method, allocation_value, balance, created_at, updated_at)
      VALUES ('env2', 'u1', 'Fun', 'percentage', 10, 20000, $now, $now);

      INSERT INTO envelope_coverages
        (id, user_id, expense_entry_id, source_envelope_id, covering_envelope_id, amount, covered_at, created_at, updated_at)
      VALUES ('cov1', 'u1', 'exp1', 'env1', 'env2', 10000, $now, $now, $now);

      INSERT INTO allocation_events (id, user_id, event_date, income_amount, created_at, updated_at)
      VALUES ('alloc1', 'u1', $now, 1000000, $now, $now);

      INSERT INTO allocation_event_lines
        (id, user_id, allocation_event_id, envelope_id, amount, created_at, updated_at)
      VALUES ('line1', 'u1', 'alloc1', 'env1', 200000, $now, $now);
    ''');
    raw.dispose();
  }

  test(
    'upgrading a real v2 database with Envelope/ExpenseEntry rows drops every Envelope-era table without crashing, and preserves ExpenseControlItems data',
    () async {
      seedV2Database();

      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      // Opening the database triggers onUpgrade — if the drop order were
      // wrong, `PRAGMA foreign_keys = ON` would make this throw here.
      final items = await db.select(db.expenseControlItems).get();

      expect(items, hasLength(1));
      expect(items.single.id, 'item1');
      expect(items.single.name, 'Rent');
      // FR-011: the pre-existing row's new `balance` column defaults to 0,
      // not lost or corrupted by the migration.
      expect(items.single.balance, 0);

      // Confirm every Envelope-era table is actually gone at the SQLite
      // level, not just inaccessible via the (now-removed) Drift bindings.
      final remainingTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
            "('envelopes', 'expense_entries', 'envelope_coverages', "
            "'allocation_events', 'allocation_event_lines')",
          )
          .get();
      expect(remainingTables, isEmpty);
    },
  );
}
