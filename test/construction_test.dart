import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

PlanePoint pt(double x, double y) => (x: x, y: y);

ConstructionSet sample() => ConstructionSet.parse(File('docs/samples/constructions.sample.json').readAsStringSync());

Map<String, dynamic> base([Map<String, dynamic> over = const {}]) => {
  'id': 'c1',
  'version': 1,
  'unitId': 'u',
  'promptId': 'p',
  'explanationId': 'e',
  'altId': 'a',
  'viewBox': [0, 0, 100, 100],
  'givens': {
    'A': [20, 50],
    'B': [80, 50],
  },
  'goal': {
    'kind': 'perpendicularBisector',
    'of': ['A', 'B'],
  },
  'solution': [
    {
      'circle': ['A', 'B'],
    },
    {
      'circle': ['B', 'A'],
    },
    {
      'intersect': ['c1', 'c2'],
    },
    {
      'line': ['X1', 'X2'],
    },
  ],
  ...over,
};

Construction cn([Map<String, dynamic> over = const {}]) => Construction.fromJson(base(over));

void main() {
  final tree = UnitTree.fromJson(
    jsonDecode(File('docs/content_drafts/suugaku_chu1/units.json').readAsStringSync()) as Map<String, dynamic>,
  );

  group('作図の道具（交点）', () {
    test('円と円: 2 点・接する 1 点・離れている・内側は交点なし', () {
      var s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0)});
      s.addCircle('A', 'B');
      s.addCircle('B', 'A');
      final ids = s.intersect('c1', 'c2');
      expect(ids, ['X1', 'X2']);
      expect(s.points['X1']!.x, closeTo(5, 1e-9));
      expect(s.points['X1']!.y.abs(), closeTo(math.sqrt(75), 1e-9));
      expect(s.points['X2']!.y, closeTo(-s.points['X1']!.y, 1e-9));

      s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0), 'C': pt(20, 0)});
      s.addCircle('A', 'B'); // 半径 10
      s.addCircle('C', 'B'); // 中心 20、半径 10 → 点 (10,0) で接する
      expect(s.intersect('c1', 'c2'), ['B']);

      s = ConstructionState({'A': pt(0, 0), 'B': pt(1, 0), 'C': pt(50, 0), 'D': pt(50, 5)});
      s.addCircle('A', 'B');
      s.addCircle('C', 'D');
      expect(s.intersect('c1', 'c2'), isEmpty); // 離れている

      s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0), 'C': pt(1, 0)});
      s.addCircle('A', 'B');
      s.addCircle('C', 'A'); // 中心 1、半径 1 → 大きい円の内側
      expect(s.intersect('c1', 'c2'), isEmpty);
    });
    test('コンパスを移す: 半径は 2 点の間の長さ', () {
      final s = ConstructionState({'A': pt(0, 0), 'B': pt(3, 4), 'C': pt(20, 0)});
      s.addCircle('C', 'A', 'B');
      expect(s.objects.single.r, closeTo(5, 1e-9));
      expect(s.objects.single.cx, 20);
    });
    test('同心円は交点なし', () {
      final s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0), 'C': pt(0, 20)});
      s.addCircle('A', 'B');
      s.addCircle('A', 'C');
      expect(s.intersect('c1', 'c2'), isEmpty);
    });
    test('直線と円: 2 点・接する 1 点・離れている', () {
      final s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0), 'C': pt(5, 3), 'D': pt(5, 10), 'E': pt(5, 4)});
      s.addLine('A', 'B'); // y = 0
      s.addCircle('C', 'E'); // 中心 (5,3)、半径 1
      expect(s.intersect('l1', 'c1'), isEmpty); // 距離 3 > 1
      s.addCircle('C', 'A', 'C'); // 半径 |AC|=√34
      final two = s.intersect('l1', 'c2');
      expect(two.length, 2);
      expect(s.points[two[0]]!.y.abs(), closeTo(0, 1e-9));
      final t = ConstructionState({'C': pt(5, 3), 'A': pt(0, 0), 'B': pt(10, 0), 'D': pt(5, 0)});
      t.addLine('A', 'B');
      t.addCircle('C', 'D'); // 半径 3 → y=0 に接する
      expect(t.intersect('l1', 'c1'), ['D']); // 接点は (5,0)＝D
    });
    test('直線と直線: 1 点・平行は交点なし', () {
      final s = ConstructionState({
        'A': pt(0, 0),
        'B': pt(10, 0),
        'C': pt(5, -5),
        'D': pt(5, 5),
        'E': pt(0, 3),
        'F': pt(10, 3),
      });
      s.addLine('A', 'B');
      s.addLine('C', 'D');
      s.addLine('E', 'F');
      final ids = s.intersect('l1', 'l2');
      expect(ids.length, 1);
      expect(s.points[ids.single]!.x, closeTo(5, 1e-9));
      expect(s.points[ids.single]!.y, closeTo(0, 1e-9));
      expect(s.intersect('l1', 'l3'), isEmpty); // 平行
    });
    test('交点の ID は新しい点にだけ順に付き、同じ位置の点は使い回す', () {
      final s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0)});
      s.addCircle('A', 'B');
      s.addCircle('B', 'A');
      expect(s.intersect('c1', 'c2'), ['X1', 'X2']);
      expect(s.intersect('c1', 'c2'), ['X1', 'X2']); // もう一度求めても同じ点
      s.addLine('A', 'B');
      expect(s.intersect('c1', 'l1'), ['B', 'X3']); // B はすでにある。もう 1 つは新しい点
      expect(s.points.keys.toList(), ['A', 'B', 'X1', 'X2', 'X3']);
    });
    test('不正な操作は ArgumentError（点・図形がない、同じ位置の 2 点、半径 0、同じ図形どうし）', () {
      final s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0), 'C': pt(0, 0)});
      expect(() => s.addCircle('A', 'Z'), throwsArgumentError);
      expect(() => s.addCircle('Z', 'A'), throwsArgumentError);
      expect(() => s.addCircle('A', 'C'), throwsArgumentError); // 半径 0
      expect(() => s.addCircle('A', 'B', 'C'), returnsNormally);
      expect(() => s.addLine('A', 'C'), throwsArgumentError); // 同じ位置
      expect(() => s.addLine('A', 'Z'), throwsArgumentError);
      expect(() => s.intersect('c1', 'c1'), throwsArgumentError);
      expect(() => s.intersect('c1', 'l9'), throwsArgumentError);
    });
    test('手順の数・作った図形・点の一覧', () {
      final s = ConstructionState({'A': pt(0, 0), 'B': pt(10, 0)});
      expect(s.steps, 0);
      s.addCircle('A', 'B');
      s.addCircle('B', 'A');
      s.intersect('c1', 'c2');
      s.addLine('X1', 'X2');
      expect(s.steps, 4);
      expect(s.objects.map((o) => o.id), ['c1', 'c2', 'l1']);
      expect(s.objects.where((o) => o.isLine).single.p, 'X1');
      expect(s.points.length, 4);
      expect(() => s.points['Z'] = pt(0, 0), throwsUnsupportedError);
      expect(() => s.objects.clear(), throwsUnsupportedError);
    });
  });

  group('直線を枠で切る clipLine', () {
    const box = [0.0, 0.0, 100.0, 100.0];
    test('斜め・水平・垂直。枠の外の水平・垂直は null', () {
      final d = ConstructionState.clipLine(pt(50, 50), pt(60, 60), box)!;
      expect(d.$1, pt(0, 0));
      expect(d.$2, pt(100, 100));
      final h = ConstructionState.clipLine(pt(30, 40), pt(60, 40), box)!;
      expect(h.$1, pt(0, 40));
      expect(h.$2, pt(100, 40));
      final v = ConstructionState.clipLine(pt(70, 10), pt(70, 20), box)!;
      expect(v.$1, pt(70, 0));
      expect(v.$2, pt(70, 100));
      expect(ConstructionState.clipLine(pt(150, 0), pt(150, 100), box), isNull);
      expect(ConstructionState.clipLine(pt(0, 150), pt(100, 150), box), isNull);
      expect(ConstructionState.clipLine(pt(-50, 0), pt(-50, 100), box), isNull);
    });
    test('枠をかすめる斜めの線・枠から離れた斜めの線', () {
      final c = ConstructionState.clipLine(pt(-10, 95), pt(10, 115), box);
      expect(c, isNull); // 角の外を通る（y = x + 105）
      final e = ConstructionState.clipLine(pt(-10, 110), pt(110, -10), box)!;
      expect(e.$1.x, closeTo(0, 1e-9)); // 右上がりの線が枠の左端と上端で切れる
    });
    test('枠が原点でないとき', () {
      final c = ConstructionState.clipLine(pt(30, 30), pt(40, 30), const [20.0, 10.0, 50.0, 40.0])!;
      expect(c.$1, pt(20, 30));
      expect(c.$2, pt(70, 30));
    });
  });

  group('サンプルの作図教材', () {
    test('検証エラーなし。模範の手順が目標を達成し、手順の数が上限以内', () {
      final set = sample();
      expect(set.constructions.length, 4);
      expect(validateConstructions(set, tree: tree), isEmpty);
      for (final c in set.constructions) {
        final s = c.replay(c.solution);
        expect(c.isSolved(s), isTrue, reason: c.id);
        expect(s.steps, lessThanOrEqualTo(c.maxSteps), reason: c.id);
      }
    });
    test('途中では達成にならず、手順の最後の直線で達成する', () {
      for (final c in sample().constructions) {
        final all = c.solution;
        expect(c.isSolved(c.replay(all.sublist(0, all.length - 1))), isFalse, reason: c.id);
        expect(c.isSolved(c.replay(all)), isTrue, reason: c.id);
      }
    });
    test('目標以外の直線は達成にならない（垂直二等分線の問題で線分 AB 自身・AB に平行な線・片方の点を通る垂線）', () {
      final c = sample().constructions.first; // A(25,65) B(75,40)
      var s = c.start()..addLine('A', 'B');
      expect(c.isSolved(s), isFalse);
      // 中点を通るが垂直でない線: 中点と、AB 上にない点を通る直線 → X1,X2 を使う線以外
      s = c.start()
        ..addCircle('A', 'B')
        ..addCircle('B', 'A')
        ..intersect('c1', 'c2')
        ..addLine('A', 'X1');
      expect(c.isSolved(s), isFalse); // 目標の直線ではない
      s = c.start()
        ..addCircle('A', 'B')
        ..addCircle('B', 'A')
        ..intersect('c1', 'c2')
        ..addLine('X2', 'X1');
      expect(c.isSolved(s), isTrue); // 向きが逆でも同じ直線
    });
    test('目標に平行でも、重ならない直線は達成にならない', () {
      final c = cn({
        'givens': {
          'A': [20, 50],
          'B': [80, 50],
          'C': [20, 20],
          'D': [20, 80],
        }, // C-D は垂直だが x=20（目標は x=50）
      });
      final s = c.start()..addLine('C', 'D');
      expect(c.isSolved(s), isFalse);
      final ok = c.replay(c.solution);
      expect(c.isSolved(ok), isTrue);
    });
    test('どの目標も、通る点が合っていても垂直・二等分でなければ達成にならない', () {
      final set = sample();
      final perp = set.constructions[2]; // P(60,25) から AB への垂線
      var s = perp.start()..addLine('P', 'A');
      expect(perp.isSolved(s), isFalse);
      s = perp.start()..addLine('P', 'B');
      expect(perp.isSolved(s), isFalse);
      final bis = set.constructions[1]; // ∠AOB の二等分線
      s = bis.start()..addLine('O', 'A');
      expect(bis.isSolved(s), isFalse);
      s = bis.start()..addLine('O', 'B');
      expect(bis.isSolved(s), isFalse);
    });
    test('途中経過の図: 見せる図形・作った直線（枠で切る）・円・点とその名前', () {
      final c = sample().constructions.first;
      final s = c.replay(c.solution);
      final f = c.figure(s);
      expect(f.altId, 'fig_ct_perp_bisector');
      expect(f.labels.map((l) => l.text), ['A', 'B', 'X1', 'X2']);
      final kinds = f.shapes.map((x) => x.kind).toList();
      expect(kinds.where((k) => k == FigureShapeKind.circle).length, 2 + 4); // 円 2 + 点 4（小さい円）
      final svg = f.toSvg();
      expect(svg, startsWith('<svg'));
      expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse);
      // 直線は枠 [0,100]² の中に切り取られている
      for (final sh in f.shapes.where((x) => x.kind == FigureShapeKind.seg)) {
        for (final p in sh.points) {
          expect(p.x, inInclusiveRange(-1e-9, 100 + 1e-9));
          expect(p.y, inInclusiveRange(-1e-9, 100 + 1e-9));
        }
      }
    });
    test('見せる図形: 線分・直線・半直線', () {
      final line = sample().constructions[2].shownShapes().single; // 直線 AB（枠の端まで）
      expect(line.points[0].x, closeTo(0, 1e-9));
      expect(line.points[1].x, closeTo(100, 1e-9));
      final rays = sample().constructions[1].shownShapes(); // 半直線 OA・OB（O から枠の端まで）
      expect(rays.length, 2);
      for (final r in rays) {
        expect(r.points[0], pt(15, 75));
      }
      expect(rays[0].points[1].x, closeTo(100, 1e-9)); // O→A は右へ
      final seg = sample().constructions.first.shownShapes().single; // 線分 AB はそのまま
      expect(seg.points, [pt(25, 65), pt(75, 40)]);
    });
  });

  group('読み込み', () {
    test('書き間違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        {'extra': 1},
        {'id': 'a~b'},
        {'version': 0},
        {'promptId': ''},
        {
          'viewBox': [0, 0, 100],
        },
        {
          'viewBox': [0, 0, 0, 100],
        },
        {
          'givens': {
            'A': [20, 50],
          },
        },
        {
          'givens': {
            'A': [20, 50],
            'b': [80, 50],
          },
        }, // 小文字の名前
        {
          'givens': {
            'A': [20, 50],
            'X1': [80, 50],
          },
        }, // 交点と同じ名前
        {
          'givens': {
            'A': [20, 50],
            'B': [80],
          },
        },
        {
          'givens': {
            'A': [20, 50],
            'B': [200, 50],
          },
        }, // 枠の外
        {
          'givens': {
            'A': [20, 50],
            'B': [20, 50],
          },
        }, // 重なり
        {
          'show': [
            {
              'seg': ['A', 'Z'],
            },
          ],
        },
        {
          'show': [
            {
              'circle': ['A', 'B'],
            },
          ],
        },
        {
          'show': [
            {
              'seg': ['A'],
            },
          ],
        },
        {
          'show': [
            {
              'seg': ['A', 'B'],
              'line': ['A', 'B'],
            },
          ],
        },
        {
          'goal': {'kind': 'bisector'},
        },
        {
          'goal': {
            'kind': 'perpendicularBisector',
            'of': ['A', 'Z'],
          },
        },
        {
          'goal': {
            'kind': 'perpendicularBisector',
            'of': ['A'],
          },
        },
        {
          'goal': {
            'kind': 'perpendicularBisector',
            'of': ['A', 'B'],
            'extra': 1,
          },
        },
        {
          'goal': {
            'kind': 'angleBisector',
            'of': ['A', 'B'],
          },
        },
        {
          'goal': {
            'kind': 'perpendicular',
            'through': 'Z',
            'to': ['A', 'B'],
          },
        },
        {'goal': 'x'},
        {
          'solution': [
            {
              'arc': ['A', 'B'],
            },
          ],
        },
        {
          'solution': [
            {
              'circle': ['A'],
            },
          ],
        },
        {
          'solution': [
            {
              'line': ['A', 'B', 'C'],
            },
          ],
        },
        {
          'solution': [
            {
              'circle': ['A', ''],
            },
          ],
        },
        {
          'solution': [
            {
              'line': ['A', 'B'],
              'circle': ['A', 'B'],
            },
          ],
        },
        {'maxSteps': 0},
        {'maxSteps': 99},
        {'maxSteps': '5'},
      ];
      for (final b in bad) {
        expect(() => cn(b), throwsFormatException, reason: b.toString());
      }
    });
    test('正常: 目標の 3 種類、show の 3 種類', () {
      final c = cn({
        'givens': {
          'A': [20, 50],
          'B': [80, 50],
          'C': [50, 20],
        },
        'show': [
          {
            'seg': ['A', 'B'],
          },
          {
            'line': ['A', 'C'],
          },
          {
            'ray': ['B', 'C'],
          },
        ],
        'goal': {
          'kind': 'angleBisector',
          'of': ['A', 'C', 'B'],
        },
      });
      expect(c.show.map((s) => s.kind), ['seg', 'line', 'ray']);
      expect(
        cn({
          'goal': {
            'kind': 'perpendicular',
            'through': 'A',
            'to': ['A', 'B'],
          },
        }).goal,
        isA<PerpendicularGoal>(),
      );
      expect(cn().maxSteps, 10);
    });
    test('ConstructionSet: 版・形・id の重複', () {
      expect(() => ConstructionSet.parse('{'), throwsFormatException);
      expect(() => ConstructionSet.parse('[]'), throwsFormatException);
      expect(() => ConstructionSet.parse('{"version":2,"constructions":[]}'), throwsFormatException);
      expect(() => ConstructionSet.parse('{"version":1}'), throwsFormatException);
      expect(
        () => ConstructionSet.parse(
          jsonEncode({
            'version': 1,
            'constructions': [base(), base()],
          }),
        ),
        throwsFormatException,
      );
      expect(
        ConstructionSet.parse(
          jsonEncode({
            'version': 1,
            'constructions': [base()],
          }),
        ).constructions,
        hasLength(1),
      );
    });
  });

  group('検証 validateConstructions', () {
    List<String> codes(Map<String, dynamic> over) =>
        validateConstructions(ConstructionSet([cn(over)]), tree: tree).map((i) => i.code).toList();
    Map<String, dynamic> ok([Map<String, dynamic> o = const {}]) => {'unitId': 'm1_geo_basic', ...o};

    test('正常', () => expect(codes(ok()), isEmpty));
    test('単元がない', () => expect(codes({}), contains('construction_unit_missing')));
    test('模範の手順がない', () => expect(codes(ok({'solution': <dynamic>[]})), contains('construction_solution_missing')));
    test('模範の手順が成り立たない（点がない・交点の名前が違う）', () {
      expect(
        codes(
          ok({
            'solution': [
              {
                'line': ['A', 'Z'],
              },
            ],
          }),
        ),
        contains('construction_solution_fails'),
      );
      expect(
        codes(
          ok({
            'solution': [
              {
                'circle': ['A', 'B'],
              },
              {
                'line': ['A', 'X5'],
              },
            ],
          }),
        ),
        contains('construction_solution_fails'),
      );
    });
    test('模範の手順が目標を達成しない', () {
      expect(
        codes(
          ok({
            'solution': [
              {
                'line': ['A', 'B'],
              },
            ],
          }),
        ),
        contains('construction_solution_fails'),
      );
    });
    test('模範の手順が maxSteps を超える', () {
      expect(codes(ok({'maxSteps': 3})), contains('construction_solution_too_long'));
      expect(codes(ok({'maxSteps': 4})), isEmpty);
    });
  });
}
