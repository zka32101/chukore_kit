import 'dart:convert';
import 'dart:math' as math;

import '../bank/question_bank.dart';
import '../scope/unit_tree.dart';
import 'figure.dart';

/// 平面上の点。
typedef PlanePoint = ({double x, double y});

const _eps = 1e-7;

/// 作図の目標（定規とコンパスで引く直線）。
sealed class ConstructionGoal {
  const ConstructionGoal();

  /// 目標の直線（通る 1 点と向き）。
  ({PlanePoint point, PlanePoint dir}) line(Map<String, PlanePoint> givens);
}

/// 線分 AB の垂直二等分線。
class PerpendicularBisectorGoal extends ConstructionGoal {
  const PerpendicularBisectorGoal(this.a, this.b);

  final String a, b;

  @override
  ({PlanePoint point, PlanePoint dir}) line(Map<String, PlanePoint> g) {
    final p = g[a]!, q = g[b]!;
    return (point: (x: (p.x + q.x) / 2, y: (p.y + q.y) / 2), dir: (x: -(q.y - p.y), y: q.x - p.x));
  }
}

/// ∠AOB の二等分線（O から引く）。
class AngleBisectorGoal extends ConstructionGoal {
  const AngleBisectorGoal(this.a, this.o, this.b);

  final String a, o, b;

  @override
  ({PlanePoint point, PlanePoint dir}) line(Map<String, PlanePoint> g) {
    final pa = g[a]!, po = g[o]!, pb = g[b]!;
    final la = math.sqrt(math.pow(pa.x - po.x, 2) + math.pow(pa.y - po.y, 2));
    final lb = math.sqrt(math.pow(pb.x - po.x, 2) + math.pow(pb.y - po.y, 2));
    return (point: po, dir: (x: (pa.x - po.x) / la + (pb.x - po.x) / lb, y: (pa.y - po.y) / la + (pb.y - po.y) / lb));
  }
}

/// 点 P を通り、直線 AB に垂直な直線（P が AB の上にあってもなくてもよい）。
class PerpendicularGoal extends ConstructionGoal {
  const PerpendicularGoal(this.through, this.a, this.b);

  final String through, a, b;

  @override
  ({PlanePoint point, PlanePoint dir}) line(Map<String, PlanePoint> g) {
    final p = g[a]!, q = g[b]!;
    return (point: g[through]!, dir: (x: -(q.y - p.y), y: q.x - p.x));
  }
}

/// 作図で作った図形 1 つ（直線か円）。
class ConstructedObject {
  const ConstructedObject.line(this.id, this.p, this.q) : isLine = true, cx = 0, cy = 0, r = 0;
  const ConstructedObject.circle(this.id, this.cx, this.cy, this.r) : isLine = false, p = null, q = null;

  final String id;
  final bool isLine;

  /// 直線の通る 2 点。
  final String? p, q;

  /// 円の中心と半径。
  final double cx, cy, r;
}

/// 作図の途中の状態。定規（2 点を通る直線）とコンパス（円）と、交点だけで進める。
/// 点は最初にある点と、交点だけを選べる（自由な位置に点は打てない）ので、手順そのものが作図として正しい。
/// ID は決まった順で付く: 円 `c1, c2, …`、直線 `l1, l2, …`、交点 `X1, X2, …`。
class ConstructionState {
  ConstructionState(Map<String, ({double x, double y})> givens) : _points = {...givens};

  final Map<String, PlanePoint> _points;
  final List<ConstructedObject> _objects = [];
  var _circles = 0, _lines = 0, _crossings = 0;

  /// 点（最初の点と交点）。
  Map<String, ({double x, double y})> get points => Map.unmodifiable(_points);

  /// 作った直線と円（作った順）。
  List<ConstructedObject> get objects => List.unmodifiable(_objects);

  /// 手順の数（円・直線・交点を求める操作の合計）。
  int steps = 0;

  PlanePoint _pt(String id) {
    final p = _points[id];
    if (p == null) throw ArgumentError('点がありません: $id');
    return p;
  }

