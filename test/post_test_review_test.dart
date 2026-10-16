import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree _tree() => UnitTree(1, [
      Unit(id: 'g', subject: 'math', grade: 1, title: 'G'),
      Unit(id: 'a', subject: 'math', grade: 1, title: 'A', parentId: 'g', estimatedQuestions: 10),
      Unit(id: 'b', subject: 'math', grade: 1, title: 'B', parentId: 'g', estimatedQuestions: 10),
      Unit(id: 'c', subject: 'math', grade: 1, title: 'C', estimatedQuestions: 10),
    ]);

final _day = DateTime(2026, 10, 10);

PostTestReview _r(List<TestLoss> losses, {double score = 70}) =>
    PostTestReview(testDate: _day, score: score, losses: losses);

void main() {
  test('失点を単元別・理由別にまとめる（失点の多い順、同点はID順）', () {
    final rep = buildPostTestReview(_r([
      const TestLoss('b', 8, LossReason.dontKnow),
      const TestLoss('a', 8, LossReason.careless),
      const TestLoss('a', 6, LossReason.forgot),
      const TestLoss('c', 8, LossReason.timeShort),
    ], score: 70));
    expect(rep.byUnit.map((u) => (u.unitId, u.lostPoints)), [('a', 14.0), ('b', 8.0), ('c', 8.0)]);
    expect(rep.lostTotal, 30);
    expect(rep.byReason[LossReason.careless], 8);
    expect(rep.recoverablePoints, 16); // ケアレス 8 + 時間切れ 8
    expect(rep.relearnPoints, 14); // 理解不足 8 + 忘れ 6
    expect(rep.byUnit.first.needsRelearning, 6);
    expect(rep.consistent, isTrue);
  });

  test('失点の合計が満点との差と大きくずれたら consistent=false（5% までは許す）', () {
    expect(buildPostTestReview(_r([const TestLoss('a', 20, LossReason.dontKnow)], score: 70)).consistent, isFalse);
    expect(buildPostTestReview(_r([const TestLoss('a', 33, LossReason.dontKnow)], score: 70)).consistent, isTrue);
    expect(buildPostTestReview(_r([const TestLoss('a', 35, LossReason.dontKnow)], score: 70)).consistent, isTrue);
    expect(buildPostTestReview(_r([const TestLoss('a', 36, LossReason.dontKnow)], score: 70)).consistent, isFalse);
  });

  test('入力の問題: 失点が 0 以下・ツリーに無い単元・葉でない単元は報告して外す', () {
    final rep = buildPostTestReview(
      _r([
        const TestLoss('a', 0, LossReason.dontKnow),
        const TestLoss('zzz', 5, LossReason.dontKnow),
        const TestLoss('g', 5, LossReason.dontKnow),
        const TestLoss('b', 5, LossReason.dontKnow),
      ]),
      tree: _tree(),
    );
    expect(rep.issues.map((i) => i.code), ['loss_not_positive', 'unit_missing', 'unit_not_leaf']);
    expect(rep.hasErrors, isTrue);
    expect(rep.byUnit.map((u) => u.unitId), ['b']);
  });

  test('習熟度: 理解不足・忘れの分だけ下げる。ケアレス・時間切れは下げない。下限は 0', () {
    final base = {
      'a': Mastery(unitId: 'a', score: 0.8, lastPracticedAt: _day),
      'b': const Mastery(unitId: 'b', score: 0.8),
      'c': const Mastery(unitId: 'c', score: 0.8),
    };
    final rep = buildPostTestReview(
      _r([
        const TestLoss('a', 5, LossReason.dontKnow), // -0.20
        const TestLoss('b', 9, LossReason.careless), // 下げない
        const TestLoss('c', 30, LossReason.forgot), // 上限 0.5
      ]),
      mastery: base,
    );
    expect(rep.adjustedMastery['a']!.score, closeTo(0.6, 1e-9));
    expect(rep.adjustedMastery['a']!.lastPracticedAt, _day);
    expect(rep.adjustedMastery['b']!.score, 0.8);
    expect(rep.adjustedMastery['c']!.score, closeTo(0.3, 1e-9));
    expect(base['a']!.score, 0.8); // 元は変えない
  });

  test('習熟度の記録がない単元は 0.5 から下げる', () {
    final rep = buildPostTestReview(_r([const TestLoss('a', 5, LossReason.dontKnow)]));
    expect(rep.adjustedMastery['a']!.score, closeTo(0.3, 1e-9));
  });

  test('履歴: 理解不足・忘れの単元だけ、real_test の不正解として残る', () {
    final rep = buildPostTestReview(_r([
      const TestLoss('a', 5, LossReason.dontKnow),
      const TestLoss('a', 3, LossReason.forgot),
      const TestLoss('b', 5, LossReason.careless),
    ]));
    expect(rep.attempts.length, 1);
    final a = rep.attempts.single;
    expect((a.unitId, a.correct, a.mode, a.questionId), ('a', false, 'real_test', 'real:2026-10-10:a'));
    expect(computeMastery(rep.attempts, _day)['a']!.score, 0);
  });

  test('次の計画に効く: 失点の単元が、重点枠で多く配分される', () {
    final tree = _tree();
    final plan = TestPlan(id: 'p', subject: 'math', testDate: DateTime(2026, 10, 24), unitIds: const ['a', 'b', 'c']);
    final even = {for (final id in ['a', 'b', 'c']) id: Mastery(unitId: id, score: 0.7, lastPracticedAt: _day)};
    int focusOf(Map<String, Mastery> m, String id) => buildPlan(
          today: DateTime(2026, 10, 12), plan: plan, tree: tree, mastery: m,
        ).days.fold(0, (s, d) => s + (d.focusByUnit[id] ?? 0));
    final rep = buildPostTestReview(_r([const TestLoss('a', 10, LossReason.dontKnow)]), mastery: even);
    expect(focusOf(rep.adjustedMastery, 'a'), greaterThan(focusOf(even, 'a')));
    // 重点枠の総量は同じなので、a が増えた分、他の単元の合計は減る
    int others(Map<String, Mastery> m) => focusOf(m, 'b') + focusOf(m, 'c');
    expect(others(rep.adjustedMastery), lessThan(others(even)));
  });

  test('失点が無ければ空の結果', () {
    final rep = buildPostTestReview(_r(const [], score: 100));
    expect(rep.lostTotal, 0);
    expect(rep.byUnit, isEmpty);
    expect(rep.attempts, isEmpty);
    expect(rep.consistent, isTrue);
  });
}
