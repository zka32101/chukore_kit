import 'package:sqlite3/sqlite3.dart';

import '../models/models.dart';
import 'attempt_store.dart';

/// SQLite（sqlite3）による回答履歴ストア。回答は UTC の ISO8601 文字列で保存し、
/// 文字列比較で日付範囲・単元別に絞る。
/// 海外対応: 日付の区切りは端末のローカル暦日。読み出しはローカル時刻にして、
/// 範囲の境界はローカルの0時を UTC に直して比較する（時差のある国でも日付がずれない）。
class SqliteAttemptStore implements AttemptStore {
  SqliteAttemptStore(this._db) {
    final version = _db.select('PRAGMA user_version').first.values.first as int;
    if (version > schemaVersion) {
      throw StateError('新しい版のデータベースです（$version > $schemaVersion）。アプリを更新してください');
    }
    _db.execute('''
      CREATE TABLE IF NOT EXISTS attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        correct INTEGER NOT NULL,
        chosen_id TEXT,
        answered_at TEXT NOT NULL,
        elapsed_ms INTEGER NOT NULL DEFAULT 0,
        mode TEXT NOT NULL DEFAULT 'practice',
        confident INTEGER,
        reason TEXT,
        hints_used INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_attempts_unit ON attempts(unit_id, answered_at);
      CREATE INDEX IF NOT EXISTS idx_attempts_time ON attempts(answered_at);
    ''');
    // 版 1 → 2: 自信度の列を足す。版の数字ではなく列の有無で見る
    // （版を記録する前に作られた DB は user_version が 0 のままのため）。
    final columns = {for (final r in _db.select('PRAGMA table_info(attempts)')) r['name'] as String};
    if (!columns.contains('confident')) _db.execute('ALTER TABLE attempts ADD COLUMN confident INTEGER');
    // 版 2 → 3: 間違えた理由の自己申告の列を足す。
    if (!columns.contains('reason')) _db.execute('ALTER TABLE attempts ADD COLUMN reason TEXT');
    // 版 3 → 4: 見たヒントの数の列を足す。
    if (!columns.contains('hints_used')) _db.execute('ALTER TABLE attempts ADD COLUMN hints_used INTEGER NOT NULL DEFAULT 0');
    if (version < schemaVersion) _db.execute('PRAGMA user_version = $schemaVersion');
  }

  /// テーブル構成の版。列を足すときは上げて、移行を書く。
  static const schemaVersion = 4;

  final Database _db;

  @override
  Future<void> add(Attempt a) async {
    _db.execute(
      'INSERT INTO attempts (question_id, unit_id, correct, chosen_id, answered_at, elapsed_ms, mode, confident, reason, hints_used) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        a.questionId,
        a.unitId,
        a.correct ? 1 : 0,
        a.chosenId,
        a.answeredAt.toUtc().toIso8601String(),
        a.elapsedMs,
        a.mode,
        a.confident == null ? null : (a.confident! ? 1 : 0),
        a.reason?.name,
        a.hintsUsed,
      ],
    );
  }

  /// 全件削除。`VACUUM` で空き領域も詰め、削除した行の内容がファイルに残らないようにする。
  @override
  Future<void> deleteAll() async {
    _db.execute('DELETE FROM attempts');
    _db.execute('VACUUM');
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
      args.add(_localMidnightUtc(from));
    }
    if (to != null) {
      where.add('answered_at < ?');
      args.add(_localMidnightUtc(to));
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
          answeredAt: DateTime.parse(r['answered_at'] as String).toLocal(),
          elapsedMs: r['elapsed_ms'] as int,
          mode: r['mode'] as String,
          confident: switch (r['confident'] as int?) { null => null, final c => c == 1 },
          // 知らない値（将来の版で足された理由など）は読み飛ばして null にする
          reason: LossReason.values.where((x) => x.name == r['reason']).firstOrNull,
          hintsUsed: r['hints_used'] as int,
        ),
    ];
  }

  /// 指定日（日付部分）のローカル0時を UTC の文字列にする。
  static String _localMidnightUtc(DateTime d) =>
      DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
}
