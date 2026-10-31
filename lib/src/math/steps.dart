import 'dart:math' as math;

import 'math_expr.dart';

/// 方程式 `左 = 右`。
class MathEquation {
  MathEquation(this.left, this.right);

  final MathExpr left, right;

  /// `左=右`（全角の `＝` も可）。`=` が 1 つでない・両辺が読めないときは [FormatException]。
  factory MathEquation.parse(String source) {
    final s = source.replaceAll('＝', '=');
    if ('='.allMatches(s).length != 1) {
      throw const FormatException('等号（=）がちょうど 1 つの式にしてください');
    }
    final i = s.indexOf('=');
    return MathEquation(MathExpr.parse(s.substring(0, i)), MathExpr.parse(s.substring(i + 1)));
  }

  /// 変数の一覧（辞書順）。
  List<String> get variables => ({...left.variables, ...right.variables}.toList()..sort());

  /// 左辺 − 右辺。
  double residual(Map<String, double> env) => left.eval(env) - right.eval(env);

  // 変数ごとに決めた標本点で、2 つの式の残りが比例する（定数倍で一致する）か。
  static const _pts = <double>[2, 3, -2, 0.5, 5, -3, 1.5, 7, -0.7, 4, -1.3, 6, 2.5, -4, 8];

  /// 2 つの方程式が同じ解の集まりか。左辺 − 右辺が**0 でない定数倍**で一致するときに真
  /// （両辺に同じ数をたす・ひく・同じ 0 でない数をかける・わる、移項、同じ式の整理）。
  /// 両辺に変数をかける（`x=2` → `x*x=2*x`）は、解が増えるので別の方程式になる。
  /// どの点でも残りが 0 の式（`x=x`）どうしは同じ。
  static bool equivalent(MathEquation a, MathEquation b, {double tolerance = 1e-9}) {
    final vars = {...a.variables, ...b.variables}.toList()..sort();
    double? ratio;
    var valid = 0, zeroA = 0, zeroB = 0;
    for (var k = 0; k < _pts.length; k++) {
      final env = {for (var i = 0; i < vars.length; i++) vars[i]: _pts[(k + i * 5) % _pts.length]};
      final x = a.residual(env), y = b.residual(env);
      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) {
        if ((x.isNaN || x.isInfinite) != (y.isNaN || y.isInfinite)) return false;
        continue;
      }
      valid++;
      final zx = x.abs() <= tolerance * math.max(1.0, y.abs()), zy = y.abs() <= tolerance * math.max(1.0, x.abs());
      if (zx) zeroA++;
      if (zy) zeroB++;
      if (zx != zy) return false; // 片方だけ 0
      if (zx) continue;
      final r = x / y;
      if (ratio == null) {
        ratio = r;
      } else if ((r - ratio).abs() > 1e-7 * math.max(1.0, ratio.abs())) {
        return false;
      }
    }
    if (valid < 5) return false;
    if (zeroA == valid && zeroB == valid) return true; // どちらも恒等式
    return true; // 0 でない点があれば、比は 1 つに決まっている
  }

  /// 変数 [v] の一次式 `a v + b` になっているか（左辺 − 右辺）。そうなら (a, b)、違えば null。
  ({double a, double b})? linear(String v) {
    double f(double x) => residual({v: x});
    final f0 = f(0), f1 = f(1), f2 = f(2), f3 = f(-3);
    if ([f0, f1, f2, f3].any((e) => e.isNaN || e.isInfinite)) return null;
    final a = f1 - f0, b = f0;
    if ((f2 - (a * 2 + b)).abs() > 1e-7 || (f3 - (a * -3 + b)).abs() > 1e-7) return null;
    return (a: a, b: b);
  }

  /// 「x = 数」または「数 = x」の形（解の形）か。変数は 1 つで、片方の辺がその変数だけ、もう片方が変数を含まない。
  bool get isSolvedForm {
    final lv = left.variables, rv = right.variables;
    if (lv.length == 1 && rv.isEmpty) return _isBareVar(left);
    if (rv.length == 1 && lv.isEmpty) return _isBareVar(right);
    return false;
  }

  static bool _isBareVar(MathExpr e) {
    final v = e.variables.single;
    return MathExpr.equivalent(e, MathExpr.parse(v)) &&
        e.hasForm('expanded', MathExpr.parse(v)) &&
        !_hasCoefficient(e, v);
  }

  static bool _hasCoefficient(MathExpr e, String v) =>
      (e.eval({v: 2}) - 2).abs() > 1e-9 || (e.eval({v: 5}) - 5).abs() > 1e-9;
}

