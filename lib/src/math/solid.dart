import 'dart:math' as math;

import 'figure.dart';

typedef _P = ({double x, double y});

/// 立体の図の仕様（`figure.solid`）。種類と寸法の式、ラベルの文字列を持つ。
/// 立体は斜投影（奥行きは右上へ 45°・半分の長さ）、円の面は縦を 0.3 に縮めた楕円で描き、見えない辺は破線にする。
/// 展開図（`view: net`）は平面に広げた形。図の大きさは枠（100 × 100）に収まるよう寸法の比を保って決める。
class SolidSpec {
  const SolidSpec._(this.kind, this.view, this.dims, this.labels, [this.cells]);

  /// 立方体の展開図の候補（`net/cells`）のマス（列, 行）。他の種類は null。
  final List<({int col, int row})>? cells;

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
    'solid/prism': ['n', 'r', 'h'],
    'solid/pyramid': ['n', 'r', 'h'],
    'net/cube': ['a'],
    'net/cylinder': ['r', 'h'],
    'net/cone': ['r', 'h'],
    'net/cells': <String>[],
  };

  /// ラベルに使える名前。
  static const labelNames = {
    'solid/cuboid': {'a', 'b', 'c'},
    'solid/cylinder': {'r', 'h'},
    'solid/cone': {'r', 'h'},
    'solid/sphere': {'r'},
    'solid/prism': {'h'},
    'solid/pyramid': {'h'},
    'net/cube': {'a'},
    'net/cylinder': {'r', 'h', 'w'},
    'net/cone': {'r', 'l'},
    'net/cells': <String>{},
  };

  factory SolidSpec.fromJson(Map<String, dynamic> j, void Function(Object?, String) checkExpr) {
    final extra = j.keys.where((k) => !const {'kind', 'view', 'dims', 'labels', 'cells'}.contains(k));
    if (extra.isNotEmpty) throw FormatException('figure.solid: 未知のキー: ${extra.join(', ')}');
    final kind = j['kind'], view = j['view'] ?? 'solid';
    if (kind is! String || view is! String || !dimNames.containsKey('$view/$kind')) {
      throw FormatException('figure.solid: 未対応の種類: $view/$kind（${dimNames.keys.join('・')}）');
    }
    final key = '$view/$kind';
    if (key == 'net/cells') {
      // マスの並びだけで決まる展開図（立方体の展開図の選択肢など）。寸法・ラベルはない
      if (j.containsKey('dims') || j.containsKey('labels')) {
        throw const FormatException('figure.solid: net/cells に dims・labels は使えません');
      }
      final raw = j['cells'];
      if (raw is! List || raw.isEmpty || raw.length > 12) throw const FormatException('figure.solid: cells は 1〜12 マス');
      final cells = <({int col, int row})>[];
      for (final c in raw) {
        if (c is! List || c.length != 2 || c.any((e) => e is! int || e < 0 || e > 9)) {
          throw FormatException('figure.solid: cells の各マスは [列, 行]（0〜9 の整数）: $c');
        }
        cells.add((col: c[0] as int, row: c[1] as int));
      }
      if (cells.toSet().length != cells.length) throw const FormatException('figure.solid: cells に同じマスがあります');
      return SolidSpec._(kind, view, const {}, const {}, cells);
    }
    if (j.containsKey('cells')) throw const FormatException('figure.solid: cells は net/cells だけ');
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

  /// 角柱・角錐の底面の辺の数（`n`）の範囲。
  static const minSides = 3, maxSides = 8;

  /// 寸法 [d]（すべて正の数）と、文字列にしたラベル [labels] から図形を作る。寸法が正でなければ null。
  /// 角柱・角錐は、`n`（底面の辺の数）が 3〜8 の整数でなければ null。
  ({List<FigureShape> shapes, List<FigureLabel> labels})? build(Map<String, double> d, Map<String, String> labels) {
    if (d.values.any((v) => !(v > 0) || v.isInfinite)) return null;
    if (kind == 'prism' || kind == 'pyramid') {
      final n = d['n']!;
      if ((n - n.roundToDouble()).abs() > 1e-9 || n.round() < minSides || n.round() > maxSides) return null;
    }
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
      case 'solid/prism' || 'solid/pyramid':
        final n = d['n']!.round(), r = d['r']!, h = d['h']!;
        final isPrism = kind == 'prism';
        final k = isPrism ? math.min(72 / (2 * r), 72 / (h + 0.6 * r)) : math.min(72 / (2 * r), 72 / (h + 0.3 * r));
        final rx = k * r, ry = 0.3 * rx;
        final top = isPrism ? 50 - k * h / 2 : 50 - (k * h + ry) / 2;
        final bot = top + k * h; // 角柱: 上の面の中心 → 下の面の中心。角錐: 頂点 → 底面の中心
        // 底面の頂点（正 n 角形を、縦に 0.3 に縮めた楕円に内接させる）。最も手前の面が正面の中央にくる向き
        // n が 4 の倍数だと、真横を向く面ができて図が潰れるので、半周期だけ回して角を手前にする
        final turn = n % 4 == 0 ? 180 / n : 0.0;
        double ang(int i) => (90 + 180 / n + 360 * i / n + turn) * math.pi / 180;
        _P at(int i, double cy) => p(50 + rx * math.cos(ang(i)), cy + ry * math.sin(ang(i)));
        bool front(int i) => math.sin((ang(i) + ang(i + 1)) / 2) > 1e-9; // i と i+1 の間の側面が見えるか
        final base = [for (var i = 0; i < n; i++) at(i, bot)];
        if (isPrism) {
          final upper = [for (var i = 0; i < n; i++) at(i, top)];
          s.add(FigureShape.poly(upper));
          for (var i = 0; i < n; i++) {
            final j = (i + 1) % n;
            s.add(FigureShape.seg(base[i], base[j], dashed: !front(i)));
            s.add(FigureShape.seg(upper[i], base[i], dashed: !(front(i) || front((i - 1 + n) % n))));
          }
          label('h', 50 + rx + 9, (top + bot) / 2 + 2);
        } else {
          final apex = p(50, top);
          for (var i = 0; i < n; i++) {
            final j = (i + 1) % n;
            s.add(FigureShape.seg(base[i], base[j], dashed: !front(i)));
            s.add(FigureShape.seg(apex, base[i], dashed: !(front(i) || front((i - 1 + n) % n))));
          }
          s.add(FigureShape.seg(apex, p(50, bot), dashed: true));
          label('h', 50 + 8, top + 0.62 * (bot - top));
        }
      case 'net/cells':
        final cs = cells!;
        final cols = cs.map((c) => c.col).reduce(math.max) + 1, rows = cs.map((c) => c.row).reduce(math.max) + 1;
        final u = math.min(18.0, 72 / math.max(cols, rows));
        final x0 = 50 - cols * u / 2, y0 = 50 - rows * u / 2;
        for (final c in cs) {
          s.add(
            FigureShape.poly([
              p(x0 + c.col * u, y0 + c.row * u),
              p(x0 + (c.col + 1) * u, y0 + c.row * u),
              p(x0 + (c.col + 1) * u, y0 + (c.row + 1) * u),
              p(x0 + c.col * u, y0 + (c.row + 1) * u),
            ]),
          );
        }
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

/// マスの並び [cells]（列, 行）が、立方体の展開図になるか。6 マスで、辺でつながっていて、折りたたむと 6 面が重ならずにそろうとき真。
/// 立方体を展開図の上で転がし、各マスに接する面がすべて違うかを調べる（回転・裏返しを含めて 35 種類の六マスのうち 11 種類が真）。
bool isCubeNet(List<({int col, int row})> cells) {
  if (cells.length != 6 || cells.toSet().length != 6) return false;
  final set = cells.toSet();
  final start = cells.first;
  // 面の並び: 上・下・北・南・東・西
  final state = <({int col, int row}), List<int>>{
    start: [0, 1, 2, 3, 4, 5],
  };
  final stack = [start];
  final bottoms = {1};
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    final f = state[cur]!;
    final t = f[0], b = f[1], n = f[2], s = f[3], e = f[4], w = f[5];
    for (final (dc, dr, next) in [
      (1, 0, [w, e, n, s, t, b]), // 東へ転がす
      (-1, 0, [e, w, n, s, b, t]), // 西へ
      (0, 1, [n, s, b, t, e, w]), // 南へ（行が増える向き）
      (0, -1, [s, n, t, b, e, w]), // 北へ
    ]) {
      final nx = (col: cur.col + dc, row: cur.row + dr);
      if (set.contains(nx) && !state.containsKey(nx)) {
        state[nx] = next;
        stack.add(nx);
        bottoms.add(next[1]);
      }
    }
  }
  return bottoms.length == 6; // 6 つの面がそろうのは、6 マスすべてに転がり着いたとき
}
