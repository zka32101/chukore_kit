import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> seg({Object? anim, String bx = '10+t*10'}) => {
      'viewBox': [0, 0, 100, 80],
      'points': {
        'A': [10, 40],
        'B': [bx, 40],
      },
      'draw': [
        {'seg': ['A', 'B']},
      ],
      'altId': 'fig_move',
      'animation': ?anim,
    };

Map<String, dynamic> anim({Object from = 1, Object to = 5, Object? frames, Object? ms, Object? loop}) => {
      'from': from,
      'to': to,
      'frames': ?frames,
      'durationMs': ?ms,
      'loop': ?loop,
    };

FigureTemplate ft(Map<String, dynamic> j, [Set<String> known = const {'p'}]) => FigureTemplate.fromJson(j, known);

Matcher bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

String render(String s) => s;

void main() {
  group('読み込み', () {
    test('正常: 既定は 24 コマ・3 秒・くり返しなし。t が式で使える', () {
      final t = ft(seg(anim: anim()));
      expect(t.animation, isNotNull);
      expect(t.animation!.frames, 24);
      expect(t.animation!.durationMs, 3000);
      expect(t.animation!.loop, isFalse);
      final c = ft(seg(anim: anim(frames: 2, ms: 200, loop: true)));
      expect([c.animation!.frames, c.animation!.durationMs, c.animation!.loop], [2, 200, true]);
      expect(ft(seg(bx: '10+p*10')).animation, isNull);
    });

    test('from・to はパラメータの式でもよい（t は使えない）', () {
      ft(seg(anim: anim(to: 'p')));
      ft(seg(anim: anim(from: 'p-1', to: 'p+3')));
      expect(() => ft(seg(anim: anim(to: 't'))), bad('パラメータにない'));
      expect(() => ft(seg(anim: anim(to: 'z'))), bad('パラメータにない'));
    });

    test('書き間違い', () {
      expect(() => ft(seg(anim: 5)), bad('animation'));
      expect(() => ft(seg(anim: {...anim(), 'zzz': 1})), bad('animation'));
      expect(() => ft(seg(anim: {'from': 0})), bad('to'));
      expect(() => ft(seg(anim: {'to': 0})), bad('from'));
      expect(() => ft(seg(anim: anim(from: '1+'))), bad('数か式'));
      expect(() => ft(seg(anim: anim(to: true))), bad('数か式'));
      expect(() => ft(seg(anim: anim(frames: 1))), bad('frames'));
      expect(() => ft(seg(anim: anim(frames: 121))), bad('frames'));
      expect(() => ft(seg(anim: anim(frames: 2.5))), bad('frames'));
      ft(seg(anim: anim(frames: 120)));
      expect(() => ft(seg(anim: anim(ms: 199))), bad('durationMs'));
      expect(() => ft(seg(anim: anim(ms: 20001))), bad('durationMs'));
      ft(seg(anim: anim(ms: 20000)));
      expect(() => ft(seg(anim: anim(loop: 'yes'))), bad('loop'));
    });

    test('パラメータ名 t は予約', () {
      expect(() => ft(seg(anim: anim()), {'t'}), bad('t'));
      ft(seg(bx: '10+t*10'), {'t'}); // 動かない図なら t を使ってよい（パラメータ名）
    });
  });

  group('コマ', () {
    test('コマの数・時刻は from から to まで等間隔・点が動く・最後のコマが静止画', () {
      final t = ft(seg(anim: anim(frames: 5)));
      final a = t.animate(const {}, render)!;
      expect(a.frames.length, 5);
      expect(a.times, [1, 2, 3, 4, 5]);
      final xs = [for (final f in a.frames) f.shapes.single.points[1].x];
      expect(xs, [20, 30, 40, 50, 60]);
      expect(a.durationMs, 3000);
      expect(a.loop, isFalse);
      // 静止画（resolve）は最後のコマ
      expect(t.resolve(const {}, render)!.toSvg(), a.frames.last.toSvg());
    });

    test('to はパラメータの式。値ごとに時刻の範囲が変わる', () {
      final t = ft(seg(anim: anim(from: 1, to: 'p', frames: 3)));
      expect(t.animate({'p': 5}, render)!.times, [1, 3, 5]);
      expect(t.animate({'p': 9}, render)!.times, [1, 5, 9]);
    });

    test('t が減っていく向きもよい（from > to）', () {
      final a = ft(seg(anim: anim(from: 5, to: 1, frames: 3))).animate(const {}, render)!;
      expect(a.times, [5, 3, 1]);
    });

    test('動かない・計算できない・描けないコマがあれば null', () {
      expect(ft(seg(anim: anim(from: 2, to: 2))).animate(const {}, render), isNull);
      expect(ft(seg(anim: anim(to: '1/0'))).animate(const {}, render), isNull);
      // 点が枠の外に出るコマがある（10+t*10 が 100 を超える）
      expect(ft(seg(anim: anim(to: 12))).animate(const {}, render), isNull);
      // 最後の 1 コマだけ重なる点（A と B が同じ位置）
      expect(ft(seg(anim: anim(from: 5, to: 0, frames: 6))).animate(const {}, render), isNull);
    });

    test('途中のコマだけ描けなければ null（最後のコマは描ける）', () {
      // B の x = 10 + 50·t·(3−t): t=1.46 で枠の外（122）に出て、最後（t=2.9）は 24.5 に戻る
      final t = ft(seg(anim: anim(from: 0.5, to: 2.9, frames: 6), bx: '10+50*t*(3-t)'));
      expect(t.resolve(const {}, render), isNotNull);
      expect(t.animate(const {}, render), isNull);
    });

    test('animation のない図は animate が null', () {
      expect(ft(seg(bx: '10+p*10')).animate(const {'p': 1}, render), isNull);
    });

    test('静止画（resolve）は t を渡さなくてよい。渡せばそのコマ', () {
      final t = ft(seg(anim: anim()));
      expect(t.resolve(const {}, render)!.shapes.single.points[1].x, 60); // to = 5
      expect(t.resolve(const {'t': 2}, render)!.shapes.single.points[1].x, 30);
      expect(ft(seg(anim: anim(to: '1/0'))).resolve(const {}, render), isNull);
    });
  });

  group('再生 FigureAnimation', () {
    FigureAnimation make() => ft(seg(anim: anim(frames: 5))).animate(const {}, render)!;

    test('進み具合から最も近いコマ（範囲外は端、NaN は先頭）', () {
      final a = make();
      expect([a.indexAt(0), a.indexAt(0.5), a.indexAt(1)], [0, 2, 4]);
      expect([a.indexAt(0.12), a.indexAt(0.13), a.indexAt(0.37), a.indexAt(0.38)], [0, 1, 1, 2]);
      expect([a.indexAt(-3), a.indexAt(7), a.indexAt(double.nan)], [0, 4, 0]);
      expect(a.figureAt(0), same(a.frames.first));
      expect(a.figureAt(1), same(a.frames.last));
    });

    test('全コマの SVG', () {
      final svgs = make().toSvgFrames();
      expect(svgs.length, 5);
      expect(svgs.every((s) => s.startsWith('<svg') && s.endsWith('</svg>')), isTrue);
      expect(svgs.toSet().length, 5); // コマごとに違う
      expect(make().toSvgFrames(fontSize: 3, padding: 2).first == svgs.first, isFalse);
    });
  });

  group('型・グラフの図に組み込む', () {
    Map<String, dynamic> tpl(Map<String, dynamic> figure) => {
          'id': 'anim_t',
          'templateVersion': 1,
          'unitId': 'u',
          'type': 'expr',
          'difficulty': 0.5,
          'params': {
            'p': {'int': [2, 6]},
          },
          'derived': {'y': '5*p*p'},
          'figure': figure,
          'display': {'p': '{p}'},
          'answer': '{y}',
          'wrong': [
            {'expr': '{(5*p)^2}', 'tag': 't1'},
          ],
          'explanationId': 'e',
        };

    Map<String, dynamic> ball({Object to = 'p'}) => {
          'plot': {
            'x': [0, 6],
            'y': [0, 200],
            'curves': [
              {'expr': '5*x^2'},
            ],
            'points': [
              {'at': ['t', '5*t*t']},
            ],
            'ticks': {'x': 1, 'y': 50},
          },
          'altId': 'fig_free_fall',
          'animation': anim(from: 0, to: to, frames: 13),
        };

    test('グラフの上を動く点: 変種ごとに時刻が p まで。静止画は最後のコマ。点の位置は式どおり', () {
      final t = MathTemplate.fromJson(tpl(ball()));
      for (var s = 1; s <= 20; s++) {
        final v = t.generate(s);
        final p = v.params['p']!;
        final a = v.animation!;
        expect(a.frames.length, 13);
        expect(a.times.first, 0);
        expect(a.times.last, p);
        // 点は (t, 5t²)。y が増えるほど画面の y は小さい
        double dotY(Figure f) => f.shapes.firstWhere((x) => x.kind == FigureShapeKind.circle).points.single.y;
        double dotX(Figure f) => f.shapes.firstWhere((x) => x.kind == FigureShapeKind.circle).points.single.x;
        for (var i = 1; i < a.frames.length; i++) {
          expect(dotX(a.frames[i]) > dotX(a.frames[i - 1]), isTrue);
          expect(dotY(a.frames[i]) < dotY(a.frames[i - 1]), isTrue);
        }
        expect(v.figure!.toSvg(), a.frames.last.toSvg());
      }
    });

    test('動く図のない型は animation が null', () {
      final plain = Map<String, dynamic>.from(ball())..remove('animation');
      plain['plot'] = {...(plain['plot'] as Map<String, dynamic>)}..['points'] = [];
      final v = MathTemplate.fromJson(tpl(plain)).generate(1);
      expect(v.animation, isNull);
      expect(v.figure, isNotNull);
    });

    test('どれかのコマが描けなければ引き直し、毎回なら StateError', () {
      // t が 6 を超えると点が x の範囲（0〜6）の外に出る
      final t = MathTemplate.fromJson(tpl(ball(to: '8')));
      expect(() => t.generate(1), throwsStateError);
    });

    test('途中のコマが描けない型は、変種を作れない（StateError）', () {
      final t = MathTemplate.fromJson(tpl(seg(anim: anim(from: 0.5, to: 2.9, frames: 6), bx: '10+50*t*(3-t)')));
      expect(() => t.generate(1), throwsStateError);
    });

    test('パラメータ名 t と animation は併用できない（型の読み込みでエラー）', () {
      final j = tpl(ball())..['params'] = {'t': {'int': [2, 6]}}..['derived'] = {'y': '5*t*t'};
      expect(() => MathTemplate.fromJson(j), throwsFormatException);
    });
  });
}
