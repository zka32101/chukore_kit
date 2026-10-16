import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Attempt _a(String q, int day, bool ok, {bool? confident, String unit = 'u1', String? chosen}) => Attempt(
      questionId: q,
      unitId: unit,
      correct: ok,
      chosenId: chosen,
      answeredAt: DateTime(2026, 10, day, 9),
      confident: confident,
    );

void main() {
  test('正誤と自信の4分類。聞いていなければ null', () {
    expect(confidenceKindOf(_a('q', 1, true, confident: true)), ConfidenceKind.solid);
    expect(confidenceKindOf(_a('q', 1, true, confident: false)), ConfidenceKind.lucky);
    expect(confidenceKindOf(_a('q', 1, false, confident: true)), ConfidenceKind.misconception);
    expect(confidenceKindOf(_a('q', 1, false, confident: false)), ConfidenceKind.gap);
    expect(confidenceKindOf(_a('q', 1, true)), isNull);
  });

  test('単元別の集計: 聞いていない回答は数えず、割合を出す', () {
    final s = summarizeConfidence([
      _a('a', 1, false, confident: true, unit: 'u2'),
      _a('b', 1, false, confident: true, unit: 'u2'),
      _a('c', 1, false, confident: false, unit: 'u2'),
      _a('d', 1, true, confident: false, unit: 'u1'),
      _a('e', 1, true, confident: true, unit: 'u1'),
      _a('f', 1, true, unit: 'u1'), // 聞いていない
    ]);
    expect(s.map((x) => x.unitId), ['u1', 'u2']);
    expect(s[0].answered, 2);
    expect(s[0].luckyShare, 0.5);
    expect(s[0].misconceptionShare, isNull); // 誤答なし
    expect(s[1].misconceptionShare, closeTo(2 / 3, 1e-9));
    expect(s[1].luckyShare, isNull); // 正解なし
  });

  group('間隔反復との連携', () {
    test('自信なしの正解は箱を上げない（初回は 0 のまま）', () {
      var s = buildReviewStates([_a('q', 1, true, confident: false)])['q']!;
      expect(s.box, 0);
      s = buildReviewStates([_a('q', 1, true, confident: true), _a('q', 2, true, confident: true), _a('q', 5, true, confident: false)])['q']!;
      expect(s.box, 1); // 自信ありの 2 回目で 1。自信なしの 3 回目は上げない
      // 自信を聞いていなければ従来どおり上がる
      s = buildReviewStates([_a('q', 1, true), _a('q', 2, true), _a('q', 5, true)])['q']!;
      expect(s.box, 2);
    });

    test('自信ありで誤答した問題は、同じ遅れなら先に出る', () {
      final states = buildReviewStates([
        _a('a_plain', 1, false, confident: false),
        _a('b_sure', 1, false, confident: true),
      ]);
      expect(states['b_sure']!.lastConfidentWrong, isTrue);
      expect(dueForReview(states, DateTime(2026, 10, 5)).map((s) => s.questionId), ['b_sure', 'a_plain']);
      // 遅れの大きさが優先
      final late = buildReviewStates([_a('z_late', 1, false, confident: false), _a('b_sure', 3, false, confident: true)]);
      expect(dueForReview(late, DateTime(2026, 10, 10)).map((s) => s.questionId), ['z_late', 'b_sure']);
    });
  });

  test('弱点ノート: 自信ありで誤答した回数', () {
    final q = Question(
      id: 'x', unitId: 'u1', type: 'choice', difficulty: .5,
      choices: const ['a', 'b'], answer: 'a', explanationId: 'e',
    );
    final notes = buildWeakNotes([
      _a('x', 1, false, confident: true),
      _a('x', 2, false, confident: false),
      _a('x', 3, false),
    ], {'x': q});
    expect(notes.single.wrongCount, 3);
    expect(notes.single.confidentWrongCount, 1);
  });

  test('模試: 自信を履歴に残す', () {
    final q = Question(
      id: 'q1', unitId: 'u1', type: 'choice', difficulty: .5,
      choices: const ['a', 'b'], answer: 'a', explanationId: 'e',
    );
    final e = MockExam(questions: [q], requestedCount: 1);
    final r = scoreMockExam(e, {'q1': 'b'}, answeredAt: DateTime(2026, 10, 10), confident: {'q1': true});
    expect(r.attempts.single.confident, isTrue);
    expect(confidenceKindOf(r.attempts.single), ConfidenceKind.misconception);
  });

  group('SQLite', () {
    test('自信の保存と復元（あり・なし・未回答）', () async {
      final store = SqliteAttemptStore(sqlite3.openInMemory());
      await store.add(_a('a', 1, true, confident: true));
      await store.add(_a('b', 2, false, confident: false));
      await store.add(_a('c', 3, true));
      final r = await store.query();
      expect(r.map((x) => x.confident), [true, false, null]);
    });

    test('旧版の DB（自信の列なし）を開くと、列が足され、既存の回答は残る', () async {
      for (final version in [0, 1]) {
        final db = sqlite3.openInMemory();
        db.execute('''
          CREATE TABLE attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT, question_id TEXT NOT NULL, unit_id TEXT NOT NULL,
            correct INTEGER NOT NULL, chosen_id TEXT, answered_at TEXT NOT NULL,
            elapsed_ms INTEGER NOT NULL DEFAULT 0, mode TEXT NOT NULL DEFAULT 'practice');
          INSERT INTO attempts (question_id, unit_id, correct, answered_at)
            VALUES ('old', 'u1', 1, '2026-10-01T00:00:00.000Z');
          PRAGMA user_version = $version;
        ''');
        final store = SqliteAttemptStore(db);
        await store.add(_a('new', 5, false, confident: true));
        final r = await store.query();
        expect(r.map((x) => (x.questionId, x.confident)), [('old', null), ('new', true)], reason: 'v$version');
        expect(db.select('PRAGMA user_version').first.values.first, SqliteAttemptStore.schemaVersion);
        // 開き直しても壊れない
        SqliteAttemptStore(db);
      }
    });
  });
}
