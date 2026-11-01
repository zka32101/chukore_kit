import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _j(String kind, List<String> cats, List<List<num>> series, {String altId = 'a'}) => {
      'kind': kind,
      'altId': altId,
      'categories': cats,
      'series': [for (var i = 0; i < series.length; i++) {'id': 's$i', 'values': series[i]}],
    };

ChartSpec _p(String kind, List<String> cats, List<List<num>> series) => ChartSpec.fromJson(_j(kind, cats, series));

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

ChartSpec _climate() => _p('climate', [for (var i = 1; i <= 12; i++) '$i'], [
      [5, 6, 9, 14, 19, 22, 26, 27, 23, 17, 12, 7],
      [50, 60, 120, 130, 150, 180, 150, 140, 220, 190, 90, 50],
    ]);

int _count(String s, String sub) => sub.allMatches(s).length;

void main() {
  group('目盛り', () {
    test('1・2・5 の刻み', () {
      NiceScale n(num lo, num hi, {int t = 5}) => niceScale(lo.toDouble(), hi.toDouble(), target: t);
      var s = n(0, 100);
      expect([s.min, s.max, s.step], [0, 100, 20]);
      s = n(0, 9);
      expect([s.min, s.max, s.step], [0, 10, 2]);
      s = n(-5, 27);
      expect([s.min, s.max, s.step], [-10, 30, 10]);
      s = n(0, 0.45);
      expect([s.min, s.max, s.step], [0, 0.5, 0.1]);
      s = n(3, 3);
      expect([s.min, s.max], [0, 3]);
      s = n(-3, -3);
      expect([s.min, s.max], [-3, 0]);
      s = n(0, 0);
      expect([s.min, s.max], [0, 1]);
      s = n(0, 1000, t: 10);
      expect(s.step, 100);
      expect(n(0, 100).ticks, [0, 20, 40, 60, 80, 100]);
      expect(n(0, 0.45).ticks, [0, 0.1, 0.2, 0.3, 0.4, 0.5]);
    });

    test('端がちょうど刻みのときは広げない・少し超えると広がる', () {
      expect(niceScale(0, 20, target: 4).max, 20);
      expect(niceScale(0, 20.5, target: 4).max, 30); // 刻みが 10 になる
      expect(niceScale(0, 21, target: 10).max, 25); // 2.1 は 2 より大きいので刻みは 5
      expect(niceScale(-20, 0, target: 4).min, -20);
      expect(niceScale(-20.5, 0, target: 4).min, -30); // 刻みが 10
    });

    test('小数の誤差で目盛りが 1 つ余らない', () {
      expect(niceScale(0, 1.1, target: 11).max, 1.1); // 1.1 / 0.1 = 11.000000000000002
      expect(niceScale(-1.1, 0, target: 11).min, -1.1);
      expect(niceScale(0, 0.07, target: 7).max, 0.07); // 0.07 / 0.01 = 7.000000000000001
      expect(niceScale(0.3, 0.6, target: 3).min, 0.3); // 0.3 / 0.1 = 2.9999999999999996
    });

    test('最大 ÷ 刻み は target 以下（雨温図の右軸が収まる条件）', () {
      for (var c = 1; c <= 12; c++) {
        for (var m = 1; m <= 2000; m += 7) {
          final v = m / 10;
          final s = niceScale(0, v, target: c);
          expect(s.max / s.step <= c + 1e-9, isTrue, reason: 'c=$c m=$v');
          expect(s.max >= v - 1e-9, isTrue, reason: 'c=$c m=$v');
        }
      }
    });

    test('引数の検査', () {
      expect(() => niceScale(2, 1), throwsArgumentError);
      expect(() => niceScale(0, 1, target: 0), throwsArgumentError);
    });
  });

  group('読み取り', () {
    test('各 kind', () {
      expect(_p('bars', ['a', 'b'], [[1, 2]]).kind, ChartKind.bars);
      expect(_p('line', ['a', 'b'], [[-1, 2], [3, 4]]).series.length, 2);
      expect(_climate().kind, ChartKind.climate);
      expect(_p('pyramid', ['0-14', '15-64'], [[1, 2], [1, 3]]).kind, ChartKind.pyramid);
      expect(_p('pie', ['a', 'b'], [[1, 3]]).kind, ChartKind.pie);
      expect(ChartSpec.parse(jsonEncode(_j('bars', ['a'], [[1]]))).altId, 'a');
    });

    test('形の誤り', () {
      Map<String, dynamic> with_(String k, Object? v) => {..._j('bars', ['a', 'b'], [[1, 2]]), k: v};
      expect(() => ChartSpec.fromJson({..._j('bars', ['a'], [[1]]), 'x': 1}), _bad('未知のキー'));
      expect(() => ChartSpec.fromJson(with_('kind', 'radar')), _bad('kind'));
      expect(() => ChartSpec.fromJson(with_('altId', '')), _bad('altId'));
      expect(() => ChartSpec.fromJson(with_('categories', [])), _bad('categories'));
      expect(() => ChartSpec.fromJson(with_('categories', ['a', ''])), _bad('categories'));
      expect(() => ChartSpec.fromJson(with_('categories', List.filled(61, 'a'))), _bad('1〜60'));
      ChartSpec.fromJson({..._j('bars', List.filled(60, 'a'), [List.filled(60, 1)])});
      expect(() => ChartSpec.fromJson(with_('series', [])), _bad('series'));
      expect(() => ChartSpec.fromJson(with_('series', List.filled(7, {'id': 'a', 'values': [1, 2]}))), _bad('series'));
      expect(() => ChartSpec.fromJson(with_('series', [{'id': 'a', 'values': [1, 2], 'x': 1}])), _bad('系列は'));
      expect(() => ChartSpec.fromJson(with_('series', [{'id': 'a-b', 'values': [1, 2]}])), _bad('id'));
      expect(() => ChartSpec.fromJson(with_('series', [{'id': 'a', 'values': [1]}])), _bad('同じ数'));
      expect(() => ChartSpec.fromJson(with_('series', [{'id': 'a', 'values': [1, 'x']}])), _bad('同じ数'));
      expect(
        () => ChartSpec.fromJson(with_('series', [{'id': 'a', 'values': [1, 2]}, {'id': 'a', 'values': [1, 2]}])),
        _bad('重複'),
      );
      expect(() => ChartSpec.parse('['), _bad('読めません'));
      expect(() => ChartSpec.parse('[]'), _bad('オブジェクト'));
    });

    test('系列の数と値の範囲', () {
      expect(() => _p('climate', ['a', 'b'], [[1, 2]]), _bad('2 個'));
      expect(() => _p('pyramid', ['a', 'b'], [[1, 2]]), _bad('2 個'));
      expect(() => _p('pie', ['a', 'b'], [[1, 2], [1, 2]]), _bad('1 個'));
      expect(() => _p('bars', ['a', 'b'], [[1, -2]]), _bad('0 以上'));
      expect(() => _p('pyramid', ['a', 'b'], [[1, 2], [-1, 2]]), _bad('0 以上'));
      expect(() => _p('pie', ['a', 'b'], [[1, -2]]), _bad('0 以上'));
      expect(() => _p('pie', ['a', 'b'], [[0, 0]]), _bad('合計'));
      expect(() => _p('climate', ['a', 'b'], [[1, 2], [1, -2]]), _bad('0 以上'));
      _p('climate', ['a', 'b'], [[-10, -2], [1, 2]]); // 気温は負でよい
      _p('line', ['a', 'b'], [[-1, -2]]);
    });
  });

  group('読み取りの補助', () {
    final c = _climate();
    test('最大・最小・合計・平均', () {
      expect(c.argMax('s1'), 8); // 9 月 220
      expect(c.argMin('s1'), 0); // 1 月と 12 月が 50 → 先
      expect(c.argMax('s0'), 7);
      expect(c.argMin('s0'), 0);
      expect(c.total('s1'), 1530);
      expect(c.mean('s0'), closeTo(15.583333, 1e-5));
      expect(() => c.argMax('zz'), throwsArgumentError);
      expect(() => c.total('zz'), throwsArgumentError);
      expect(c.seriesById('s1'), isNotNull);
      expect(c.seriesById('zz'), isNull);
    });

    test('同じ値は先の位置', () {
      final s = _p('bars', ['a', 'b', 'c'], [[3, 5, 5]]);
      expect(s.argMax('s0'), 1);
      final t = _p('bars', ['a', 'b', 'c'], [[3, 3, 5]]);
      expect(t.argMin('s0'), 0);
    });

    test('円グラフの割合', () {
      final p = _p('pie', ['a', 'b', 'c'], [[1, 1, 2]]);
      expect([p.shareOf(0), p.shareOf(2)], [0.25, 0.5]);
      expect(() => p.shareOf(3), throwsRangeError);
      expect(() => p.shareOf(-1), throwsRangeError);
      expect(() => _climate().shareOf(0), throwsStateError);
    });
  });

  group('箱ひげ図 box', () {
    List<List<num>> five5(List<num> mn, List<num> q1, List<num> md, List<num> q3, List<num> mx) => [mn, q1, md, q3, mx];
    Map<String, dynamic> boxJson({List<String>? ids, List<List<num>>? v, List<String>? cats}) => {
          'kind': 'box',
          'altId': 'a',
          'categories': cats ?? ['A', 'B'],
          'series': [
            for (var i = 0; i < 5; i++)
              {'id': (ids ?? ['min', 'q1', 'median', 'q3', 'max'])[i], 'values': (v ?? five5([1, 2], [3, 4], [5, 6], [7, 8], [9, 10]))[i]},
          ],
        };

    test('読み取りと補助（四分位範囲・範囲）', () {
      final c = ChartSpec.fromJson(boxJson());
      expect(c.kind, ChartKind.box);
      expect([c.iqrOf(0), c.iqrOf(1), c.rangeOf(0), c.rangeOf(1)], [4, 4, 8, 8]);
      expect(() => c.iqrOf(2), throwsRangeError);
      expect(() => c.iqrOf(-1), throwsRangeError);
      expect(() => c.rangeOf(2), throwsRangeError);
      expect(() => _climate().iqrOf(0), throwsStateError);
      expect(() => _climate().rangeOf(0), throwsStateError);
      expect(c.argMax('median'), 1);
    });

    test('形の誤り: 系列の数・ID の順・各項目で小さい順', () {
      expect(() => _p('box', ['a'], [[1], [2], [3], [4]]), _bad('5 個'));
      expect(() => ChartSpec.fromJson(boxJson(ids: ['q1', 'min', 'median', 'q3', 'max'])), _bad('順'));
      for (var k = 0; k < 4; k++) {
        final v = five5([1, 2], [3, 4], [5, 6], [7, 8], [9, 10]);
        v[k] = [v[k + 1][0] + 1, v[k][1]]; // 項目 A の k 番目を次より大きくする
        expect(() => ChartSpec.fromJson(boxJson(v: v)), _bad('A'), reason: 'k=$k');
      }
      // 等しいのはよい（箱が線になる）
      ChartSpec.fromJson(boxJson(v: five5([1, 1], [1, 1], [1, 1], [1, 1], [1, 1])));
      // 負の値もよい
      ChartSpec.fromJson(boxJson(v: five5([-9, -8], [-7, -6], [-5, -4], [-3, -2], [-1, 0])));
    });

    test('生のデータから: 五数要約は中学校の定義', () {
      final c = ChartSpec.boxFromData(altId: 'a', categories: ['A組', 'B組'], data: [
        [1, 2, 3, 4, 5, 6, 7, 8],
        [2, 4, 6, 8, 10, 12, 14],
      ]);
      expect(c.series.map((s) => s.id), ['min', 'q1', 'median', 'q3', 'max']);
      expect(c.series[0].values, [1, 2]);
      expect(c.series[1].values, [2.5, 4]);
      expect(c.series[2].values, [4.5, 8]);
      expect(c.series[3].values, [6.5, 12]);
      expect(c.series[4].values, [8, 14]);
      expect([c.iqrOf(0), c.iqrOf(1)], [4, 8]);
      expect(() => ChartSpec.boxFromData(altId: 'a', categories: ['A'], data: [[1, 2], [3, 4]]), throwsArgumentError);
      expect(() => ChartSpec.boxFromData(altId: 'a', categories: ['A'], data: [[1]]), throwsArgumentError);
    });

    test('SVG: 項目ごとに箱 1 つ・目盛り・項目の名前。色は currentColor だけ', () {
      final c = ChartSpec.boxFromData(altId: 'a', categories: ['A組', 'B組', 'C組'], data: [
        [10, 20, 30, 40, 50, 60],
        [25, 30, 35, 40, 45],
        [5, 50, 55, 60, 95, 100],
      ]);
      final svg = c.toSvg();
      expect(svg.startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80"'), isTrue);
      expect(_count(svg, '<rect'), 3);
      for (final n in ['A組', 'B組', 'C組']) {
        expect(svg.contains('>$n</text>'), isTrue, reason: n);
      }
      expect(RegExp(r'#[0-9a-fA-F]{3,6}').hasMatch(svg), isFalse);
      expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse);
      // 目盛り: 最小 5〜最大 100 → 0〜100（20 刻み）の 6 本
      for (final t in ['0', '20', '40', '60', '80', '100']) {
        expect(svg.contains('>$t</text>'), isTrue, reason: t);
      }
      expect(c.toSvg(), svg);
    });

    test('SVG: 箱の位置は値に比例する（中央値の縦線は箱の中）', () {
      final c = ChartSpec.fromJson(boxJson(cats: ['A'], v: five5([0], [20], [50], [60], [100])));
      final svg = c.toSvg();
      final rect = RegExp(r'<rect x="([\d.]+)" y="[\d.]+" width="([\d.]+)"').firstMatch(svg)!;
      final x = double.parse(rect.group(1)!), w = double.parse(rect.group(2)!);
      // 軸 0〜100 が 24〜108 → 20 は 40.8、60 は 74.4（幅 33.6）
      expect(x, closeTo(24 + 0.2 * 84, 0.01));
      expect(w, closeTo(0.4 * 84, 0.01));
    });

    test('SVG: ひげ（最小〜q1、q3〜最大）・端の短い縦線・中央値の縦線・箱の高さと濃さ', () {
      final c = ChartSpec.fromJson(boxJson(cats: ['A'], v: five5([0], [20], [50], [60], [100])));
      final svg = c.toSvg();
      // 軸 0〜100 → x = 24 + 0.84·v。1 項目なので行の高さ 54、中心 y = 35、箱の高さ 27
      expect(svg.contains('<line x1="24" y1="35" x2="40.8" y2="35"/>'), isTrue, reason: '最小〜q1 のひげ');
      expect(svg.contains('<line x1="74.4" y1="35" x2="108" y2="35"/>'), isTrue, reason: 'q3〜最大 のひげ');
      expect(svg.contains('<line x1="24" y1="26" x2="24" y2="44"/>'), isTrue, reason: '最小の端');
      expect(svg.contains('<line x1="108" y1="26" x2="108" y2="44"/>'), isTrue, reason: '最大の端');
      expect(svg.contains('<line x1="66" y1="21.5" x2="66" y2="48.5"/>'), isTrue, reason: '中央値');
      expect(svg.contains('height="27" fill="currentColor" fill-opacity="0.2"/>'), isTrue, reason: '箱');
    });

    test('SVG: 値がすべて同じでも描ける。項目が 8 を超えると文字を小さくする', () {
      final same = ChartSpec.fromJson(boxJson(cats: ['A'], v: five5([5], [5], [5], [5], [5])));
      expect(same.toSvg().contains('NaN'), isFalse);
      List<String> cats(int n) => [for (var i = 0; i < n; i++) 'c$i'];
      List<List<num>> flat(int n) => five5(List.filled(n, 1), List.filled(n, 2), List.filled(n, 3), List.filled(n, 4), List.filled(n, 5));
      expect(ChartSpec.fromJson(boxJson(cats: cats(8), v: flat(8))).toSvg().contains('font-size="4" text-anchor="end"'), isTrue);
      expect(ChartSpec.fromJson(boxJson(cats: cats(9), v: flat(9))).toSvg().contains('font-size="3" text-anchor="end"'), isTrue);
    });
  });

  group('SVG', () {
    void common(String svg) {
      expect(svg.startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80"'), isTrue);
      expect(svg.endsWith('</svg>'), isTrue);
      expect(svg.contains('currentColor'), isTrue);
      expect(RegExp(r'#[0-9a-fA-F]{3,6}').hasMatch(svg), isFalse);
      expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse);
    }

    test('雨温図: 棒 12 本・折れ線 1 本・両側の目盛り・月のラベル', () {
      final svg = _climate().toSvg();
      common(svg);
      expect(_count(svg, '<rect'), 12);
      expect(_count(svg, '<polyline'), 1);
      expect(_count(svg, '<circle'), 12);
      for (final m in ['1', '12']) {
        expect(svg.contains('>$m</text>'), isTrue);
      }
      // 左: 気温 5〜30（5 刻み・6 本）、右: 降水量 0〜250（同じ 6 本。横線を共有する）
      expect(svg.contains('text-anchor="end" fill="currentColor" stroke="none">30</text>'), isTrue);
      expect(svg.contains('text-anchor="end" fill="currentColor" stroke="none">5</text>'), isTrue);
      expect(svg.contains('text-anchor="start" fill="currentColor" stroke="none">250</text>'), isTrue);
      expect(svg.contains('text-anchor="start" fill="currentColor" stroke="none">0</text>'), isTrue);
      expect(_count(svg, 'text-anchor="end"'), 6);
      expect(_count(svg, 'text-anchor="start"'), 6);
    });

    test('雨温図: 降水量が少なくても、右の軸は左と同じ本数の目盛り（横線を共有）', () {
      final svg = _p('climate', ['1', '2', '3'], [[5, 20, 30], [2, 4, 12]]).toSvg();
      expect(_count(svg, 'text-anchor="end"'), 6);
      expect(_count(svg, 'text-anchor="start"'), 6);
      expect(svg.contains('stroke="none">25</text>'), isTrue);
    });

    test('雨温図: 気温がすべて負でも描ける', () {
      final svg = _p('climate', ['1', '2', '3'], [[-20, -15, -10], [10, 20, 30]]).toSvg();
      common(svg);
      expect(_count(svg, '<rect'), 3);
      expect(svg.contains('>-20</text>'), isTrue);
    });

    test('雨温図: 降水量がすべて 0 でも描ける', () {
      final svg = _p('climate', ['1', '2'], [[1, 2], [0, 0]]).toSvg();
      common(svg);
    });

    test('棒グラフ: 系列 × 項目の数だけ棒', () {
      final svg = _p('bars', ['a', 'b', 'c'], [[1, 2, 3], [3, 2, 1]]).toSvg();
      common(svg);
      expect(_count(svg, '<rect'), 6);
      final single = _p('bars', ['a', 'b'], [[5, 10]]).toSvg();
      expect(_count(single, '<rect'), 2);
      expect(single.contains('fill-opacity="0.55"'), isTrue);
      expect(single.contains('>0</text>'), isTrue); // 棒の軸は 0 から（全部正でも）
      expect(svg.contains('fill-opacity="0.15"'), isTrue);
    });

    test('折れ線: 系列ごとに線 1 本。2 本目は破線', () {
      final svg = _p('line', ['a', 'b', 'c'], [[1, 2, 3], [3, 2, 1], [0, 0, 0]]).toSvg();
      common(svg);
      expect(_count(svg, '<polyline'), 3);
      expect(_count(svg, 'stroke-dasharray="3 2"'), 1);
      expect(_count(svg, '<circle'), 9);
    });

    test('折れ線: 値がすべて同じでも描ける', () {
      common(_p('line', ['a', 'b'], [[5, 5]]).toSvg());
      common(_p('line', ['a', 'b'], [[0, 0]]).toSvg());
    });

    test('人口ピラミッド: 左右の棒と年齢層のラベル', () {
      final svg = _p('pyramid', ['0-14', '15-64', '65-'], [[10, 30, 20], [9, 31, 25]]).toSvg();
      common(svg);
      expect(_count(svg, '<rect'), 6);
      expect(svg.contains('>0-14</text>'), isTrue);
      expect(svg.contains('>65-</text>'), isTrue);
      expect(_count(svg, '>0</text>'), 1); // 中央の 0 は 1 回だけ
      expect(_count(svg, 'stroke-opacity="0.25"'), 4); // 目盛り 20・40 の補助線が左右に 2 本ずつ（0 の線は中心線）
    });

    test('円グラフ: 0 の項目は描かない。1 項目だけなら円', () {
      final svg = _p('pie', ['a', 'b', 'c'], [[1, 0, 3]]).toSvg();
      common(svg);
      expect(_count(svg, '<path'), 2);
      expect(svg.contains('>b</text>'), isFalse);
      final one = _p('pie', ['a', 'b'], [[0, 5]]).toSvg();
      expect(_count(one, '<circle'), 1);
      expect(_count(one, '<path'), 0);
      // 半分より大きい扇は large-arc フラグが 1
      final big = _p('pie', ['a', 'b'], [[3, 1]]).toSvg();
      expect(big.contains('A28 28 0 1 1'), isTrue);
      final small = _p('pie', ['a', 'b'], [[1, 1]]).toSvg();
      expect(small.contains('A28 28 0 1 1'), isFalse);
    });

    test('文字は XML エスケープする', () {
      final svg = _p('bars', ['<a&"b">'], [[1]]).toSvg();
      expect(svg.contains('&lt;a&amp;&quot;b&quot;&gt;'), isTrue);
      expect(svg.contains('<a&'), isFalse);
    });

    test('項目が 12 を超えたら文字を小さくする', () {
      List<String> cats(int n) => [for (var i = 0; i < n; i++) 'c$i'];
      for (final kind in ['bars', 'pyramid']) {
        final series = kind == 'pyramid' ? [List.filled(12, 1), List.filled(12, 1)] : [List.filled(12, 1)];
        final twelve = _p(kind, cats(12), series).toSvg();
        final more = _p(kind, cats(13), [for (final s in series) [...s, 1]]).toSvg();
        expect(twelve.contains('font-size="${kind == 'bars' ? '4' : '3.5'}" text-anchor="${kind == 'bars' ? 'middle' : 'end'}"'), isTrue, reason: kind);
        expect(more.contains('font-size="3" text-anchor="${kind == 'bars' ? 'middle' : 'end'}"'), isTrue, reason: kind);
      }
    });

    test('同じ仕様なら同じ SVG', () {
      expect(_climate().toSvg(), _climate().toSvg());
    });
  });
}
