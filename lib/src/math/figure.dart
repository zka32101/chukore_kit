import 'dart:math' as math;

import 'math_expr.dart';

/// 図の仕様（平面図形）。点・線分・円・弧・多角形・角印・直角印・長さの印・ラベルを、座標で持つ。
/// 型（`MathTemplate`）の `figure` に書き、数は式（`"10+a*2"`）と `{…}` で差し込む。描くのは画面側か [Figure.toSvg]。
/// 設計は docs/math_figures_design.md §3。
class FigureTemplate {
  FigureTemplate._(this._points, this._draw, this._marks, this.viewBox, this.names, this.altId);

  final List<({String name, Object spec})> _points;
  final List<Map<String, dynamic>> _draw;
  final List<Map<String, dynamic>> _marks;
  final List<double> viewBox;
  final bool names;
  final String altId;

  static const _keys = {'viewBox', 'points', 'draw', 'marks', 'names', 'altId'};
  static const _drawKinds = {'seg', 'circle', 'arc', 'poly'};
  static const _markKinds = {'angle', 'right', 'tick', 'length', 'text'};

  /// 読めなければ [FormatException]。[known] は式で使える名前（パラメータ・stats・derived）。
  factory FigureTemplate.fromJson(Map<String, dynamic> j, Set<String> known) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('figure: 未知のキー: ${unknown.join(', ')}');
    final vb = j['viewBox'];
    if (vb is! List || vb.length != 4 || vb.any((e) => e is! num) || (vb[2] as num) <= 0 || (vb[3] as num) <= 0) {
      throw const FormatException('figure: viewBox は [x, y, 幅, 高さ]（幅・高さは正）');
    }
    final altId = j['altId'];
    if (altId is! String || altId.isEmpty) throw const FormatException('figure: altId（図の説明の ID）が必要です');
    final rawPoints = j['points'];
    if (rawPoints is! Map || rawPoints.isEmpty) throw const FormatException('figure: points が必要です');

    void expr(Object? e, String where) {
      if (e is num) return;
      if (e is! String) throw FormatException('figure: $where は数か式');
      final x = MathExpr.tryParse(e);
      if (x == null) throw FormatException('figure: $where の式が読めません: $e');
      final bad = x.variables.where((v) => !known.contains(v));
      if (bad.isNotEmpty) throw FormatException('figure: $where にパラメータにない文字 ${bad.join()}: $e');
    }

