import 'figure.dart';
import 'math_expr.dart';

typedef _P = ({double x, double y});

/// 関数のグラフの図の仕様（`figure.plot`）。座標軸・曲線（式 y = f(x) を折れ線で近似）・点・目盛りを持つ。
/// ```json
/// "plot": {"x": [-4, 4], "y": [-2, 10], "curves": [{"expr": "a*x^2"}],
///          "points": [{"at": [2, "4*a"], "label": "A"}], "ticks": {"x": 1, "y": 2}}
/// ```
/// 図の枠は 100 × 100 で、`[x の範囲]` × `[y の範囲]` を枠の内側（10〜90）に収める（縦横の縮尺は同じとは限らない。範囲で決まる）。
/// 範囲は 0 を含むこと（軸が枠の中に引けるように）。曲線は y の範囲で切り取り、計算できない点（NaN・無限大）で途切れる。
class PlotSpec {
  const PlotSpec._(this.xRange, this.yRange, this.curves, this.points, this.xTick, this.yTick);

  /// x・y の範囲（数か式）。
  final List<Object> xRange, yRange;

  /// 曲線: 式（`x` とパラメータ）と、破線か。
  final List<({MathExpr expr, bool dashed})> curves;

  /// 点: 座標（数か式）とラベル（`{…}` を含む文字列。無ければ null）。
  final List<({List<Object> at, String? label})> points;

  /// 目盛りの間隔（無ければ目盛りなし）。
  final double? xTick, yTick;

  static const maxCurves = 4, maxPoints = 8, maxTicks = 12, samples = 80;
  static const _keys = {'x', 'y', 'curves', 'points', 'ticks'};

  factory PlotSpec.fromJson(Map<String, dynamic> j, void Function(Object?, String) checkExpr, Set<String> known) {
    final extra = j.keys.where((k) => !_keys.contains(k));
    if (extra.isNotEmpty) throw FormatException('figure.plot: 未知のキー: ${extra.join(', ')}');
    List<Object> range(String k) {
      final v = j[k];
      if (v is! List || v.length != 2) throw FormatException('figure.plot: $k は [最小, 最大]');
      for (final e in v) {
        checkExpr(e, '$k の範囲');
      }
      return [for (final e in v) e as Object];
    }

    final rc = j['curves'];
    if (rc is! List || rc.isEmpty || rc.length > maxCurves) {
      throw FormatException('figure.plot: curves は 1〜$maxCurves 本');
    }
    final curves = <({MathExpr expr, bool dashed})>[];
    for (final c in rc) {
      if (c is! Map || c.keys.any((k) => k != 'expr' && k != 'dashed')) {
        throw const FormatException('figure.plot: 曲線は {"expr": 式, "dashed": 真偽}');
      }
      final e = c['expr'];
      final parsed = e is String ? MathExpr.tryParse(e) : null;
      if (parsed == null) throw FormatException('figure.plot: 曲線の式が読めません: $e');
      final bad = parsed.variables.where((v) => v != 'x' && !known.contains(v));
      if (bad.isNotEmpty) throw FormatException('figure.plot: 曲線の式にパラメータにない文字 ${bad.join()}: $e');
      final d = c['dashed'] ?? false;
      if (d is! bool) throw const FormatException('figure.plot: dashed は真偽');
      curves.add((expr: parsed, dashed: d));
    }

    final rp = j['points'] ?? const [];
    if (rp is! List || rp.length > maxPoints) throw FormatException('figure.plot: points は $maxPoints 個まで');
    final points = <({List<Object> at, String? label})>[];
    for (final p in rp) {
      if (p is! Map || p.keys.any((k) => k != 'at' && k != 'label')) {
        throw const FormatException('figure.plot: 点は {"at": [x, y], "label": 文字列}');
      }
      final at = p['at'];
      if (at is! List || at.length != 2) throw const FormatException('figure.plot: 点の at は [x, y]');
      for (final e in at) {
        checkExpr(e, '点の座標');
      }
      final l = p['label'];
      if (l != null && l is! String) throw const FormatException('figure.plot: 点の label は文字列');
      points.add((at: [for (final e in at) e as Object], label: l as String?));
    }

    double? tick(Map? t, String k) {
      final v = t?[k];
      if (v == null) return null;
      if (v is! num || !(v > 0) || v.isInfinite) throw FormatException('figure.plot: ticks.$k は正の数');
      return v.toDouble();
    }

    final rt = j['ticks'];
    if (rt != null && (rt is! Map || rt.keys.any((k) => k != 'x' && k != 'y'))) {
      throw const FormatException('figure.plot: ticks は {"x": 間隔, "y": 間隔}');
    }
    return PlotSpec._(range('x'), range('y'), curves, points, tick(rt as Map?, 'x'), tick(rt, 'y'));
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
  }

