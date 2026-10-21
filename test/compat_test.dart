// 互換性の固定。v0.2.0 で配った形式（SQLite のスキーマ版・バックアップ形式）を、今後の版でも読めることを守る。
// これらのテストが落ちたら、形式を変えたことになる。**版を上げ、移行を書き、CHANGELOG の「移行時の注意」に書く**こと。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final t = DateTime.utc(2026, 9, 1, 3);

// 各版のテーブル定義（実際に配った形）
const _v1 = '''
CREATE TABLE attempts (
  id INTEGER PRIMARY KEY AUTOINCREMENT, question_id TEXT NOT NULL, unit_id TEXT NOT NULL,
  correct INTEGER NOT NULL, chosen_id TEXT, answered_at TEXT NOT NULL,
  elapsed_ms INTEGER NOT NULL DEFAULT 0, mode TEXT NOT NULL DEFAULT 'practice');
CREATE INDEX idx_attempts_unit ON attempts(unit_id, answered_at);
CREATE INDEX idx_attempts_time ON attempts(answered_at);
''';

void main() {
  group('SQLite: どの旧版からでも、最新へ移行して、既存の回答が残る', () {
    // 版 → (追加で持つ列, user_version)。版 1 は user_version を記録する前だったので 0
    final stages = <String, List<String>>{
      'v1（版の記録なし）': [_v1, 'PRAGMA user_version = 0;'],
      'v1（版 1）': [_v1, 'PRAGMA user_version = 1;'],
      'v2（自信度）': [_v1, 'ALTER TABLE attempts ADD COLUMN confident INTEGER;', 'PRAGMA user_version = 2;'],
      'v3（理由）': [
        _v1,
        'ALTER TABLE attempts ADD COLUMN confident INTEGER;',
        'ALTER TABLE attempts ADD COLUMN reason TEXT;',
        'PRAGMA user_version = 3;',
      ],
    };

    for (final e in stages.entries) {
      test(e.key, () async {
        final db = sqlite3.openInMemory();
        for (final sql in e.value) {
          db.execute(sql);
        }
        db.execute("INSERT INTO attempts (question_id, unit_id, correct, chosen_id, answered_at, elapsed_ms, mode) "
            "VALUES ('old1', 'u1', 0, 'b', '2026-09-01T03:00:00.000Z', 1500, 'mock')");
        db.execute("INSERT INTO attempts (question_id, unit_id, correct, answered_at) VALUES ('old2', 'u1', 1, '2026-09-02T03:00:00.000Z')");

        final store = SqliteAttemptStore(db);
        final r = await store.query();
        expect(r.map((a) => a.questionId), ['old1', 'old2']);
        expect(r[0].correct, isFalse);
        expect(r[0].chosenId, 'b');
        expect(r[0].elapsedMs, 1500);
        expect(r[0].mode, 'mock');
        expect(r[0].answeredAt.isAtSameMomentAs(t), isTrue);
        expect(r[1].mode, 'practice', reason: '既定値');
        expect([r[0].confident, r[0].reason, r[0].hintsUsed], [null, null, 0], reason: '足された列の既定値');
        expect(db.select('PRAGMA user_version').first.values.first, SqliteAttemptStore.schemaVersion);

        // 新しい項目つきの回答も足せて、開き直しても同じ
        await store.add(Attempt(
            questionId: 'new', unitId: 'u1', correct: false, answeredAt: t.add(const Duration(days: 3)), confident: true, reason: LossReason.forgot, hintsUsed: 1));
        final again = await SqliteAttemptStore(db).query();
        expect(again.length, 3);
        expect([again.last.confident, again.last.reason, again.last.hintsUsed], [true, LossReason.forgot, 1]);
      });
    }

    test('実ファイルでも同じ（閉じて開き直す）', () async {
      final dir = Directory.systemTemp.createTempSync('chukore_compat_');
      try {
        final path = '${dir.path}/old.db';
        final old = sqlite3.open(path);
        old.execute(_v1);
        old.execute("INSERT INTO attempts (question_id, unit_id, correct, answered_at) VALUES ('old', 'u1', 1, '2026-09-01T03:00:00.000Z')");
        old.dispose();

        final db1 = sqlite3.open(path);
        final s1 = SqliteAttemptStore(db1);
        await s1.add(Attempt(questionId: 'new', unitId: 'u1', correct: true, answeredAt: t, hintsUsed: 2));
        db1.dispose();

        final db2 = sqlite3.open(path);
        final r = await SqliteAttemptStore(db2).query();
        expect(r.map((a) => (a.questionId, a.hintsUsed)), [('old', 0), ('new', 2)]);
        db2.dispose();
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('最新の版より新しい DB は拒否し、中身に触れない', () async {
      final db = sqlite3.openInMemory();
      SqliteAttemptStore(db);
      db.execute("INSERT INTO attempts (question_id, unit_id, correct, answered_at) VALUES ('keep', 'u1', 1, '2026-09-01T03:00:00.000Z')");
      db.execute('PRAGMA user_version = ${SqliteAttemptStore.schemaVersion + 1}');
      expect(() => SqliteAttemptStore(db), throwsStateError);
      expect(db.select('SELECT count(*) AS n FROM attempts').first['n'], 1);
      expect(db.select('PRAGMA user_version').first.values.first, SqliteAttemptStore.schemaVersion + 1, reason: '版を巻き戻さない');
    });
  });

  group('バックアップ: v0.2.0 の形式のファイルを、今後も読める（固定したファイル）', () {
    String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

    test('最小の形（任意の項目なし）', () {
      final a = AttemptBackup.parse(fixture('backup_v1_minimal.json'));
      expect(a.length, 2);
      expect([a[0].questionId, a[0].correct, a[0].elapsedMs, a[0].mode, a[0].chosenId], ['q1', true, 1500, 'practice', null]);
      expect([a[1].questionId, a[1].correct, a[1].chosenId, a[1].mode], ['q2', false, 'b', 'mock']);
      expect([a[0].confident, a[0].reason, a[0].hintsUsed], [null, null, 0]);
      expect(a[0].answeredAt.isAtSameMomentAs(t), isTrue);
    });

    test('全項目（自信度・理由・ヒント）', () {
      final a = AttemptBackup.parse(fixture('backup_v1_full.json'));
      expect(a.length, 4);
      expect([a[2].confident, a[2].reason, a[2].hintsUsed, a[2].chosenId], [true, LossReason.careless, 2, 'c']);
      expect(a[3].confident, isFalse);
      expect(a[3].correct, isTrue);
    });

    test('今の書き出しは、固定したファイルと同じ内容（形式が変わったら気づく）', () {
      for (final name in ['backup_v1_minimal.json', 'backup_v1_full.json']) {
        final parsed = AttemptBackup.parse(fixture(name));
        final raw = fixture(name);
        final exportedAt = RegExp(r'"exportedAt":"([^"]+)"').firstMatch(raw)!.group(1)!;
        expect(AttemptBackup.export(parsed, now: DateTime.parse(exportedAt)), raw, reason: name);
      }
    });

    test('固定したファイルを SQLite の端末に取り込める。もう一度入れても二重にならない', () async {
      final store = SqliteAttemptStore(sqlite3.openInMemory());
      final first = await AttemptBackup.importInto(store, fixture('backup_v1_full.json'));
      expect([first.added, first.duplicates], [4, 0]);
      final second = await AttemptBackup.importInto(store, fixture('backup_v1_full.json'));
      expect([second.added, second.duplicates], [0, 4]);
      expect((await store.query()).length, 4);
    });

    test('版の数字は 1 のまま（上げたら、古い読み取りを残すこと）', () {
      expect(AttemptBackup.version, 1);
      expect(SqliteAttemptStore.schemaVersion, 4);
    });
  });
}