/// 途中式の 1 行の判定。
enum LineStatus {
  /// 前の行と同じ値（同じ解）。最初の行（問題）もこれ。
  ok,

  /// 前の行と同じ値（同じ解）でない。ここで式が変わった。
  broken,

  /// 式として読めない。
  unreadable,

  /// 前の行と種類（式／方程式）が違う。
  kindMismatch,
}

/// 途中式の種類。
enum LineKind { expression, equation }

/// 1 行ぶんの結果。[tag] は、この行が前の行からのよくある誤りに当たるときの誤解の型。
class LineVerdict {
  const LineVerdict(this.index, this.text, this.status, {this.tag});

  final int index;
  final String text;
  final LineStatus status;
  final String? tag;
}

/// 途中式の判定結果。
class SolutionCheck {
  const SolutionCheck({
    required this.kind,
    required this.verdicts,
    required this.firstProblem,
    required this.reachedTarget,
    required this.finalNotSolved,
    required this.finalWrongForm,
  });

  final LineKind? kind;
  final List<LineVerdict> verdicts;

  /// 最初に ok でなかった行の番号（0 始まり）。なければ null。
  final int? firstProblem;

  /// すべての行が ok で、最後の行が目標に着いたか（目標を渡したときだけ真になりうる）。
  final bool reachedTarget;

  /// 方程式で、最後の行は目標と同じ解だが、解の形（`x = 数`）まで整理されていない。
  final bool finalNotSolved;

  /// 式で、最後の行は目標と同じ値だが、指定した形（`expanded` など）になっていない。
  final bool finalWrongForm;

  /// 最初に壊れた行の誤解の型（なければ null）。
  String? get tag => firstProblem == null ? null : verdicts[firstProblem!].tag;

  /// ここまで全部 ok か。
  bool get allOk => firstProblem == null;
}

/// 途中式を 1 行ずつ判定する。[lines] の最初の行は問題の式（または方程式）で、各行が**前の行と同じ値（同じ解）**なら ok。
/// 最初に壊れた行を [SolutionCheck.firstProblem] で返し、その行が前の行からのよくある誤りに当たるときは誤解の型を付ける
/// （例: `2x+3=11` → `2x=11+3` は `move_term_sign`、`2(x+3)` → `2x+3` は `distribute_first_only`）。
/// [target] を渡すと、最後の行が目標に着いたかも返す（方程式は解の形まで、式は [form] まで）。
/// 全行は同じ種類（式か方程式）にする。空の行は読めない行として数える。
SolutionCheck checkSolutionSteps(List<String> lines, {String? target, String? form}) {
  final verdicts = <LineVerdict>[];
  LineKind? kind;
  Object? prev; // MathExpr か MathEquation
  int? firstProblem;
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i];
    final parsed = _parseLine(text);
    if (parsed == null) {
      verdicts.add(LineVerdict(i, text, LineStatus.unreadable));
      firstProblem ??= i;
      continue;
    }
    final k = parsed is MathEquation ? LineKind.equation : LineKind.expression;
    kind ??= k;
    if (k != kind) {
      verdicts.add(LineVerdict(i, text, LineStatus.kindMismatch));
      firstProblem ??= i;
      continue;
    }
    if (prev == null) {
      verdicts.add(LineVerdict(i, text, LineStatus.ok));
      prev = parsed;
      continue;
    }
    final same = parsed is MathEquation
        ? MathEquation.equivalent(prev as MathEquation, parsed)
        : MathExpr.equivalent(prev as MathExpr, parsed as MathExpr);
    if (same) {
      verdicts.add(LineVerdict(i, text, LineStatus.ok));
    } else {
      verdicts.add(LineVerdict(i, text, LineStatus.broken, tag: _diagnose(prev, parsed)));
      firstProblem ??= i;
    }
    prev = parsed; // 次の行は、この行（書かれたとおり）との比較にする
  }
  var reached = false, notSolved = false, wrongForm = false;
  if (target != null && firstProblem == null && prev != null && kind != null) {
    final t = _parseLine(target);
    if (t != null && (t is MathEquation) == (kind == LineKind.equation)) {
      if (t is MathEquation) {
        final last = prev as MathEquation;
        if (MathEquation.equivalent(last, t)) {
          if (last.isSolvedForm || !t.isSolvedForm) {
            reached = true;
          } else {
            notSolved = true;
          }
        }
      } else {
        final last = prev as MathExpr;
        if (MathExpr.equivalent(last, t as MathExpr)) {
          if (form == null || last.hasForm(form, t)) {
            reached = true;
          } else {
            wrongForm = true;
          }
        }
      }
    }
  }
  return SolutionCheck(
    kind: kind,
    verdicts: verdicts,
    firstProblem: firstProblem,
    reachedTarget: reached,
    finalNotSolved: notSolved,
    finalWrongForm: wrongForm,
  );
}

