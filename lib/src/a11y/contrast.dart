import 'dart:math' as math;

double _channel(int c) {
  final s = c / 255;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG の相対輝度（0 = 黒、1 = 白）。[argb] は 0xAARRGGBB（透明度は無視する）。
double relativeLuminance(int argb) =>
    0.2126 * _channel((argb >> 16) & 0xFF) + 0.7152 * _channel((argb >> 8) & 0xFF) + 0.0722 * _channel(argb & 0xFF);

/// WCAG のコントラスト比（1〜21）。順番は問わない。
double contrastRatio(int a, int b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// 文字の WCAG AA（通常の文字は 4.5、大きな文字は 3）。
bool meetsTextContrast(int fg, int bg, {bool largeText = false}) => contrastRatio(fg, bg) >= (largeText ? 3 : 4.5);

/// 図形・アイコンなど文字以外の WCAG AA（3）。
bool meetsGraphicContrast(int fg, int bg) => contrastRatio(fg, bg) >= 3;
