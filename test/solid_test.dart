import 'dart:math' as math;

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sol(String kind, Map<String, Object> dims, {String? view, Map<String, String>? labels}) => {
  'solid': {'kind': kind, 'view': ?view, 'dims': dims, 'labels': ?labels},
  'altId': 'fig_x',
};

FigureTemplate ft(Map<String, dynamic> j) => FigureTemplate.fromJson(j, {'r', 'h', 'a', 'b', 'c', 'l'});

Figure? make(String kind, Map<String, double> v, {String? view, Map<String, String>? labels}) {
  final dims = {for (final e in v.entries) e.key: e.key as Object};
  return ft(sol(kind, dims, view: view, labels: labels)).resolve(v, (s) => renderTemplateString(s, v));
}

/// 図形が枠（0〜100）に収まっているか。円・楕円は半径ぶん、弧は弧の上の点で調べる。
void expectInside(Figure f, {String reason = ''}) {
  void pt(double x, double y) {
    expect(x, inInclusiveRange(-0.01, 100.01), reason: reason);
    expect(y, inInclusiveRange(-0.01, 100.01), reason: reason);
  }

  for (final s in f.shapes) {
    final c = s.points.first;
    switch (s.kind) {
      case FigureShapeKind.circle:
        pt(c.x - s.r, c.y - s.r);
        pt(c.x + s.r, c.y + s.r);
      case FigureShapeKind.ellipse || FigureShapeKind.ellipseHalf:
        pt(c.x - s.r, c.y - s.ry);
        pt(c.x + s.r, c.y + s.ry);
      case FigureShapeKind.arc:
        for (var i = 0; i <= 40; i++) {
          final t = (s.start + (s.end - s.start) * i / 40) * math.pi / 180;
          pt(c.x + s.r * math.cos(t), c.y - s.r * math.sin(t));
        }
      default:
        for (final p in s.points) {
          pt(p.x, p.y);
        }
    }
  }
  for (final l in f.labels) {
    expect(l.x, inInclusiveRange(-8, 108), reason: reason);
    expect(l.y, inInclusiveRange(-8, 108), reason: reason);
  }
}

