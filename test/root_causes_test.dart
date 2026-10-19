import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Mastery m(String u, double s) => Mastery(unitId: u, score: s);

// c → b → a、d → b、e → a、g → h（別の系統）、f は前提なし
final graph = PrerequisiteGraph([
  const PrereqNode('c', requires: ['b']),
  const PrereqNode('d', requires: ['b']),
  const PrereqNode('b', requires: ['a']),
  const PrereqNode('e', requires: ['a']),
  const PrereqNode('a'),
  const PrereqNode('f'),
  const PrereqNode('g', requires: ['h']),
  const PrereqNode('h', external: [ExternalRef(id: 'ext1', title: '算数')]),
]);

void main() {
  test('同じ土台に行き着く弱い単元をまとめ、多く説明する順に並べる', () {
    final mastery = {
      'a': m('a', 0.3), // 土台（弱い）
      'b': m('b', 0.9), // 固まっている
      'c': m('c', 0.4),
      'd': m('d', 0.5),
      'e': m('e', 0.5),
      'f': m('f', 0.2), // 前提なし・弱い → 自分が土台
    };
    final r = rankRootCauses(graph, mastery);
    expect(r.map((x) => x.unitId), ['a', 'f']);
    expect(r.first.explains, ['a', 'c', 'd', 'e']);
    expect(r.first.selfWeak, isTrue);
    expect(r.first.mastery, 0.3);
    expect(r.last.explains, ['f']);
  });

  test('前提が固まっていて自分だけ弱い単元は、自分が土台。土台が弱くない前提のときは前提を指さない', () {
    final r = rankRootCauses(graph, {'a': m('a', 0.9), 'b': m('b', 0.9), 'c': m('c', 0.3)});
    expect(r.single.unitId, 'c');
    expect(r.single.explains, ['c']);
  });

  test('同数なら習熟度の低い順（記録なしが先）→ 単元ID順', () {
    // x1,x2 は同じ数（1）を説明。x2 のほうが低い。y は記録なし（includeUnknown）
    final g = PrerequisiteGraph([const PrereqNode('x1'), const PrereqNode('x2'), const PrereqNode('y')]);
    final r = rankRootCauses(g, {'x1': m('x1', 0.5), 'x2': m('x2', 0.1)}, unitIds: ['x1', 'x2', 'y'], includeUnknown: true);
    expect(r.map((x) => x.unitId), ['y', 'x2', 'x1']);
    expect(r.first.mastery, isNull);
    expect(r.first.selfWeak, isFalse);
    final ties = rankRootCauses(g, {'x1': m('x1', 0.3), 'x2': m('x2', 0.3)});
    expect(ties.map((x) => x.unitId), ['x1', 'x2']);
  });

  test('記録の無い単元は、includeUnknown でなければ弱い単元に数えない', () {
    final mastery = {'c': m('c', 0.4), 'b': m('b', 0.9), 'a': m('a', 0.9)};
    expect(rankRootCauses(graph, mastery, unitIds: ['c', 'f']).map((x) => x.unitId), ['c']);
    expect(rankRootCauses(graph, mastery, unitIds: ['c', 'f'], includeUnknown: true).map((x) => x.unitId), ['f', 'c']);
  });

  test('unitIds で範囲を絞る。範囲外の弱い単元は数えない', () {
    final mastery = {'a': m('a', 0.3), 'c': m('c', 0.4), 'f': m('f', 0.1)};
    final r = rankRootCauses(graph, mastery, unitIds: ['c']);
    expect(r.single.unitId, 'a');
    expect(r.single.explains, ['c']);
  });

  test('weakBelow が境目（未満が弱い）', () {
    expect(rankRootCauses(graph, {'f': m('f', 0.6)}), isEmpty);
    expect(rankRootCauses(graph, {'f': m('f', 0.59)}).single.unitId, 'f');
    expect(rankRootCauses(graph, {'f': m('f', 0.6)}, weakBelow: 0.61).single.unitId, 'f');
  });

  test('weakBelow は前提の判定にも使う（前提が 0.7 でも、0.8 を基準にすれば前提が土台）', () {
    final mastery = {'a': m('a', 0.9), 'b': m('b', 0.7), 'c': m('c', 0.5)};
    expect(rankRootCauses(graph, mastery).single.unitId, 'c');
    final r = rankRootCauses(graph, mastery, weakBelow: 0.8);
    expect(r.single.unitId, 'b');
    expect(r.single.explains, ['b', 'c']);
  });

  test('他アプリへの誘導先を土台に付ける', () {
    final r = rankRootCauses(graph, {'g': m('g', 0.3), 'h': m('h', 0.2)});
    expect(r.single.unitId, 'h');
    expect(r.single.explains, ['g', 'h']);
    expect(r.single.externalReferrals.map((e) => e.id), ['ext1']);
  });

  test('弱い単元が無ければ空', () {
    expect(rankRootCauses(graph, const {}), isEmpty);
    expect(rankRootCauses(graph, {'a': m('a', 0.9)}), isEmpty);
  });
}
