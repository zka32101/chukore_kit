import 'dart:convert';
import 'dart:math' as math;

import '../bank/question_bank.dart';
import '../question/map_tap.dart';
import '../question/map_viewport.dart';

/// 地図データ 1 枚（世界の国・日本の都道府県など）。形式・検証・簡略化・SVG 出力。
/// 境界線のデータそのものはコンテンツ側（`chukore_<国>_shakai`）が持つ。出典の記載が必須。
///
/// JSON（`map_packs/*.json`）:
/// `{"version":1,"id":"world","attribution":"出典","scale":100,"flipY":true,"bounds":[minX,minY,maxX,maxY],`
/// `"regions":[{"id":"jp","label":"日本","rings":[[x0,y0,dx1,dy1,dx2,dy2,…]]}]}`
/// 座標は整数（1 / [scale] の単位）。リングは最初の点だけ絶対値、あとは直前の点からの差（容量を抑える）。
/// リングは閉じる点を繰り返さない（最後の点から最初の点へ自動で閉じる）。`bounds` は実数の座標（経緯度など）。
class MapPack {
  const MapPack._({
    required this.id,
    required this.attribution,
    required this.scale,
    required this.flipY,
    required this.bounds,
    required this.regions,
  });

  /// 実数の座標の領域から作る（座標は [scale] の単位に丸められる）。
  factory MapPack({
    required String id,
    required String attribution,
    required List<MapRegion> regions,
    int scale = 100,
    bool flipY = true,
    MapBounds? bounds,
  }) {
    if (scale < 1) throw ArgumentError('scale は 1 以上');
    return MapPack._(
      id: id,
      attribution: attribution,
      scale: scale,
      flipY: flipY,
      bounds: bounds ?? MapBounds.of(regions),
      regions: [
        for (final r in regions)
          MapRegion(id: r.id, label: r.label, rings: [
            for (final ring in r.rings) [for (final p in ring) GeoPoint(_q(p.x, scale), _q(p.y, scale))],
          ]),
      ],
    );
  }

  static double _q(double v, int scale) => (v * scale).roundToDouble() / scale;

  final String id;

  /// 出典の表示（必須）。
  final String attribution;

  /// 整数座標 1 つ分が実数の座標でいくつか（1 / scale）。
  final int scale;

  /// y を上向き（緯度）として描くか。
  final bool flipY;
  final MapBounds bounds;
  final List<MapRegion> regions;

  int get vertexCount => regions.fold(0, (s, r) => s + r.rings.fold(0, (t, ring) => t + ring.length));

  static const _keys = {'version', 'id', 'attribution', 'scale', 'flipY', 'bounds', 'regions'};

