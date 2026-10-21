import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Mastery m(String u, double s) => Mastery(unitId: u, score: s);

// b → a、c → b、d → a、g → [a, h]、e・f は前提なし
final graph = PrerequisiteGraph([
  const PrereqNode('a'),
  const PrereqNode('b', requires: ['a']),
  const PrereqNode('c', requires: ['b']),
  const PrereqNode('d', requires: ['a']),
  const PrereqNode('e'),
  const PrereqNode('f', external: [ExternalRef(id: 'x', title: '算数')]),
  const PrereqNode('h'),
  const PrereqNode('g', requires: ['a', 'h']),
]);

List<String> ids(List<NextUnit> r) => [for (final u in r) u.unitId];

void main() {
  test('前提が固まった単元だけが出る。仕上がり済みと、前提が固まっていない単元は出ない', () {
    final r = suggestNextUnits(graph, {'a': m('a', 0.9)}, maxUnits: 10);
    // a は仕上がり済み。b・d は a が固まっている。e・f・h は前提なし。c は b が未学習、g は h が未学習で止まる
    expect(ids(r).toSet(), {'b', 'd', 'e', 'f', 'h'});
    expect(ids(r), isNot(contains('a')));
    expect(ids(r), isNot(contains('c')));
    expect(ids(r), isNot(contains('g')));
  });

  test('続きから（記録あり）が先、習熟度の低い順。新しく始めるものは、先が開ける数の多い順 → 単元ID順', () {
    final mastery = {'a': m('a', 0.9), 'e': m('e', 0.7), 'h': m('h', 0.5)};
    final r = suggestNextUnits(graph, mastery, maxUnits: 10);
    // 続きから: h(0.5) → e(0.7)。新しく: b(unlocks 1:c)・d(0)・f(0) → b が先、あとは d, f
    expect(ids(r), ['h', 'e', 'b', 'd', 'f'], reason: 'g は h(0.5) が readyAt 未満なので止まる');
  });

  test('前提の境目: readyAt ちょうどは固まっている。仕上がりの境目: doneAt ちょうどは仕上がり済み', () {
    expect(ids(suggestNextUnits(graph, {'a': m('a', 0.6)}, unitIds: ['b'])), ['b']);
    expect(ids(suggestNextUnits(graph, {'a': m('a', 0.59)}, unitIds: ['b'])), isEmpty);
    expect(ids(suggestNextUnits(graph, {'e': m('e', 0.8)}, unitIds: ['e'])), isEmpty);
    expect(ids(suggestNextUnits(graph, {'e': m('e', 0.79)}, unitIds: ['e'])), ['e']);
    expect(ids(suggestNextUnits(graph, {'a': m('a', 0.7), 'e': m('e', 0.7)}, unitIds: ['b'], readyAt: 0.8)), isEmpty);
    expect(ids(suggestNextUnits(graph, {'e': m('e', 0.7)}, unitIds: ['e'], doneAt: 0.7)), isEmpty);
  });

  test('複数の前提は、すべて固まっている必要がある', () {
    expect(ids(suggestNextUnits(graph, {'a': m('a', 0.9), 'h': m('h', 0.9)}, unitIds: ['g'])), ['g']);
    expect(ids(suggestNextUnits(graph, {'a': m('a', 0.9), 'h': m('h', 0.3)}, unitIds: ['g'])), isEmpty);
    expect(ids(suggestNextUnits(graph, {'a': m('a', 0.9)}, unitIds: ['g'])), isEmpty, reason: 'h に記録が無い');
  });

  test('他アプリの前提は止めない。前提グラフに無い単元は前提なし', () {
    expect(ids(suggestNextUnits(graph, const {}, unitIds: ['f', 'unknown_unit'])), ['f', 'unknown_unit']);
  });

  test('unitIds で範囲を絞る。範囲外の前提も習熟度は見る。maxUnits で件数を絞る', () {
    final mastery = {'a': m('a', 0.9)};
    expect(ids(suggestNextUnits(graph, mastery, unitIds: ['b', 'c'])), ['b']);
    expect(suggestNextUnits(graph, mastery, maxUnits: 2).length, 2);
    expect(suggestNextUnits(graph, mastery, maxUnits: 100).length, 5);
  });

  test('結果には状態・習熟度・先が開ける数が入る', () {
    final r = suggestNextUnits(graph, {'a': m('a', 0.9), 'b': m('b', 0.65)}, unitIds: ['b', 'd', 'c']);
    final b = r.firstWhere((u) => u.unitId == 'b');
    expect([b.status, b.mastery, b.unlocks], [NextUnitStatus.inProgress, 0.65, 1]);
    final d = r.firstWhere((u) => u.unitId == 'd');
    expect([d.status, d.mastery, d.unlocks], [NextUnitStatus.notStarted, null, 0]);
    expect(ids(r), ['b', 'c', 'd'], reason: 'b(0.65) は readyAt(0.6) 以上なので c も出る。新しい単元どうしは先が開ける数が同じ（0）なので単元ID順');
  });

  test('先が開ける数は、その単元を前提にしている単元の数（a は b・d・g の 3 つ）。記録の無い前提は readyAt が 0 でも固まっていない', () {
    final r = suggestNextUnits(graph, {'a': m('a', 0.7)}, unitIds: ['a']);
    expect([r.single.unitId, r.single.unlocks], ['a', 3]);
    expect(ids(suggestNextUnits(graph, const {}, unitIds: ['b'], readyAt: 0)), isEmpty);
  });

  test('入力が不正ならエラー。前提が無ければ空', () {
    expect(() => suggestNextUnits(graph, const {}, maxUnits: 0), throwsArgumentError);
    expect(suggestNextUnits(PrerequisiteGraph(const []), const {}), isEmpty);
  });
}
