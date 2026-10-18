import 'dart:math' as math;

/// 色の見え方のタイプ（一色覚は含めない）。
enum ColorVision {
  /// 通常の色覚。
  normal,

  /// P型（1型色覚。赤が暗く、赤と緑が近く見える）。
  protan,

  /// D型（2型色覚。赤と緑が近く見える。日本人男性の約 5% 前後）。
  deutan,

  /// T型（3型色覚。青と緑・黄と赤紫が近く見える。まれ）。
  tritan,
}

// Machado, Oliveira, Fernandes (2009) の完全型（severity 1.0）。線形 RGB に掛ける。
const _matrices = <ColorVision, List<double>>{
  ColorVision.protan: [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
  ColorVision.deutan: [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
  ColorVision.tritan: [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
};

double _toLinear(int c) {
  final s = c / 255;
  return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

int _fromLinear(double v) {
  final c = v.clamp(0.0, 1.0);
  final s = c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return (s * 255).round().clamp(0, 255);
}

/// [argb]（0xAARRGGBB）が [vision] の人にどう見えるかの近似色（透明度は保つ）。
int simulateColorVision(int argb, ColorVision vision) {
  final m = _matrices[vision];
  if (m == null) return argb;
  final r = _toLinear((argb >> 16) & 0xFF), g = _toLinear((argb >> 8) & 0xFF), b = _toLinear(argb & 0xFF);
  final nr = _fromLinear(m[0] * r + m[1] * g + m[2] * b);
  final ng = _fromLinear(m[3] * r + m[4] * g + m[5] * b);
  final nb = _fromLinear(m[6] * r + m[7] * g + m[8] * b);
  return (argb & 0xFF000000) | (nr << 16) | (ng << 8) | nb;
}

List<double> _lab(int argb) {
  final r = _toLinear((argb >> 16) & 0xFF), g = _toLinear((argb >> 8) & 0xFF), b = _toLinear(argb & 0xFF);
  final x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
  final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
  final z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
  double f(double t) => t > 216 / 24389 ? math.pow(t, 1 / 3).toDouble() : (24389 / 27 * t + 16) / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// 2 色の見た目の違い（CIE76 の ΔE。0 = 同じ。目安: 10 未満は並べると区別しにくい、20 以上ははっきり違う）。
double colorDifference(int a, int b) {
  final p = _lab(a), q = _lab(b);
  return math.sqrt(math.pow(p[0] - q[0], 2) + math.pow(p[1] - q[1], 2) + math.pow(p[2] - q[2], 2));
}

/// 配色 [colors] のうち、[vision] の見え方で ΔE が [minDelta] 未満になる組（添字の小さい順）。
/// 空なら、全部の組が区別できる。色だけで意味を分けているところ（正解/不正解、教科ごとの色）に使う。
List<(int, int)> confusablePairs(List<int> colors, ColorVision vision, {double minDelta = 20}) {
  final seen = [for (final c in colors) simulateColorVision(c, vision)];
  return [
    for (var i = 0; i < seen.length; i++)
      for (var j = i + 1; j < seen.length; j++)
        if (colorDifference(seen[i], seen[j]) < minDelta) (i, j),
  ];
}
