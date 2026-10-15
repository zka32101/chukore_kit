import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree _tree() => UnitTree(1, [
      Unit(id: 'g', subject: 'math', grade: 1, title: 'G'),
      Unit(id: 'a', subject: 'math', grade: 1, title: 'A', parentId: 'g', estimatedQuestions: 30),
      Unit(id: 'b', subject: 'math', grade: 1, title: 'B', parentId: 'g', estimatedQuestions: 10),
      Unit(id: 'c', subject: 'math', grade: 1, title: 'C', estimatedQuestions: 10),
    ]);

Question _q(String id, String unit, {double p = .5, String answer = 'x'}) => Question(
      id: id, unitId: unit, type: 'choice', difficulty: p,
      choices: const ['x', 'y'], answer: answer, explanationId: 'e',
    );

List<Question> _bank() => [
      for (var i = 0; i < 20; i++) _q('a$i', 'a'),
      for (var i = 0; i < 20; i++) _q('b$i', 'b'),
      for (var i = 0; i < 20; i++) _q('c$i', 'c'),
    ];

Map<String, int> _perUnit(MockExam e) {
  final m = <String, int>{};
  for (final q in e.questions) {
    m[q.unitId] = (m[q.unitId] ?? 0) + 1;
  }
  return m;
}

void main() {
  test('範囲の単元から、estimatedQuestions に比例して選ぶ（合計は希望の数）', () {
    final e = buildMockExam(questions: _bank(), tree: _tree(), unitIds: ['g', 'c'], count: 10);
    expect(e.questions.length, 10);
    expect(e.shortfall, isFalse);
    // 重み 30:10:10 → 6:2:2
    expect(_perUnit(e), {'a': 6, 'b': 2, 'c': 2});
  });

  test('範囲外の単元は出ない。親を選べば配下の葉すべて', () {
    final e = buildMockExam(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 10);
    expect(e.questions.every((q) => q.unitId == 'a' || q.unitId == 'b'), isTrue);
  });

  test('同じ入力・seed なら同じ出題と順序。seed が違えば変わる', () {
    List<String> ids(int seed) =>
        buildMockExam(questions: _bank(), tree: _tree(), unitIds: ['g', 'c'], count: 10, seed: seed)
            .questions.map((q) => q.id).toList();
    expect(ids(1), ids(1));
    expect(ids(1), isNot(ids(2)));
    // 問題集の並びに依らない
    final shuffled = _bank().reversed.toList();
    expect(
      buildMockExam(questions: shuffled, tree: _tree(), unitIds: ['g', 'c'], count: 10, seed: 1)
          .questions.map((q) => q.id).toList(),
      ids(1),
    );
  });

  test('問題が足りない単元は他の単元に回す。全体で足りなければ shortfall', () {
    final bank = [for (var i = 0; i < 2; i++) _q('b$i', 'b'), for (var i = 0; i < 20; i++) _q('a$i', 'a')];
    final e = buildMockExam(questions: bank, tree: _tree(), unitIds: ['g'], count: 10);
    expect(e.questions.length, 10);
    expect(_perUnit(e)['b'], lessThanOrEqualTo(2));

    final few = buildMockExam(questions: bank.take(3).toList(), tree: _tree(), unitIds: ['g'], count: 10);
    expect(few.questions.length, 3);
    expect(few.shortfall, isTrue);
  });

  test('除外した問題は出ない。重複もしない', () {
    final e = buildMockExam(
      questions: _bank(), tree: _tree(), unitIds: ['g', 'c'], count: 30,
      excludeQuestionIds: {'a0', 'a1', 'a2'},
    );
    final ids = e.questions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.contains('a0'), isFalse);
  });

  test('採点: 単元別・未回答は不正解・履歴は mode=mock で未回答を含まない', () {
    final e = MockExam(questions: [_q('a1', 'a'), _q('a2', 'a'), _q('b1', 'b'), _q('b2', 'b')], requestedCount: 4);
    final r = scoreMockExam(
      e,
      {'a1': 'x', 'a2': 'y', 'b1': 'x'}, // a2 は誤答、b2 は未回答
      answeredAt: DateTime(2026, 10, 10, 9),
      elapsed: const Duration(minutes: 10),
      perQuestionMs: {'a1': 1500},
    );
    expect((r.total, r.correct, r.unanswered), (4, 2, 1));
    expect(r.score100, 50);
    expect(r.byUnit.map((u) => (u.unitId, u.correct, u.total)), [('a', 1, 2), ('b', 1, 2)]);
    expect(r.attempts.length, 3);
    expect(r.attempts.every((a) => a.mode == 'mock'), isTrue);
    expect(r.attempts.first.elapsedMs, 1500);
    expect(r.timedOut, isFalse);
  });

  test('弱い単元は正答率の低い順', () {
    final e = MockExam(questions: [
      _q('a1', 'a'), _q('a2', 'a'), _q('b1', 'b'), _q('b2', 'b'), _q('c1', 'c'), _q('c2', 'c'),
    ], requestedCount: 6);
    final r = scoreMockExam(e, {'a1': 'x', 'a2': 'x', 'b1': 'x', 'b2': 'y', 'c1': 'y', 'c2': 'y'},
        answeredAt: DateTime(2026, 10, 10));
    expect(r.weakUnits().map((u) => u.unitId), ['c', 'b']);
    expect(r.weakUnits(below: 0.3).map((u) => u.unitId), ['c']);
  });

  test('制限時間を超えると timedOut。制限なしなら超えない', () {
    final e = MockExam(questions: [_q('a1', 'a')], requestedCount: 1, timeLimit: const Duration(minutes: 5));
    expect(scoreMockExam(e, {}, answeredAt: DateTime(2026, 10, 10), elapsed: const Duration(minutes: 6)).timedOut, isTrue);
    expect(scoreMockExam(e, {}, answeredAt: DateTime(2026, 10, 10), elapsed: const Duration(minutes: 5)).timedOut, isFalse);
    final free = MockExam(questions: [_q('a1', 'a')], requestedCount: 1);
    expect(scoreMockExam(free, {}, answeredAt: DateTime(2026, 10, 10), elapsed: const Duration(hours: 9)).timedOut, isFalse);
  });

  test('アプリ内偏差値: 平均点なら 50、満点なら上がる', () {
    final qs = [for (var i = 0; i < 10; i++) _q('q$i', 'a', p: .5)];
    final e = MockExam(questions: qs, requestedCount: 10);
    final avg = scoreMockExam(e, {for (var i = 0; i < 5; i++) 'q$i': 'x', for (var i = 5; i < 10; i++) 'q$i': 'y'},
        answeredAt: DateTime(2026, 10, 10));
    expect(avg.deviation.value, closeTo(50, 1e-9));
    final full = scoreMockExam(e, {for (var i = 0; i < 10; i++) 'q$i': 'x'}, answeredAt: DateTime(2026, 10, 10));
    expect(full.deviation.value, greaterThan(60));
  });

  test('模試の履歴は習熟度・間隔反復にそのまま使える', () {
    final e = MockExam(questions: [_q('a1', 'a')], requestedCount: 1);
    final r = scoreMockExam(e, {'a1': 'y'}, answeredAt: DateTime(2026, 10, 10, 9));
    expect(computeMastery(r.attempts, DateTime(2026, 10, 10))['a']!.score, 0);
    expect(buildReviewStates(r.attempts)['a1']!.dueOn, DateTime.utc(2026, 10, 11));
  });

  test('count が 0 以下は不正', () {
    expect(() => buildMockExam(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 0), throwsArgumentError);
  });
}
