import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteAttemptStore store;

  setUp(() => store = SqliteAttemptStore(sqlite3.openInMemory()));

  Attempt at(String u, int d, {bool ok = true, String? chosen}) => Attempt(
        questionId: 'q$d',
        unitId: u,
        correct: ok,
        chosenId: chosen,
        answeredAt: DateTime.utc(2026, 10, d, 9),
        elapsedMs: 1200,
      );

  test('保存した回答を復元できる', () async {
    await store.add(at('u1', 5, ok: false, chosen: 'b'));
    final r = (await store.query()).single;
    expect(r.correct, isFalse);
    expect(r.chosenId, 'b');
    expect(r.elapsedMs, 1200);
    expect(r.answeredAt.isAtSameMomentAs(DateTime.utc(2026, 10, 5, 9)), isTrue);
  });

  test('期間と単元で絞れて、日付順に並ぶ', () async {
    await store.add(at('u1', 7));
    await store.add(at('u2', 6));
    await store.add(at('u1', 5));
    expect((await store.query(unitId: 'u1')).map((a) => a.questionId), ['q5', 'q7']);
    expect(
      (await store.query(from: DateTime.utc(2026, 10, 6), to: DateTime.utc(2026, 10, 7)))
          .map((a) => a.questionId),
      ['q6'],
    );
  });

  test('読み出しはローカル時刻で、範囲の境界はローカル暦日（時差のある国でも日付がずれない）', () async {
    // ローカルの 0:30 と 23:30 に回答 → どちらも「その日」に入る
    final early = DateTime(2026, 10, 6, 0, 30);
    final late = DateTime(2026, 10, 6, 23, 30);
    final nextDay = DateTime(2026, 10, 7, 0, 10);
    for (final t in [early, late, nextDay]) {
      await store.add(Attempt(questionId: '${t.hour}-${t.day}', unitId: 'u', correct: true, answeredAt: t));
    }
    final day = await store.query(from: DateTime(2026, 10, 6), to: DateTime(2026, 10, 7));
    expect(day.length, 2);
    expect(day.every((a) => !a.answeredAt.isUtc), isTrue);
    expect(day.map((a) => a.answeredAt.day).toSet(), {6});
  });

  test('メモリ実装と同じ結果になる', () async {
    final mem = InMemoryAttemptStore();
    for (final a in [at('u1', 7), at('u2', 6), at('u1', 5)]) {
      await store.add(a);
      await mem.add(a);
    }
    final from = DateTime.utc(2026, 10, 6);
    expect((await store.query(from: from)).map((a) => a.questionId),
        (await mem.query(from: from)).map((a) => a.questionId));
  });

  test('スキーマ版を記録し、新しい版の DB は拒否する', () {
    final db = sqlite3.openInMemory();
    SqliteAttemptStore(db);
    expect(db.select('PRAGMA user_version').first.values.first, SqliteAttemptStore.schemaVersion);
    db.execute('PRAGMA user_version = ${SqliteAttemptStore.schemaVersion + 1}');
    expect(() => SqliteAttemptStore(db), throwsStateError);
  });
}
