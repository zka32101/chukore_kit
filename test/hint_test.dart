import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final today = DateTime(2026, 10, 20);

Attempt att(
  String q,
  bool ok,
  int daysAgo, {
  int hints = 0,
  String unit = 'u1',
  String mode = 'practice',
  String? chosen,
}) =>
    Attempt(
      questionId: q,
      unitId: unit,
      correct: ok,
      chosenId: chosen,
      answeredAt: today.subtract(Duration(days: daysAgo)).add(const Duration(hours: 10)),
      hintsUsed: hints,
      mode: mode,
    );

Question question({List<String> hintIds = const [], String explanationId = 'e1', String id = 'q1'}) => Question(
      id: id,
      unitId: 'u1',
      type: 'choice',
      difficulty: 0.6,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: explanationId,
      hintIds: hintIds,
    );

String fnv(String s) {
  var h = 0x811c9dc5;
  for (final u in utf8.encode(s)) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

void main() {
  group('習熟度: ヒントを使った正解は加点を小さく', () {
    double score(List<Attempt> a) => computeMastery(a, today)['u1']!.score;

    test('ヒントの数に応じた加点（0 個 1.0・1 個 0.7・2 個 0.45・3 個以上 0.25）。誤答は 0', () {
      expect(score([att('a', true, 0)]), 1.0);
      expect(score([att('a', true, 0, hints: 1)]), closeTo(0.7, 1e-9));
      expect(score([att('a', true, 0, hints: 2)]), closeTo(0.45, 1e-9));
      expect(score([att('a', true, 0, hints: 3)]), closeTo(0.25, 1e-9));
      expect(score([att('a', true, 0, hints: 9)]), closeTo(0.25, 1e-9));
      expect(score([att('a', false, 0, hints: 2)]), 0.0, reason: '誤答はヒントの有無で変わらない');
    });

    test('自力の正解とヒントありの正解が混ざれば、その平均', () {
      expect(score([att('a', true, 0), att('b', true, 0, hints: 1)]), closeTo((1.0 + 0.7) / 2, 1e-9));
      expect(score([att('a', true, 0, hints: 1), att('b', false, 0)]), closeTo(0.35, 1e-9));
    });

    test('加点は引数で変えられる。hintsUsed が 0 の履歴はこれまでと同じ', () {
      final m = computeMastery([att('a', true, 0, hints: 1)], today, hintCredits: const [1.0, 0.5])['u1']!;
      expect(m.score, 0.5);
      expect(score([att('a', true, 0), att('b', false, 0)]), 0.5);
    });

    test('hintCredit: 範囲外・空の加点表でも落ちない', () {
      expect(hintCredit(-3), 1.0);
      expect(hintCredit(1, credits: const []), 1.0);
      expect(hintCredit(2, credits: const [1.0]), 1.0);
    });
  });

  group('間隔反復: ヒントを使った正解は箱を上げない', () {
    test('自力の正解は箱が上がるが、ヒントありの正解は上がらない', () {
      final self = buildReviewStates([att('q', true, 9), att('q', true, 5)])['q']!;
      expect(self.box, 1);
      final hinted = buildReviewStates([att('q', true, 9), att('q', true, 5, hints: 1)])['q']!;
      expect(hinted.box, 0);
      // 初回がヒントありの正解でも箱 0 から始まる（誤答のように 0 に戻るわけではない）
      expect(buildReviewStates([att('q', true, 5, hints: 2)])['q']!.box, 0);
    });
  });

  group('弱点ノート: ヒントを使った正解は克服に数えない', () {
    final q = Question(
      id: 'x',
      unitId: 'u1',
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: const {'b': 'sign_error'},
    );
    bool overcome(List<Attempt> a) => buildWeakNotes(a, {'x': q}).single.overcome;

    test('自力で 3 回連続正解（2 日以上）で克服。1 回でもヒントを使っていたら未克服', () {
      final wrong = att('x', false, 12, chosen: 'b');
      expect(overcome([wrong, att('x', true, 6), att('x', true, 5), att('x', true, 4)]), isTrue);
      expect(overcome([wrong, att('x', true, 6), att('x', true, 5, hints: 1), att('x', true, 4)]), isFalse);
      expect(overcome([wrong, att('x', true, 6), att('x', true, 5), att('x', true, 4, hints: 1)]), isFalse);
    });
    test('isOvercome も同じ', () {
      expect(isOvercome([att('x', true, 3), att('x', true, 2), att('x', true, 1, hints: 2)]), isFalse);
      expect(isOvercome([att('x', true, 3), att('x', true, 2), att('x', true, 1)]), isTrue);
    });
  });

  group('問題集: hintIds', () {
    List<String> codes(Question x) {
      final unit = [const Unit(id: 'u1', subject: 's', grade: 1, title: 'u')];
      return [for (final i in validateQuestionBank(questions: [x], tree: UnitTree(1, unit), mistakeLines: const []) ) i.code];
    }

    test('JSON に書いて読み戻せる。無ければ空で、書き出しにも出さない', () {
      final q1 = Question.fromJson({...question(hintIds: ['h1', 'h2']).toJson()});
      expect(q1.hintIds, ['h1', 'h2']);
      expect(question().toJson().containsKey('hintIds'), isFalse);
      expect(Question.fromJson(question().toJson()).hintIds, isEmpty);
    });
    test('正しいヒントは問題なし', () => expect(codes(question(hintIds: ['h1', 'h2', 'h3'])), isEmpty));
    test('空の ID・重複はエラー。解説と同じ ID・5 段以上は警告', () {
      expect(codes(question(hintIds: ['h1', ' '])), contains('hint_id_empty'));
      expect(codes(question(hintIds: ['h1', 'h1'])), contains('hint_duplicate'));
      expect(codes(question(hintIds: ['e1'])), contains('hint_is_explanation'));
      expect(codes(question(hintIds: ['h1', 'h2', 'h3', 'h4', 'h5'])), contains('hints_too_many'));
    });
    test('ヒントを足しただけでも、問題の内容が変わった扱い（差分更新で version を上げる）', () {
      final diff = BankDiff.between([question()], [question(hintIds: ['h1'])]);
      expect(diff.check([question()]).map((i) => i.code), ['changed_without_version_bump']);
    });
  });

  group('保存', () {
    test('SQLite: ヒントの数を保存して読み戻せる。版 3 の DB は開くと列が足され、古い行は 0', () async {
      final db = sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT, question_id TEXT NOT NULL, unit_id TEXT NOT NULL,
          correct INTEGER NOT NULL, chosen_id TEXT, answered_at TEXT NOT NULL,
          elapsed_ms INTEGER NOT NULL DEFAULT 0, mode TEXT NOT NULL DEFAULT 'practice', confident INTEGER, reason TEXT
        );
        INSERT INTO attempts (question_id, unit_id, correct, answered_at) VALUES ('old', 'u1', 1, '2026-10-01T09:00:00.000Z');
        PRAGMA user_version = 3;
      ''');
      final store = SqliteAttemptStore(db);
      await store.add(att('new', true, 0, hints: 2));
      expect((await store.query()).map((a) => (a.questionId, a.hintsUsed)), [('old', 0), ('new', 2)]);
      expect(db.select('PRAGMA user_version').first.values.first, SqliteAttemptStore.schemaVersion);
    });

    test('バックアップ: hu を書き出して読み戻せる。0 のときは項目を付けない。無い古いファイルも読める', () {
      final json = AttemptBackup.export([att('a', true, 1, hints: 3), att('b', true, 2)]);
      final rows = (jsonDecode(json) as Map)['attempts'] as List;
      expect((rows[0] as Map)['hu'], 3);
      expect((rows[1] as Map).containsKey('hu'), isFalse);
      expect(AttemptBackup.parse(json).map((a) => a.hintsUsed), [3, 0]);
    });

    test('バックアップ: 不正なヒントの数のファイルは全体を受け付けない', () {
      for (final bad in [-1, 99, 'x', 1.5]) {
        final rows = [
          {'q': 'q1', 'u': 'u1', 'ok': true, 't': '2026-10-01T09:00:00.000Z', 'ms': 1000, 'm': 'practice', 'hu': bad},
        ];
        final json = jsonEncode({
          'format': AttemptBackup.formatName,
          'version': 1,
          'exportedAt': '2026-10-18T00:00:00.000Z',
          'count': 1,
          'checksum': fnv(jsonEncode(rows)),
          'attempts': rows,
        });
        expect(() => AttemptBackup.parse(json), throwsFormatException, reason: '$bad');
      }
    });
  });

  group('集計', () {
    final attempts = [
      att('a', true, 1),
      att('b', true, 1, hints: 1),
      att('c', true, 1, hints: 2),
      att('d', false, 1, hints: 1),
      att('e', false, 1),
      att('f', true, 20, unit: 'u2'),
      att('g', true, 1, mode: 'mock'),
    ];

    test('自力で解けた正解の割合・ヒントを使った割合・見たヒントの延べ数', () {
      final u = summarizeHintUsage(attempts, unitId: 'u1', mode: 'practice');
      expect((u.correct, u.correctWithHints, u.wrong, u.wrongWithHints, u.hintsShown), (3, 2, 2, 1, 4));
      expect(u.independentRate, closeTo(1 / 3, 1e-9));
      expect(u.hintRate, closeTo(3 / 5, 1e-9));
    });
    test('単元・期間・出題の種類で絞れる。該当が無ければ null', () {
      expect(summarizeHintUsage(attempts, unitId: 'u2').total, 1);
      expect(summarizeHintUsage(attempts, since: today.subtract(const Duration(days: 5))).total, 6);
      expect(summarizeHintUsage(attempts, mode: 'mock').correct, 1);
      final none = summarizeHintUsage(const []);
      expect((none.independentRate, none.hintRate), (null, null));
    });
  });
}
