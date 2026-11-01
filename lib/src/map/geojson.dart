import 'dart:convert';

import '../question/map_tap.dart';
import 'map_pack.dart';

/// GeoJSON（`FeatureCollection`。`Polygon`・`MultiPolygon`）から [MapPack] を作る。
/// - 領域の ID は各 Feature の `properties[idProperty]`、表示名は `properties[labelProperty]`（どちらも空でない文字列）。
/// - 外側のリングだけを使う（穴＝内側のリングは捨てる。穴を別の領域として判定に使うと、穴の中が元の領域でなくなるため。
///   飛び地は元の領域のリングとして残る）。閉じるための最後の点は取り除く。
/// - 座標は `[経度, 緯度]`（3 つ目以降は無視）。[scale] の単位（既定 1000 = 0.001 度）に丸め、続けて同じ点になったもの・
///   行って戻るだけのとげは取り除く。丸めたあとに 3 頂点未満になったリングは捨てる。
///   粗い [scale]（世界 110m で 100 など）は、近い辺が丸めで交差することがある（`validateMapPack` で見つかる）。
///   [only] を渡すと、その ID の領域だけを使う。使えるリングが 1 つも無い領域は [FormatException]。
/// 読めなければ [FormatException]。簡略化は [simplifyMapPack]、検証は [validateMapPack]。
MapPack mapPackFromGeoJson(
  String source, {
  required String id,
  required String attribution,
  String idProperty = 'ADM0_A3',
  String labelProperty = 'NAME_JA',
  int scale = 1000,
  Set<String>? only,
}) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } on FormatException catch (e) {
    throw FormatException('GeoJSON を読めません: ${e.message}');
  }
  if (j is! Map || j['type'] != 'FeatureCollection' || j['features'] is! List) {
    throw const FormatException('GeoJSON は FeatureCollection です');
  }
  final regions = <MapRegion>[];
  final seen = <String>{};
  for (final f in j['features'] as List) {
    if (f is! Map) throw const FormatException('Feature はオブジェクトです');
    final props = f['properties'];
    if (props is! Map) throw const FormatException('Feature に properties がありません');
    final rid = props[idProperty], label = props[labelProperty];
    if (rid is! String || rid.isEmpty) throw FormatException('$idProperty が空でない文字列ではありません: $rid');
    if (only != null && !only.contains(rid)) continue;
    if (label is! String || label.isEmpty) throw FormatException('$rid: $labelProperty が空でない文字列ではありません');
    if (!seen.add(rid)) throw FormatException('領域の id が重複しています: $rid');
    final g = f['geometry'];
    if (g is! Map) throw FormatException('$rid: geometry がありません');
    final polygons = switch (g['type']) {
      'Polygon' => [g['coordinates']],
      'MultiPolygon' => g['coordinates'],
      final t => throw FormatException('$rid: 未対応の geometry: $t'),
    };
    if (polygons is! List) throw FormatException('$rid: coordinates が配列ではありません');
    final rings = <List<GeoPoint>>[];
    for (final poly in polygons) {
      if (poly is! List || poly.isEmpty) throw FormatException('$rid: ポリゴンが空です');
      final ring = _ring(poly.first, rid, scale);
      if (ring.length >= 3) rings.add(ring);
    }
    if (rings.isEmpty) throw FormatException('$rid: 使えるリングがありません');
    regions.add(MapRegion(id: rid, label: label, rings: rings));
  }
  if (regions.isEmpty) throw const FormatException('領域がありません');
  return MapPack(id: id, attribution: attribution, regions: regions, scale: scale);
}

List<GeoPoint> _ring(Object? raw, String rid, int scale) {
  if (raw is! List) throw FormatException('$rid: リングが配列ではありません');
  final out = <GeoPoint>[];
  for (final p in raw) {
    if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num) {
      throw FormatException('$rid: 座標は [経度, 緯度]');
    }
    final x = (p[0] as num).toDouble(), y = (p[1] as num).toDouble();
    if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) throw FormatException('$rid: 座標が数ではありません');
    final q = GeoPoint((x * scale).roundToDouble() / scale, (y * scale).roundToDouble() / scale);
    if (out.isEmpty || out.last.x != q.x || out.last.y != q.y) out.add(q);
  }
  // 丸めで「A→B→A」のような行って戻るだけのとげができる。とげの先を取り除き、できた重複もまとめる（変わらなくなるまで）
  var changed = true;
  while (changed && out.length >= 3) {
    changed = false;
    for (var i = 0; i < out.length && out.length >= 3; i++) {
      final prev = out[(i - 1 + out.length) % out.length], cur = out[i], next = out[(i + 1) % out.length];
      final same = prev.x == cur.x && prev.y == cur.y; // 続けて同じ点（最後と最初が同じ場合を含む）
      final spike = prev.x == next.x && prev.y == next.y; // 行って戻る
      if (same || spike) {
        out.removeAt(same && i == 0 ? out.length - 1 : i); // 最後と最初が同じなら、最後の方を捨てる
        changed = true;
        break;
      }
    }
  }
  return out;
}
