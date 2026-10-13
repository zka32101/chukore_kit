import 'package:sqlite3/sqlite3.dart';

import '../models/models.dart';
import 'attempt_store.dart';

/// SQLite（sqlite3）による回答履歴ストア。回答は UTC の ISO8601 文字列で保存し、
/// 文字列比較で日付範囲・単元別に絞る。
class SqliteAttemptStore implements AttemptStore {
  SqliteAttemptStore(this._db) {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        correct INTEGER NOT NULL,
        chosen_id TEXT,
        answered_at TEXT NOT NULL,
        elapsed_ms INTEGER NOT NULL DEFAULT 0,
        mode TEXT NOT NULL DEFAULT 'practice'
      );
      CREATE INDEX IF NOT EXISTS idx_attempts_unit ON attempts(unit_id, answered_at);
      CREATE INDEX IF NOT EXISTS idx_attempts_time ON attempts(answered_at);
    ''');
  }

  final Database _db;

  @override
  Future<void> add(Attempt a) async {
    _db.execute(
      'INSERT INTO attempts (question_id, unit_id, correct, chosen_id, answered_at, elapsed_ms, mode) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        a.questionId,
        a.unitId,
        a.correct ? 1 : 0,
        a.chosenId,
        a.answeredAt.toUtc().toIso8601String(),
        a.elapsedMs,
        a.mode,
      ],
    );
  }

  @override
  Future<List<Attempt>> query({DateTime? from, DateTime? to, String? unitId}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (unitId != null) {
      where.add('unit_id = ?');
      args.add(unitId);
    }
    if (from != null) {
      where.add('answered_at >= ?');
      args.add(dateOnly(from).toIso8601String());
    }
    if (to != null) {
      where.add('answered_at < ?');
      args.add(dateOnly(to).toIso8601String());
    }
    final rows = _db.select(
      'SELECT * FROM attempts ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY answered_at, id',
      args,
    );
    return [
      for (final r in rows)
        Attempt(
          questionId: r['question_id'] as String,
          unitId: r['unit_id'] as String,
          correct: (r['correct'] as int) == 1,
          chosenId: r['chosen_id'] as String?,
          answeredAt: DateTime.parse(r['answered_at'] as String),
          elapsedMs: r['elapsed_ms'] as int,
          mode: r['mode'] as String,
        ),
    ];
  }
}
