import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../l10n/strings.dart';

/// 範囲カードの QR コード。白地に黒で描く（読み取りやすさのため、教科色などは使わない）。
/// 周りの余白（クワイエットゾーン）は 4 モジュール分。
class ScopeQrView extends StatelessWidget {
  const ScopeQrView({
    super.key,
    required this.code,
    this.size = 220,
    this.strings = const JaStrings(),
  });

  /// `encodeScope` の符号。
  final String code;
  final double size;
  final ChukoreStrings strings;

  @override
  Widget build(BuildContext context) => Semantics(
        label: strings.scopeQrSemantics,
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _QrPainter(QrImage(QrCode.fromData(data: code, errorCorrectLevel: QrErrorCorrectLevel.M)))),
        ),
      );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    const quiet = 4;
    final cells = image.moduleCount + quiet * 2;
    final cell = size.shortestSide / cells;
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < image.moduleCount; y++) {
      for (var x = 0; x < image.moduleCount; x++) {
        if (image.isDark(y, x)) {
          // 隙間（アンチエイリアスの線）が出ないよう、少し大きく塗る
          canvas.drawRect(Rect.fromLTWH((x + quiet) * cell, (y + quiet) * cell, cell + 0.5, cell + 0.5), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