  /// 読めなければ [FormatException]。
  factory MapPack.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('地図の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('地図の JSON はオブジェクトです');
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('未知のキー: ${unknown.join(', ')}');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final id = j['id'];
    if (id is! String || !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('id は英数字と _ だけ: $id');
    final attribution = j['attribution'];
    if (attribution is! String) throw const FormatException('attribution は文字列');
    final scale = j['scale'];
    if (scale is! int || scale < 1) throw const FormatException('scale は 1 以上の整数');
    final flipY = j['flipY'] ?? true;
    if (flipY is! bool) throw const FormatException('flipY は真偽');
    final rb = j['bounds'];
    if (rb is! List || rb.length != 4 || rb.any((e) => e is! num || e.isNaN || e.isInfinite)) {
      throw const FormatException('bounds は 4 つの数 [minX, minY, maxX, maxY]');
    }
    final b = [for (final e in rb) (e as num).toDouble()];
    if (!(b[0] < b[2] && b[1] < b[3])) throw const FormatException('bounds は min < max');
    final rr = j['regions'];
    if (rr is! List || rr.isEmpty) throw const FormatException('regions が必要です');
    final regions = <MapRegion>[];
    for (final r in rr) {
      if (r is! Map || r.keys.any((k) => k != 'id' && k != 'label' && k != 'rings')) {
        throw const FormatException('領域は id・label・rings だけ');
      }
      final rid = r['id'], label = r['label'];
      if (rid is! String || rid.isEmpty) throw const FormatException('領域の id は空でない文字列');
      if (label is! String || label.isEmpty) throw FormatException('$rid: label は空でない文字列');
      final rings = r['rings'];
      if (rings is! List) throw FormatException('$rid: rings は配列');
      regions.add(MapRegion(id: rid, label: label, rings: [for (final ring in rings) _decode(ring, rid, scale)]));
    }
    return MapPack._(
      id: id,
      attribution: attribution,
      scale: scale,
      flipY: flipY,
      bounds: MapBounds(b[0], b[1], b[2], b[3]),
      regions: regions,
    );
  }

  static List<GeoPoint> _decode(Object? ring, String rid, int scale) {
    if (ring is! List || ring.length.isOdd || ring.any((e) => e is! int)) {
      throw FormatException('$rid: リングは整数の偶数個（x0,y0,dx,dy,…）');
    }
    final out = <GeoPoint>[];
    var x = 0, y = 0;
    for (var i = 0; i < ring.length; i += 2) {
      x += ring[i] as int;
      y += ring[i + 1] as int;
      out.add(GeoPoint(x / scale, y / scale));
    }
    return out;
  }

  List<int> _encode(List<GeoPoint> ring) {
    final out = <int>[];
    var px = 0, py = 0;
    for (final p in ring) {
      final x = (p.x * scale).round(), y = (p.y * scale).round();
      out
        ..add(x - px)
        ..add(y - py);
      px = x;
      py = y;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'attribution': attribution,
    'scale': scale,
    if (!flipY) 'flipY': false,
    'bounds': [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY],
    'regions': [
      for (final r in regions) {'id': r.id, 'label': r.label, 'rings': [for (final ring in r.rings) _encode(ring)]},
    ],
  };

  /// 書き出した JSON（余分な空白なし）。
  String encode() => jsonEncode(toJson());

  /// 書き出した JSON の大きさ（バイト）。
  int get encodedBytes => utf8.encode(encode()).length;
}

// ───────────────────────── 検証 ─────────────────────────

/// 地図の検証。エラー: `map_attribution_missing`（出典が空）・`map_region_duplicate`・`map_region_no_ring`・
/// `map_ring_too_small`（頂点が 3 未満）・`map_ring_self_intersect`・`map_out_of_bounds`。
/// 警告: `map_ring_closed_duplicate`（最後の点が最初の点と同じ）・`map_ring_repeated_point`（同じ点が続く）・
/// `map_too_many_vertices`（頂点が [maxVertices] 超）・`map_too_large`（書き出しが [maxBytes] バイト超）。
List<ValidationIssue> validateMapPack(MapPack pack, {int maxVertices = 20000, int maxBytes = 150000}) {
  final issues = <ValidationIssue>[];
  void add(IssueSeverity s, String code, String id, String msg) => issues.add(ValidationIssue(s, code, id, msg));
  if (pack.attribution.trim().isEmpty) {
    add(IssueSeverity.error, 'map_attribution_missing', pack.id, '出典（attribution）がありません');
  }
  final seen = <String>{};
  final eps = 0.5 / pack.scale;
  final b = pack.bounds;
  for (final r in pack.regions) {
    if (!seen.add(r.id)) add(IssueSeverity.error, 'map_region_duplicate', r.id, '領域の id が重複しています');
    if (r.rings.isEmpty) add(IssueSeverity.error, 'map_region_no_ring', r.id, 'リングがありません');
    for (var k = 0; k < r.rings.length; k++) {
      final ring = r.rings[k];
      final where = '${r.id}[$k]';
      if (ring.length < 3) {
        add(IssueSeverity.error, 'map_ring_too_small', where, '頂点が 3 未満です（${ring.length}）');
        continue;
      }
      if (ring.any((p) => p.x < b.minX - eps || p.x > b.maxX + eps || p.y < b.minY - eps || p.y > b.maxY + eps)) {
        add(IssueSeverity.error, 'map_out_of_bounds', where, '座標が bounds の外にあります');
      }
      if (ring.first.x == ring.last.x && ring.first.y == ring.last.y) {
        add(IssueSeverity.warning, 'map_ring_closed_duplicate', where, '最後の点が最初の点と同じです（閉じる点は書かない）');
      }
      var repeated = false;
      for (var i = 0; i + 1 < ring.length; i++) {
        if (ring[i].x == ring[i + 1].x && ring[i].y == ring[i + 1].y) repeated = true;
      }
      if (repeated) add(IssueSeverity.warning, 'map_ring_repeated_point', where, '同じ点が続いています');
      if (_selfIntersects(_dedupe(ring))) add(IssueSeverity.error, 'map_ring_self_intersect', where, 'リングが自分と交差しています');
    }
  }
  if (pack.vertexCount > maxVertices) {
    add(IssueSeverity.warning, 'map_too_many_vertices', pack.id, '頂点が多すぎます（${pack.vertexCount} > $maxVertices）。簡略化してください');
  }
  final bytes = pack.encodedBytes;
  if (bytes > maxBytes) {
    add(IssueSeverity.warning, 'map_too_large', pack.id, '書き出しが大きすぎます（$bytes > $maxBytes バイト）');
  }
  return issues;
}

/// 続けて同じ点（最後と最初が同じ場合を含む）を 1 つにしたリング。交差の判定は点の重複を除いてから行う。
List<GeoPoint> _dedupe(List<GeoPoint> ring) {
  final out = <GeoPoint>[];
  for (final p in ring) {
    if (out.isEmpty || out.last.x != p.x || out.last.y != p.y) out.add(p);
  }
  while (out.length > 1 && out.first.x == out.last.x && out.first.y == out.last.y) {
    out.removeLast();
  }
  return out;
}

double _cross(GeoPoint o, GeoPoint a, GeoPoint b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

bool _onSegment(GeoPoint a, GeoPoint b, GeoPoint p) =>
    math.min(a.x, b.x) <= p.x && p.x <= math.max(a.x, b.x) && math.min(a.y, b.y) <= p.y && p.y <= math.max(a.y, b.y);

/// 線分 ab と cd が（端点を含めて）交わるか。
bool _segmentsIntersect(GeoPoint a, GeoPoint b, GeoPoint c, GeoPoint d) {
  final d1 = _cross(a, b, c), d2 = _cross(a, b, d), d3 = _cross(c, d, a), d4 = _cross(c, d, b);
  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) return true;
  if (d1 == 0 && _onSegment(a, b, c)) return true;
  if (d2 == 0 && _onSegment(a, b, d)) return true;
  if (d3 == 0 && _onSegment(c, d, a)) return true;
  if (d4 == 0 && _onSegment(c, d, b)) return true;
  return false;
}

/// 隣り合わない辺どうしが交わる（または隣り合う辺が重なる）か。
bool _selfIntersects(List<GeoPoint> ring) {
  final n = ring.length;
  for (var i = 0; i < n; i++) {
    final a = ring[i], b = ring[(i + 1) % n];
    for (var j = i + 1; j < n; j++) {
      final c = ring[j], d = ring[(j + 1) % n];
      final adjacent = j == i + 1 || (i == 0 && j == n - 1);
      if (adjacent) {
        // 隣り合う辺は、共有する点から同じ向きに伸びて重なっていたら交差とみなす
        final shared = j == i + 1 ? b : a;
        final p = j == i + 1 ? a : b, q = j == i + 1 ? d : c;
        final dot = (p.x - shared.x) * (q.x - shared.x) + (p.y - shared.y) * (q.y - shared.y);
        if (_cross(shared, p, q) == 0 && dot > 0) return true;
        continue;
      }
      if (_segmentsIntersect(a, b, c, d)) return true;
    }
  }
  return false;
}

// ───────────────────────── 簡略化 ─────────────────────────

double _distToSegment(GeoPoint p, GeoPoint a, GeoPoint b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return math.sqrt(math.pow(p.x - a.x, 2) + math.pow(p.y - a.y, 2)).toDouble();
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  final cx = a.x + t * dx, cy = a.y + t * dy;
  return math.sqrt(math.pow(p.x - cx, 2) + math.pow(p.y - cy, 2)).toDouble();
}

/// Douglas–Peucker（開いた折れ線 [pts] の始点と終点は残す）。
List<GeoPoint> _dp(List<GeoPoint> pts, double tol) {
  if (pts.length < 3) return pts;
  final keep = List.filled(pts.length, false);
  keep[0] = keep[pts.length - 1] = true;
  final stack = <(int, int)>[(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (s, e) = stack.removeLast();
    var maxD = -1.0, idx = -1;
    for (var i = s + 1; i < e; i++) {
      final d = _distToSegment(pts[i], pts[s], pts[e]);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx != -1 && maxD > tol) {
      keep[idx] = true;
      stack.add((s, idx));
      stack.add((idx, e));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

double _ringArea(List<GeoPoint> r) {
  var s = 0.0;
  for (var i = 0; i < r.length; i++) {
    final a = r[i], b = r[(i + 1) % r.length];
    s += a.x * b.y - b.x * a.y;
  }
  return s.abs() / 2;
}

/// 閉じたリングを簡略化する（許容誤差 [tolerance]）。結果は 3 頂点以上。
List<GeoPoint> simplifyRing(List<GeoPoint> ring, double tolerance) {
  if (tolerance < 0) throw ArgumentError('tolerance は 0 以上');
  if (ring.length <= 3 || tolerance == 0) return ring;
  // 閉じたリングは、最初の点から最も遠い点で 2 つの折れ線に分けて、それぞれ簡略化する
  var far = 1;
  var best = -1.0;
  for (var i = 1; i < ring.length; i++) {
    final d = math.pow(ring[i].x - ring[0].x, 2) + math.pow(ring[i].y - ring[0].y, 2);
    if (d > best) {
      best = d.toDouble();
      far = i;
    }
  }
  final a = _dp(ring.sublist(0, far + 1), tolerance);
  final b = _dp([...ring.sublist(far), ring[0]], tolerance);
  final out = [...a, ...b.sublist(1, b.length - 1)];
  if (out.length >= 3) return out;
  // 細すぎて 2 点に潰れたときは、2 点から最も離れた点を足して三角形にする
  var third = -1;
  var td = -1.0;
  for (var i = 0; i < ring.length; i++) {
    final d = _distToSegment(ring[i], out[0], out[1]);
    if (d > td) {
      td = d;
      third = i;
    }
  }
  return [out[0], ring[third], out[1]];
}

/// 地図全体の簡略化。各リングを [tolerance]（実数の座標の単位）で簡略化し、面積が [minRingArea] 未満のリング
/// （小さな島）を落とす。領域の最後の 1 リングは落とさない。座標は元の [MapPack.scale] に丸める。
MapPack simplifyMapPack(MapPack pack, {required double tolerance, double minRingArea = 0}) {
  final regions = <MapRegion>[];
  for (final r in pack.regions) {
    final rings = [for (final ring in r.rings) simplifyRing(ring, tolerance)];
    final kept = [for (final ring in rings) if (_ringArea(ring) >= minRingArea) ring];
    if (kept.isEmpty && rings.isNotEmpty) {
      // 全部が小さい領域は、いちばん大きいリングだけ残す
      final big = rings.reduce((a, b) => _ringArea(a) >= _ringArea(b) ? a : b);
      kept.add(big);
    }
    regions.add(MapRegion(id: r.id, label: r.label, rings: kept));
  }
  return MapPack(
    id: pack.id,
    attribution: pack.attribution,
    regions: regions,
    scale: pack.scale,
    flipY: pack.flipY,
    bounds: pack.bounds,
  );
}

// ───────────────────────── SVG ─────────────────────────

String _n(double v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// 地図の SVG。色は `currentColor` だけ（[highlight] の領域は濃く、他は薄く塗る）。
/// [width]×[height] の枠に縦横比を保って収める。[labels] が真なら領域の名前を重心に書く。[xScale] は経度方向の補正。
/// 文字は XML エスケープする。同じ入力なら同じ SVG。
String renderMapSvg(
  MapPack pack, {
  Set<String> highlight = const {},
  bool labels = false,
  double width = 200,
  double height = 140,
  double padding = 4,
  double xScale = 1.0,
}) {
  final vp = MapViewport(pack.bounds, width, height, padding: padding, xScale: xScale, flipY: pack.flipY);
  final b = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_n(width)} ${_n(height)}" ')
    ..write('fill="none" stroke="currentColor" stroke-width="0.5" stroke-linejoin="round">');
  for (final r in pack.regions) {
    final d = StringBuffer();
    for (final ring in r.rings) {
      for (var i = 0; i < ring.length; i++) {
        final (x, y) = vp.toScreen(ring[i]);
        d.write('${i == 0 ? 'M' : 'L'}${_n(x)} ${_n(y)}');
      }
      d.write('Z');
    }
    final op = highlight.contains(r.id) ? '0.5' : '0.08';
    b.write('<path d="$d" fill="currentColor" fill-opacity="$op"/>');
  }
  if (labels) {
    for (final r in pack.regions) {
      final (x, y) = vp.toScreen(r.centroid);
      b.write('<text x="${_n(x)}" y="${_n(y)}" font-size="4" text-anchor="middle" fill="currentColor" stroke="none">${_esc(r.label)}</text>');
    }
  }
  b.write('</svg>');
  return b.toString();
}
