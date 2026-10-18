import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 1, 10);

MockExamResult exam(Map<String, List<int>> units) => MockExamResult(
      total: 10,
      correct: 5,
      unanswered: 0,
      timedOut: false,
      elapsed: Duration.zero,
      byUnit: [for (final e in units.entries) UnitScore(e.key, e.value[0], e.value[1])],
      deviation: const DeviationEstimate(50),
      attempts: const [],
    );

Question q(String id, String unit, {Map<String, String> tags = const {}}) => Question(
      id: id,
      unitId: unit,
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: tags,
    );

Mastery m(String u, double s) => Mastery(unitId: u, score: s);

void main() {
  final graph = PrerequisiteGraph([
    const PrereqNode('c', requires: ['b']),
    const PrereqNode('b', requires: ['a']),
    const PrereqNode('a'),
    const PrereqNode('z'),
  ]);

  test('落とした単元ごとに、前提の出発点 → その単元の順を示す。低い順・maxUnits まで', () {
    // 正答率: z=0.5, c=0.2, b=0.4。ID順（b,c,z）でも履歴順でもなく正答率の低い順（c,b,z）
    final r = exam({'z': [10, 5], 'c': [10, 2], 'b': [10, 4]});
    final mastery = {'a': m('a', 0.3), 'b': m('b', 0.9)};
    final s = planNextSteps(result: r, graph: graph, mastery: mastery);
    expect(s.map((e) => e.unitId), ['c', 'b', 'z']);
    expect(s[0].studyOrder, ['a', 'c'], reason: 'b は固まっているので出発点は a');
    expect(s[0].rootCauseUnitIds, ['a']);
    expect(s[0].prerequisitesSolid, isFalse);
    expect(s[2].studyOrder, ['z']);
    expect(s[2].prerequisitesSolid, isTrue);
    expect(planNextSteps(result: r, graph: graph, mastery: mastery, maxUnits: 2).map((e) => e.unitId), ['c', 'b']);
  });

  test('below 以上の単元は取り上げない。落とした単元が無ければ空', () {
    final r = exam({'a': [10, 6], 'b': [10, 9]});
    expect(planNextSteps(result: r, graph: graph, mastery: const {}), isEmpty);
    expect(planNextSteps(result: r, graph: graph, mastery: const {}, below: 0.61).map((e) => e.unitId), ['a']);
  });

  test('解き直しセットは、取り組む単元（出発点を含む）の問題だけで作る', () {
    final qs = [
      q('qa', 'a', tags: {'b': 'ta'}),
      q('qc', 'c', tags: {'b': 'tc'}),
      q('qz', 'z', tags: {'b': 'tz'}),
    ];
    final att = [
      for (final id in ['qa', 'qc', 'qz'])
        Attempt(questionId: id, unitId: id.substring(1), correct: false, answeredAt: t0, chosenId: 'b'),
    ];
    final s = planNextSteps(
      result: exam({'c': [10, 2]}),
      graph: graph,
      mastery: {'a': m('a', 0.3), 'b': m('b', 0.9)},
      attempts: att,
      questions: qs,
    );
    expect(s.single.retrySets.map((r) => r.key).toSet(), {'tag:ta', 'tag:tc'});
  });

  test('他アプリへの誘導先を引き継ぐ', () {
    final g = PrerequisiteGraph([
      const PrereqNode('x', requires: ['y']),
      const PrereqNode('y', external: [ExternalRef(id: 'ext1', title: '算数の復習')]),
    ]);
    final s = planNextSteps(result: exam({'x': [10, 1]}), graph: g, mastery: {'y': m('y', 0.2)});
    expect(s.single.externalReferrals.map((e) => e.id), ['ext1']);
  });

  test('maxUnits が 1 未満ならエラー', () {
    expect(() => planNextSteps(result: exam({}), graph: graph, mastery: const {}, maxUnits: 0), throwsArgumentError);
  });
}
