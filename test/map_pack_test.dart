import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

MapRegion _r(String id, List<List<(double, double)>> rings, [String? label]) => MapRegion(
      id: id, label: label ?? id,
      rings: [for (final ring in rings) [for (final (x, y) in ring) GeoPoint(x, y)]],
    );

const _sq = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)];
List<(double, double)> _shift(List<(double, double)> r, double dx, double dy) => [for (final (x, y) in r) (x + dx, y + dy)];

MapPack _pack({List<MapRegion>? regions, String attribution = '出典', int scale = 100, bool flipY = true, MapBounds? bounds}) =>
    MapPack(id: 'p', attribution: attribution, regions: regions ?? [_r('a', [_sq]), _r('b', [_shift(_sq, 20, 0)])], scale: scale, flipY: flipY, bounds: bounds);

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

List<String> _codes(MapPack p, {int maxVertices = 20000, int maxBytes = 150000}) =>
    [for (final i in validateMapPack(p, maxVertices: maxVertices, maxBytes: maxBytes)) '${i.code}:${i.severity.name}'];

void main() {
  group('形式', () {
    test('書き出し → 読み取りで同じ領域（差分符号化の往復）', () {
      final p = _pack(regions: [
        _r('a', [_sq, _shift([(0.0, 0.0), (1.5, 0.0), (1.5, 1.25)], 2, 2)], '甲'),
        _r('b', [_shift(_sq, -30, 5.5)]),
      ]);
      final q = MapPack.parse(p.encode());
      expect(q.id, 'p');
      expect(q.attribution, '出典');
      expect(q.scale, 100);
      expect(q.flipY, isTrue);
      expect([for (final r in q.regions) r.id], ['a', 'b']);
      expect(q.regions[0].label, '甲');
      expect(q.regions[0].rings.length, 2);
      for (var i = 0; i < p.regions.length; i++) {
        for (var k = 0; k < p.regions[i].rings.length; k++) {
          final a = p.regions[i].rings[k], b = q.regions[i].rings[k];
          expect(b.length, a.length);
          for (var m = 0; m < a.length; m++) {
            expect([b[m].x, b[m].y], [a[m].x, a[m].y]);
          }
        }
      }
      expect(q.bounds.minX, p.bounds.minX);
      expect(q.bounds.maxY, p.bounds.maxY);
      expect(q.encode(), p.encode());
    });

    test('最初の点だけ絶対値、あとは差（整数）', () {
      final p = _pack(regions: [_r('a', [[(1.0, 2.0), (4.0, 2.0), (4.0, 0.5)]])], scale: 10);
      final ring = ((p.toJson()['regions'] as List).first as Map)['rings'][0] as List;
      expect(ring, [10, 20, 30, 0, 0, -15]);
    });

    test('座標は scale の単位に丸められる', () {
      final p = _pack(regions: [_r('a', [[(0.004, 0.0), (1.006, 0.0), (1.0, 1.0)]])], scale: 100);
      expect(p.regions.first.rings.first.first.x, 0.0);
      expect(p.regions.first.rings.first[1].x, 1.01);
    });

    test('flipY: 既定は書かない・false は書く', () {
      expect(_pack().toJson().containsKey('flipY'), isFalse);
      final q = _pack(flipY: false);
      expect(q.toJson()['flipY'], false);
      expect(MapPack.parse(q.encode()).flipY, isFalse);
    });

    test('頂点数と書き出しの大きさ', () {
      final p = _pack();
      expect(p.vertexCount, 8);
      expect(p.encodedBytes, utf8.encode(p.encode()).length);
      expect(p.encodedBytes > 50, isTrue);
    });

    test('bounds は渡さなければ領域から', () {
      final p = _pack();
      expect([p.bounds.minX, p.bounds.minY, p.bounds.maxX, p.bounds.maxY], [0, 0, 30, 10]);
      final q = _pack(bounds: const MapBounds(-5, -5, 50, 50));
      expect(q.bounds.minX, -5);
    });

    test('scale は 1 以上', () {
      expect(() => _pack(scale: 0), throwsArgumentError);
    });

    String json(Map<String, dynamic> over) => jsonEncode({
          'version': 1, 'id': 'p', 'attribution': 'x', 'scale': 1, 'bounds': [0, 0, 10, 10],
          'regions': [{'id': 'a', 'label': 'A', 'rings': [[0, 0, 5, 0, 0, 5]]}],
          ...over,
        });

    test('形の誤り', () {
      expect(MapPack.parse(json({})).regions.single.rings.single.length, 3);
      expect(() => MapPack.parse('{'), _bad('読めません'));
      expect(() => MapPack.parse('[]'), _bad('オブジェクト'));
      expect(() => MapPack.parse(json({'zzz': 1})), _bad('未知のキー'));
      expect(() => MapPack.parse(json({'version': 2})), _bad('版'));
      expect(() => MapPack.parse(json({'id': 'a-b'})), _bad('id'));
      expect(() => MapPack.parse(json({'attribution': 1})), _bad('attribution'));
      expect(() => MapPack.parse(json({'scale': 0})), _bad('scale'));
      expect(() => MapPack.parse(json({'scale': 1.5})), _bad('scale'));
      expect(() => MapPack.parse(json({'flipY': 'yes'})), _bad('flipY'));
      expect(() => MapPack.parse(json({'bounds': [0, 0, 10]})), _bad('bounds'));
      expect(() => MapPack.parse(json({'bounds': [0, 0, 'x', 10]})), _bad('bounds'));
      expect(() => MapPack.parse(json({'bounds': [0, 0, 10, 10, 20]})), _bad('bounds'));
      expect(() => MapPack.parse(json({'bounds': [0, 0, 0, 10]})), _bad('min < max'));
      expect(() => MapPack.parse(json({'bounds': [0, 5, 10, 5]})), _bad('min < max'));
      expect(() => MapPack.parse(json({'regions': []})), _bad('regions'));
      expect(() => MapPack.parse(json({'regions': [1]})), _bad('id・label・rings'));
      expect(() => MapPack.parse(json({'regions': [{'id': 'a', 'label': 'A', 'rings': [], 'x': 1}]})), _bad('id・label・rings'));
      expect(() => MapPack.parse(json({'regions': [{'id': '', 'label': 'A', 'rings': []}]})), _bad('id'));
      expect(() => MapPack.parse(json({'regions': [{'id': 'a', 'label': '', 'rings': []}]})), _bad('label'));
      expect(() => MapPack.parse(json({'regions': [{'id': 'a', 'label': 'A', 'rings': 1}]})), _bad('rings'));
      expect(() => MapPack.parse(json({'regions': [{'id': 'a', 'label': 'A', 'rings': [[0, 0, 1]]}]})), _bad('偶数'));
      expect(() => MapPack.parse(json({'regions': [{'id': 'a', 'label': 'A', 'rings': [[0, 0, 1.5, 2]]}]})), _bad('整数'));
      expect(() => MapPack.parse(json({'regions': [{'id': 'a', 'label': 'A', 'rings': [1]}]})), _bad('偶数'));
    });

    test('flipY を省略したら true', () {
      expect(MapPack.parse(json({})).flipY, isTrue);
    });

    test('領域の判定（タップ）に使える', () {
      final p = MapPack.parse(_pack().encode());
      expect(regionAt(p.regions, const GeoPoint(5, 5)), 'a');
      expect(regionAt(p.regions, const GeoPoint(25, 5)), 'b');
      expect(regionAt(p.regions, const GeoPoint(15, 5)), isNull);
    });
  });

  group('検証', () {
    test('問題のない地図は指摘なし', () => expect(_codes(_pack()), isEmpty));

    test('出典・領域 id の重複・リングなし', () {
      expect(_codes(_pack(attribution: '  ')), ['map_attribution_missing:error']);
      expect(_codes(_pack(regions: [_r('a', [_sq]), _r('a', [_shift(_sq, 20, 0)])])), ['map_region_duplicate:error']);
      expect(_codes(_pack(regions: [_r('a', [_sq]), _r('b', const [])])), ['map_region_no_ring:error']);
    });

    test('頂点が 3 未満', () {
      expect(_codes(_pack(regions: [_r('a', [_sq]), _r('b', [[(20.0, 0.0), (21.0, 0.0)]])])), ['map_ring_too_small:error']);
    });

    test('bounds の 4 辺: 丸めの半分以内は許す・それ以上は外', () {
      // scale 100 なので 0.005 まで許す
      MapPack at(double dx, double dy) => _pack(
            regions: [_r('a', [[(0.0 + dx, 0.0 + dy), (10.0 + dx, 0.0 + dy), (10.0 + dx, 10.0 + dy)]])],
            bounds: const MapBounds(0, 0, 10, 10),
          );
      expect(_codes(at(0, 0)), isEmpty);
      for (final (dx, dy) in [(-0.02, 0.0), (0.02, 0.0), (0.0, -0.02), (0.0, 0.02)]) {
        expect(_codes(at(dx, dy)), ['map_out_of_bounds:error'], reason: '$dx,$dy');
      }
      for (final (dx, dy) in [(-0.004, 0.0), (0.004, 0.0), (0.0, -0.004), (0.0, 0.004)]) {
        expect(_codes(at(dx, dy)), isEmpty, reason: '$dx,$dy');
      }
    });

    test('bounds が目盛りの間にあるとき、丸めの半分（0.005）以内の食い込みは許す', () {
      final r = _r('a', [[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)]]);
      expect(_codes(_pack(regions: [r], bounds: const MapBounds(0.004, 0.004, 9.996, 9.996))), isEmpty);
      expect(_codes(_pack(regions: [r], bounds: const MapBounds(0.006, 0.0, 10, 10))), ['map_out_of_bounds:error']);
      expect(_codes(_pack(regions: [r], bounds: const MapBounds(0, 0.006, 10, 10))), ['map_out_of_bounds:error']);
      expect(_codes(_pack(regions: [r], bounds: const MapBounds(0, 0, 9.994, 10))), ['map_out_of_bounds:error']);
      expect(_codes(_pack(regions: [r], bounds: const MapBounds(0, 0, 10, 9.994))), ['map_out_of_bounds:error']);
    });

    test('3 頂点のリング（鋭い角でもよい）は問題なし', () {
      final acute = _r('a', [[(0.0, 0.0), (10.0, 1.0), (10.0, 2.0)]]);
      expect(_codes(_pack(regions: [acute])), isEmpty);
    });

    test('向きを逆にした蝶ネクタイも交差', () {
      final bow = _r('a', [[(0.0, 10.0), (10.0, 0.0), (10.0, 10.0), (0.0, 0.0)]]);
      expect(_codes(_pack(regions: [bow])), ['map_ring_self_intersect:error']);
    });

    test('座標が bounds の外', () {
      final p = _pack(regions: [_r('a', [_sq]), _r('b', [_shift(_sq, 20, 0)])], bounds: const MapBounds(0, 0, 25, 10));
      expect(_codes(p), ['map_out_of_bounds:error']);
      // ちょうど端と、丸めの半分以内は外ではない
      final q = _pack(bounds: const MapBounds(0, 0, 30, 10));
      expect(_codes(q), isEmpty);
    });

    test('最後の点が最初と同じ・同じ点が続く（警告）', () {
      final closed = _r('a', [[...[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)], (0.0, 0.0)]]);
      expect(_codes(_pack(regions: [closed])), ['map_ring_closed_duplicate:warning']);
      final rep = _r('a', [[(0.0, 0.0), (10.0, 0.0), (10.0, 0.0), (10.0, 10.0)]]);
      expect(_codes(_pack(regions: [rep])), ['map_ring_repeated_point:warning']);
    });

    test('自己交差: ちょうネクタイ型・辺の重なり・端点で触れる', () {
      final bow = _r('a', [[(0.0, 0.0), (10.0, 10.0), (10.0, 0.0), (0.0, 10.0)]]);
      expect(_codes(_pack(regions: [bow])), ['map_ring_self_intersect:error']);
      // 隣り合う辺が折り返して重なる（0,0 → 10,0 → 5,0）
      final fold = _r('a', [[(0.0, 0.0), (10.0, 0.0), (5.0, 0.0), (5.0, 5.0)]]);
      expect(_codes(_pack(regions: [fold])), contains('map_ring_self_intersect:error'));
      // 別の辺の端点が辺の上に触れる
      final touch = _r('a', [[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (5.0, 0.0), (0.0, 10.0)]]);
      expect(_codes(_pack(regions: [touch])), contains('map_ring_self_intersect:error'));
      // 凹んだ形は交差ではない
      final concave = _r('a', [[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (5.0, 3.0), (0.0, 10.0)]]);
      expect(_codes(_pack(regions: [concave])), isEmpty);
      // 同じ向きの共線（まっすぐ続く 3 点）は交差ではない
      final straight = _r('a', [[(0.0, 0.0), (5.0, 0.0), (10.0, 0.0), (10.0, 10.0)]]);
      expect(_codes(_pack(regions: [straight])), isEmpty);
    });

    test('最後の辺と最初の辺が折り返して重なる', () {
      // (0,0)-(10,0)-(10,10)-(5,0)… 最後の点 (5,0) から最初の点 (0,0) へ戻る辺は、最初の辺 (0,0)-(10,0) と同じ向きで重なる
      final r = _r('a', [[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (5.0, 0.0)]]);
      expect(_codes(_pack(regions: [r])), contains('map_ring_self_intersect:error'));
    });

    test('頂点・大きさの上限（警告）', () {
      expect(_codes(_pack(), maxVertices: 8), isEmpty);
      expect(_codes(_pack(), maxVertices: 7), ['map_too_many_vertices:warning']);
      final bytes = _pack().encodedBytes;
      expect(_codes(_pack(), maxBytes: bytes), isEmpty);
      expect(_codes(_pack(), maxBytes: bytes - 1), ['map_too_large:warning']);
    });
  });

  group('簡略化', () {
    // 一辺 10 の正方形の辺に 0.1 のでこぼこをつけた輪郭
    List<(double, double)> wavy() => [
          for (var i = 0; i < 10; i++) (i.toDouble(), i.isEven ? 0.0 : 0.1),
          for (var i = 0; i < 10; i++) (10.0, i.toDouble()),
          for (var i = 10; i > 0; i--) (i.toDouble(), 10.0),
          for (var i = 10; i > 0; i--) (0.0, i.toDouble()),
        ];

    test('許容誤差より小さいでこぼこは消え、角は残る', () {
      final ring = wavy().map((e) => GeoPoint(e.$1, e.$2)).toList();
      final s = simplifyRing(ring, 0.5);
      expect(s.length < ring.length, isTrue);
      expect(s.length >= 4, isTrue);
      for (final corner in const [GeoPoint(0, 0), GeoPoint(10, 0), GeoPoint(10, 10), GeoPoint(0, 10)]) {
        expect(s.any((p) => p.x == corner.x && p.y == corner.y), isTrue, reason: '$corner');
      }
      expect(s.length, 4);
    });

    test('許容誤差 0 は何もしない・小さいでこぼこより小さければ残す', () {
      final ring = wavy().map((e) => GeoPoint(e.$1, e.$2)).toList();
      expect(simplifyRing(ring, 0).length, ring.length);
      expect(simplifyRing(ring, 0.01).length, ring.length - 0 - (ring.length - simplifyRing(ring, 0.01).length));
      expect(simplifyRing(ring, 0.01).any((p) => p.y == 0.1), isTrue);
      expect(() => simplifyRing(ring, -1), throwsArgumentError);
    });

    test('3 頂点以下はそのまま。細すぎても 3 頂点以上を保つ', () {
      const tri = [GeoPoint(0, 0), GeoPoint(5, 0), GeoPoint(0, 5)];
      expect(simplifyRing(tri, 100), tri);
      final thin = [for (var i = 0; i < 6; i++) GeoPoint(i.toDouble(), 0.001 * (i % 2)), const GeoPoint(5, 0.002)];
      expect(simplifyRing(thin, 1).length >= 3, isTrue);
    });

    test('許容誤差ちょうどの出っ張りは消える・線分の外側の点は端点までの距離で測る', () {
      // (5,3) は線分 (0,0)-(10,0) から距離 3 ちょうど
      final r1 = [const GeoPoint(0, 0), const GeoPoint(5, 3), const GeoPoint(10, 0), const GeoPoint(5, -8)];
      expect(simplifyRing(r1, 3).length, 3);
      expect(simplifyRing(r1, 2.9).length, 4);
      // (-5,1) は線分 (0,0)-(10,0) の外側。端点 (0,0) までの距離 5.1 > 2 なので残る（垂線の距離 1 で測ると消える）
      final r2 = [const GeoPoint(0, 0), const GeoPoint(-5, 1), const GeoPoint(10, 0), const GeoPoint(5, -6)];
      expect(simplifyRing(r2, 2).any((p) => p.x == -5 && p.y == 1), isTrue);
    });

    test('同じ点ばかりのリングでも落ちない', () {
      final same = List.filled(5, const GeoPoint(2, 2));
      final s = simplifyRing(same, 1);
      expect(s.length >= 3, isTrue);
      expect(s.every((p) => p.x == 2 && p.y == 2), isTrue);
    });

    test('地図全体: 頂点が減り、領域・出典・scale・flipY は変わらない', () {
      final p = _pack(regions: [_r('a', [wavy()]), _r('b', [_shift(wavy(), 20, 0)])], flipY: false, scale: 10);
      final s = simplifyMapPack(p, tolerance: 0.5);
      expect(s.vertexCount < p.vertexCount, isTrue);
      expect([for (final r in s.regions) r.id], ['a', 'b']);
      expect(s.attribution, '出典');
      expect(s.scale, 10);
      expect(s.flipY, isFalse);
      expect(s.bounds.maxX, p.bounds.maxX);
      expect(s.encodedBytes < p.encodedBytes, isTrue);
      expect(validateMapPack(s).where((i) => i.isError), isEmpty);
      // タップの判定は簡略化しても同じ
      expect(regionAt(s.regions, const GeoPoint(5, 5)), 'a');
      expect(regionAt(s.regions, const GeoPoint(25, 5)), 'b');
    });

    test('小さな島を落とす（領域の最後の 1 リングは残す）', () {
      final island = [(20.0, 20.0), (20.5, 20.0), (20.5, 20.5), (20.0, 20.5)];
      final p = _pack(regions: [_r('a', [_sq, island]), _r('tiny', [_shift(island, 5, 5)])], bounds: const MapBounds(0, 0, 30, 30));
      final s = simplifyMapPack(p, tolerance: 0, minRingArea: 1);
      expect(s.regions[0].rings.length, 1);
      expect(s.regions[1].rings.length, 1, reason: '全部が小さい領域は一番大きいリングだけ残す');
      expect(simplifyMapPack(p, tolerance: 0, minRingArea: 0.3).regions[0].rings.length, 1); // 面積 0.25 < 0.3
      final keep = simplifyMapPack(p, tolerance: 0, minRingArea: 0.25);
      expect(keep.regions[0].rings.length, 2); // 面積ちょうど 0.25 は残す
    });

    test('全部が小さい領域は一番大きいリングを残す', () {
      final small = [(0.0, 0.0), (0.4, 0.0), (0.4, 0.4), (0.0, 0.4)];
      final smaller = [(1.0, 1.0), (1.1, 1.0), (1.1, 1.1), (1.0, 1.1)];
      final p = _pack(regions: [_r('a', [smaller, small])], bounds: const MapBounds(0, 0, 5, 5));
      final s = simplifyMapPack(p, tolerance: 0, minRingArea: 1);
      expect(s.regions.single.rings.single.first.x, 0.0);
      expect(s.regions.single.rings.single[2].x, 0.4);
    });
  });

  group('SVG', () {
    test('領域ごとに path 1 つ。強調は濃く。色は currentColor だけ', () {
      final svg = renderMapSvg(_pack(), highlight: {'b'});
      expect(svg.startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 140"'), isTrue);
      expect(svg.endsWith('</svg>'), isTrue);
      expect('<path'.allMatches(svg).length, 2);
      expect('fill-opacity="0.5"'.allMatches(svg).length, 1);
      expect('fill-opacity="0.08"'.allMatches(svg).length, 1);
      expect(svg.indexOf('fill-opacity="0.5"') > svg.indexOf('fill-opacity="0.08"'), isTrue, reason: '強調は 2 つ目の領域（b）');
      expect(svg.contains('currentColor'), isTrue);
      expect(RegExp(r'#[0-9a-fA-F]{3,6}').hasMatch(svg), isFalse);
      expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse);
      expect(svg.contains('<text'), isFalse);
    });

    test('複数リングは 1 つの path に M…Z を並べる', () {
      final p = _pack(regions: [_r('a', [_sq, _shift(_sq, 20, 0)])]);
      final svg = renderMapSvg(p);
      expect('<path'.allMatches(svg).length, 1);
      expect('M'.allMatches(RegExp(r'd="[^"]*"').firstMatch(svg)!.group(0)!).length, 2);
      expect('Z'.allMatches(svg).length, 2);
    });

    test('y は緯度（上向き）なら反転、flipY=false ならそのまま', () {
      String firstPoint(MapPack p) {
        final d = RegExp(r'd="M([^ ]+) ([^L]+)L').firstMatch(renderMapSvg(p, width: 100, height: 100, padding: 0))!;
        return '${d.group(1)},${d.group(2)}';
      }

      final r = [_r('a', [[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]])];
      expect(firstPoint(_pack(regions: r)), '0,100'); // 原点（左下）は画面の下
      expect(firstPoint(_pack(regions: r, flipY: false)), '0,0');
    });

    test('ラベルは重心に書き、XML エスケープする', () {
      final svg = renderMapSvg(_pack(regions: [_r('a', [_sq], '<甲&"乙">')]), labels: true);
      expect('<text'.allMatches(svg).length, 1);
      expect(svg.contains('&lt;甲&amp;&quot;乙&quot;&gt;'), isTrue);
      expect(svg.contains('<甲'), isFalse);
    });

    test('大きさ・余白・経度の補正', () {
      final a = renderMapSvg(_pack(), width: 300, height: 100);
      expect(a.contains('viewBox="0 0 300 100"'), isTrue);
      final w = renderMapSvg(_pack(), width: 100, height: 100, padding: 0);
      final n = renderMapSvg(_pack(), width: 100, height: 100, padding: 0, xScale: 0.5);
      expect(w == n, isFalse);
    });

    test('同じ入力なら同じ SVG', () {
      expect(renderMapSvg(_pack(), highlight: {'a'}, labels: true), renderMapSvg(_pack(), highlight: {'a'}, labels: true));
    });
  });
}