  double _dist(PlanePoint a, PlanePoint b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  /// 中心 [center] の円。半径は、[a] だけなら center から a までの長さ、[a] と [b] なら線分 ab の長さ（コンパスを移す）。
  /// 半径が 0 になる円は作れない（[ArgumentError]）。
  String addCircle(String center, String a, [String? b]) {
    final c = _pt(center);
    final r = b == null ? _dist(c, _pt(a)) : _dist(_pt(a), _pt(b));
    if (r < _eps) throw ArgumentError('半径が 0 の円は作れません');
    steps++;
    final id = 'c${++_circles}';
    _objects.add(ConstructedObject.circle(id, c.x, c.y, r));
    return id;
  }

  /// 2 点 [a]・[b] を通る直線。同じ点は選べない（[ArgumentError]）。
  String addLine(String a, String b) {
    final p = _pt(a), q = _pt(b);
    if (_dist(p, q) < _eps) throw ArgumentError('同じ位置の 2 点では直線を引けません');
    steps++;
    final id = 'l${++_lines}';
    _objects.add(ConstructedObject.line(id, a, b));
    return id;
  }

  ConstructedObject _obj(String id) {
    for (final o in _objects) {
      if (o.id == id) return o;
    }
    throw ArgumentError('図形がありません: $id');
  }

  ({double a, double b, double c}) _implicit(ConstructedObject o) {
    final p = _pt(o.p!), q = _pt(o.q!);
    final dx = q.x - p.x, dy = q.y - p.y, len = math.sqrt(dx * dx + dy * dy);
    final a = dy / len, b = -dx / len;
    return (a: a, b: b, c: a * p.x + b * p.y);
  }

  /// 2 つの図形の交点を求め、点として加える。すでにある点と同じ位置の交点は、その点を返す。
  /// 交わらない・平行・同じ図形のときは空。同じ図形どうし（[a] == [b]）は [ArgumentError]。
  List<String> intersect(String a, String b) {
    if (a == b) throw ArgumentError('同じ図形どうしの交点は求められません');
    final o1 = _obj(a), o2 = _obj(b);
    steps++;
    final found = <PlanePoint>[];
    if (o1.isLine && o2.isLine) {
      final l1 = _implicit(o1), l2 = _implicit(o2);
      final det = l1.a * l2.b - l2.a * l1.b;
      if (det.abs() > 1e-12) {
        found.add((x: (l1.c * l2.b - l2.c * l1.b) / det, y: (l1.a * l2.c - l2.a * l1.c) / det));
      }
    } else if (o1.isLine != o2.isLine) {
      final line = o1.isLine ? o1 : o2, circle = o1.isLine ? o2 : o1;
      final l = _implicit(line);
      final d = l.a * circle.cx + l.b * circle.cy - l.c; // 中心から直線への符号つき距離
      if (d.abs() <= circle.r + _eps) {
        final fx = circle.cx - d * l.a, fy = circle.cy - d * l.b;
        final h = math.sqrt(math.max(0, circle.r * circle.r - d * d));
        if (h < _eps) {
          found.add((x: fx, y: fy));
        } else {
          found
            ..add((x: fx - h * l.b, y: fy + h * l.a))
            ..add((x: fx + h * l.b, y: fy - h * l.a));
        }
      }
    } else {
      final dx = o2.cx - o1.cx, dy = o2.cy - o1.cy, d = math.sqrt(dx * dx + dy * dy);
      if (d > _eps && d <= o1.r + o2.r + _eps && d >= (o1.r - o2.r).abs() - _eps) {
        final along = (o1.r * o1.r - o2.r * o2.r + d * d) / (2 * d);
        final h = math.sqrt(math.max(0, o1.r * o1.r - along * along));
        final ux = dx / d, uy = dy / d;
        final bx = o1.cx + along * ux, by = o1.cy + along * uy;
        if (h < _eps) {
          found.add((x: bx, y: by));
        } else {
          found
            ..add((x: bx - h * uy, y: by + h * ux))
            ..add((x: bx + h * uy, y: by - h * ux));
        }
      }
    }
    final ids = <String>[];
    for (final p in found) {
      final existing = _points.entries.where((e) => _dist(e.value, p) < 1e-6);
      if (existing.isNotEmpty) {
        ids.add(existing.first.key);
      } else {
        final id = 'X${++_crossings}';
        _points[id] = p;
        ids.add(id);
      }
    }
    return ids;
  }

  /// 引いた直線のうち、目標の直線と重なるものがあるか。
  bool isSolved(ConstructionGoal goal, Map<String, ({double x, double y})> givens) {
    final t = goal.line(givens);
    final tl = math.sqrt(t.dir.x * t.dir.x + t.dir.y * t.dir.y);
    for (final o in _objects.where((o) => o.isLine)) {
      final p = _pt(o.p!), q = _pt(o.q!);
      final dx = q.x - p.x, dy = q.y - p.y, len = math.sqrt(dx * dx + dy * dy);
      final cross = (dx * t.dir.y - dy * t.dir.x) / (len * tl); // 平行なら 0
      final off = ((t.point.x - p.x) * dy - (t.point.y - p.y) * dx) / len; // 目標の通る点から直線までの距離
      if (cross.abs() < 1e-6 && off.abs() < 1e-6) return true;
    }
    return false;
  }

  /// 直線を枠の中に切り取る（Liang–Barsky）。枠と交わらなければ null。
  static (PlanePoint, PlanePoint)? clipLine(PlanePoint p, PlanePoint q, List<double> box) {
    final dx = q.x - p.x, dy = q.y - p.y;
    var t0 = double.negativeInfinity, t1 = double.infinity;
    bool clip(double pk, double qk) {
      if (pk.abs() < 1e-12) return qk >= 0;
      final t = qk / pk;
      if (pk < 0) {
        if (t > t1) return false;
        t0 = math.max(t0, t);
      } else {
        if (t < t0) return false;
        t1 = math.min(t1, t);
      }
      return true;
    }

    final x0 = box[0], y0 = box[1], x1 = box[0] + box[2], y1 = box[1] + box[3];
    if (!clip(-dx, p.x - x0) || !clip(dx, x1 - p.x) || !clip(-dy, p.y - y0) || !clip(dy, y1 - p.y)) return null;
    return ((x: p.x + t0 * dx, y: p.y + t0 * dy), (x: p.x + t1 * dx, y: p.y + t1 * dy));
  }

  /// 途中経過の図。[shown] は最初から見せる図形（線分など）、点には名前を添える。
  Figure toFigure(List<double> viewBox, List<FigureShape> shown, {String altId = 'fig_construction'}) {
    final shapes = [...shown];
    for (final o in _objects) {
      if (o.isLine) {
        final c = clipLine(_pt(o.p!), _pt(o.q!), viewBox);
        if (c != null) shapes.add(FigureShape.seg(c.$1, c.$2));
      } else {
        shapes.add(FigureShape.circle((x: o.cx, y: o.cy), o.r));
      }
    }
    final labels = <FigureLabel>[];
    for (final e in _points.entries) {
      shapes.add(FigureShape.circle(e.value, 0.9));
      labels.add(FigureLabel(e.value.x + 3.5, e.value.y - 3, e.key));
    }
    return Figure.fromShapes(viewBox: viewBox, shapes: shapes, labels: labels, altId: altId, points: _points);
  }
}

/// 作図の教材 1 つ（体験型）。最初の点と目標、見せる図形、模範の手順を持つ。画面は選んだ点・図形の ID で [ConstructionState] を進める。
class Construction {
  Construction._({
    required this.id,
    required this.version,
    required this.unitId,
    required this.promptId,
    required this.explanationId,
    required this.altId,
    required this.viewBox,
    required this.givens,
    required this.show,
    required this.goal,
    required this.solution,
    required this.maxSteps,
  });

