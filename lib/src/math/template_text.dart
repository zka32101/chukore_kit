import 'math_expr.dart';

/// 値が整数または分母 1000 以下の分数で正確に書けないときに投げる（変種生成は引き直す）。
class InexactValueException implements Exception {
  const InexactValueException(this.source);
  final String source;
  @override
  String toString() => 'InexactValueException: $source';
}

/// [v] を整数または既約分数の文字列にする（`3`・`-3`・`3/4`・`-3/4`）。書けなければ null。
String? formatExact(double v) {
  if (v.isNaN || v.isInfinite || v.abs() > 1e12) return null;
  final r = v.roundToDouble();
  if ((v - r).abs() < 1e-9) return r == 0 ? '0' : r.toInt().toString();
  for (var q = 2; q <= 1000; q++) {
    final p = (v * q).roundToDouble();
    if ((v - p / q).abs() < 1e-9) {
      return '${p.toInt()}/$q'; // q は小さい順に探すので、約分済み
    }
  }
  return null;
}

/// 文字列中の `{…}` を、パラメータで計算した値に置き換える。数列（英大文字 1 字）は `{L}`（そのままの順）・`{~L}`（小さい順）で
/// `3, 8, 5` のように差し込む。
/// `{e}` 値、`{+e}` 符号つき（`+12`・`-12`・`+0`）、`{&e}` 負なら `(-3)` のようにかっこで囲む。
/// `e` はパラメータ（英小文字 1 字）の四則・`^`・かっこ・`sqrt`。パラメータに無い文字は [FormatException]、
/// 整数にも分数にも書けない値は [InexactValueException]。`{` と `}` 以外の文字はそのまま。
String renderTemplateString(String template, Map<String, double> params, {Map<String, List<double>> lists = const {}}) {
  final out = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final c = template[i];
    if (c == '}') throw FormatException('対応する { がありません: $template');
    if (c != '{') {
      out.write(c);
      i++;
      continue;
    }
    final end = template.indexOf('}', i);
    if (end < 0) throw FormatException('} で閉じていません: $template');
    var body = template.substring(i + 1, end);
    var mode = '';
    if (body.startsWith('+') || body.startsWith('&')) {
      mode = body[0];
      body = body.substring(1);
    }
    if (body.contains('{')) throw FormatException('{ が入れ子です: $template');
    out.write(_render(body, mode, params, lists));
    i = end + 1;
  }
  return out.toString();
}

String _render(String body, String mode, Map<String, double> params, Map<String, List<double>> lists) {
  final listRef = RegExp(r'^(~?)([A-Z])$').firstMatch(body);
  if (listRef != null) {
    if (mode.isNotEmpty) throw FormatException('数列には + や & は使えません: $body');
    final data = lists[listRef.group(2)];
    if (data == null) throw FormatException('数列にない名前です: ${listRef.group(2)}（$body）');
    final items = [...data];
    if (listRef.group(1) == '~') items.sort();
    return items.map((v) => formatExact(v) ?? (throw InexactValueException(body))).join(', ');
  }
  final e = MathExpr.parse(body);
  final unknown = e.variables.where((v) => !params.containsKey(v));
  if (unknown.isNotEmpty) throw FormatException('パラメータにない文字です: ${unknown.join()}（$body）');
  final s = formatExact(e.eval(params));
  if (s == null) throw InexactValueException(body);
  final neg = s.startsWith('-');
  switch (mode) {
    case '+':
      return neg ? s : '+$s';
    case '&':
      return neg ? '($s)' : s;
    default:
      return s;
  }
}

/// 制約 `左 比較 右`（比較は `== != <= >= < >`）をパラメータで評価する。計算できない（NaN）ときは偽。
bool evalConstraint(String constraint, Map<String, double> params) {
  const ops = ['==', '!=', '<=', '>=', '<', '>'];
  for (final op in ops) {
    final i = constraint.indexOf(op);
    if (i < 0) continue;
    final l = MathExpr.parse(constraint.substring(0, i)), r = MathExpr.parse(constraint.substring(i + op.length));
    for (final v in {...l.variables, ...r.variables}) {
      if (!params.containsKey(v)) throw FormatException('パラメータにない文字です: $v（$constraint）');
    }
    final a = l.eval(params), b = r.eval(params);
    if (a.isNaN || b.isNaN) return false;
    const eps = 1e-9;
    switch (op) {
      case '==':
        return (a - b).abs() <= eps;
      case '!=':
        return (a - b).abs() > eps;
      case '<=':
        return a <= b + eps;
      case '>=':
        return a >= b - eps;
      case '<':
        return a < b - eps;
      default:
        return a > b + eps;
    }
  }
  throw FormatException('比較（== != <= >= < >）がありません: $constraint');
}
