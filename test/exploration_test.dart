import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> base([Map<String, dynamic> over = const {}]) => {
  'id': 'e1',
  'version': 1,
  'unitId': 'u',
  'kind': 'slider_graph',
  'promptId': 'p',
  'expr': 'a*x+b',
  'params': [
    {'name': 'a', 'min': -3, 'max': 3, 'step': 1, 'initial': 0},
    {'name': 'b', 'min': -2, 'max': 2, 'step': 1, 'initial': 0},
  ],
  'goal': {'expr': '2*x+1'},
  'explanationId': 'e',
  ...over,
};

Exploration ex([Map<String, dynamic> over = const {}]) => Exploration.fromJson(base(over));

void main() {
  final sample = ExplorationSet.parse(File('docs/samples/explorations.sample.json').readAsStringSync());
  final tree = UnitTree.fromJson(
    jsonDecode(File('docs/content_drafts/suugaku_chu1/units.json').readAsStringSync()) as Map<String, dynamic>,
  );

  group('サンプル', () {
    test('検証エラーなし。どの教材も目標に届く', () {
      expect(validateExplorations(sample, tree: tree), isEmpty);
      for (final e in sample.explorations) {
        final s = e.goalSolutions(limit: 3);
        expect(s, isNotEmpty, reason: e.id);
        for (final m in s) {
          expect(e.goalReached(m), isTrue, reason: e.id);
        }
      }
    });
    test('比例の教材: 目標は a=3、予想の答え合わせ', () {
      final e = sample.explorations.first;
      expect(e.goalSolutions(), [
        {'a': 3.0},
      ]);
      expect(e.goalReached({'a': 3}), isTrue);
      expect(e.goalReached({'a': 2.5}), isFalse);
      expect(e.checkPrediction('steeper'), isTrue);
      expect(e.checkPrediction('same'), isFalse);
      expect(e.checkPrediction('nope'), isNull);
    });
    test('一次関数の教材: 目標は a=2, b=1 の 1 組だけ', () {
      expect(sample.explorations[1].goalSolutions(limit: 10), [
        {'a': 2.0, 'b': 1.0},
      ]);
      expect(sample.explorations[1].checkPrediction('x'), isNull); // 予想の問いがない
    });
    test('反比例の教材: 目標は a=9', () {
      expect(sample.explorations[2].goalSolutions(), [
        {'a': 9.0},
      ]);
    });
  });

  group('パラメータ', () {
    test('格子: 値の一覧・最も近い値・範囲外は端', () {
      final p = ExplorationParam.fromJson({'name': 'a', 'min': -1, 'max': 1, 'step': 0.5, 'initial': 0});
      expect(p.values, [-1.0, -0.5, 0.0, 0.5, 1.0]);
      expect(p.count, 5);
      expect(p.snap(0.3), 0.5);
      expect(p.snap(0.2), 0.0);
      expect(p.snap(9), 1.0);
      expect(p.snap(-9), -1.0);
      expect(p.onGrid(0.5), isTrue);
      expect(p.onGrid(0.3), isFalse);
      expect(p.onGrid(1.5), isFalse);
    });
    test('0.1 刻みでも誤差で外れない', () {
      final p = ExplorationParam.fromJson({'name': 'a', 'min': 0, 'max': 1, 'step': 0.1, 'initial': 0.3});
      expect(p.count, 11);
      expect(p.values[3], 0.3);
      expect(p.snap(0.7000000001), 0.7);
    });
    test('書き間違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        {'name': 'x', 'min': 0, 'max': 1, 'step': 1, 'initial': 0},
        {'name': 'ab', 'min': 0, 'max': 1, 'step': 1, 'initial': 0},
        {'name': 'a', 'min': 1, 'max': 1, 'step': 1, 'initial': 1},
        {'name': 'a', 'min': 2, 'max': 1, 'step': 1, 'initial': 1},
        {'name': 'a', 'min': 0, 'max': 1, 'step': 0, 'initial': 0},
        {'name': 'a', 'min': 0, 'max': 1, 'step': 2, 'initial': 0},
        {'name': 'a', 'min': 0, 'max': 1, 'step': 0.5, 'initial': 0.3},
        {'name': 'a', 'min': 0, 'max': 1, 'step': 1, 'initial': 2},
        {'name': 'a', 'min': 0, 'max': 1000000, 'step': 1, 'initial': 0},
        {'name': 'a', 'min': 'z', 'max': 1, 'step': 1, 'initial': 0},
      ];
      for (final b in bad) {
        expect(() => ExplorationParam.fromJson(b), throwsFormatException, reason: b.toString());
      }
    });
  });

  group('グラフと目標', () {
    test('sample: 両端を含む点。パラメータは格子に合わせる。定義できない点は NaN', () {
      final e = ex();
      final pts = e.sample({'a': 2, 'b': 1}, xMin: -1, xMax: 1, count: 3);
      expect(pts.map((p) => p.x), [-1.0, 0.0, 1.0]);
      expect(pts.map((p) => p.y), [-1.0, 1.0, 3.0]);
      expect(e.sample({'a': 1.9, 'b': 0.8}, xMin: 0, xMax: 1, count: 2).map((p) => p.y), [1.0, 3.0]);
      final inv = ExplorationSet.parse(
        File('docs/samples/explorations.sample.json').readAsStringSync(),
      ).explorations[2];
      final ys = inv.sample({'a': 6}, xMin: -1, xMax: 1, count: 3).map((p) => p.y).toList();
      expect(ys[0], -6.0);
      expect(ys[1].isNaN, isTrue); // x=0
      expect(ys[2], 6.0);
      final huge = ex({'expr': 'a*x^400+b', 'goal': null}).sample({'a': 1}, xMin: 0, xMax: 10, count: 2);
      expect(huge[1].y.isNaN, isTrue); // 桁あふれ（無限大）も NaN にして、画面が描かない点として扱えるようにする
      expect(() => e.sample({}, xMin: 1, xMax: 1), throwsArgumentError);
      expect(() => e.sample({}, xMin: 0, xMax: 1, count: 1), throwsArgumentError);
    });
    test('goalReached: 同じ関数なら達成（書き方によらない）。目標が無ければ偽', () {
      final e = ex();
      expect(e.goalReached({'a': 2, 'b': 1}), isTrue);
      expect(e.goalReached({'a': 2, 'b': 0}), isFalse);
      expect(e.goalReached({'a': 1.9, 'b': 1.2}), isTrue); // 格子に合わせて (2, 1) にしてから判定
      expect(e.goalReached({'a': 1.4, 'b': 1.2}), isFalse); // (1, 1)
      expect(ex({'goal': null}).goalReached({'a': 2, 'b': 1}), isFalse);
      expect(ex({'goal': null}).goalSolutions(), isEmpty);
      // 目標 2(x+1) = 2x+2 と同じ関数: a*x+b で (2,2)
      expect(
        ex({
          'goal': {'expr': '2*(x+1)'},
        }).goalReached({'a': 2, 'b': 2}),
        isTrue,
      );
    });
    test('initialValues と normalize', () {
      final e = ex();
      expect(e.initialValues, {'a': 0.0, 'b': 0.0});
      expect(e.normalize({'a': 2.4}), {'a': 2.0, 'b': 0.0});
    });
    test('goalSolutions: 複数の組があるとき limit で止まる', () {
      final e = ex({
        'expr': 'a*x+b*x',
        'goal': {'expr': '2*x'},
      });
      expect(e.goalSolutions(limit: 10).length, 4); // a+b=2: (0,2) (1,1) (2,0) (3,-1)
      expect(e.goalSolutions(limit: 2).length, 2);
      expect(e.goalSolutions(limit: 10).every(e.goalReached), isTrue);
    });
  });

  group('読み込み', () {
    test('必須・未知のキー・式の文字・予想・目標の書き間違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        {'extra': 1},
        {'id': 'a~b'},
        {'version': 0},
        {'kind': 'balance'},
        {'params': <dynamic>[]},
        {
          'params': [
            {'name': 'a', 'min': 0, 'max': 1, 'step': 1, 'initial': 0},
            {'name': 'a', 'min': 0, 'max': 1, 'step': 1, 'initial': 0},
          ],
        },
        {'expr': 'a*x+z'},
        {'expr': 'a*x+'},
        {'expr': 'a*x'}, // b が使われていない
        {
          'goal': {'expr': 'a*x'},
        },
        {
          'goal': {'expr': '2x+'},
        },
        {
          'goal': {'expr': '2x', 'extra': 1},
        },
        {
          'predict': {
            'promptId': 'p',
            'choices': ['a'],
            'answer': 'a',
          },
        },
        {
          'predict': {
            'promptId': 'p',
            'choices': ['a', 'a'],
            'answer': 'a',
          },
        },
        {
          'predict': {
            'promptId': 'p',
            'choices': ['a', 'b'],
            'answer': 'c',
          },
        },
        {
          'predict': {
            'promptId': 'p',
            'choices': ['a', 'b'],
            'answer': 'a',
            'extra': 1,
          },
        },
        {'promptId': ''},
      ];
      for (final b in bad) {
        expect(() => ex(b), throwsFormatException, reason: b.toString());
      }
    });
    test('ExplorationSet: 版・形・id の重複', () {
      expect(() => ExplorationSet.parse('{'), throwsFormatException);
      expect(() => ExplorationSet.parse('[]'), throwsFormatException);
      expect(() => ExplorationSet.parse('{"version":2,"explorations":[]}'), throwsFormatException);
      expect(() => ExplorationSet.parse('{"version":1}'), throwsFormatException);
      expect(
        () => ExplorationSet.parse(
          jsonEncode({
            'version': 1,
            'explorations': [base(), base()],
          }),
        ),
        throwsFormatException,
      );
      expect(
        ExplorationSet.parse(
          jsonEncode({
            'version': 1,
            'explorations': [base()],
          }),
        ).explorations,
        hasLength(1),
      );
    });
  });

  group('検証 validateExplorations', () {
    List<String> codes(Map<String, dynamic> over) =>
        validateExplorations(ExplorationSet([ex(over)]), tree: tree).map((i) => i.code).toList();
    Map<String, dynamic> ok([Map<String, dynamic> o = const {}]) => {'unitId': 'm1_func_graph', ...o};

    test('正常', () => expect(codes(ok()), isEmpty));
    test('単元がない', () => expect(codes({}), contains('exploration_unit_missing')));
    test('目標が格子の上にない', () {
      expect(
        codes(
          ok({
            'goal': {'expr': '2.5*x+1'},
          }),
        ),
        contains('exploration_goal_unreachable'),
      );
    });
    test('最初から目標を満たす', () {
      expect(
        codes(
          ok({
            'goal': {'expr': '0*x'},
          }),
        ),
        contains('exploration_initial_is_goal'),
      );
    });
    test('格子が大きすぎて探索できない目標は届くか確かめられない', () {
      final big = {
        'params': [
          {'name': 'a', 'min': 0, 'max': 1000, 'step': 1, 'initial': 0},
          {'name': 'b', 'min': 0, 'max': 1000, 'step': 1, 'initial': 0},
        ],
        'goal': {'expr': '2*x+1'},
      };
      expect(codes(ok(big)), contains('exploration_goal_unreachable'));
    });
    test('目標のない教材は検証にかからない', () => expect(codes(ok({'goal': null})), isEmpty));
  });
}