  final String id;
  final int version;
  final String unitId;
  final String promptId;
  final String explanationId;
  final String altId;
  final List<double> viewBox;
  final Map<String, ({double x, double y})> givens;
  final List<({String kind, List<String> points})> show;
  final ConstructionGoal goal;

  /// 模範の手順（ヒント・検証用）。`{"circle": [中心, 点]}`・`{"circle": [中心, 点 a, 点 b]}`・`{"line": [点, 点]}`・`{"intersect": [図形, 図形]}`。
  final List<Map<String, List<String>>> solution;

  /// 手順の数の上限（これを超えたら「もっと少ない手順で」と促す）。
  final int maxSteps;

  static const _keys = {
    'id', 'version', 'unitId', 'promptId', 'explanationId', 'altId', 'viewBox', 'givens', 'show', 'goal', //
    'solution', 'maxSteps',
  };

  factory Construction.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('未知のキー: ${unknown.join(', ')}');
    String str(String k) {
      final v = j[k];
      if (v is! String || v.isEmpty) throw FormatException('$k は空でない文字列');
      return v;
    }

    final id = str('id');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('id は英数字と _ だけ: $id');
    final version = j['version'];
    if (version is! int || version < 1) throw FormatException('$id: version は 1 以上の整数');
    final vb = j['viewBox'];
    if (vb is! List || vb.length != 4 || vb.any((e) => e is! num) || (vb[2] as num) <= 0 || (vb[3] as num) <= 0) {
      throw FormatException('$id: viewBox は [x, y, 幅, 高さ]');
    }
    final box = [for (final e in vb) (e as num).toDouble()];
    final rawGivens = j['givens'];
    if (rawGivens is! Map || rawGivens.length < 2) throw FormatException('$id: givens は 2 点以上');
    final givens = <String, PlanePoint>{};
    for (final e in rawGivens.entries) {
      final n = e.key as String, v = e.value;
      if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(n) || RegExp(r'^X\d+$').hasMatch(n)) {
        throw FormatException('$id: 点の名前は英大文字で始め、X1 などの交点の名前は使えない: $n');
      }
      if (v is! List || v.length != 2 || v.any((x) => x is! num)) throw FormatException('$id: 点 $n は [x, y]');
      final x = (v[0] as num).toDouble(), y = (v[1] as num).toDouble();
      if (x < box[0] || x > box[0] + box[2] || y < box[1] || y > box[1] + box[3]) {
        throw FormatException('$id: 点 $n が枠の外です');
      }
      givens[n] = (x: x, y: y);
    }
    final names = givens.keys.toList();
    for (var a = 0; a < names.length; a++) {
      for (var b = a + 1; b < names.length; b++) {
        final p = givens[names[a]]!, q = givens[names[b]]!;
        if ((p.x - q.x).abs() < 1e-6 && (p.y - q.y).abs() < 1e-6) {
          throw FormatException('$id: 点 ${names[a]} と ${names[b]} が重なっています');
        }
      }
    }
    void ref(Object? n, String where) {
      if (n is! String || !givens.containsKey(n)) throw FormatException('$id: $where に宣言のない点: $n');
    }