    final points = <({String name, Object spec})>[];
    final names = <String>{};
    for (final e in rawPoints.entries) {
      final n = e.key as String;
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(n)) throw FormatException('figure: 点の名前が不正: $n');
      final v = e.value;
      if (v is List && v.length == 2) {
        expr(v[0], '点 $n の x');
        expr(v[1], '点 $n の y');
      } else if (v is Map && v.length == 1 && v['polar'] is List && (v['polar'] as List).length == 3) {
        final p = v['polar'] as List;
        if (p[0] is! String || !names.contains(p[0])) {
          throw FormatException('figure: 点 $n の polar の中心は先に宣言した点: ${p[0]}');
        }
        expr(p[1], '点 $n の半径');
        expr(p[2], '点 $n の角度');
      } else {
        throw FormatException('figure: 点 $n は [x, y] か {"polar": [中心, 半径, 角度]}');
      }
      names.add(n);
      points.add((name: n, spec: v as Object));
    }

    void pointRef(Object? p, String where) {
      if (p is! String || !names.contains(p)) throw FormatException('figure: $where に宣言のない点: $p');
    }

    List<Map<String, dynamic>> items(String key, Set<String> kinds) {
      final raw = j[key];
      if (raw == null) return const [];
      if (raw is! List) throw FormatException('figure: $key は配列');
      final out = <Map<String, dynamic>>[];
      for (final r in raw) {
        if (r is! Map || r.isEmpty) throw FormatException('figure: $key の要素は {種類: …}');
        final m = Map<String, dynamic>.from(r);
        final kind = m.keys.where(kinds.contains).toList();
        if (kind.length != 1) {
          throw FormatException('figure: $key の要素の種類は ${kinds.join('・')} のどれか 1 つ: ${r.keys.join(',')}');
        }
        final k = kind.single;
        final v = m[k];
        if (m['label'] != null && m['label'] is! String) {
          throw FormatException('figure: $k の label は文字列');
        }
        if (m['fill'] != null && (m['fill'] is! bool || k != 'poly')) {
          throw FormatException('figure: fill は poly の true/false');
        }
        if (m['n'] != null && (m['n'] is! int || (m['n'] as int) < 1 || (m['n'] as int) > 4 || k != 'tick')) {
          throw FormatException('figure: n は tick の 1〜4');
        }
        final extra = m.keys.where((e) => e != k && !const {'label', 'style', 'fill', 'n'}.contains(e));
        if (extra.isNotEmpty) throw FormatException('figure: $k に未知のキー: ${extra.join(', ')}');
        switch (k) {
          case 'seg' || 'poly':
            if (v is! List || v.length < 2 || (k == 'seg' && v.length != 2) || (k == 'poly' && v.length < 3)) {
              throw FormatException('figure: $k の点の数が不正');
            }
            for (final p in v) {
              pointRef(p, k);
            }
          case 'circle':
            if (v is! List || v.length != 2) throw const FormatException('figure: circle は [中心, 半径]');
            pointRef(v[0], 'circle');
            expr(v[1], 'circle の半径');
          case 'arc':
            if (v is! List || v.length != 4) throw const FormatException('figure: arc は [中心, 半径, 開始角, 終了角]');
            pointRef(v[0], 'arc');
            for (var i = 1; i < 4; i++) {
              expr(v[i], 'arc');
            }
          case 'angle' || 'right':
            if (v is! List || v.length != 3) throw FormatException('figure: $k は [端の点, 頂点, 端の点]');
            for (final p in v) {
              pointRef(p, k);
            }
          case 'tick' || 'length':
            if (v is! List || v.length != 2) throw FormatException('figure: $k は [点, 点]');
            for (final p in v) {
              pointRef(p, k);
            }
          case 'text':
            if (v is! List || v.length != 2) throw const FormatException('figure: text は [点, 文字列]');
            pointRef(v[0], 'text');
            if (v[1] is! String) throw const FormatException('figure: text の文字列');
        }
        final style = m['style'];
        if (style != null && style != 'dashed') throw FormatException('figure: style は dashed だけ: $style');
        out.add(m);
      }
      return out;
    }

    return FigureTemplate._(
      points,
      items('draw', _drawKinds),
      items('marks', _markKinds),
      [for (final e in vb) (e as num).toDouble()],
      j['names'] == true,
      altId,
    );
  }

  /// 値を入れて座標にする。図が枠の外にはみ出す・点が重なる・角が作れないなど、描けないときは null
  /// （変種生成が引き直す）。
  Figure? resolve(Map<String, double> values, String Function(String) render) {
    double ev(Object? e) {
      if (e is num) return e.toDouble();
      return MathExpr.parse(e as String).eval(values);
    }

    final pts = <String, ({double x, double y})>{};
    for (final p in _points) {
      final s = p.spec;
      double x, y;
      if (s is List) {
        x = ev(s[0]);
        y = ev(s[1]);
      } else {
        final polar = (s as Map)['polar'] as List;
        final o = pts[polar[0]]!;
        final r = ev(polar[1]), t = ev(polar[2]) * math.pi / 180;
        x = o.x + r * math.cos(t);
        y = o.y - r * math.sin(t);
      }
      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) return null;
      pts[p.name] = (x: x, y: y);
    }
    final minX = viewBox[0], minY = viewBox[1], maxX = viewBox[0] + viewBox[2], maxY = viewBox[1] + viewBox[3];
    for (final p in pts.values) {
      if (p.x < minX || p.x > maxX || p.y < minY || p.y > maxY) return null;
    }
    final list = pts.values.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if ((list[i].x - list[j].x).abs() < 1e-6 && (list[i].y - list[j].y).abs() < 1e-6) return null;
      }
    }
    final shapes = <FigureShape>[];
    for (final d in _draw) {
      final dashed = d['style'] == 'dashed';
      if (d.containsKey('seg')) {
        final v = d['seg'] as List;
        shapes.add(FigureShape.seg(pts[v[0]]!, pts[v[1]]!, dashed: dashed));
      } else if (d.containsKey('poly')) {
        shapes.add(
          FigureShape.poly([for (final n in d['poly'] as List) pts[n]!], fill: d['fill'] == true, dashed: dashed),
        );
      } else if (d.containsKey('circle')) {
        final v = d['circle'] as List;
        final r = ev(v[1]);
        if (!(r > 0)) return null;
        shapes.add(FigureShape.circle(pts[v[0]]!, r, dashed: dashed));
      } else {
        final v = d['arc'] as List;
        final r = ev(v[1]), a = ev(v[2]), b = ev(v[3]);
        if (!(r > 0) || a.isNaN || b.isNaN || a == b) return null;
        shapes.add(FigureShape.arc(pts[v[0]]!, r, a, b, dashed: dashed));
      }
    }
    final labels = <FigureLabel>[];
    final marks = <FigureShape>[];
    for (final m in _marks) {
      String? label;
      final raw = m['label'];
      if (raw is String) label = render(raw);
      if (m.containsKey('angle') || m.containsKey('right')) {
        final v = (m['angle'] ?? m['right']) as List;
        final a = pts[v[0]]!, o = pts[v[1]]!, b = pts[v[2]]!;
        if ((a.x - o.x).abs() + (a.y - o.y).abs() < 1e-6 || (b.x - o.x).abs() + (b.y - o.y).abs() < 1e-6) return null;
        final cross = (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
        if (cross.abs() < 1e-6) return null; // 一直線の角は印にしない
        marks.add(m.containsKey('right') ? FigureShape.rightAngle(a, o, b) : FigureShape.angle(a, o, b));
        if (label != null) labels.add(_angleLabel(a, o, b, label));
      } else if (m.containsKey('tick')) {
        final v = m['tick'] as List;
        marks.add(FigureShape.tick(pts[v[0]]!, pts[v[1]]!, (m['n'] as int?) ?? 1));
      } else if (m.containsKey('length')) {
        final v = m['length'] as List;
        final a = pts[v[0]]!, b = pts[v[1]]!;
        if (label != null) labels.add(_lengthLabel(a, b, label));
      } else {
        final v = m['text'] as List;
        final p = pts[v[0]]!;
        labels.add(FigureLabel(p.x, p.y - 3, render(v[1] as String)));
      }
    }
    if (names) {
      final cx = list.map((p) => p.x).reduce((a, b) => a + b) / list.length;
      final cy = list.map((p) => p.y).reduce((a, b) => a + b) / list.length;
      for (final e in pts.entries) {
        final dx = e.value.x - cx, dy = e.value.y - cy;
        final d = math.sqrt(dx * dx + dy * dy);
        final ux = d < 1e-6 ? 0.0 : dx / d, uy = d < 1e-6 ? -1.0 : dy / d;
        labels.add(FigureLabel(e.value.x + ux * 5, e.value.y + uy * 5 + 2, e.key));
      }
    }
    return Figure._(viewBox, pts, [...shapes, ...marks], labels, altId);
  }

  static FigureLabel _angleLabel(
    ({double x, double y}) a,
    ({double x, double y}) o,
    ({double x, double y}) b,
    String label,
  ) {
    final a1 = math.atan2(a.y - o.y, a.x - o.x), a2 = math.atan2(b.y - o.y, b.x - o.x);
    var d = a2 - a1;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d <= -math.pi) {
      d += 2 * math.pi;
    }
    final mid = a1 + d / 2;
    return FigureLabel(o.x + 16 * math.cos(mid), o.y + 16 * math.sin(mid) + 2, label);
  }

  static FigureLabel _lengthLabel(({double x, double y}) a, ({double x, double y}) b, String label) {
    final mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
    final dx = b.x - a.x, dy = b.y - a.y;
    final d = math.sqrt(dx * dx + dy * dy);
    final nx = -dy / d, ny = dx / d; // 線分に垂直な向き
    return FigureLabel(mx + nx * 5, my + ny * 5 + 2, label);
  }
}

