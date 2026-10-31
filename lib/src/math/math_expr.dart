import 'dart:math' as math;

/// 数式（`2x+6`・`(x+3)^2`・`1/2`・`√2`）の読み取りと、同じ値かどうかの判定。
/// 純粋な Dart で、式の文字列を木にして、決まった点で値を比べる（記号計算はしない）。
/// 使える記号: 数・英小文字 1 字の変数・`+ - * / ^`・かっこ・`sqrt(…)`・`√`。
/// `2x`・`2(x+1)`・`(x+1)(x-1)` のような省略した掛け算も読む。`x2` や `2 3` は誤り。
class MathExpr {
  MathExpr._(this._root, this.variables);

  final _Node _root;

  /// 式に出てくる変数（辞書順）。
  final List<String> variables;

  /// 読めなければ [FormatException]。
  factory MathExpr.parse(String source) {
    final tokens = _tokenize(source);
    final p = _Parser(tokens);
    final node = p.parse();
    final vars = <String>{};
    node.collect(vars);
    return MathExpr._(node, vars.toList()..sort());
  }

  /// 読めれば式、読めなければ null。
  static MathExpr? tryParse(String source) {
    try {
      return MathExpr.parse(source);
    } on FormatException {
      return null;
    }
  }

  /// 変数に値を入れて計算する。0 での割り算・負の数の平方根などは NaN。
  double eval(Map<String, double> values) => _root.eval(values);

  /// 2 つの式が、すべての変数で同じ値になるか（決まった点で比べる）。
  /// 定義できる点が [minPoints] 未満なら比べられないので偽。
  static bool equivalent(MathExpr a, MathExpr b, {double tolerance = 1e-9, int minPoints = 5}) {
    final vars = {...a.variables, ...b.variables}.toList()..sort();
    var valid = 0;
    for (var k = 0; k < _samples.length; k++) {
      final env = {for (var i = 0; i < vars.length; i++) vars[i]: _samples[(k + i * 5) % _samples.length]};
      final x = a.eval(env), y = b.eval(env);
      if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) {
        if ((x.isNaN || x.isInfinite) != (y.isNaN || y.isInfinite)) return false; // 定義域が違う
        continue;
      }
      valid++;
      if ((x - y).abs() > tolerance * math.max(1.0, math.max(x.abs(), y.abs()))) return false;
    }
    return valid >= minPoints;
  }

  // 0・1・-1 は x と x^2 などが偶然一致するので避ける。
  static const _samples = <double>[2, 3, -2, 0.5, 5, -3, 1.5, 7, -0.7, 4, -1.3, 6, 2.5, -4, 8];
}

abstract class _Node {
  double eval(Map<String, double> v);
  void collect(Set<String> vars) {}
}

class _Num extends _Node {
  _Num(this.v);
  final double v;
  @override
  double eval(Map<String, double> _) => v;
}

class _Var extends _Node {
  _Var(this.name);
  final String name;
  @override
  double eval(Map<String, double> v) => v[name] ?? double.nan;
  @override
  void collect(Set<String> vars) => vars.add(name);
}

class _Bin extends _Node {
  _Bin(this.op, this.a, this.b);
  final String op;
  final _Node a, b;
  @override
  double eval(Map<String, double> v) {
    final x = a.eval(v), y = b.eval(v);
    switch (op) {
      case '+':
        return x + y;
      case '-':
        return x - y;
      case '*':
        return x * y;
      case '/':
        return y == 0 ? double.nan : x / y;
      default:
        return math.pow(x, y).toDouble(); // 負の数の小数乗は NaN
    }
  }

  @override
  void collect(Set<String> vars) {
    a.collect(vars);
    b.collect(vars);
  }
}

class _Neg extends _Node {
  _Neg(this.a);
  final _Node a;
  @override
  double eval(Map<String, double> v) => -a.eval(v);
  @override
  void collect(Set<String> vars) => a.collect(vars);
}

class _Sqrt extends _Node {
  _Sqrt(this.a);
  final _Node a;
  @override
  double eval(Map<String, double> v) {
    final x = a.eval(v);
    return x < 0 ? double.nan : math.sqrt(x);
  }

