import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 単元ID → 習熟度（0〜1）から Mastery の Map を作る。
Map<String, Mastery> ms(Map<String, double> scores) =>
    {for (final e in scores.entries) e.key: Mastery(unitId: e.key, score: e.value)};

UnitTree _tree(List<String> ids) =>
    UnitTree(1, [for (final id in ids) Unit(id: id, subject: 'math', grade: 1, title: id, estimatedQuestions: 5)]);

void main() {
  // 一次方程式(eq) ← 文字式(expr) ← 正負の数(neg) ← [小学: 分数の計算]
  final graph = PrerequisiteGraph([
    const PrereqNode('eq', requires: ['expr']),
    const PrereqNode('expr', requires: ['neg']),
    const PrereqNode('neg', external: [ExternalRef(id: 'shogaku_fraction', title: '分数の計算', link: 'https://example.com/shogaku')]),
  ]);

  test('土台に近い順に並び、つまずきの出発点を特定する', () {
    final r = diagnoseBacktrace(graph, 'eq', ms({'expr': 0.4, 'neg': 0.3}));
    expect(r.steps.map((s) => s.unitId), ['neg', 'expr']);
    expect(r.steps.map((s) => s.depth), [2, 1]);
    // expr は前提 neg も弱いので出発点ではない。neg が出発点
    expect(r.rootCauses.map((s) => s.unitId), ['neg']);
    expect(r.prerequisitesSolid, isFalse);
  });

  test('出発点が他アプリの単元につながるとき、誘導先を返す', () {
    final r = diagnoseBacktrace(graph, 'eq', ms({'expr': 0.4, 'neg': 0.3}));
    expect(r.externalReferrals.single.id, 'shogaku_fraction');
    expect(r.externalReferrals.single.link, 'https://example.com/shogaku');
  });

  test('土台が固ければ、出発点はその上の弱い単元', () {
    final r = diagnoseBacktrace(graph, 'eq', ms({'neg': 0.9, 'expr': 0.3}));
    expect(r.rootCauses.map((s) => s.unitId), ['expr']);
    expect(r.externalReferrals, isEmpty); // neg が固いので小学へは誘導しない
  });

  test('前提がすべて基準以上なら、前提は固まっている（その単元そのものを復習）', () {
    final r = diagnoseBacktrace(graph, 'eq', ms({'neg': 0.8, 'expr': 0.7}));
    expect(r.prerequisitesSolid, isTrue);
    expect(r.rootCauses, isEmpty);
    expect(r.steps.every((s) => s.status == StepStatus.ok), isTrue);
  });

  test('学習の記録が無い前提は unknown（弱いとは断定しない）', () {
    final r = diagnoseBacktrace(graph, 'eq', ms({'expr': 0.9}));
    final neg = r.steps.firstWhere((s) => s.unitId == 'neg');
    expect(neg.status, StepStatus.unknown);
    expect(neg.mastery, isNull);
    expect(r.rootCauses.map((s) => s.unitId), ['neg']);
  });

  test('基準値は変えられる（ちょうどの値は ok）', () {
    final strict = diagnoseBacktrace(graph, 'eq', ms({'neg': 0.7, 'expr': 0.7}), threshold: 0.8);
    expect(strict.rootCauses.map((s) => s.unitId), ['neg']);
    final exact = diagnoseBacktrace(graph, 'eq', ms({'neg': 0.6, 'expr': 0.6}));
    expect(exact.prerequisitesSolid, isTrue);
  });

  test('複数の道（ひし形）: 最短の段数、土台は1つ', () {
    final g = PrerequisiteGraph(const [
      PrereqNode('top', requires: ['left', 'right']),
      PrereqNode('left', requires: ['base']),
      PrereqNode('right', requires: ['base']),
    ]);
    final r = diagnoseBacktrace(g, 'top', ms({'left': .2, 'right': .3, 'base': .1}));
    expect(r.steps.map((s) => (s.unitId, s.depth)), [('base', 2), ('left', 1), ('right', 1)]);
    expect(r.rootCauses.map((s) => s.unitId), ['base']);
  });

  test('前提が無い単元で、他アプリの前提だけがある場合は誘導先を返す', () {
    final g = PrerequisiteGraph(const [
      PrereqNode('neg', external: [ExternalRef(id: 'shogaku_fraction', title: '分数の計算')]),
    ]);
    final r = diagnoseBacktrace(g, 'neg', const {});
    expect(r.steps, isEmpty);
    expect(r.externalReferrals.single.title, '分数の計算');
  });

  test('前提の定義が無い単元は空の結果。循環があっても止まる', () {
    final none = diagnoseBacktrace(graph, 'neg_unknown_unit', const {});
    expect(none.steps, isEmpty);
    expect(none.externalReferrals, isEmpty);
    final cyc = PrerequisiteGraph(const [PrereqNode('a', requires: ['b']), PrereqNode('b', requires: ['a'])]);
    final r = diagnoseBacktrace(cyc, 'a', ms({'b': .1}));
    expect(r.steps.map((s) => s.unitId), ['b']); // 自分(a)には戻らない
  });

  test('同じ入力で同じ結果', () {
    final m = ms({'expr': .4, 'neg': .3});
    final a = diagnoseBacktrace(graph, 'eq', m).steps.map((s) => s.unitId).toList();
    final b = diagnoseBacktrace(graph, 'eq', m).steps.map((s) => s.unitId).toList();
    expect(a, b);
  });

  group('検証と JSON', () {
    final tree = _tree(['eq', 'expr', 'neg']);

    Set<String> codes(PrerequisiteGraph g, {Iterable<PrereqNode>? raw}) =>
        g.validate(tree, rawNodes: raw).map((i) => i.code).toSet();

    test('正常', () => expect(graph.validate(tree), isEmpty));

    test('単元が無い・前提が無い・自分自身・循環・重複・外部の空欄', () {
      expect(codes(PrerequisiteGraph(const [PrereqNode('zzz')])), contains('prereq_unit_missing'));
      expect(codes(PrerequisiteGraph(const [PrereqNode('eq', requires: ['zzz'])])), contains('prereq_requires_missing'));
      expect(codes(PrerequisiteGraph(const [PrereqNode('eq', requires: ['eq'])])), contains('prereq_self'));
      expect(
        codes(PrerequisiteGraph(const [PrereqNode('eq', requires: ['expr']), PrereqNode('expr', requires: ['eq'])])),
        contains('prereq_cycle'),
      );
      const dup = [PrereqNode('eq'), PrereqNode('eq')];
      expect(codes(PrerequisiteGraph(dup), raw: dup), contains('prereq_duplicate'));
      expect(
        codes(PrerequisiteGraph(const [PrereqNode('eq', external: [ExternalRef(id: '', title: 'x')])])),
        contains('prereq_external_empty'),
      );
    });

    test('JSON から読める（external は link 省略可）', () {
      final g = PrerequisiteGraph.fromJson({
        'version': 1,
        'prerequisites': [
          {'unitId': 'eq', 'requires': ['expr']},
          {'unitId': 'neg', 'external': [{'id': 'shogaku_fraction', 'title': '分数の計算'}]},
        ],
      });
      expect(g.requiresOf('eq'), ['expr']);
      expect(g.externalOf('neg').single.link, isNull);
      expect(g.validate(tree), isEmpty);
      expect(ExternalRef.fromJson(g.externalOf('neg').single.toJson()).id, 'shogaku_fraction');
    });
  });

  test('サンプル（docs/samples）は誤りなし。診断までつながる', () {
    final units = jsonDecode(File('docs/samples/units.sample.json').readAsStringSync()) as Map<String, dynamic>;
    final prereq = jsonDecode(File('docs/samples/prerequisites.sample.json').readAsStringSync()) as Map<String, dynamic>;
    final tree = UnitTree.fromJson(units);
    final g = PrerequisiteGraph.fromJson(prereq);
    expect(g.validate(tree), isEmpty);
    final r = diagnoseBacktrace(g, 'en1_verbs', ms({'en1_be': 0.3}));
    expect(r.rootCauses.map((s) => s.unitId), ['en1_be']);
    expect(r.externalReferrals.single.id, 'shogaku_english_basic');
  });

  test('循環した前提でも、出発点の候補が空にならない（検証を通さない入力）', () {
    final g = PrerequisiteGraph([
      const PrereqNode('a', requires: ['b']),
      const PrereqNode('b', requires: ['c']),
      const PrereqNode('c', requires: ['b']),
    ]);
    final r = diagnoseBacktrace(g, 'a', ms({'b': 0.2, 'c': 0.3}));
    expect(r.prerequisitesSolid, isFalse);
    expect(r.rootCauses, isNotEmpty);
  });
}
