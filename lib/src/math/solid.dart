import 'dart:math' as math;

import 'figure.dart';

typedef _P = ({double x, double y});

/// 立体の図の仕様（`figure.solid`）。種類と寸法の式、ラベルの文字列を持つ。
/// 立体は斜投影（奥行きは右上へ 45°・半分の長さ）、円の面は縦を 0.3 に縮めた楕円で描き、見えない辺は破線にする。
/// 展開図（`view: net`）は平面に広げた形。図の大きさは枠（100 × 100）に収まるよう寸法の比を保って決める。
class SolidSpec {
  const SolidSpec._(this.kind, this.view, this.dims, this.labels);

  final String kind;
  final String view;

  /// 寸法の名前 → 数か式。
  final Map<String, Object> dims;

  /// ラベルの名前 → 文字列（`{…}` を含む）。
  final Map<String, String> labels;

  /// 種類と見え方ごとの寸法の名前。
  static const dimNames = {
    'solid/cuboid': ['a', 'b', 'c'],
    'solid/cylinder': ['r', 'h'],
    'solid/cone': ['r', 'h'],
    'solid/sphere': ['r'],
    'net/cube': ['a'],
    'net/cylinder': ['r', 'h'],
    'net/cone': ['r', 'h'],
  };

  /// ラベルに使える名前。
  static const labelNames = {
    'solid/cuboid': {'a', 'b', 'c'},
    'solid/cylinder': {'r', 'h'},
    'solid/cone': {'r', 'h'},
    'solid/sphere': {'r'},
    'net/cube': {'a'},
    'net/cylinder': {'r', 'h', 'w'},
    'net/cone': {'r', 'l'},
  };

  factory SolidSpec.fromJson(Map<String, dynamic> j, void Function(Object?, String) checkExpr) {
    final extra = j.keys.where((k) => !const {'kind', 'view', 'dims', 'labels'}.contains(k));
    if (extra.isNotEmpty) throw FormatException('figure.solid: 未知のキー: ${extra.join(', ')}');
    final kind = j['kind'], view = j['view'] ?? 'solid';
    if (kind is! String || view is! String || !dimNames.containsKey('$view/$kind')) {
      throw FormatException('figure.solid: 未対応の種類: $view/$kind（${dimNames.keys.join('・')}）');
    }
    final key = '$view/$kind';
    final rawDims = j['dims'];
    if (rawDims is! Map) throw const FormatException('figure.solid: dims が必要です');
    final want = dimNames[key]!;
    if (rawDims.length != want.length || !want.every(rawDims.containsKey)) {
      throw FormatException('figure.solid: $key の dims は ${want.join('・')}');
    }
    final dims = <String, Object>{};
    for (final n in want) {
      checkExpr(rawDims[n], '寸法 $n');
      dims[n] = rawDims[n] as Object;
    }
    final rawLabels = j['labels'] ?? const {};
    if (rawLabels is! Map || rawLabels.values.any((e) => e is! String)) {
      throw const FormatException('figure.solid: labels は 名前 → 文字列');
    }
    final bad = rawLabels.keys.where((k) => !labelNames[key]!.contains(k));
    if (bad.isNotEmpty) throw FormatException('figure.solid: $key のラベルに使えない名前: ${bad.join(', ')}');
    return SolidSpec._(kind, view, dims, {for (final e in rawLabels.entries) e.key as String: e.value as String});
  }

