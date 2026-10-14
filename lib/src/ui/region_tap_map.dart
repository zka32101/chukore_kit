import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/strings.dart';
import '../question/map_tap.dart';
import '../question/map_viewport.dart';

/// 地図タップ問題の描画。境界線データ（[regions]）と教科色（[regionColors]）はアプリ側が渡す。
/// 当たり判定と回答後の状態は map_tap.dart のロジックを使う（flutter_map には依存しない）。
/// 色だけに頼らない目印。正解はチェック、不正解はバツ（色覚の多様性・白黒表示でも区別できる）。
enum RegionMark { none, check, cross }

RegionMark regionMarkOf(RegionVisual v) => switch (v) {
      RegionVisual.correct => RegionMark.check,
      RegionVisual.wrong => RegionMark.cross,
      _ => RegionMark.none,
    };

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
    this.bounds,
    this.flipY = true,
    this.background,
    this.strings = const JaStrings(),
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

  /// 図タップ用: 画像の座標範囲（例: MapBounds(0, 0, 1, 1)）。省略時は領域の外接矩形。
  final MapBounds? bounds;

  /// 画像座標（y が下向き）の図なら false。
  final bool flipY;

  /// 領域の下に敷く画像など（図タップ）。領域と同じ範囲に重なる。
  final Widget? background;

  /// 読み上げ文言の言語。
  final ChukoreStrings strings;
  final void Function(String regionId) onRegionTapped;

  @override
  Widget build(BuildContext context) {
    final bounds = this.bounds ?? MapBounds.of(regions);
    final visuals = {
      for (final r in regions)
        r.id: regionVisual(
          regionId: r.id,
          available: available,
          answered: answered,
          correctId: correctId,
          selectedId: selectedId,
        ),
    };
    // スクリーンリーダー向け: 領域ごとのラベル（回答後は正解・不正解を言う）
    String labelOf(MapRegion r) => switch (visuals[r.id]!) {
          RegionVisual.correct => '${r.label} (${strings.markCorrect})',
          RegionVisual.wrong => '${r.label} (${strings.markWrong})',
          _ => r.label,
        };
    return Semantics(
      label: strings.mapSemantics,
      child: AspectRatio(
        aspectRatio: bounds.width * xScale / (bounds.height <= 0 ? 1 : bounds.height),
        child: LayoutBuilder(builder: (context, c) {
          final vp = MapViewport(bounds, c.maxWidth, c.maxHeight,
              padding: background == null ? 8 : 0, xScale: xScale, flipY: flipY);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (answered) return;
              final id = regionAt(regions, vp.fromScreen(d.localPosition.dx, d.localPosition.dy),
                  available: available);
              if (id != null) onRegionTapped(id);
            },
            child: Stack(fit: StackFit.expand, children: [
              ?background,
              CustomPaint(
              size: Size(c.maxWidth, c.maxHeight),
              painter: _RegionPainter(
                regions: regions,
                viewport: vp,
                visuals: visuals,
                labels: {for (final r in regions) r.id: labelOf(r)},
                onTap: onRegionTapped,
                textDirection: Directionality.of(context),
                regionColors: regionColors,
                showLabels: showLabels,
              ),
            ),
            ]),
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
    required this.labels,
    required this.onTap,
    required this.textDirection,
  });

  final List<MapRegion> regions;
  final MapViewport viewport;
  final Map<String, String> labels;
  final void Function(String regionId) onTap;
  final TextDirection textDirection;
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
    for (final r in regions) {
      final mark = regionMarkOf(visuals[r.id]!);
      if (mark == RegionMark.none) continue;
      final (x, y) = viewport.toScreen(r.centroid);
      _drawMark(canvas, Offset(x, y - 16), mark);
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

  /// 白い丸にチェック／バツ。塗りの色が見分けにくくても、形で正解・不正解が分かる。
  void _drawMark(Canvas canvas, Offset c, RegionMark mark) {
    const r = 10.0;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black87,
    );
    final glyph = Path();
    if (mark == RegionMark.check) {
      glyph
        ..moveTo(c.dx - 5, c.dy)
        ..lineTo(c.dx - 1.5, c.dy + 4)
        ..lineTo(c.dx + 5.5, c.dy - 4);
    } else {
      glyph
        ..moveTo(c.dx - 4.5, c.dy - 4.5)
        ..lineTo(c.dx + 4.5, c.dy + 4.5)
        ..moveTo(c.dx + 4.5, c.dy - 4.5)
        ..lineTo(c.dx - 4.5, c.dy + 4.5);
    }
    canvas.drawPath(
      glyph,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.6
        ..color = Colors.black87,
    );
  }

  /// スクリーンリーダー用: 領域ごとに、ボタンとして読み上げ・操作できるようにする。
  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
        return [
          for (final r in regions)
            CustomPainterSemantics(
              key: ValueKey(r.id),
              rect: _bounds(r),
              properties: SemanticsProperties(
                label: labels[r.id],
                textDirection: textDirection,
                button: true,
                enabled: visuals[r.id] == RegionVisual.selectable,
                onTap: visuals[r.id] == RegionVisual.selectable ? () => onTap(r.id) : null,
              ),
            ),
        ];
      };

  /// 領域の画面上の外接矩形。小さい領域も押せるよう、最低 24 の大きさにする。
  Rect _bounds(MapRegion r) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final ring in r.rings) {
      for (final p in ring) {
        final (x, y) = viewport.toScreen(p);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width < 24 ? 24 : rect.width,
      height: rect.height < 24 ? 24 : rect.height,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.regions != regions ||
      old.viewport.width != viewport.width ||
      old.viewport.height != viewport.height ||
      old.showLabels != showLabels ||
      old.regionColors != regionColors ||
      _labelsDiffer(old.labels, labels) ||
      _differs(old.visuals, visuals);

  static bool _labelsDiffer(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return true;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return true;
    }
    return false;
  }

  static bool _differs(Map<String, RegionVisual> a, Map<String, RegionVisual> b) {
    if (a.length != b.length) return true;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return true;
    }
    return false;
  }
}
