import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../growth/growth_card.dart';

/// 成長カードの描画。名前・ID・メールの欄は無い。画面表示にも画像化にも同じ描画を使う。
class GrowthCardPainter extends CustomPainter {
  GrowthCardPainter(this.data, {this.accent = const Color(0xFF3B82F6)});

  final GrowthCardData data;

  /// 教科色。
  final Color accent;

  /// 基準サイズ。画像は 4:5。
  static const Size designSize = Size(1080, 1350);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / designSize.width, size.height / designSize.height);
    final w = designSize.width, h = designSize.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h),
            [accent.withValues(alpha: 0.18), Colors.white]),
    );

    _text(canvas, data.strings.cardTitle(data.subjectLabel), const Offset(72, 64), 44,
        Colors.black54, bold: true);
    _text(canvas, data.headline, const Offset(72, 140), 76, Colors.black87, bold: true, maxWidth: w - 144);

    // レベルバッジ
    final badge = Offset(w - 200, 330);
    canvas.drawCircle(badge, 110, Paint()..color = accent);
    _text(canvas, data.levelLabel, badge - const Offset(0, 0), 120, Colors.white,
        bold: true, center: true);
    _text(canvas, data.nextLine, const Offset(72, 330), 44, Colors.black87, maxWidth: w - 450);
    if (data.streakDays > 0) {
      _text(canvas, data.strings.streakDays(data.streakDays), const Offset(72, 400), 40, Colors.black54,
          maxWidth: w - 450);
    }

    // レーダー
    _radar(canvas, Offset(w / 2, 800), 270);

    // 数字
    _stat(canvas, const Offset(72, 1130), data.strings.statStamps, '${data.overcomeStamps}');
    _stat(canvas, const Offset(560, 1130), data.strings.statSolvable, data.strings.solvableValue(data.nowSolvable));
    canvas.restore();
  }

  void _radar(Canvas canvas, Offset c, double r) {
    final n = data.radar.length;
    Offset at(int i, double v) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return c + Offset(math.cos(a), math.sin(a)) * (r * v);
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black12;
    for (final level in [0.25, 0.5, 0.75, 1.0]) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final o = at(i, level);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(p..close(), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, at(i, 1), grid);
    }

    Path poly(double Function(RadarAxis) pick) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final o = at(i, pick(data.radar[i]));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p..close();
    }

    // 先月（あれば）を薄く重ね、今月を濃く描く。
    if (data.radar.every((a) => a.previous != null)) {
      final prev = poly((a) => a.previous!);
      canvas.drawPath(prev, Paint()..color = Colors.black.withValues(alpha: 0.06));
      canvas.drawPath(
          prev,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = Colors.black38);
    }
    final cur = poly((a) => a.current);
    canvas.drawPath(cur, Paint()..color = accent.withValues(alpha: 0.35));
    canvas.drawPath(
        cur,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..color = accent);

    for (var i = 0; i < n; i++) {
      final o = at(i, 1.18);
      _text(canvas, data.radar[i].label, o, 36, Colors.black87, center: true);
    }
  }

  void _stat(Canvas canvas, Offset o, String label, String value) {
    _text(canvas, label, o, 36, Colors.black54);
    _text(canvas, value, o + const Offset(0, 50), 80, Colors.black87, bold: true);
  }

  void _text(Canvas canvas, String s, Offset o, double size, Color color,
      {bool bold = false, bool center = false, double maxWidth = 900}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, center ? o - Offset(tp.width / 2, tp.height / 2) : o);
  }

  @override
  bool shouldRepaint(GrowthCardPainter old) => old.data != data || old.accent != accent;
}

/// 画面に出す成長カード（4:5）。
class GrowthCardView extends StatelessWidget {
  const GrowthCardView({super.key, required this.data, this.accent = const Color(0xFF3B82F6)});

  final GrowthCardData data;
  final Color accent;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: GrowthCardPainter.designSize.width / GrowthCardPainter.designSize.height,
        child: Semantics(
          label: data.strings.cardSemantics(data.headline, data.levelLabel),
          child: CustomPaint(painter: GrowthCardPainter(data, accent: accent)),
        ),
      );
}

/// 成長カードを PNG にする（端末内で描画。通信しない）。共有は呼び出し側が OS の共有画面へ渡す。
Future<Uint8List> renderGrowthCardPng(
  GrowthCardData data, {
  Color accent = const Color(0xFF3B82F6),
  double scale = 1.0,
}) async {
  final size = GrowthCardPainter.designSize * scale;
  final recorder = ui.PictureRecorder();
  GrowthCardPainter(data, accent: accent).paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
