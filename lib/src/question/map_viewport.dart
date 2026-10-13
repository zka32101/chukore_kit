import 'dart:math' as math;

import 'map_tap.dart';

/// 領域全体の外接矩形。
class MapBounds {
  const MapBounds(this.minX, this.minY, this.maxX, this.maxY);

  factory MapBounds.of(Iterable<MapRegion> regions) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final r in regions) {
      for (final ring in r.rings) {
        for (final p in ring) {
          minX = math.min(minX, p.x);
          maxX = math.max(maxX, p.x);
          minY = math.min(minY, p.y);
          maxY = math.max(maxY, p.y);
        }
      }
    }
    if (minX.isInfinite) return const MapBounds(0, 0, 1, 1);
    return MapBounds(minX, minY, maxX, maxY);
  }

  final double minX, minY, maxX, maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
}

/// 地図座標と画面座標の変換。縦横比を保って余白つきで収める。
/// [flipY] が true（既定）なら y は上向き（緯度）として反転、false なら画像座標（y が下向き）のまま。
/// [xScale] は経度方向の縮尺補正（緯度が高いほど小さくする。例: cos(中心緯度)）。
class MapViewport {
  MapViewport(
    this.bounds,
    this.width,
    this.height, {
    this.padding = 8,
    this.xScale = 1.0,
    this.flipY = true,
  }) {
    final w = math.max(1e-9, bounds.width * xScale);
    final h = math.max(1e-9, bounds.height);
    scale = math.max(
      0,
      math.min((width - 2 * padding) / w, (height - 2 * padding) / h),
    ).toDouble();
    _offsetX = (width - w * scale) / 2;
    _offsetY = (height - h * scale) / 2;
  }

  final MapBounds bounds;
  final double width, height, padding, xScale;
  final bool flipY;
  late final double scale;
  late final double _offsetX, _offsetY;

  (double, double) toScreen(GeoPoint p) => (
        _offsetX + (p.x - bounds.minX) * xScale * scale,
        _offsetY + (flipY ? bounds.maxY - p.y : p.y - bounds.minY) * scale,
      );

  GeoPoint fromScreen(double dx, double dy) => scale == 0
      ? GeoPoint(bounds.minX, bounds.maxY)
      : GeoPoint(
          bounds.minX + (dx - _offsetX) / (scale * xScale),
          flipY ? bounds.maxY - (dy - _offsetY) / scale : bounds.minY + (dy - _offsetY) / scale,
        );
}