    final show = <({String kind, List<String> points})>[];
    for (final s in (j['show'] as List? ?? const [])) {
      if (s is! Map || s.length != 1) throw FormatException('$id: show の要素は {seg|line|ray: [点, 点]}');
      final k = s.keys.first as String, v = s[k];
      if (!const {'seg', 'line', 'ray'}.contains(k) || v is! List || v.length != 2) {
        throw FormatException('$id: show は seg・line・ray の [点, 点]: $k');
      }
      for (final n in v) {
        ref(n, 'show');
      }
      show.add((kind: k, points: [for (final n in v) n as String]));
    }
    final g = j['goal'];
    if (g is! Map || g['kind'] is! String) throw FormatException('$id: goal は {"kind": …}');
    final ConstructionGoal goal;
    List<String> names2(String key, int n) {
      final v = g[key];
      if (v is! List || v.length != n) throw FormatException('$id: goal の $key は点 $n つ');
      for (final x in v) {
        ref(x, 'goal');
      }
      return [for (final x in v) x as String];
    }

    switch (g['kind']) {
      case 'perpendicularBisector':
        _only(g, {'kind', 'of'}, id);
        final o = names2('of', 2);
        goal = PerpendicularBisectorGoal(o[0], o[1]);
      case 'angleBisector':
        _only(g, {'kind', 'of'}, id);
        final o = names2('of', 3);
        goal = AngleBisectorGoal(o[0], o[1], o[2]);
      case 'perpendicular':
        _only(g, {'kind', 'through', 'to'}, id);
        ref(g['through'], 'goal');
        final t = names2('to', 2);
        goal = PerpendicularGoal(g['through'] as String, t[0], t[1]);
      default:
        throw FormatException('$id: 未対応の goal: ${g['kind']}（perpendicularBisector・angleBisector・perpendicular）');
    }
    final solution = <Map<String, List<String>>>[];
    for (final s in (j['solution'] as List? ?? const [])) {
      if (s is! Map || s.length != 1) throw FormatException('$id: solution の要素は {circle|line|intersect: […]}');
      final k = s.keys.first as String, v = s[k];
      final okLen = switch (k) {
        'circle' => v is List && (v.length == 2 || v.length == 3),
        'line' || 'intersect' => v is List && v.length == 2,
        _ => false,
      };
      if (!okLen || (v as List).any((e) => e is! String || e.isEmpty)) {
        throw FormatException('$id: solution の $k が不正: $v');
      }
      solution.add({
        k: [for (final e in v) e as String],
      });
    }
    final maxSteps = j['maxSteps'] ?? 10;
    if (maxSteps is! int || maxSteps < 1 || maxSteps > 50) throw FormatException('$id: maxSteps は 1〜50');
    return Construction._(
      id: id,
      version: version,
      unitId: str('unitId'),
      promptId: str('promptId'),
      explanationId: str('explanationId'),
      altId: str('altId'),
      viewBox: box,
      givens: givens,
      show: show,
      goal: goal,
      solution: solution,
      maxSteps: maxSteps,
    );
  }

  static void _only(Map g, Set<String> keys, String id) {
    final extra = g.keys.where((k) => !keys.contains(k));
    if (extra.isNotEmpty) throw FormatException('$id: goal に未知のキー: ${extra.join(', ')}');
  }

  /// 最初の状態。
  ConstructionState start() => ConstructionState(givens);

  /// 手順 [steps]（[solution] と同じ形）を最初から順に実行した状態。手順が成り立たない（点がない・交わらない図形の交点の名前を使うなど）ときは
  /// [ArgumentError]。交点の名前は、実際にできた順の `X1, X2, …` で参照する。
  ConstructionState replay(List<Map<String, List<String>>> steps) {
    final s = start();
    for (final step in steps) {
      final k = step.keys.single, v = step[k]!;
      switch (k) {
        case 'circle':
          s.addCircle(v[0], v[1], v.length == 3 ? v[2] : null);
        case 'line':
          s.addLine(v[0], v[1]);
        default:
          s.intersect(v[0], v[1]);
      }
    }
    return s;
  }

  /// 目標を達成したか。
  bool isSolved(ConstructionState s) => s.isSolved(goal, givens);

  /// 見せる図形（線分・直線・半直線）を図形にしたもの。
  List<FigureShape> shownShapes() {
    final shapes = <FigureShape>[];
    for (final s in show) {
      final p = givens[s.points[0]]!, q = givens[s.points[1]]!;
      switch (s.kind) {
        case 'seg':
          shapes.add(FigureShape.seg(p, q));
        case 'line':
          final c = ConstructionState.clipLine(p, q, viewBox);
          if (c != null) shapes.add(FigureShape.seg(c.$1, c.$2));
        default: // ray: p から q の向きに枠の端まで（p は枠の中にあるので、切り取った線分の後ろの端が前方）
          final c = ConstructionState.clipLine(p, q, viewBox);
          if (c != null) shapes.add(FigureShape.seg(p, c.$2));
      }
    }
    return shapes;
  }

  /// 今の状態の図。
  Figure figure(ConstructionState s) => s.toFigure(viewBox, shownShapes(), altId: altId);
}