  /// 寸法 [d]（すべて正の数）と、文字列にしたラベル [labels] から図形を作る。寸法が正でなければ null。
  ({List<FigureShape> shapes, List<FigureLabel> labels})? build(Map<String, double> d, Map<String, String> labels) {
    if (d.values.any((v) => !(v > 0) || v.isInfinite)) return null;
    final s = <FigureShape>[];
    final l = <FigureLabel>[];
    void label(String name, double x, double y) {
      final t = labels[name];
      if (t != null) l.add(FigureLabel(x, y, t));
    }

    _P p(double x, double y) => (x: x, y: y);
    switch ('$view/$kind') {
      case 'solid/cuboid':
        final a = d['a']!, b = d['b']!, c = d['c']!;
        const o = 0.35355339059327373; // 奥行き 1 あたりの右・上への移動（斜め 45°・半分）
        final k = math.min(72 / (a + o * b), 72 / (c + o * b));
        final x0 = 50 - k * (a + o * b) / 2, y0 = 50 + k * (c + o * b) / 2;
        final fl = p(x0, y0), fr = p(x0 + k * a, y0), ftr = p(x0 + k * a, y0 - k * c), ftl = p(x0, y0 - k * c);
        final dx = k * o * b, dy = -k * o * b;
        p2(_P q) => p(q.x + dx, q.y + dy);
        final bl = p2(fl), br = p2(fr), btr = p2(ftr), btl = p2(ftl);
        s
          ..add(FigureShape.poly([fl, fr, ftr, ftl]))
          ..add(FigureShape.poly([ftl, ftr, btr, btl]))
          ..add(FigureShape.poly([fr, br, btr, ftr]))
          ..add(FigureShape.seg(bl, btl, dashed: true))
          ..add(FigureShape.seg(bl, fl, dashed: true))
          ..add(FigureShape.seg(bl, br, dashed: true));
        label('a', (fl.x + fr.x) / 2, y0 + 8);
        label('c', x0 - 9, y0 - k * c / 2 + 2);
        label('b', (fr.x + br.x) / 2 + 5, (fr.y + br.y) / 2 + 5);
      case 'solid/cylinder':
        final r = d['r']!, h = d['h']!;
        final k = math.min(72 / (2 * r), 72 / (h + 0.6 * r));
        final rx = k * r, ry = 0.3 * rx, top = 50 - k * h / 2, bot = top + k * h;
        s
          ..add(FigureShape.ellipse(p(50, top), rx, ry))
          ..add(FigureShape.ellipseHalf(p(50, bot), rx, ry, upper: false))
          ..add(FigureShape.ellipseHalf(p(50, bot), rx, ry, upper: true, dashed: true))
          ..add(FigureShape.seg(p(50 - rx, top), p(50 - rx, bot)))
          ..add(FigureShape.seg(p(50 + rx, top), p(50 + rx, bot)))
          ..add(FigureShape.seg(p(50, top), p(50 + rx, top), dashed: true));
        label('r', 50 + rx / 2, top - 2);
        label('h', 50 + rx + 10, (top + bot) / 2 + 2);
      case 'solid/cone':
        final r = d['r']!, h = d['h']!;
        final k = math.min(72 / (2 * r), 72 / (h + 0.3 * r));
        final rx = k * r, ry = 0.3 * rx, apex = 50 - (k * h + ry) / 2, bot = apex + k * h;
        s
          ..add(FigureShape.ellipseHalf(p(50, bot), rx, ry, upper: false))
          ..add(FigureShape.ellipseHalf(p(50, bot), rx, ry, upper: true, dashed: true))
          ..add(FigureShape.seg(p(50, apex), p(50 - rx, bot)))
          ..add(FigureShape.seg(p(50, apex), p(50 + rx, bot)))
          ..add(FigureShape.seg(p(50, apex), p(50, bot), dashed: true))
          ..add(FigureShape.seg(p(50, bot), p(50 + rx, bot), dashed: true));
        label('h', 50 - 9, (apex + bot) / 2 + 2);
        label('r', 50 + rx / 2, bot - 2);
      case 'solid/sphere':
        const r = 36.0;
        s
          ..add(FigureShape.circle(p(50, 50), r))
          ..add(FigureShape.ellipseHalf(p(50, 50), r, 0.3 * r, upper: false))
          ..add(FigureShape.ellipseHalf(p(50, 50), r, 0.3 * r, upper: true, dashed: true))
          ..add(FigureShape.seg(p(50, 50), p(50 + r, 50), dashed: true));
        label('r', 50 + r / 2, 50 - 2);
      case 'net/cube':
        final u = 72 / 4, x0 = 50 - 2 * u, y0 = 50 - 1.5 * u;
        for (final (col, row) in const [(1, 0), (0, 1), (1, 1), (2, 1), (3, 1), (1, 2)]) {
          s.add(
            FigureShape.poly([
              p(x0 + col * u, y0 + row * u),
              p(x0 + (col + 1) * u, y0 + row * u),
              p(x0 + (col + 1) * u, y0 + (row + 1) * u),
              p(x0 + col * u, y0 + (row + 1) * u),
            ]),
          );
        }
        label('a', x0 + 1.5 * u, y0 + 3 * u + 7);
      case 'net/cylinder':
        final r = d['r']!, h = d['h']!, w = 2 * math.pi * r;
        final k = math.min(72 / w, 72 / (h + 4 * r));
        final kw = k * w, kh = k * h, kr = k * r;
        final x0 = 50 - kw / 2, yTop = 50 - (kh + 4 * kr) / 2 + 2 * kr;
        s
          ..add(FigureShape.poly([p(x0, yTop), p(x0 + kw, yTop), p(x0 + kw, yTop + kh), p(x0, yTop + kh)]))
          ..add(FigureShape.circle(p(50, yTop - kr), kr))
          ..add(FigureShape.circle(p(50, yTop + kh + kr), kr))
          ..add(FigureShape.seg(p(50, yTop - kr), p(50 + kr, yTop - kr), dashed: true));
        label('r', 50 + kr / 2, yTop - kr - 2);
        label('h', x0 - 10, yTop + kh / 2 + 2);
        label('w', 50, yTop + kh / 2 + 2);
      case 'net/cone':
        final r = d['r']!, h = d['h']!, len = math.sqrt(r * r + h * h);
        final theta = 360 * r / len; // おうぎ形の中心角（度）。底面の円周とおうぎ形の弧が等しい
        final half = theta / 2 * math.pi / 180;
        final width = 2 * math.max(r, len * (theta < 180 ? math.sin(half) : 1));
        final above = half > math.pi / 2 ? -len * math.cos(half) : 0.0; // 中心角が 180° を超えると、おうぎ形は頂点より上にも出る
        final k = math.min(72 / width, 72 / (above + len + 2 * r));
        final apexY = 50 - k * (above + len + 2 * r) / 2 + k * above, kl = k * len, kr = k * r;
        final a = p(50, apexY);
        _P ray(double deg) => p(50 + kl * math.cos(deg * math.pi / 180), apexY - kl * math.sin(deg * math.pi / 180));
        s
          ..add(FigureShape.seg(a, ray(270 - theta / 2)))
          ..add(FigureShape.seg(a, ray(270 + theta / 2)))
          ..add(FigureShape.arc(a, kl, 270 - theta / 2, 270 + theta / 2))
          ..add(FigureShape.circle(p(50, apexY + kl + kr), kr));
        label('l', 50 - kl * math.sin(half) / 2 - 4, apexY + kl * math.cos(half) / 2);
        label('r', 50, apexY + kl + kr + 2);
    }
    return (shapes: s, labels: l);
  }
}
