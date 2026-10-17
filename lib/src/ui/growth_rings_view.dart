import 'package:flutter/material.dart';

import '../growth/growth_rings.dart';
import '../l10n/strings.dart';
import 'text_direction.dart';

/// G7 成長の年輪。一番内側が最初の月、外へ向かって新しい月。学習した日が多い月ほど太く濃い輪になる。
/// 休んだ月も細い輪として残る（消えない）。
class GrowthRingsView extends StatelessWidget {
  const GrowthRingsView({
    super.key,
    required this.rings,
    this.accent = const Color(0xFF3B82F6),
    this.strings = const JaStrings(),
  });

  final GrowthRings rings;
  final Color accent;
  final ChukoreStrings strings;

  /// 読み上げ: 合計の学習日数に加えて、最新の月の学習日数も伝える（図の太さは見えない人にも）。
  String get semanticsLabel {
    final total = strings.ringsSemantics(rings.totalDays);
    if (rings.months.isEmpty) return total;
    final latest = rings.months.last;
    return '$total. ${strings.ringsLatestMonth(latest.label, latest.days)}';
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: Semantics(
          label: semanticsLabel,
          textDirection: textDirectionOf(strings),
          child: CustomPaint(painter: GrowthRingsPainter(rings, accent: accent)),
        ),
      );
}

class GrowthRingsPainter extends CustomPainter {
  GrowthRingsPainter(this.rings, {required this.accent});

  final GrowthRings rings;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final n = rings.months.length;
    if (n == 0) return;
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final gap = maxR / (n + 1);
    for (var i = 0; i < n; i++) {
      final ratio = rings.months[i].ratio;
      canvas.drawCircle(
        c,
        gap * (i + 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = gap * (0.18 + 0.72 * ratio)
          ..color = accent.withValues(alpha: 0.2 + 0.8 * ratio),
      );
    }
  }

  @override
  bool shouldRepaint(GrowthRingsPainter old) => old.rings != rings || old.accent != accent;
}