/// 図の要素の種類。
enum FigureShapeKind { seg, poly, circle, arc, angle, rightAngle, tick }

/// 描く図形 1 つ（座標は図の座標系。y は下向き）。
class FigureShape {
  const FigureShape._(
    this.kind,
    this.points, {
    this.r = 0,
    this.start = 0,
    this.end = 0,
    this.fill = false,
    this.dashed = false,
    this.n = 1,
  });

  final FigureShapeKind kind;
  final List<({double x, double y})> points;
  final double r, start, end;
  final bool fill, dashed;
  final int n;

  factory FigureShape.seg(({double x, double y}) a, ({double x, double y}) b, {bool dashed = false}) =>
      FigureShape._(FigureShapeKind.seg, [a, b], dashed: dashed);
  factory FigureShape.poly(List<({double x, double y})> p, {bool fill = false, bool dashed = false}) =>
      FigureShape._(FigureShapeKind.poly, p, fill: fill, dashed: dashed);
  factory FigureShape.circle(({double x, double y}) c, double r, {bool dashed = false}) =>
      FigureShape._(FigureShapeKind.circle, [c], r: r, dashed: dashed);
  factory FigureShape.arc(({double x, double y}) c, double r, double start, double end, {bool dashed = false}) =>
      FigureShape._(FigureShapeKind.arc, [c], r: r, start: start, end: end, dashed: dashed);
  factory FigureShape.angle(({double x, double y}) a, ({double x, double y}) o, ({double x, double y}) b) =>
      FigureShape._(FigureShapeKind.angle, [a, o, b]);
  factory FigureShape.rightAngle(({double x, double y}) a, ({double x, double y}) o, ({double x, double y}) b) =>
      FigureShape._(FigureShapeKind.rightAngle, [a, o, b]);
  factory FigureShape.tick(({double x, double y}) a, ({double x, double y}) b, int n) =>
      FigureShape._(FigureShapeKind.tick, [a, b], n: n);
}

