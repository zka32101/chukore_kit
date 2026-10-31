import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fig([Map<String, dynamic> over = const {}]) => {
  'viewBox': [0, 0, 100, 80],
  'points': {
    'A': [10, 70],
    'B': [90, 70],
    'C': [50, 'h'],
  },
  'draw': [
    {
      'poly': ['A', 'B', 'C'],
      'fill': true,
    },
  ],
  'marks': [
    {
      'angle': ['B', 'A', 'C'],
      'label': '{a}°',
    },
    {
      'right': ['A', 'B', 'C'],
    },
  ],
  'names': true,
  'altId': 'fig_t',
  ...over,
};

FigureTemplate ft([Map<String, dynamic> over = const {}]) => FigureTemplate.fromJson(fig(over), {'a', 'h', 'r'});

Figure? resolve(FigureTemplate t, Map<String, double> v) => t.resolve(v, (s) => renderTemplateString(s, v));

Map<String, dynamic> tbase([Map<String, dynamic> over = const {}]) => {
  'id': 'f1',
  'templateVersion': 1,
  'unitId': 'u',
  'type': 'expr',
  'difficulty': 0.5,
  'params': {
    'a': {
      'int': [30, 80],
    },
    'h': {
      'int': [10, 60],
    },
  },
  'figure': fig(),
  'display': {'x': '{a}'},
  'answer': '{180-a-a}',
  'explanationId': 'e',
  ...over,
};