  @override
  void collect(Set<String> vars) => a.collect(vars);
}

const _superscripts = {'²': '2', '³': '3'};

List<String> _tokenize(String source) {
  final out = <String>[];
  final s = StringBuffer();
  for (final r in source.runes) {
    var c = String.fromCharCode(r);
    if (r >= 0xFF01 && r <= 0xFF5E) c = String.fromCharCode(r - 0xFEE0); // 全角英数記号→半角
    switch (c) {
      case '×' || '・' || '·':
        c = '*';
      case '÷':
        c = '/';
      case '−' || 'ー' || '－':
        c = '-';
      case '　':
        c = ' ';
    }
    if (_superscripts.containsKey(c)) {
      s.write('^${_superscripts[c]}');
    } else {
      s.write(c);
    }
  }
  final t = s.toString().replaceAll('√', 'sqrt');
  var i = 0;
  while (i < t.length) {
    final c = t[i];
    if (c == ' ') {
      i++;
    } else if (RegExp(r'[0-9.]').hasMatch(c)) {
      var j = i;
      while (j < t.length && RegExp(r'[0-9.]').hasMatch(t[j])) {
        j++;
      }
      final lit = t.substring(i, j);
      if (double.tryParse(lit) == null) throw FormatException('数として読めません: $lit');
      out.add(lit);
      i = j;
    } else if (t.startsWith('sqrt', i)) {
      out.add('sqrt');
      i += 4;
    } else if (RegExp(r'[a-z]').hasMatch(c)) {
      out.add(c);
      i++;
    } else if ('+-*/^()'.contains(c)) {
      out.add(c);
      i++;
    } else {
      throw FormatException('使えない文字です: $c');
    }
  }
  if (out.isEmpty) throw const FormatException('式が空です');
  return out;
}

class _Parser {
  _Parser(this.t);
  final List<String> t;
  var i = 0;

  String? get peek => i < t.length ? t[i] : null;

  _Node parse() {
    final n = _expr();
    if (i != t.length) throw FormatException('読めない部分があります: ${t[i]}');
    return n;
  }

  _Node _expr() {
    var n = _term();
    while (peek == '+' || peek == '-') {
      final op = t[i++];
      n = _Bin(op, n, _term());
    }
    return n;
  }

  bool _startsAtom(String? s) => s != null && (s == '(' || s == 'sqrt' || RegExp(r'^[a-z]$').hasMatch(s));

  _Node _term() {
    var n = _unary();
    while (true) {
      if (peek == '*' || peek == '/') {
        final op = t[i++];
        n = _Bin(op, n, _unary());
      } else if (_startsAtom(peek)) {
        n = _Bin('*', n, _unary()); // 省略した掛け算（数の直後に数は続けられない）
      } else {
        return n;
      }
    }
  }

  _Node _unary() {
    if (peek == '-') {
      i++;
      return _Neg(_unary());
    }
    if (peek == '+') {
      i++;
      return _unary();
    }
    return _power();
  }

  _Node _power() {
    final base = _atom();
    if (peek == '^') {
      i++;
      return _Bin('^', base, _unary());
    }
    return base;
  }

  _Node _atom() {
    final s = peek;
    if (s == null) throw const FormatException('式が途中で終わっています');
    i++;
    if (s == '(') {
      final n = _expr();
      if (peek != ')') throw const FormatException('かっこが閉じていません');
      i++;
      return n;
    }
    if (s == 'sqrt') {
      if (peek != '(') {
        // √2 のようにかっこなしは、直後の 1 つの数または変数だけを根号の中にする
        return _Sqrt(_atom());
      }
      i++;
      final n = _expr();
      if (peek != ')') throw const FormatException('かっこが閉じていません');
      i++;
      return _Sqrt(n);
    }
    final d = double.tryParse(s);
    if (d != null) return _Num(d);
    if (RegExp(r'^[a-z]$').hasMatch(s)) return _Var(s);
    throw FormatException('ここには置けません: $s');
  }
}