/// 図の文字（ラベル）。位置は文字の中心。
class FigureLabel {
  const FigureLabel(this.x, this.y, this.text);

  final double x, y;
  final String text;
}

/// 値を入れた図。画面が [shapes]・[labels] から描くか、[toSvg] で SVG にする。
class Figure {
  const Figure._(this.viewBox, this.points, this.shapes, this.labels, this.altId);

  final List<double> viewBox;
  final Map<String, ({double x, double y})> points;
  final List<FigureShape> shapes;
  final List<FigureLabel> labels;

  /// 図の説明文の ID（文言はコンテンツ側）。
  final String altId;

  static String _n(double v) {
    final s = v.toStringAsFixed(2);
    return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
  }

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  /// SVG 文字列。色は `currentColor` だけ（画面の文字色に合わせる）。ラベルは XML エスケープする。
  /// 枠（[viewBox]）の外側に [padding] の余白をとる（枠の端の点のラベルが切れないように）。
  String toSvg({double fontSize = 6, double padding = 8}) {
    final vb = [viewBox[0] - padding, viewBox[1] - padding, viewBox[2] + 2 * padding, viewBox[3] + 2 * padding];
    final b = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb.map(_n).join(' ')}" ')
      ..write('fill="none" stroke="currentColor" stroke-width="0.8" stroke-linecap="round" stroke-linejoin="round">');
    for (final s in shapes) {
      final dash = s.dashed ? ' stroke-dasharray="3 2"' : '';
      final p = s.points;
      switch (s.kind) {
        case FigureShapeKind.seg:
          b.write('<line x1="${_n(p[0].x)}" y1="${_n(p[0].y)}" x2="${_n(p[1].x)}" y2="${_n(p[1].y)}"$dash/>');
        case FigureShapeKind.poly:
          final fill = s.fill ? ' fill="currentColor" fill-opacity="0.12"' : '';
          b.write('<polygon points="${p.map((e) => '${_n(e.x)},${_n(e.y)}').join(' ')}"$fill$dash/>');
        case FigureShapeKind.circle:
          b.write('<circle cx="${_n(p[0].x)}" cy="${_n(p[0].y)}" r="${_n(s.r)}"$dash/>');
        case FigureShapeKind.arc:
          final t0 = s.start * math.pi / 180, t1 = s.end * math.pi / 180;
          final x0 = p[0].x + s.r * math.cos(t0), y0 = p[0].y - s.r * math.sin(t0);
          final x1 = p[0].x + s.r * math.cos(t1), y1 = p[0].y - s.r * math.sin(t1);
          final sweepDeg = (s.end - s.start) % 360; // Dart の % は割る数が正なら 0 以上
          b.write(
            '<path d="M${_n(x0)} ${_n(y0)}A${_n(s.r)} ${_n(s.r)} 0 ${sweepDeg > 180 ? 1 : 0} 0 ${_n(x1)} ${_n(y1)}"$dash/>',
          );
        case FigureShapeKind.angle:
          final a1 = math.atan2(p[0].y - p[1].y, p[0].x - p[1].x), a2 = math.atan2(p[2].y - p[1].y, p[2].x - p[1].x);
          var d = a2 - a1;
          while (d > math.pi) {
            d -= 2 * math.pi;
          }
          while (d <= -math.pi) {
            d += 2 * math.pi;
          }
          const r = 8.0;
          final sx = p[1].x + r * math.cos(a1), sy = p[1].y + r * math.sin(a1);
          final ex = p[1].x + r * math.cos(a2), ey = p[1].y + r * math.sin(a2);
          b.write('<path d="M${_n(sx)} ${_n(sy)}A${_n(r)} ${_n(r)} 0 0 ${d > 0 ? 1 : 0} ${_n(ex)} ${_n(ey)}"/>');
        case FigureShapeKind.rightAngle:
          double len(({double x, double y}) q) =>
              math.sqrt(math.pow(q.x - p[1].x, 2) + math.pow(q.y - p[1].y, 2)).toDouble();
          final ux = (p[0].x - p[1].x) / len(p[0]) * 6, uy = (p[0].y - p[1].y) / len(p[0]) * 6;
          final vx = (p[2].x - p[1].x) / len(p[2]) * 6, vy = (p[2].y - p[1].y) / len(p[2]) * 6;
          b.write(
            '<polyline points="${_n(p[1].x + ux)},${_n(p[1].y + uy)} ${_n(p[1].x + ux + vx)},${_n(p[1].y + uy + vy)} ${_n(p[1].x + vx)},${_n(p[1].y + vy)}"/>',
          );
        case FigureShapeKind.tick:
          final mx = (p[0].x + p[1].x) / 2, my = (p[0].y + p[1].y) / 2;
          final dx = p[1].x - p[0].x, dy = p[1].y - p[0].y;
          final d = math.sqrt(dx * dx + dy * dy);
          final nx = -dy / d * 2.5, ny = dx / d * 2.5, tx = dx / d * 1.2, ty = dy / d * 1.2;
          for (var i = 0; i < s.n; i++) {
            final off = (i - (s.n - 1) / 2) * 2.4;
            b.write(
              '<line x1="${_n(mx + tx * off - nx)}" y1="${_n(my + ty * off - ny)}" x2="${_n(mx + tx * off + nx)}" y2="${_n(my + ty * off + ny)}"/>',
            );
          }
      }
    }
    for (final l in labels) {
      b.write(
        '<text x="${_n(l.x)}" y="${_n(l.y)}" font-size="${_n(fontSize)}" text-anchor="middle" fill="currentColor" stroke="none">${_esc(l.text)}</text>',
      );
    }
    b.write('</svg>');
    return b.toString();
  }
}