  /// 値を入れて図形にする。範囲が 0 を含まない・範囲が不正・点が範囲の外・目盛りが多すぎるときは null（引き直し）。
  /// [ev] は数か式の値、[render] はラベルの `{…}` を入れる関数、[values] は曲線の式で使うパラメータの値。
  ({List<FigureShape> shapes, List<FigureLabel> labels})? build(
    double Function(Object?) ev,
    String Function(String) render,
    Map<String, double> values,
  ) {
    final xlo = ev(xRange[0]), xhi = ev(xRange[1]), ylo = ev(yRange[0]), yhi = ev(yRange[1]);
    if ([xlo, xhi, ylo, yhi].any((v) => v.isNaN || v.isInfinite)) return null;
    if (!(xlo < xhi && ylo < yhi) || xlo > 0 || xhi < 0 || ylo > 0 || yhi < 0) return null;
    const lo = 10.0, hi = 90.0;
    double px(double x) => lo + (x - xlo) / (xhi - xlo) * (hi - lo);
    double py(double y) => hi - (y - ylo) / (yhi - ylo) * (hi - lo);
    _P pt(double x, double y) => (x: px(x), y: py(y));

    final s = <FigureShape>[];
    final l = <FigureLabel>[];
    // 軸
    s
      ..add(FigureShape.seg(pt(xlo, 0), pt(xhi, 0)))
      ..add(FigureShape.seg(pt(0, ylo), pt(0, yhi)));
    l
      ..add(FigureLabel(px(0) - 4, py(0) + 7, 'O'))
      ..add(FigureLabel(hi + 4, py(0) + 7, 'x'))
      ..add(FigureLabel(px(0) + 5, lo - 3, 'y'));
    // 目盛り
    void ticks(double? step, double min, double max, bool horizontal) {
      if (step == null) return;
      final first = (min / step).ceil(), last = (max / step).floor();
      if (last - first + 1 > maxTicks + 1) return;
      for (var k = first; k <= last; k++) {
        if (k == 0) continue;
        final v = k * step;
        if (horizontal) {
          s.add(FigureShape.seg(pt(v, 0), (x: px(v), y: py(0) - 1.5)));
          l.add(FigureLabel(px(v), py(0) + 6, _fmt(v)));
        } else {
          s.add(FigureShape.seg(pt(0, v), (x: px(0) + 1.5, y: py(v))));
          l.add(FigureLabel(px(0) - 5, py(v) + 2, _fmt(v)));
        }
      }
    }

    for (final t in [(xTick, xlo, xhi), (yTick, ylo, yhi)]) {
      final (step, a, b) = t;
      if (step != null && (b - a) / step > 4 * maxTicks) return null; // 目盛りが細かすぎる
    }
    ticks(xTick, xlo, xhi, true);
    ticks(yTick, ylo, yhi, false);

    // 曲線（y の範囲で切り取り、計算できない点で途切れる）
    for (final c in curves) {
      final run = <_P>[];
      void flush() {
        if (run.length >= 2) s.add(FigureShape.polyline(List.of(run), dashed: c.dashed));
        run.clear();
      }

      double? prevX, prevY;
      for (var i = 0; i <= samples; i++) {
        final x = xlo + (xhi - xlo) * i / samples;
        final y = c.expr.eval({...values, 'x': x});
        if (y.isNaN || y.isInfinite) {
          flush();
          prevX = prevY = null;
          continue;
        }
        if (prevX != null) {
          // 前の点との線分を y の範囲に切り取る（Liang–Barsky の y だけ）
          final dy = y - prevY!;
          var t0 = 0.0, t1 = 1.0;
          var ok = true;
          void clip(double p, double q) {
            if (p == 0) {
              if (q < 0) ok = false;
            } else {
              final r = q / p;
              if (p < 0) {
                if (r > t1) ok = false;
                if (r > t0) t0 = r;
              } else {
                if (r < t0) ok = false;
                if (r < t1) t1 = r;
              }
            }
          }

          clip(-dy, prevY - ylo);
          clip(dy, yhi - prevY);
          if (ok && t0 <= t1) {
            final ax = prevX + (x - prevX) * t0, ay = prevY + dy * t0;
            final bx = prevX + (x - prevX) * t1, by = prevY + dy * t1;
            if (run.isEmpty) run.add(pt(ax, ay));
            run.add(pt(bx, by));
            if (t1 < 1) flush();
          } else {
            flush();
          }
        }
        prevX = x;
        prevY = y;
      }
      flush();
    }

    // 点
    for (final p in points) {
      final x = ev(p.at[0]), y = ev(p.at[1]);
      if (x.isNaN || y.isNaN || x < xlo || x > xhi || y < ylo || y > yhi) return null;
      s.add(FigureShape.circle(pt(x, y), 1.3));
      final t = p.label;
      if (t != null) l.add(FigureLabel(px(x) + (x >= 0 ? 14 : -14), py(y) + 4, render(t))); // 曲線をよける（右の枝は右下、左の枝は左下）
    }
    return (shapes: s, labels: l);
  }
}