/// 作図教材の集まり（`constructions.json`）。
class ConstructionSet {
  const ConstructionSet(this.constructions);

  final List<Construction> constructions;

  /// `{"version":1,"constructions":[…]}`。読めなければ [FormatException]。
  factory ConstructionSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('作図の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('作図の JSON はオブジェクトです');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['constructions'];
    if (raw is! List) throw const FormatException('constructions が必要です');
    final out = [for (final c in raw) Construction.fromJson(Map<String, dynamic>.from(c as Map))];
    final ids = <String>{};
    for (final c in out) {
      if (!ids.add(c.id)) throw FormatException('id が重複しています: ${c.id}');
    }
    return ConstructionSet(out);
  }
}

/// 作図教材の検証。`construction_unit_missing`（単元がない）・`construction_solution_missing`（模範の手順がない）・
/// `construction_solution_fails`（模範の手順が成り立たない、または目標を達成しない）・`construction_solution_too_long`
/// （模範が `maxSteps` を超える）はエラー。
List<ValidationIssue> validateConstructions(ConstructionSet set, {required UnitTree tree}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) => issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  for (final c in set.constructions) {
    if (tree[c.unitId] == null) err('construction_unit_missing', c.id, '単元 ${c.unitId} がありません');
    if (c.solution.isEmpty) {
      err('construction_solution_missing', c.id, '模範の手順（solution）がありません');
      continue;
    }
    try {
      final s = c.replay(c.solution);
      if (!c.isSolved(s)) {
        err('construction_solution_fails', c.id, '模範の手順で目標の直線が引けません');
      } else if (s.steps > c.maxSteps) {
        err('construction_solution_too_long', c.id, '模範の手順 ${s.steps} 回が maxSteps ${c.maxSteps} を超えています');
      }
    } on ArgumentError catch (e) {
      err('construction_solution_fails', c.id, '模範の手順が成り立ちません: ${e.message}');
    }
  }
  return issues;
}