void main() {
  group('読み込み', () {
    test('正常: 立体と展開図', () {
      expect(ft(sol('cylinder', {'r': 'r', 'h': 'h'})).altId, 'fig_x');
      expect(ft(sol('cube', {'a': 'a'}, view: 'net')).viewBox, [0.0, 0.0, 100.0, 100.0]);
    });
    test('書き間違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        sol('cube', {'a': 'a'}), // 立体の cube はない（cuboid）
        sol('cuboid', {'a': 'a', 'b': 'b'}),
        sol('cuboid', {'a': 'a', 'b': 'b', 'c': 'c', 'd': 'a'}),
        sol('cylinder', {'r': 'r', 'h': 'z'}),
        sol('cylinder', {'r': 'r', 'h': 'h+'}),
        sol('cylinder', {'r': 'r', 'h': true}),
        sol('sphere', {'r': 'r'}, view: 'net'),
        sol('cylinder', {'r': 'r', 'h': 'h'}, labels: {'q': 'x'}),
        sol('cone', {'r': 'r', 'h': 'h'}, labels: {'w': 'x'}), // w は円柱の展開図だけ
        {
          'solid': {
            'kind': 'cylinder',
            'dims': {'r': 'r', 'h': 'h'},
            'extra': 1,
          },
          'altId': 'a',
        },
        {
          'solid': {
            'kind': 'cylinder',
            'dims': {'r': 'r', 'h': 'h'},
          },
        },
        {
          ...sol('cylinder', {'r': 'r', 'h': 'h'}),
          'points': {
            'A': [1, 2],
          },
        },
        {
          ...sol('cylinder', {'r': 'r', 'h': 'h'}),
          'viewBox': [0, 0, 100, 100],
        },
        {'solid': 'cylinder', 'altId': 'a'},
        {
          'solid': {
            'kind': 'cylinder',
            'dims': {'r': 'r', 'h': 'h'},
            'labels': {'r': 5},
          },
          'altId': 'a',
        },
      ];
      for (final b in bad) {
        expect(() => ft(b), throwsFormatException, reason: b.toString());
      }
    });
  });

  group('図形', () {
    test('寸法が正でなければ描けない（null）', () {
      expect(make('cylinder', {'r': 0, 'h': 5}), isNull);
      expect(make('cylinder', {'r': 3, 'h': -1}), isNull);
      expect(make('cylinder', {'r': 3, 'h': double.nan}), isNull);
      expect(make('cylinder', {'r': 3, 'h': double.infinity}), isNull);
    });

    test('円柱: 上の楕円・下の半楕円 2 つ（手前は実線、奥は破線）・縦の 2 本・半径の破線・ラベル', () {
      final f = make('cylinder', {'r': 3, 'h': 5}, labels: {'r': '{r}cm', 'h': '{h}cm'})!;
      expect(f.shapes.map((s) => s.kind), [
        FigureShapeKind.ellipse,
        FigureShapeKind.ellipseHalf,
        FigureShapeKind.ellipseHalf,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
      ]);
      expect(f.shapes[1].dashed, isFalse);
      expect(f.shapes[1].upper, isFalse); // 手前（下側）
      expect(f.shapes[2].dashed, isTrue);
      expect(f.shapes[2].upper, isTrue); // 奥（上側）
      expect(f.shapes[5].dashed, isTrue); // 半径
      expect(f.labels.map((l) => l.text), ['3cm', '5cm']);
      // 楕円の縦横比 0.3、図は枠の中央
      expect(f.shapes[0].ry, closeTo(0.3 * f.shapes[0].r, 1e-9));
      expect(f.shapes[0].points.single.x, 50);
      expectInside(f);
    });
    test('寸法の比が保たれる: 円柱の高さ ÷ 半径', () {
      final f = make('cylinder', {'r': 2, 'h': 6})!;
      final rx = f.shapes[0].r;
      final top = f.shapes[0].points.single.y, bot = f.shapes[1].points.single.y;
      expect((bot - top) / rx, closeTo(3, 1e-9));
    });
    test('円錐: 頂点から底面の左右へ 2 本、軸と半径は破線、底面の楕円の手前だけ実線', () {
      final f = make('cone', {'r': 3, 'h': 4}, labels: {'r': '3', 'h': '4'})!;
      expect(f.shapes.map((s) => s.kind).toList(), [
        FigureShapeKind.ellipseHalf,
        FigureShapeKind.ellipseHalf,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
      ]);
      expect(f.shapes[2].dashed, isFalse);
      expect(f.shapes[4].dashed, isTrue);
      expect(f.shapes[5].dashed, isTrue);
      final apex = f.shapes[2].points[0];
      expect(f.shapes[3].points[0], apex); // 2 本の線は同じ頂点から
      expect(apex.x, 50);
      expectInside(f);
    });
    test('球: 円・赤道の楕円（手前実線・奥破線）・半径', () {
      final f = make('sphere', {'r': 7}, labels: {'r': '7cm'})!;
      expect(f.shapes.map((s) => s.kind).toList(), [
        FigureShapeKind.circle,
        FigureShapeKind.ellipseHalf,
        FigureShapeKind.ellipseHalf,
        FigureShapeKind.seg,
      ]);
      expect(f.shapes[0].r, 36);
      expect(f.labels.single.text, '7cm');
      expectInside(f);
    });
    test('直方体: 見える 3 面と、見えない 3 辺の破線。寸法の比が保たれる', () {
      final f = make('cuboid', {'a': 4, 'b': 2, 'c': 3}, labels: {'a': 'A', 'b': 'B', 'c': 'C'})!;
      expect(f.shapes.map((s) => s.kind).toList(), [
        FigureShapeKind.poly,
        FigureShapeKind.poly,
        FigureShapeKind.poly,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
      ]);
      expect(f.shapes.skip(3).every((s) => s.dashed), isTrue);
      final front = f.shapes[0].points;
      final w = front[1].x - front[0].x, ht = front[0].y - front[3].y;
      expect(w / ht, closeTo(4 / 3, 1e-9)); // 正面は a : c
      final top = f.shapes[1].points; // 上面の奥行き: 右へ 0.3536b・上へ 0.3536b
      expect(top[2].x - top[1].x, closeTo(w / 4 * 2 * 0.35355339059327373, 1e-9));
      expect(f.labels.map((l) => l.text), ['A', 'C', 'B']);
      expectInside(f);
    });
    test('立方体の展開図: 十字形の正方形 6 つ', () {
      final f = make('cube', {'a': 3}, view: 'net', labels: {'a': '3cm'})!;
      expect(f.shapes.length, 6);
      expect(f.shapes.every((s) => s.kind == FigureShapeKind.poly), isTrue);
      final xs = f.shapes.map((s) => s.points[0].x).toSet().toList()..sort();
      final ys = f.shapes.map((s) => s.points[0].y).toSet().toList()..sort();
      expect(xs.length, 4); // 4 列
      expect(ys.length, 3); // 3 行
      expect(f.labels.single.text, '3cm');
      expectInside(f);
    });
    test('円柱の展開図: 長方形（横は円周 2πr）と、上下に接する円', () {
      final f = make('cylinder', {'r': 2, 'h': 6}, view: 'net', labels: {'r': 'r', 'h': 'h', 'w': '?'})!;
      expect(f.shapes.map((s) => s.kind).toList(), [
        FigureShapeKind.poly,
        FigureShapeKind.circle,
        FigureShapeKind.circle,
        FigureShapeKind.seg,
      ]);
      final rect = f.shapes[0].points;
      final w = rect[1].x - rect[0].x, ht = rect[2].y - rect[0].y;
      expect(w / ht, closeTo(2 * math.pi * 2 / 6, 1e-9));
      final c1 = f.shapes[1], c2 = f.shapes[2];
      expect(c1.r, closeTo(w / (2 * math.pi), 1e-9)); // 円の半径は rect 幅 ÷ 2π（r の比）
      expect(c1.points.single.y + c1.r, closeTo(rect[0].y, 1e-9)); // 上の円は長方形の上辺に接する
      expect(c2.points.single.y - c2.r, closeTo(rect[2].y, 1e-9)); // 下の円は下辺に接する
      expectInside(f);
    });
    test('円錐の展開図: おうぎ形の中心角は 360r/l。弧と底面の円周が等しい。180° を超えても枠に収まる', () {
      for (final (r, h) in [(3.0, 4.0), (5.0, 5.0), (7.0, 2.0), (1.0, 20.0)]) {
        final l = math.sqrt(r * r + h * h);
        final f = make('cone', {'r': r, 'h': h}, view: 'net')!;
        final arc = f.shapes.firstWhere((s) => s.kind == FigureShapeKind.arc);
        expect(arc.end - arc.start, closeTo(360 * r / l, 1e-9), reason: '$r,$h');
        final circle = f.shapes.firstWhere((s) => s.kind == FigureShapeKind.circle);
        // 弧の長さ = 2π·(おうぎ形の半径)·θ/360 = 底面の円周 2π·(円の半径)
        expect(
          2 * math.pi * arc.r * (arc.end - arc.start) / 360,
          closeTo(2 * math.pi * circle.r, 1e-6),
          reason: '$r,$h',
        );
        expectInside(f, reason: '$r,$h');
      }
    });
    test('どの種類・どの寸法の比でも枠（0〜100）に収まる', () {
      for (final a in [0.5, 1.0, 3.0, 10.0, 40.0]) {
        for (final b in [0.5, 1.0, 3.0, 10.0, 40.0]) {
          expectInside(make('cylinder', {'r': a, 'h': b})!, reason: 'cylinder $a $b');
          expectInside(make('cone', {'r': a, 'h': b})!, reason: 'cone $a $b');
          expectInside(make('cylinder', {'r': a, 'h': b}, view: 'net')!, reason: 'cylinder net $a $b');
          expectInside(make('cone', {'r': a, 'h': b}, view: 'net')!, reason: 'cone net $a $b');
          for (final c in [0.5, 3.0, 40.0]) {
            expectInside(make('cuboid', {'a': a, 'b': b, 'c': c})!, reason: 'cuboid $a $b $c');
          }
        }
      }
    });
  });

  group('大きさと配置', () {
    /// 図形全体の幅と高さ（円・楕円・弧は実際に描かれる範囲）。
    ({double w, double h}) extent(Figure f) {
      var x0 = double.infinity, x1 = -double.infinity, y0 = double.infinity, y1 = -double.infinity;
      void pt(double x, double y) {
        x0 = math.min(x0, x);
        x1 = math.max(x1, x);
        y0 = math.min(y0, y);
        y1 = math.max(y1, y);
      }

      for (final s in f.shapes) {
        final c = s.points.first;
        switch (s.kind) {
          case FigureShapeKind.circle:
            pt(c.x - s.r, c.y - s.r);
            pt(c.x + s.r, c.y + s.r);
          case FigureShapeKind.ellipse:
            pt(c.x - s.r, c.y - s.ry);
            pt(c.x + s.r, c.y + s.ry);
          case FigureShapeKind.ellipseHalf:
            pt(c.x - s.r, c.y);
            pt(c.x + s.r, c.y + (s.upper ? -s.ry : s.ry));
          case FigureShapeKind.arc:
            for (var i = 0; i <= 2000; i++) {
              final t = (s.start + (s.end - s.start) * i / 2000) * math.pi / 180;
              pt(c.x + s.r * math.cos(t), c.y - s.r * math.sin(t));
            }
          default:
            for (final p in s.points) {
              pt(p.x, p.y);
            }
        }
      }
      return (w: x1 - x0, h: y1 - y0);
    }

    test('枠いっぱい（72）に収める: 縦長なら高さ、横長なら幅がちょうど 72', () {
      for (final (r, h) in [(1.0, 20.0), (20.0, 1.0)]) {
        final e = extent(make('cylinder', {'r': r, 'h': h})!);
        expect(math.max(e.w, e.h), closeTo(72, 0.01), reason: '円柱 $r,$h');
        final c = extent(make('cone', {'r': r, 'h': h})!);
        expect(math.max(c.w, c.h), closeTo(72, 0.01), reason: '円錐 $r,$h');
        final n = extent(make('cylinder', {'r': r, 'h': h}, view: 'net')!);
        expect(math.max(n.w, n.h), closeTo(72, 0.01), reason: '円柱の展開図 $r,$h');
      }
      expect(extent(make('cuboid', {'a': 10, 'b': 2, 'c': 2})!).w, closeTo(72, 0.01));
      expect(extent(make('cuboid', {'a': 2, 'b': 2, 'c': 10})!).h, closeTo(72, 0.01));
      // 円錐の展開図: 中心角が小さい（細い）・大きい（180° 超）どちらでも 72 に収まる
      for (final (r, h) in [(1.0, 20.0), (3.0, 4.0), (7.0, 2.0), (2.0, 4.0)]) {
        final e = extent(make('cone', {'r': r, 'h': h}, view: 'net')!);
        expect(math.max(e.w, e.h), closeTo(72, 0.05), reason: '円錐の展開図 $r,$h');
      }
    });
    test('立方体の展開図は 4 × 3 マスの十字（72 × 54）。マスの位置が決まっている', () {
      final f = make('cube', {'a': 3}, view: 'net')!;
      final e = extent(f);
      expect(e.w, closeTo(72, 1e-9));
      expect(e.h, closeTo(54, 1e-9));
      final x0 = f.shapes.map((s) => s.points[0].x).reduce(math.min),
          y0 = f.shapes.map((s) => s.points[0].y).reduce(math.min);
      final cells = {
        for (final s in f.shapes) ((s.points[0].x - x0) / 18).round() * 10 + ((s.points[0].y - y0) / 18).round(),
      };
      expect(cells, {10, 1, 11, 21, 31, 12}); // (列, 行) = (1,0)(0,1)(1,1)(2,1)(3,1)(1,2)
      expect(f.shapes.every((s) => (s.points[1].x - s.points[0].x - 18).abs() < 1e-9), isTrue);
    });
    test('円錐の展開図: 2 本の線は頂点から左右対称。底面の円は弧の真下に接する', () {
      final f = make('cone', {'r': 3, 'h': 4}, view: 'net')!;
      final segs = f.shapes.where((s) => s.kind == FigureShapeKind.seg).toList();
      expect(segs.length, 2);
      expect(segs[0].points[0], segs[1].points[0]); // 同じ頂点
      expect(segs[0].points[1].x + segs[1].points[1].x, closeTo(100, 1e-9));
      expect(segs[0].points[1].x, lessThan(segs[1].points[1].x));
      expect(segs[0].points[1].y, closeTo(segs[1].points[1].y, 1e-9));
      final arc = f.shapes.firstWhere((s) => s.kind == FigureShapeKind.arc);
      final c = f.shapes.firstWhere((s) => s.kind == FigureShapeKind.circle);
      expect(c.points.single.x, 50);
      expect(c.points.single.y - c.r, closeTo(arc.points.single.y + arc.r, 1e-9));
    });
    test('ラベルの位置: 直方体は辺の外側、円柱の高さは右の辺の外側', () {
      final cb = make('cuboid', {'a': 4, 'b': 2, 'c': 3}, labels: {'a': 'A', 'c': 'C', 'b': 'B'})!;
      final front = cb.shapes[0].points;
      final la = cb.labels.firstWhere((l) => l.text == 'A');
      expect(la.x, closeTo((front[0].x + front[1].x) / 2, 1e-9)); // 手前の下の辺の真ん中
      expect(la.y, closeTo(front[0].y + 8, 1e-9)); // その下
      final lc = cb.labels.firstWhere((l) => l.text == 'C');
      expect(lc.x, closeTo(front[0].x - 9, 1e-9)); // 手前の左の辺の外
      final cy = make('cylinder', {'r': 3, 'h': 5}, labels: {'h': 'H'})!;
      final lh = cy.labels.single;
      expect(lh.x, closeTo(50 + cy.shapes[0].r + 10, 1e-9));
    });
  });

  group('SVG', () {
    test('楕円・半楕円（手前は反時計回り、奥は時計回り）・破線', () {
      final svg = make('cylinder', {'r': 3, 'h': 5})!.toSvg();
      expect(svg, contains('<ellipse '));
      expect('<path d="M'.allMatches(svg).length, 2);
      expect(svg, contains(' 0 0 0 ')); // 手前（下側）
      expect(svg, contains(' 0 0 1 ')); // 奥（上側）
      expect(svg, contains('stroke-dasharray="3 2"'));
      expect(svg, contains('viewBox="-8 -8 116 116"'));
      expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse);
    });
    test('半楕円の座標: 左端から右端まで', () {
      final f = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'O': [50, 50],
        },
        'altId': 'a',
      }, {});
      expect(f.resolve({}, (s) => s), isNotNull);
      final svg = make('sphere', {'r': 4})!.toSvg();
      expect(svg, contains('<path d="M14 50A36 10.8 0 0 0 86 50"/>')); // 手前（下側）
      expect(svg, contains('<path d="M14 50A36 10.8 0 0 1 86 50" stroke-dasharray="3 2"/>')); // 奥（上側）
    });
  });

  group('型に組み込む', () {
    test('立体の図つきの変種。式の寸法（sqrt など）を使える', () {
      final t = MathTemplate.fromJson({
        'id': 'sp1',
        'templateVersion': 1,
        'unitId': 'u',
        'type': 'expr',
        'difficulty': 0.5,
        'params': {
          'r': {
            'int': [2, 8],
          },
          'l': {
            'int': [10, 20],
          },
        },
        'figure': {
          'solid': {
            'kind': 'cone',
            'dims': {'r': 'r', 'h': 'sqrt(l*l-r*r)'},
            'labels': {'r': '{r}cm'},
          },
          'altId': 'fig_cone',
        },
        'display': {'x': '{l}'},
        'answer': '{l-r}',
        'explanationId': 'e',
      });
      for (var s = 1; s <= 20; s++) {
        final v = t.generate(s);
        expect(v.figure, isNotNull);
        expectInside(v.figure!);
      }
    });
    test('寸法が常に正でない型は引き直し→StateError', () {
      final t = MathTemplate.fromJson({
        'id': 'sp2',
        'templateVersion': 1,
        'unitId': 'u',
        'type': 'expr',
        'difficulty': 0.5,
        'params': {
          'r': {
            'int': [2, 8],
          },
        },
        'figure': {
          'solid': {
            'kind': 'sphere',
            'dims': {'r': 'r-100'},
          },
          'altId': 'fig_sphere',
        },
        'display': {'x': '{r}'},
        'answer': '{r}',
        'explanationId': 'e',
      });
      expect(() => t.generate(1), throwsStateError);
    });
  });
}
