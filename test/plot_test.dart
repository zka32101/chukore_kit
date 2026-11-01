import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> pl(Map<String, dynamic> plot, {String altId = 'fig_graph'}) => {'plot': plot, 'altId': altId};

Map<String, dynamic> base({Object x = const [-3, 3], Object y = const [-1, 10], List? curves, Map<String, dynamic> extra = const {}}) => {
      'x': x,
      'y': y,
      'curves': curves ?? [{'expr': 'x^2'}],
      ...extra,
    };

FigureTemplate ft(Map<String, dynamic> j) => FigureTemplate.fromJson(j, {'a', 'b', 'k'});

Figure? make(Map<String, dynamic> plot, [Map<String, double> v = const {}]) =>
    ft(pl(plot)).resolve(v, (s) => renderTemplateString(s, v));

List<FigureShape> shapes(Figure f, FigureShapeKind k) => f.shapes.where((s) => s.kind == k).toList();

Matcher bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

void main() {
  group('読み込み', () {
    test('正常。他のキーと併用できない・altId が要る', () {
      expect(ft(pl(base())).altId, 'fig_graph');
      expect(ft(pl(base())).viewBox, [0.0, 0.0, 100.0, 100.0]);
      expect(() => ft({...pl(base()), 'points': {}}), bad('併用'));
      expect(() => ft({...pl(base()), 'viewBox': [0, 0, 1, 1]}), bad('併用'));
      expect(() => ft({'plot': base()}), bad('altId'));
      expect(() => ft({'plot': base(), 'altId': ''}), bad('altId'));
      expect(() => ft({'plot': 5, 'altId': 'a'}), bad('オブジェクト'));
    });

    test('書き間違い', () {
      final cases = <String, Map<String, dynamic>>{
        '未知のキー': {...base(), 'zzz': 1},
        '最小': base(x: [1]),
        '最小 ': base(y: 'a'),
        '数か式': base(x: [{}, 3]),
        '1〜4': base(curves: []),
        '1〜4 ': base(curves: [for (var i = 0; i < 5; i++) {'expr': 'x'}]),
        '曲線は': base(curves: [{'expr': 'x', 'zzz': 1}]),
        '曲線は ': base(curves: [5]),
        '式が読めません': base(curves: [{'expr': '1+'}]),
        '式が読めません ': base(curves: [{'expr': 5}]),
        'パラメータにない': base(curves: [{'expr': 'z*x'}]),
        'dashed': base(curves: [{'expr': 'x', 'dashed': 'yes'}]),
        '8 個まで': base(extra: {'points': [for (var i = 0; i < 9; i++) {'at': [0, 0]}]}),
        '点は': base(extra: {'points': [{'at': [0, 0], 'zzz': 1}]}),
        '点は ': base(extra: {'points': [5]}),
        'at は': base(extra: {'points': [{'at': [0]}]}),
        'at は ': base(extra: {'points': [{'at': [0, 0, 0]}]}),
        '最大': base(x: [-3, 3, 5]),
        '点の座標': base(extra: {'points': [{'at': [0, 'zz']}]}),
        'label': base(extra: {'points': [{'at': [0, 0], 'label': 5}]}),
        'ticks は': base(extra: {'ticks': {'z': 1}}),
        'ticks は ': base(extra: {'ticks': 5}),
        'ticks.x': base(extra: {'ticks': {'x': 0}}),
        'ticks.y': base(extra: {'ticks': {'y': -1}}),
        'ticks.x ': base(extra: {'ticks': {'x': 'a'}}),
      };
      for (final e in cases.entries) {
        expect(() => ft(pl(e.value)), bad(e.key.trim()), reason: e.key);
      }
    });
  });

  group('図形', () {
    test('軸: x 軸・y 軸（0 を通る）とラベル O・x・y', () {
      final f = make(base())!;
      final segs = shapes(f, FigureShapeKind.seg);
      expect(segs.length, 2);
      // x の範囲 -3〜3 → 10〜90（0 は 50）、y の範囲 -1〜10 → 90〜10（0 は 90 − 80/11）
      final y0 = 90 - 80 / 11;
      expect([segs[0].points[0].x, segs[0].points[0].y, segs[0].points[1].x, segs[0].points[1].y], [10, closeTo(y0, 1e-9), 90, closeTo(y0, 1e-9)]);
      expect([segs[1].points[0].x, segs[1].points[0].y, segs[1].points[1].x, segs[1].points[1].y], [50, 90, 50, 10]);
      expect(f.labels.map((l) => l.text), containsAll(['O', 'x', 'y']));
    });

    test('曲線 y = x²: 81 点の折れ線 1 本。頂点は原点、左右対称', () {
      final f = make(base())!;
      final c = shapes(f, FigureShapeKind.polyline);
      expect(c.length, 1);
      final pts = c.single.points;
      expect(pts.length, 81); // 80 分割
      final y0 = 90 - 80 / 11;
      expect(pts[40].x, closeTo(50, 1e-9));
      expect(pts[40].y, closeTo(y0, 1e-9));
      for (var i = 0; i <= 40; i++) {
        expect(pts[i].x + pts[80 - i].x, closeTo(100, 1e-9));
        expect(pts[i].y, closeTo(pts[80 - i].y, 1e-9));
      }
      expect(pts.first.y < y0, isTrue); // x=-3 は y=9 で上
      expect(pts.first.y, closeTo(90 - 10 / 11 * 80, 1e-9)); // y=9 → 90 − (9+1)/11·80
    });

    test('パラメータ: y = a x²。a が大きいほど細い', () {
      final wide = make(base(curves: [{'expr': 'a*x^2'}], y: [-1, 20]), {'a': 1})!;
      final narrow = make(base(curves: [{'expr': 'a*x^2'}], y: [-1, 20]), {'a': 2})!;
      double top(Figure f) => shapes(f, FigureShapeKind.polyline).single.points.first.y;
      expect(top(narrow) < top(wide), isTrue);
    });

    test('y の範囲で切り取る: 範囲の外は描かず、切り口は枠の端（10）にそろう', () {
      final f = make(base(y: [-1, 5]))!;
      final c = shapes(f, FigureShapeKind.polyline);
      expect(c.length, 1);
      final pts = c.single.points;
      expect(pts.first.y, closeTo(10, 1e-9));
      expect(pts.last.y, closeTo(10, 1e-9));
      for (final p in pts) {
        expect(p.y, inInclusiveRange(10 - 1e-9, 90 + 1e-9));
      }
      // 左の切り口 x = -√5 の位置
      expect(pts.first.x, closeTo(50 - 40 * 2.2360679775 / 3, 0.6));
    });

    test('範囲を完全に外れる曲線は描かない。範囲の中だけ通るなら 1 本', () {
      expect(shapes(make(base(curves: [{'expr': 'x^2+20'}]))!, FigureShapeKind.polyline), isEmpty);
      expect(shapes(make(base(curves: [{'expr': 'x^2-20'}]))!, FigureShapeKind.polyline), isEmpty);
    });

    test('計算できない点で途切れる: y = 1/x は左右 2 本', () {
      final f = make(base(curves: [{'expr': '1/x'}], x: [-2, 2], y: [-5, 5]))!;
      final c = shapes(f, FigureShapeKind.polyline);
      expect(c.length, 2);
      expect(c[0].points.last.x < 50 && c[1].points.first.x > 50, isTrue);
    });

    test('破線・複数の曲線', () {
      final f = make(base(curves: [{'expr': 'x^2'}, {'expr': 'x+3', 'dashed': true}]))!;
      final c = shapes(f, FigureShapeKind.polyline);
      expect(c.map((s) => s.dashed), [false, true]);
    });

    test('点: 円とラベル（{…} を入れる）。範囲の外・計算できない点は描けない（null）', () {
      final f = make(base(extra: {'points': [{'at': [2, 'a*4'], 'label': 'A({a}, 4)'}]}), {'a': 1})!;
      expect(shapes(f, FigureShapeKind.circle).length, 1);
      expect(shapes(f, FigureShapeKind.circle).single.r, 1.3);
      expect(f.labels.map((l) => l.text), contains('A(1, 4)'));
      // ラベルは点の右下（x が負なら左下）
      final c = shapes(f, FigureShapeKind.circle).single.points.single;
      final lab = f.labels.firstWhere((l) => l.text == 'A(1, 4)');
      expect([lab.x - c.x, lab.y - c.y], [14, 4]);
      final left = make(base(extra: {'points': [{'at': [-2, 4], 'label': 'B'}]}))!;
      expect(left.labels.firstWhere((l) => l.text == 'B').x - shapes(left, FigureShapeKind.circle).single.points.single.x, -14);
      expect(make(base(extra: {'points': [{'at': [5, 0]}]})), isNull); // x が範囲の外
      expect(make(base(extra: {'points': [{'at': [0, 20]}]})), isNull); // y が範囲の外
      expect(make(base(extra: {'points': [{'at': [-3, -1]}]})), isNotNull); // 範囲の端はよい
      expect(make(base(extra: {'points': [{'at': [0, '1/0']}]})), isNull);
    });

    test('目盛り: 間隔ごとに短い線と数字（0 は除く）', () {
      final f = make(base(extra: {'ticks': {'x': 1, 'y': 5}}))!;
      final texts = f.labels.map((l) => l.text).toList();
      expect(texts, containsAll(['-3', '-2', '-1', '1', '2', '3', '5', '10']));
      expect(texts.where((t) => t == '0'), isEmpty);
      // 軸 2 本 + x の目盛り 6 + y の目盛り 2
      expect(shapes(f, FigureShapeKind.seg).length, 2 + 6 + 2);
      expect(make(base(extra: {'ticks': {'x': 0.5}}))!.labels.map((l) => l.text), contains('0.5'));
    });

    test('目盛りの間隔: 範囲の 48 倍（= 12 本の 4 倍）までは図を描く（目盛りは省く）、それより細かいと描けない', () {
      // x の範囲 6: 間隔 0.125 → 48 倍（ちょうど）→ 図は描く。0.05 → 120 倍 → null
      expect(make(base(extra: {'ticks': {'x': 0.125}})), isNotNull);
      expect(make(base(extra: {'ticks': {'x': 0.05}})), isNull);
      // y の範囲 11
      expect(make(base(extra: {'ticks': {'y': 0.25}})), isNotNull); // 44 倍
      expect(make(base(extra: {'ticks': {'y': 0.2}})), isNull); // 55 倍
    });

    test('無限大になる点も途切れる（x^1000 は |x|>1 で無限大）', () {
      final f = make(base(curves: [{'expr': 'x^1000'}]))!;
      final c = shapes(f, FigureShapeKind.polyline);
      expect(c.length, 1);
      for (final p in c.single.points) {
        expect(p.x.isFinite && p.y.isFinite, isTrue);
        expect(p.x, inInclusiveRange(10, 90));
      }
      expect(f.toSvg().contains('NaN') || f.toSvg().contains('Infinity'), isFalse);
    });

    test('範囲の外へ出て すぐ戻る曲線は 2 本に分かれる（1 本につながない）', () {
      // y = 6 − 600x²: x=0 だけ y=6 で範囲（-1〜5）の外。x=±0.1 は 0 で範囲の中、それ以外は下に外れる
      final f = make(base(x: [-3, 3], y: [-1, 5], curves: [{'expr': '6-600*x^2'}]))!;
      final c = shapes(f, FigureShapeKind.polyline);
      expect(c.length, 2);
      expect(c[0].points.last.x < 50 && c[1].points.first.x > 50, isTrue);
      for (final s in c) {
        expect(s.points.length, greaterThanOrEqualTo(2));
      }
    });

    test('目盛りが多すぎると目盛りは省く。細かすぎるなら描けない（null）', () {
      // x: 範囲 6、間隔 0.4 → 15 本（13 を超える）→ 目盛りなし。間隔 0.01 → 600 本 → null
      final f = make(base(extra: {'ticks': {'x': 0.4}}))!;
      expect(shapes(f, FigureShapeKind.seg).length, 2);
      expect(make(base(extra: {'ticks': {'x': 0.01}})), isNull);
      expect(make(base(extra: {'ticks': {'y': 0.01}})), isNull);
    });

    test('範囲が 0 を含まない・逆・同じ・数でない値は描けない（null）', () {
      expect(make(base(x: [1, 3])), isNull);
      expect(make(base(x: [-3, -1])), isNull);
      expect(make(base(y: [1, 5])), isNull);
      expect(make(base(y: [-5, -1])), isNull);
      expect(make(base(x: [3, -3])), isNull);
      expect(make(base(y: [0, 0])), isNull);
      expect(make(base(x: [0, 3])), isNotNull); // 0 が端でもよい
      expect(make(base(y: [-4, 0])), isNotNull);
      expect(make(base(x: ['1/0', 3])), isNull);
      expect(make(base(x: ['a', 3]), {'a': -2}), isNotNull);
    });

    test('枠（0〜100）に収まる', () {
      for (final plot in [base(), base(y: [-1, 5]), base(curves: [{'expr': 'x^3'}], y: [-30, 30]), base(extra: {'ticks': {'x': 1, 'y': 1}})]) {
        final f = make(plot)!;
        for (final s in f.shapes) {
          for (final p in s.points) {
            expect(p.x, inInclusiveRange(-0.01, 100.01));
            expect(p.y, inInclusiveRange(-0.01, 100.01));
          }
        }
        for (final l in f.labels) {
          expect(l.x, inInclusiveRange(-8, 108));
          expect(l.y, inInclusiveRange(-8, 108));
        }
      }
    });
  });

  group('SVG と型', () {
    test('SVG: 曲線は polyline（破線は stroke-dasharray）', () {
      final svg = make(base(curves: [{'expr': 'x^2'}, {'expr': 'x', 'dashed': true}]))!.toSvg();
      expect(svg.contains('<polyline points="'), isTrue);
      expect('<polyline'.allMatches(svg).length, 2);
      expect(svg.contains('stroke-dasharray="3 2"/>'), isTrue);
      expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse);
      expect(svg.contains('currentColor'), isTrue);
    });

    test('型に組み込む: パラメータで図が変わる。毎回描けなければ StateError', () {
      Map<String, dynamic> tpl(Map<String, dynamic> plot) => {
            'id': 'plot_t',
            'templateVersion': 1,
            'unitId': 'u',
            'type': 'expr',
            'difficulty': 0.5,
            'params': {
              'a': {'int': [1, 3]},
            },
            'figure': pl(plot),
            'display': {'a': '{a}'},
            'answer': '{a}',
            'wrong': [
              {'expr': '{a+1}', 'tag': 't1'},
            ],
            'explanationId': 'e',
          };
      final t = MathTemplate.fromJson(tpl(base(curves: [{'expr': 'a*x^2'}], y: [-1, 30])));
      final tops = {for (var s = 1; s <= 12; s++) t.generate(s).figure!.shapes.where((x) => x.kind == FigureShapeKind.polyline).single.points.first.y};
      expect(tops.length, greaterThan(1));
      final never = MathTemplate.fromJson(tpl(base(x: [1, 3])));
      expect(() => never.generate(1), throwsStateError);
    });
  });
}
