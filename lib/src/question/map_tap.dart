/// 地図タップ問題の判定ロジック（描画は含まない）。
/// 小学コレ！社会の JapanRegionTapMap（ポリゴン＋ray-casting＋回答後の色分け）と同じ考え方で、
/// 地図データ（境界線）は教科アプリ側が持つ。座標は x=経度, y=緯度のような任意の平面座標でよい。
class GeoPoint {
  const GeoPoint(this.x, this.y);

  final double x, y;
}

/// 選択できる領域（地方・都道府県・国など）。1領域が複数のリング（離島など）を持てる。
class MapRegion {
  const MapRegion({required this.id, required this.label, required this.rings});

  final String id;
  final String label;
  final List<List<GeoPoint>> rings;

  bool contains(GeoPoint p) => rings.any((r) => pointInPolygon(r, p));

  /// ラベル表示位置の目安（全頂点の平均）。
  GeoPoint get centroid {
    var sx = 0.0, sy = 0.0, n = 0;
    for (final r in rings) {
      for (final p in r) {
        sx += p.x;
        sy += p.y;
        n++;
      }
    }
    return n == 0 ? const GeoPoint(0, 0) : GeoPoint(sx / n, sy / n);
  }
}

/// 点が多角形の内側にあるか（ray-casting）。
bool pointInPolygon(List<GeoPoint> polygon, GeoPoint point) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    if ((a.y > point.y) != (b.y > point.y) &&
        point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// タップ位置の領域ID。[available] を渡すと、その中だけが選択対象になる。
String? regionAt(
  Iterable<MapRegion> regions,
  GeoPoint tap, {
  Set<String>? available,
}) {
  for (final r in regions) {
    if (available != null && !available.contains(r.id)) continue;
    if (r.contains(tap)) return r.id;
  }
  return null;
}

/// 領域の見た目の状態。色への対応は教科アプリ側（教科色）が決める。
enum RegionVisual { selectable, disabled, correct, wrong, dimmed }

RegionVisual regionVisual({
  required String regionId,
  required Set<String> available,
  required bool answered,
  required String correctId,
  String? selectedId,
}) {
  if (!answered) {
    return available.contains(regionId) ? RegionVisual.selectable : RegionVisual.disabled;
  }
  if (regionId == correctId) return RegionVisual.correct;
  if (regionId == selectedId) return RegionVisual.wrong;
  return RegionVisual.dimmed;
}