void main() {
  group('読み込み', () {
    test('正常な図', () {
      final t = ft();
      expect(t.altId, 'fig_t');
      expect(t.viewBox, [0.0, 0.0, 100.0, 80.0]);
    });
    test('書き間違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        {'extra': 1},
        {
          'viewBox': [0, 0, 100],
        },
        {
          'viewBox': [0, 0, 0, 80],
        },
        {'altId': ''},
        {'altId': null},
        {'points': <String, dynamic>{}},
        {
          'points': {
            'A': [1, 2, 3],
          },
        },
        {
          'points': {
            '1A': [1, 2],
          },
        },
        {
          'points': {
            'A': [1, 'z'],
          },
        },
        {
          'points': {
            'A': [1, 'h+'],
          },
        },
        {
          'points': {
            'A': [10, 70],
            'B': {
              'polar': ['Z', 5, 0],
            },
          },
        },
        {
          'points': {
            'A': [10, 70],
            'B': {
              'polar': ['A', 5],
            },
          },
        },
        {
          'draw': [
            {
              'seg': ['A', 'Q'],
            },
          ],
        },
        {
          'draw': [
            {
              'seg': ['A'],
            },
          ],
        },
        {
          'draw': [
            {
              'poly': ['A', 'B'],
            },
          ],
        },
        {
          'draw': [
            {
              'circle': ['A'],
            },
          ],
        },
        {
          'draw': [
            {
              'arc': ['A', 5, 0],
            },
          ],
        },
        {
          'draw': [
            {
              'line': ['A', 'B'],
            },
          ],
        },
        {
          'draw': [
            {
              'seg': ['A', 'B'],
              'poly': ['A', 'B', 'C'],
            },
          ],
        },
        {
          'draw': [
            {
              'seg': ['A', 'B'],
              'color': 'red',
            },
          ],
        },
        {
          'draw': [
            {
              'seg': ['A', 'B'],
              'style': 'dotted',
            },
          ],
        },
        {
          'draw': [
            {
              'seg': ['A', 'B'],
              'fill': true,
            },
          ],
        },
        {'draw': 'x'},
        {
          'marks': [
            {
              'angle': ['A', 'B'],
            },
          ],
        },
        {
          'marks': [
            {
              'angle': ['A', 'B', 'C'],
              'label': 3,
            },
          ],
        },
        {
          'marks': [
            {
              'tick': ['A', 'B'],
              'n': 9,
            },
          ],
        },
        {
          'marks': [
            {
              'tick': ['A', 'B'],
              'n': '2',
            },
          ],
        },
        {
          'marks': [
            {
              'text': ['A', 5],
            },
          ],
        },
        {
          'marks': [
            {
              'length': ['A'],
            },
          ],
        },
      ];
      for (final b in bad) {
        expect(() => ft(b), throwsFormatException, reason: b.toString());
      }
    });
    test('polar は先に宣言した点が中心', () {
      expect(
        () => ft({
          'points': {
            'B': {
              'polar': ['A', 5, 0],
            },
            'A': [10, 70],
          },
          'draw': <dynamic>[],
          'marks': <dynamic>[],
        }),
        throwsFormatException,
      );
    });
  });

  group('値を入れる', () {
    test('座標・ラベル・名前。式と {…} が値に置き換わる', () {
      final f = resolve(ft(), {'a': 40, 'h': 20})!;
      expect(f.points['C'], (x: 50.0, y: 20.0));
      expect(f.altId, 'fig_t');
      expect(f.labels.map((l) => l.text), containsAll(['40°', 'A', 'B', 'C']));
      expect(f.shapes.map((s) => s.kind), [FigureShapeKind.poly, FigureShapeKind.angle, FigureShapeKind.rightAngle]);
    });
    test('枠の外・点が重なる・一直線の角・NaN は null（描けない）', () {
      expect(resolve(ft(), {'a': 40, 'h': -5}), isNull); // 枠の外
      expect(resolve(ft(), {'a': 40, 'h': 100}), isNull);
      expect(
        resolve(
          ft({
            'points': {
              'A': [10, 70],
              'B': [10, 70],
            },
            'draw': <dynamic>[],
            'marks': <dynamic>[],
          }),
          {'a': 1, 'h': 1},
        ),
        isNull,
      ); // 点の重なり
      expect(
        resolve(
          ft({
            'points': {
              'A': [10, 70],
              'B': [50, 70],
              'C': [90, 70],
            },
            'draw': <dynamic>[],
            'marks': [
              {
                'angle': ['A', 'B', 'C'],
              },
            ],
          }),
          {'a': 1, 'h': 1},
        ),
        isNull,
      ); // 一直線
      expect(
        resolve(
          ft({
            'points': {
              'A': [10, '1/0'],
            },
            'draw': <dynamic>[],
            'marks': <dynamic>[],
          }),
          {'a': 1, 'h': 1},
        ),
        isNull,
      );
    });
    test('polar: 中心から半径・角度（度。反時計回り、y は下向き）', () {
      final t = FigureTemplate.fromJson(
        {
          'viewBox': [0, 0, 100, 100],
          'points': {
            'O': [50, 50],
            'P': {
              'polar': ['O', 20, 0],
            },
            'Q': {
              'polar': ['O', 20, 90],
            },
            'R': {
              'polar': ['O', 'r', 180],
            },
          },
          'altId': 'a',
        },
        {'r'},
      );
      final f = t.resolve({'r': 10}, (s) => s)!;
      expect(f.points['P']!.x, closeTo(70, 1e-9));
      expect(f.points['P']!.y, closeTo(50, 1e-9));
      expect(f.points['Q']!.x, closeTo(50, 1e-9));
      expect(f.points['Q']!.y, closeTo(30, 1e-9)); // 上
      expect(f.points['R']!.x, closeTo(40, 1e-9));
    });
    test('円・弧・線分・印の要素', () {
      final t = FigureTemplate.fromJson(
        {
          'viewBox': [0, 0, 100, 100],
          'points': {
            'O': [50, 50],
            'A': [80, 50],
            'B': [50, 20],
          },
          'draw': [
            {
              'circle': ['O', 30],
              'style': 'dashed',
            },
            {
              'arc': ['O', 30, 0, 90],
            },
            {
              'seg': ['O', 'A'],
            },
            {
              'seg': ['O', 'B'],
              'style': 'dashed',
            },
          ],
          'marks': [
            {
              'tick': ['O', 'A'],
              'n': 2,
            },
            {
              'length': ['O', 'A'],
              'label': '{r}cm',
            },
            {
              'text': ['B', 'おうぎ形'],
            },
          ],
          'altId': 'a',
        },
        {'r'},
      );
      final v = {'r': 6.0};
      final f = t.resolve(v, (s) => renderTemplateString(s, v))!;
      expect(f.shapes.map((s) => s.kind), [
        FigureShapeKind.circle,
        FigureShapeKind.arc,
        FigureShapeKind.seg,
        FigureShapeKind.seg,
        FigureShapeKind.tick,
      ]);
      expect(f.shapes.first.dashed, isTrue);
      expect(f.labels.map((l) => l.text), ['6cm', 'おうぎ形']);
      expect(resolve(t, {'r': 6}), isNotNull);
      // 半径が 0 以下・弧の始まりと終わりが同じは描けない
      final bad = FigureTemplate.fromJson(
        {
          'viewBox': [0, 0, 100, 100],
          'points': {
            'O': [50, 50],
          },
          'draw': [
            {
              'circle': ['O', 'r'],
            },
          ],
          'altId': 'a',
        },
        {'r'},
      );
      expect(bad.resolve({'r': 0}, (s) => s), isNull);
      final bad2 = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'O': [50, 50],
        },
        'draw': [
          {
            'arc': ['O', 10, 30, 30],
          },
        ],
        'altId': 'a',
      }, {});
      expect(bad2.resolve({}, (s) => s), isNull);
    });
  });

  group('SVG', () {
    test('基本の構造・座標・ラベル。色は currentColor だけ', () {
      final svg = resolve(ft(), {'a': 40, 'h': 20})!.toSvg();
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-8 -8 116 96"'));
      expect(svg, endsWith('</svg>'));
      expect(svg, contains('<polygon points="10,70 90,70 50,20" fill="currentColor" fill-opacity="0.12"/>'));
      expect(svg, contains('>40°</text>'));
      expect(svg, contains('stroke="currentColor"'));
      expect(RegExp(r'#[0-9a-fA-F]{3,6}|rgb\(').hasMatch(svg), isFalse);
      expect('<path'.allMatches(svg).length, 1); // 角印の弧
      expect('<polyline'.allMatches(svg).length, 1); // 直角印
    });
    test('余白: padding を変えられる。0 なら枠そのまま', () {
      final f = resolve(ft(), {'a': 40, 'h': 20})!;
      expect(f.toSvg(padding: 0), contains('viewBox="0 0 100 80"'));
      expect(f.toSvg(padding: 2), contains('viewBox="-2 -2 104 84"'));
    });
    test('ラベルは XML エスケープする', () {
      final t = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'A': [10, 10],
        },
        'marks': [
          {
            'text': ['A', 'a<b & "c">'],
          },
        ],
        'altId': 'a',
      }, {});
      final svg = t.resolve({}, (s) => s)!.toSvg();
      expect(svg, contains('a&lt;b &amp; &quot;c&quot;&gt;'));
      expect(svg.contains('<b'), isFalse);
    });
    test('弧: 開始・終了の座標と大弧フラグ。破線', () {
      FigureTemplate arc(num a, num b, {bool dashed = false}) => FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'O': [50, 50],
        },
        'draw': [
          {
            'arc': ['O', 20, a, b],
            if (dashed) 'style': 'dashed',
          },
        ],
        'altId': 'a',
      }, {});
      expect(arc(0, 90).resolve({}, (s) => s)!.toSvg(), contains('<path d="M70 50A20 20 0 0 0 50 30"/>'));
      expect(arc(0, 270).resolve({}, (s) => s)!.toSvg(), contains('A20 20 0 1 0 50 70'));
      expect(arc(-90, 90).resolve({}, (s) => s)!.toSvg(), contains('A20 20 0 0 0 50 30'));
      expect(arc(0, 90, dashed: true).resolve({}, (s) => s)!.toSvg(), contains('stroke-dasharray="3 2"'));
    });
    test('弧の向き: 開始角が大きく終了角が小さい（負の差）も、0〜360 の差で大弧を判定', () {
      FigureTemplate arc(num a, num b) => FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'O': [50, 50],
        },
        'draw': [
          {
            'arc': ['O', 20, a, b],
          },
        ],
        'altId': 'a',
      }, {});
      // 270° → 0°（時計回りに見えるが、反時計回りに 90°）は小弧、0° → 270° は大弧
      expect(arc(270, 360).resolve({}, (s) => s)!.toSvg(), contains(' 0 0 0 '));
      expect(arc(270, 0).resolve({}, (s) => s)!.toSvg(), contains(' 0 0 0 ')); // 差 -270 → 90°
      expect(arc(90, 0).resolve({}, (s) => s)!.toSvg(), contains(' 0 1 0 ')); // 差 -90 → 270°
    });
    test('角印の向き（小さい側の角）。頂点まわりで時計回りと反時計回りの両方', () {
      FigureTemplate ang(List<List<num>> pts) => FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {'A': pts[0], 'O': pts[1], 'B': pts[2]},
        'marks': [
          {
            'angle': ['A', 'O', 'B'],
          },
        ],
        'altId': 'a',
      }, {});
      // O=(50,50) から A=右、B=下: 画面で時計回りに 90° → sweep=1
      expect(
        ang([
          [80, 50],
          [50, 50],
          [50, 80],
        ]).resolve({}, (s) => s)!.toSvg(),
        contains('A8 8 0 0 1 '),
      );
      // A=右、B=上: 反時計回りに 90° → sweep=0
      expect(
        ang([
          [80, 50],
          [50, 50],
          [50, 20],
        ]).resolve({}, (s) => s)!.toSvg(),
        contains('A8 8 0 0 0 '),
      );
    });
    test('角印のラベルは二等分線の向き、長さのラベルは線分の中点から垂直にずれる、等しい辺の印は n 本', () {
      final t = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'A': [80, 50],
          'O': [50, 50],
          'B': [50, 80],
          'P': [10, 10],
          'Q': [30, 10],
        },
        'marks': [
          {
            'angle': ['A', 'O', 'B'],
            'label': 'x',
          },
          {
            'length': ['P', 'Q'],
            'label': 'L',
          },
          {
            'tick': ['P', 'Q'],
            'n': 3,
          },
        ],
        'altId': 'a',
      }, {});
      final f = t.resolve({}, (s) => s)!;
      final ang = f.labels.firstWhere((l) => l.text == 'x');
      expect(ang.x, closeTo(50 + 16 * 0.70710678, 1e-3)); // 右と下の二等分線＝右下 45°
      expect(ang.y, closeTo(50 + 16 * 0.70710678 + 2, 1e-3));
      final len = f.labels.firstWhere((l) => l.text == 'L');
      expect(len.x, closeTo(20, 1e-9)); // 中点 (20, 10)、線分は水平なので x はそのまま
      expect(len.y, closeTo(10 + 5 + 2, 1e-9)); // 下向きの垂直方向に 5
      expect('<line'.allMatches(f.toSvg()).length, 3);
    });
    test('等しい辺の印: 中点の両側に n 本、線分に垂直。点の名前は図の中心から外向きに置く', () {
      final t = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'P': [10, 10],
          'Q': [30, 10],
        },
        'marks': [
          {
            'tick': ['P', 'Q'],
            'n': 2,
          },
        ],
        'altId': 'a',
      }, {});
      final svg = t.resolve({}, (s) => s)!.toSvg();
      expect(svg, contains('<line x1="18.56" y1="7.5" x2="18.56" y2="12.5"/>'));
      expect(svg, contains('<line x1="21.44" y1="7.5" x2="21.44" y2="12.5"/>'));
      final names = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'A': [10, 10],
          'B': [90, 10],
          'C': [50, 70],
        },
        'names': true,
        'altId': 'a',
      }, {}).resolve({}, (s) => s)!;
      final a = names.labels.firstWhere((l) => l.text == 'A');
      // 重心 (50, 30) から A への向きは (-40, -20)/44.72。外向きに 5
      expect(a.x, closeTo(10 - 5 * 40 / 44.72135955, 1e-6));
      expect(a.y, closeTo(10 - 5 * 20 / 44.72135955 + 2, 1e-6));
    });
    test('数の書式: 余計な 0 を付けない', () {
      final t = FigureTemplate.fromJson({
        'viewBox': [0, 0, 100, 100],
        'points': {
          'A': [10.5, 20],
          'B': ['1/3*100', 40.25],
        },
        'draw': [
          {
            'seg': ['A', 'B'],
          },
        ],
        'altId': 'a',
      }, {});
      expect(t.resolve({}, (s) => s)!.toSvg(), contains('<line x1="10.5" y1="20" x2="33.33" y2="40.25"/>'));
    });
  });

  group('型に組み込む', () {
    test('図つきの変種: Variant.figure が値で決まる。種で再現する', () {
      final t = MathTemplate.fromJson(tbase());
      final v = t.generate(3);
      expect(v.figure, isNotNull);
      expect(v.figure!.points['C']!.y, v.params['h']);
      expect(v.figure!.labels.map((l) => l.text), contains('${v.params['a']!.toInt()}°'));
      expect(v.figure!.toSvg(), t.generate(3).figure!.toSvg());
      expect({for (var s = 1; s <= 20; s++) t.generate(s).figure!.toSvg()}.length, greaterThan(15));
    });
    test('図を描けない引き方は引き直し。毎回描けなければ StateError', () {
      final ok = MathTemplate.fromJson(
        tbase({
          'params': {
            'a': {
              'int': [30, 80],
            },
            'h': {
              'int': [-40, 60],
            },
          },
        }),
      );
      for (var s = 1; s <= 30; s++) {
        expect(ok.generate(s).params['h']!, greaterThanOrEqualTo(0)); // 枠の外になる h は出ない
      }
      final never = MathTemplate.fromJson(
        tbase({
          'params': {
            'a': {
              'int': [30, 80],
            },
            'h': {
              'int': [200, 300],
            },
          },
        }),
      );
      expect(() => never.generate(1), throwsStateError);
    });
    test('図のない型は figure が null。figure の書き間違いは型の読み込みで FormatException', () {
      expect(MathTemplate.fromJson(tbase({'figure': null})).generate(1).figure, isNull);
      expect(() => MathTemplate.fromJson(tbase({'figure': 'x'})), throwsFormatException);
      expect(
        () => MathTemplate.fromJson(
          tbase({
            'figure': fig({'altId': ''}),
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => MathTemplate.fromJson(
          tbase({
            'figure': fig({
              'points': {
                'A': [1, 'z'],
              },
            }),
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