Object? _parseLine(String text) {
  final s = text.replaceAll('＝', '=');
  if (s.contains('=')) {
    try {
      return MathEquation.parse(s);
    } on FormatException {
      return null;
    }
  }
  return MathExpr.tryParse(s);
}

/// 前の行 [prev] から、同じでなくなった行 [cur] への、よくある誤りの型。当たるものがなければ null。
String? _diagnose(Object prev, Object cur) {
  if (prev is MathExpr && cur is MathExpr) {
    for (final m in prev.commonMistakes()) {
      if (MathExpr.equivalent(m.expr, cur)) return m.tag;
    }
    return null;
  }
  final p = prev as MathEquation, c = cur as MathEquation;
  // 1) 一次方程式の移項・割り算の誤り
  final vars = p.variables;
  if (vars.length == 1) {
    final v = vars.single;
    final lf = p.left.linearIn(v), rf = p.right.linearIn(v);
    final cl = c.linear(v);
    if (lf != null && rf != null && cl != null) {
      bool same(double a, double b) {
        // 残り a x + b が cl の定数倍か
        final cross = a * cl.b - b * cl.a;
        final zero = a.abs() < 1e-9 && b.abs() < 1e-9;
        return !zero && cross.abs() < 1e-7 * math.max(1.0, math.max(a.abs() + b.abs(), cl.a.abs() + cl.b.abs()));
      }

      final a = lf.a, b = lf.b, cc = rf.a, d = rf.b;
      // 割り算の誤り（a x = e の形から x = ?）
      String? divide() {
        final ra = a - cc, rb = b - d; // 残り ra x + rb = 0 → ra x = e（e = -rb）
        if (ra.abs() < 1e-9) return null; // x の項が消える（解がない・すべての数が解）
        final e = -rb;
        final solved = -cl.b / cl.a;
        bool is_(double w) => (solved - w).abs() < 1e-7;
        if ((ra - 1).abs() < 1e-9) return is_(-e) ? 'sign_flip' : null; // 係数が 1 なら割り算の誤りは符号だけ
        if (is_(e)) return 'forgot_to_divide';
        if (is_(e * ra)) return 'multiplied_instead_of_divide';
        if (is_(ra / e)) return 'divide_reversed';
        if (is_(-e / ra)) return 'sign_flip';
        return null;
      }

      // 項を移すときに符号を変えない（動かす項が 0 なら、誤りの式も正しい式と同じになるので、前の行と同じでなかった行には当たらない）
      String? move() {
        final moved = <(double, double)>[
          (a - cc, -(b + d)), // 左の定数を、符号を変えずに右へ
          (a - cc, b + d), // 右の定数を、符号を変えずに左へ
          (a + cc, b - d), // 右の x の項を、符号を変えずに左へ
          (-(a + cc), b - d), // 左の x の項を、符号を変えずに右へ
        ];
        for (final (ma, mb) in moved) {
          if (same(ma, mb)) return 'move_term_sign';
        }
        return null;
      }

      // `a x = e` の形（動かす項がない）からの 1 手は割り算、それ以外は移項を先に疑う
      final divisionStep = b.abs() < 1e-9 && cc.abs() < 1e-9;
      final t = divisionStep ? (divide() ?? move()) : (move() ?? divide());
      if (t != null) return t;
    }
  }
  // 2) 片方の辺の式の誤り（分配・かっこの符号・まとめ違いなど。一次方程式の移項・割り算より後に調べる）
  for (final m in p.left.commonMistakes()) {
    if (MathEquation.equivalent(MathEquation(m.expr, p.right), c)) return m.tag;
  }
  for (final m in p.right.commonMistakes()) {
    if (MathEquation.equivalent(MathEquation(p.left, m.expr), c)) return m.tag;
  }
  return null;
}
