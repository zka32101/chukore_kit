import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _base(String kind, Map<String, dynamic> extra) => {
      'id': 'e1', 'version': 1, 'unitId': 'u', 'kind': kind, 'promptId': 'p', 'explanationId': 'x', ...extra,
    };

Experience _p(String kind, Map<String, dynamic> extra) => Experience.fromJson(_base(kind, extra));

Matcher _bad([String? part]) => throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(part ?? '')));

SortExperience _sort() => _p('sort', {
      'bins': [{'id': 'a'}, {'id': 'b'}, {'id': 'c'}],
      'items': [{'id': 'i1', 'bin': 'a'}, {'id': 'i2', 'bin': 'a'}, {'id': 'i3', 'bin': 'b'}],
    }) as SortExperience;

LinkExperience _link({bool directed = true}) => _p('link', {
      'nodes': ['n1', 'n2', 'n3', 'n4'],
      'edges': [{'from': 'n1', 'to': 'n2'}, {'from': 'n2', 'to': 'n3'}],
      'directed': directed,
    }) as LinkExperience;

DialExperience _dial({double tol = 0, double initial = 0, double target = 9}) => _p('dial', {
      'min': -12, 'max': 12, 'step': 1, 'initial': initial, 'target': target, 'tolerance': tol,
    }) as DialExperience;

BalanceExperience _bal(Map<String, dynamic> extra) => _p('balance', extra) as BalanceExperience;

UnitTree _tree() => UnitTree(1, [Unit(id: 'u', subject: 'math', grade: 1, title: 'U')]);

