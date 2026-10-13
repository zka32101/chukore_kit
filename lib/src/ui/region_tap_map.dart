import 'package:flutter/material.dart';

import '../question/map_tap.dart';
import '../question/map_viewport.dart';

/// 地図タップ問題の描画。境界線データ（[regions]）と教科色（[regionColors]）はアプリ側が渡す。
/// 当たり判定と回答後の状態は map_tap.dart のロジックを使う（flutter_map には依存しない）。
class RegionTapMap extends StatelessWidget {
  const RegionTapMap({
    super.key,
    required this.regions,
    required this.available,
    required this.answered,
    required this.correctId,
    required this.onRegionTapped,
    this.selectedId,
    this.regionColors = const {},
    this.showLabels = true,
    this.xScale = 1.0,
  });

  final List<MapRegion> regions;

  /// 選択対象にする領域ID。それ以外は薄く表示し、タップしても反応しない。
  final Set<String> available;
  final bool answered;
  final String correctId;
  final String? selectedId;
  final Map<String, Color> regionColors;
  final bool showLabels;
  final double xScale;
  final void Function(String regionId) onRegionTapped;

  @override
  Widget build(BuildContext context) {
    final bounds = MapBounds.of(regions);
    return Semantics(
      label: '地図。タップして答えを選ぶ',
      child: AspectRatio(
        aspectRatio: bounds.width * xScale / (bounds.height <= 0 ? 1 : bounds.height),
        child: LayoutBuilder(builder: (context, c) {
          final vp = MapViewport(bounds, c.maxWidth, c.maxHeight, xScale: xScale);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (answered) return;
              final id = regionAt(regions, vp.fromScreen(d.localPosition.dx, d.localPosition.dy),
                  available: available);
              if (id != null) onRegionTapped(id);
            },
            child: CustomPaint(
              size: Size(c.maxWidth, c.maxHeight),
              painter: _RegionPainter(
                regions: regions,
                viewport: vp,
                visuals: {
                  for (final r in regions)
                    r.id: regionVisual(
                      regionId: r.id,
                      available: available,
                      answered: answered,
                      correctId: correctId,
                      selectedId: selectedId,
                    ),
                },
                regionColors: regionColors,
                showLabels: showLabels,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 状態ごとの塗り・枠線の色（小学コレ！社会の配色の考え方を踏襲）。
(Color fill, Color border, double width) regionStyle(RegionVisual v, Color base) =>
    switch (v) {
      RegionVisual.selectable => (base.withValues(alpha: 0.55), base.withValues(alpha: 0.85), 1.5),
      RegionVisual.disabled => (Colors.grey.withValues(alpha: 0.15), Colors.grey.withValues(alpha: 0.4), 1.0),
      RegionVisual.correct => (Colors.green.withValues(alpha: 0.75), Colors.green, 2.5),
      RegionVisual.wrong => (Colors.red.withValues(alpha: 0.65), Colors.red, 2.5),
      RegionVisual.dimmed => (base.withValues(alpha: 0.25), base.withValues(alpha: 0.4), 1.0),
    };

class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.regions,
    required this.viewport,
    required this.visuals,
    required this.regionColors,
    required this.showLabels,
  });

  final List<MapRegion> regions;
  final MapViewport viewport;
  final Map<String, RegionVisual> visuals;
  final Map<String, Color> regionColors;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in regions) {
      final style = regionStyle(visuals[r.id]!, regionColors[r.id] ?? Colors.blueGrey);
      final path = Path();
      for (final ring in r.rings) {
        for (var i = 0; i < ring.length; i++) {
          final (x, y) = viewport.toScreen(ring[i]);
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
      }
      canvas.drawPath(path, Paint()..color = style.$1);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = style.$3
          ..color = style.$2,
      );
    }
    if (!showLabels) return;
    for (final r in regions) {
      final (x, y) = viewport.toScreen(r.centroid);
      final tp = TextPainter(
        text: TextSpan(
          text: r.label,
          style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.regions != regions ||
      old.viewport.width != viewport.width ||
      old.viewport.height != viewport.height ||
      old.showLabels != showLabels ||
      old.regionColors != regionColors ||
      _differs(old.visuals, visuals);

  static bool _differs(Map<String, RegionVisual> a, Map<String, RegionVisual> b) {
    if (a.length != b.length) return true;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return true;
    }
    return false;
  }
}