void main() {
  group('共通の読み取り', () {
    test('未対応の kind・未知のキー・id・version', () {
      expect(() => _p('puzzle', {}), _bad('未対応'));
      expect(() => _p('dial', {'min': 0, 'max': 1, 'step': 1, 'initial': 0, 'target': 1, 'zzz': 1}), _bad('未知のキー'));
      expect(() => _p('sort', {'bins': [], 'items': [], 'min': 1}), _bad('未知のキー'));
      expect(() => Experience.fromJson({..._base('dial', {}), 'id': 'a-b'}), _bad('id'));
      expect(() => Experience.fromJson({..._base('dial', {}), 'version': 0}), _bad('version'));
      expect(() => Experience.fromJson({..._base('dial', {}), 'promptId': ''}), _bad('promptId'));
      expect(() => Experience.fromJson({..._base('dial', {}), 'unitId': 1}), _bad('unitId'));
    });

    test('kind の名前', () {
      expect([_sort().kind, _link().kind, _dial().kind, _bal({'items': [{'id': 'a', 'weight': 1}]}).kind],
          ['sort', 'link', 'dial', 'balance']);
    });
  });

  group('sort', () {
    test('読み取り', () {
      final s = _sort();
      expect(s.bins, ['a', 'b', 'c']);
      expect(s.items, {'i1': 'a', 'i2': 'a', 'i3': 'b'});
    });

    test('形の誤り', () {
      Map<String, dynamic> m({List? bins, List? items}) => {
            'bins': bins ?? [{'id': 'a'}, {'id': 'b'}],
            'items': items ?? [{'id': 'i1', 'bin': 'a'}, {'id': 'i2', 'bin': 'b'}],
          };
      expect(() => _p('sort', m(bins: [{'id': 'a'}])), _bad('bins'));
      expect(() => _p('sort', m(bins: [{'id': 'a'}, {'id': 'a'}])), _bad('重複'));
      expect(() => _p('sort', m(bins: [{'id': 'a', 'x': 1}, {'id': 'b'}])), _bad('bins'));
      expect(() => _p('sort', m(items: [{'id': 'i1', 'bin': 'a'}])), _bad('items'));
      expect(() => _p('sort', m(items: [{'id': 'i1', 'bin': 'zz'}, {'id': 'i2', 'bin': 'a'}])), _bad('bins にありません'));
      expect(() => _p('sort', m(items: [{'id': 'i1', 'bin': 'a'}, {'id': 'i1', 'bin': 'b'}])), _bad('重複'));
      expect(() => _p('sort', m(items: [{'id': 'i1', 'bin': 'a', 'x': 1}, {'id': 'i2', 'bin': 'a'}])), _bad('items'));
      expect(() => _p('sort', m(items: [{'id': 'i1'}, {'id': 'i2', 'bin': 'a'}])), _bad('bin'));
    });

    test('判定: 正しい／違う／まだ', () {
      final r = _sort().check({'i1': 'a', 'i2': 'b', 'zz': 'a'});
      expect(r.correct, ['i1']);
      expect(r.wrong, ['i2']);
      expect(r.unplaced, ['i3']);
      expect(r.complete, isFalse);
      expect(_sort().check({'i1': 'a', 'i2': 'a', 'i3': 'b'}).complete, isTrue);
      expect(_sort().check(const {}).complete, isFalse);
      expect(_sort().check({'i1': 'a', 'i2': 'a', 'i3': 'c'}).complete, isFalse);
    });
  });

  group('link', () {
    test('向きありの判定: 過不足', () {
      final r = _link().check([('n1', 'n2'), ('n3', 'n2'), ('n1', 'n4'), ('n1', 'n2')]);
      expect(r.correct, ['n1>n2']);
      expect(r.missing, ['n2>n3']);
      expect(r.extra, ['n1>n4', 'n3>n2']);
      expect(r.complete, isFalse);
      expect(_link().check([('n1', 'n2'), ('n2', 'n3')]).complete, isTrue);
    });

    test('向きなしは向きを問わない', () {
      final l = _link(directed: false);
      expect(l.check([('n2', 'n1'), ('n3', 'n2')]).complete, isTrue);
      expect(l.edges, ['n1>n2', 'n2>n3']);
      expect(LinkExperience.edgeKey('b', 'a', directed: false), 'a>b');
      expect(LinkExperience.edgeKey('b', 'a'), 'b>a');
      expect(LinkExperience.edgeKey('a', 'b', directed: false), 'a>b');
    });

    test('点にない辺・自分への辺は余分', () {
      final r = _link().check([('n1', 'n2'), ('n2', 'n3'), ('zz', 'n1'), ('n1', 'n1')]);
      expect(r.extra, ['n1>n1', 'zz>n1']);
      expect(r.complete, isFalse);
    });

    test('形の誤り', () {
      Map<String, dynamic> m({Object? nodes, Object? edges, Object? directed}) => {
            'nodes': nodes ?? ['a', 'b'],
            'edges': edges ?? [{'from': 'a', 'to': 'b'}],
            'directed': ?directed,
          };
      expect(() => _p('link', m(nodes: ['a'])), _bad('nodes'));
      expect(() => _p('link', m(nodes: ['a', 'a'])), _bad('重複'));
      expect(() => _p('link', m(nodes: ['a', ''])), _bad('nodes'));
      expect(() => _p('link', m(edges: [])), _bad('edges'));
      expect(() => _p('link', m(edges: [{'from': 'a', 'to': 'zz'}])), _bad('nodes にありません'));
      expect(() => _p('link', m(edges: [{'from': 'a', 'to': 'a'}])), _bad('自分'));
      expect(() => _p('link', m(edges: [{'from': 'a', 'to': 'b'}, {'from': 'a', 'to': 'b'}])), _bad('重複'));
      expect(() => _p('link', m(edges: [{'from': 'a', 'to': 'b', 'x': 1}])), _bad('edges'));
      expect(() => _p('link', m(directed: 'yes')), _bad('directed'));
      expect(() => _p('link', m(directed: false, edges: [{'from': 'a', 'to': 'b'}, {'from': 'b', 'to': 'a'}])), _bad('重複'));
      // 向きありなら逆向きは別の辺
      expect((_p('link', m(edges: [{'from': 'a', 'to': 'b'}, {'from': 'b', 'to': 'a'}])) as LinkExperience).edges.length, 2);
    });
  });

  group('dial', () {
    test('目盛に合わせて判定する', () {
      final d = _dial();
      expect(d.snap(8.6), 9);
      expect(d.snap(100), 12);
      expect(d.snap(-100), -12);
      final r = d.check(8.6);
      expect([r.value, r.distance, r.reached], [9, 0, true]);
      final w = d.check(7.2);
      expect([w.value, w.distance, w.reached], [7, 2, false]);
    });

    test('許容: 差が tolerance 以下なら合っている', () {
      final d = _dial(tol: 1);
      expect(d.check(8).reached, isTrue);
      expect(d.check(10).reached, isTrue);
      expect(d.check(7).reached, isFalse);
      expect(d.check(11).reached, isFalse);
    });

    test('小数の目盛でも誤差で外れない', () {
      final d = _p('dial', {'min': 0, 'max': 1, 'step': 0.1, 'initial': 0, 'target': 0.3}) as DialExperience;
      expect(d.check(0.3).reached, isTrue);
      expect(d.snap(0.30000000000000004), 0.3);
      expect(d.count, 11);
      expect(d.onGrid(0.7), isTrue);
      expect(d.onGrid(0.75), isFalse);
      expect(d.onGrid(1.1), isFalse);
      expect(d.onGrid(-0.1), isFalse);
      expect(d.onGrid(-1e-12), isTrue);
      expect(d.onGrid(1 + 1e-12), isTrue);
    });

    test('形の誤り', () {
      Map<String, dynamic> m({num min = 0, num max = 10, num step = 1, num initial = 0, num target = 5, num? tol, Object? tgt}) => {
            'min': min, 'max': max, 'step': step, 'initial': initial, 'target': tgt ?? target,
            'tolerance': ?tol,
          };
      expect(() => _p('dial', m(step: 0)), _bad('step'));
      expect(() => _p('dial', m(step: 11)), _bad('step'));
      expect(() => _p('dial', m(tol: -1)), _bad('tolerance'));
      expect(() => _p('dial', m(initial: 0.5)), _bad('initial'));
      expect(() => _p('dial', m(target: 11)), _bad('target'));
      expect(() => _p('dial', m(tgt: 'x')), _bad('target'));
      expect(() => _p('dial', m(max: 20000)), _bad('多すぎ'));
      _p('dial', m(max: 9999)); // 目盛 10000 個までは可
      _p('dial', m(step: 10, target: 10)); // step = 範囲 は可
    });
  });

  group('balance', () {
    Map<String, dynamic> m({List? items, Object? l, Object? r}) => {
          'items': items ?? [{'id': 'a', 'weight': 2}, {'id': 'b', 'weight': 3}, {'id': 'c', 'weight': 5}],
          'leftFixed': ?l,
          'rightFixed': ?r,
        };

    test('つりあいと傾き', () {
      final b = _bal(m(l: [1], r: [4]));
      var r = b.check({'a': 'left'});
      expect([r.left, r.right, r.tilt, r.solved], [3.0, 4.0, Tilt.right, false]);
      r = b.check({'b': 'left'}); // 1+3 = 4
      expect([r.tilt, r.solved], [Tilt.even, true]);
      r = b.check({'c': 'left'});
      expect(r.tilt, Tilt.left);
      expect(b.check({'zz': 'left', 'a': 'up'}).left, 1);
    });

    test('何も載せずにつりあっていても solved ではない', () {
      final b = _bal(m(l: [2], r: [2]));
      final r = b.check(const {});
      expect([r.tilt, r.solved], [Tilt.even, false]);
      expect(b.check({'a': 'left', 'b': 'right'}).solved, isFalse);
    });

    test('小数の重さでも誤差で外れない', () {
      final b = _bal({'items': [{'id': 'a', 'weight': 0.1}, {'id': 'b', 'weight': 0.2}, {'id': 'c', 'weight': 0.3}]});
      expect(b.check({'a': 'left', 'b': 'left', 'c': 'right'}).solved, isTrue);
    });

    test('解の探索: 1 つ以上載せる、limit', () {
      final b = _bal(m(l: [5]));
      final all = b.solutions(limit: 100);
      expect(all, isNotEmpty);
      expect(all.every((s) => b.check(s).solved), isTrue);
      expect(all.every((s) => s.isNotEmpty), isTrue);
      expect(b.solutions(limit: 1).length, 1);
      expect(b.solutions(limit: 2).length, 2);
      // 2+3 = 5(left 5 に right で足す／ c を右)
      expect(all.any((s) => s.length == 1 && s['c'] == 'right'), isTrue);
    });

    test('解が無い', () {
      final b = _bal({'items': [{'id': 'a', 'weight': 2}], 'leftFixed': [1]});
      expect(b.solutions(), isEmpty);
    });

    test('形の誤り', () {
      expect(() => _bal(m(items: [])), _bad('items'));
      expect(() => _bal(m(items: [for (var i = 0; i < 13; i++) {'id': 'a$i', 'weight': 1}])), _bad('items'));
      expect(() => _bal(m(items: [{'id': 'a', 'weight': 0}])), _bad('weight'));
      expect(() => _bal(m(items: [{'id': 'a', 'weight': -1}])), _bad('weight'));
      expect(() => _bal(m(items: [{'id': 'a'}])), _bad('weight'));
      expect(() => _bal(m(items: [{'id': 'a', 'weight': 1}, {'id': 'a', 'weight': 2}])), _bad('重複'));
      expect(() => _bal(m(items: [{'id': 'a', 'weight': 1, 'x': 1}])), _bad('items'));
      expect(() => _bal(m(l: [-1])), _bad('leftFixed'));
      expect(() => _bal(m(r: ['x'])), _bad('rightFixed'));
      expect(() => _bal(m(l: 3)), _bad('leftFixed'));
      expect(() => _bal(m(l: List.filled(31, 1))), _bad('leftFixed'));
      _bal(m(items: [for (var i = 0; i < 12; i++) {'id': 'a$i', 'weight': 1}], l: List.filled(30, 1)));
    });
  });

  group('集まりと検証', () {
    String set(List<Map<String, dynamic>> xs) => jsonEncode({'version': 1, 'experiences': xs});

    test('読み取り・重複 id・版', () {
      final s = ExperienceSet.parse(set([_base('dial', {'min': 0, 'max': 2, 'step': 1, 'initial': 0, 'target': 2})]));
      expect(s.experiences.single, isA<DialExperience>());
      final dup = _base('dial', {'min': 0, 'max': 2, 'step': 1, 'initial': 0, 'target': 2});
      expect(() => ExperienceSet.parse(set([dup, dup])), _bad('重複'));
      expect(() => ExperienceSet.parse('{"version":2,"experiences":[]}'), _bad('版'));
      expect(() => ExperienceSet.parse('{"version":1}'), _bad('experiences'));
      expect(() => ExperienceSet.parse('[]'), _bad('オブジェクト'));
      expect(() => ExperienceSet.parse('{'), _bad('読めません'));
    });

    List<String> codes(List<Map<String, dynamic>> xs) =>
        [for (final i in validateExperiences(ExperienceSet.parse(set(xs)), tree: _tree())) '${i.code}:${i.severity.name}'];

    test('問題のない体験は指摘なし', () {
      expect(codes([
        _base('dial', {'min': 0, 'max': 2, 'step': 1, 'initial': 0, 'target': 2}),
        {..._base('balance', {'items': [{'id': 'a', 'weight': 1}], 'leftFixed': [1]}), 'id': 'e2'},
        {..._base('link', {'nodes': ['a', 'b'], 'edges': [{'from': 'a', 'to': 'b'}]}), 'id': 'e3'},
        {..._base('sort', {'bins': [{'id': 'a'}, {'id': 'b'}], 'items': [{'id': 'i', 'bin': 'a'}, {'id': 'j', 'bin': 'b'}]}), 'id': 'e4'},
      ]), isEmpty);
    });

    test('各コード', () {
      expect(codes([{..._base('dial', {'min': 0, 'max': 2, 'step': 1, 'initial': 0, 'target': 2}), 'unitId': 'zz'}]),
          ['experience_unit_missing:error']);
      expect(codes([_base('dial', {'min': 0, 'max': 2, 'step': 1, 'initial': 1, 'target': 2, 'tolerance': 1})]),
          ['experience_initial_is_goal:error']);
      expect(codes([_base('balance', {'items': [{'id': 'a', 'weight': 1}, {'id': 'b', 'weight': 1}], 'leftFixed': [1], 'rightFixed': [1]})]),
          ['experience_initial_is_goal:error']);
      expect(codes([_base('balance', {'items': [{'id': 'a', 'weight': 1}], 'leftFixed': [5]})]),
          ['experience_goal_unreachable:error']);
      expect(codes([_base('sort', {'bins': [{'id': 'a'}, {'id': 'b'}], 'items': [{'id': 'i', 'bin': 'a'}, {'id': 'j', 'bin': 'a'}]})]),
          ['experience_bin_empty:warning']);
    });

    test('ダイヤルは最初が目標でなければ許容があっても指摘しない', () {
      expect(codes([_base('dial', {'min': 0, 'max': 4, 'step': 1, 'initial': 0, 'target': 4, 'tolerance': 1})]), isEmpty);
    });
  });
}
