import 'dart:math' as math;

/// 数式（`2x+6`・`(x+3)^2`・`1/2`・`√2`）の読み取りと、同じ値かどうかの判定。
/// 純粋な Dart で、式の文字列を木にして、決まった点で値を比べる（記号計算はしない）。
/// 使える記号: 数・英小文字 1 字の変数・`+ - * / ^`・かっこ・`sqrt(…)`・`√`・円周率 `π`（`pi` とも書ける）。
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

  /// 一部の変数を定数に置き換えた式（残りの変数はそのまま）。体験型で、パラメータを決めた式を比べるのに使う。
  MathExpr bind(Map<String, double> values) {
    final node = _root.bind(values);
    final vars = <String>{};
    node.collect(vars);
    return MathExpr._(node, vars.toList()..sort());
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

  /// 答えの形の指定（[knownExprForms]）を満たすか。値が同じかどうかは見ない（[equivalent] と合わせて使う）。
  /// [reference] は正解の式（`expanded` で、同類項をまとめ忘れた式を見分けるのに使う）。
  /// `factored` は「積の形」かどうかだけを見る（これ以上因数分解できないかは見ない）。
  bool hasForm(String form, MathExpr reference) {
    switch (form) {
      case 'expanded':
        return _isExpanded(_root) && _terms(_root) <= _terms(reference._root);
      case 'factored':
        return _isFactored(_root);
      case 'reduced_fraction':
        return _isReducedFraction(_root);
      case 'simplest_radical':
        return _isSimplestRadical(_root);
      case 'in_terms_of_pi':
        return _isInTermsOfPi(_root);
      default:
        throw ArgumentError('未対応の形: $form');
    }
  }

  // 0・1・-1 は x と x^2 などが偶然一致するので避ける。
  static const _samples = <double>[2, 3, -2, 0.5, 5, -3, 1.5, 7, -0.7, 4, -1.3, 6, 2.5, -4, 8];
}

/// `Question.form` に書ける形の指定。
const knownExprForms = {'expanded', 'factored', 'reduced_fraction', 'simplest_radical', 'in_terms_of_pi'};

bool _hasVar(_Node n) {
  final v = <String>{};
  n.collect(v);
  return v.isNotEmpty;
}

_Node _unNeg(_Node n) => n is _Neg ? _unNeg(n.a) : n;

bool _isSum(_Node n) {
  final u = _unNeg(n);
  return u is _Bin && (u.op == '+' || u.op == '-');
}

int _terms(_Node n) {
  if (n is _Neg) return _terms(n.a);
  if (n is _Bin && (n.op == '+' || n.op == '-')) return _terms(n.a) + _terms(n.b);
  return 1;
}

bool _isExpanded(_Node n) {
  if (n is _Num || n is _Var || n is _Pi) return true;
  if (n is _Neg) return !(_isSum(n.a) && _hasVar(n.a)) && _isExpanded(n.a); // -(x+3)
  if (n is _Sqrt) return !_hasVar(n);
  if (n is! _Bin) return false;
  final va = _hasVar(n.a), vb = _hasVar(n.b);
  switch (n.op) {
    case '+':
    case '-':
      if (n.op == '-' && vb && _isSum(n.b)) return false; // a-(b+c)
      return _isExpanded(n.a) && _isExpanded(n.b);
    case '*':
      if (va && vb) return false; // 変数どうしの積は x^2 のように書く
      if ((va && _isSum(n.a)) || (vb && _isSum(n.b))) return false; // 2(x+3)
      return _isExpanded(n.a) && _isExpanded(n.b);
    case '/':
      if (vb) return false;
      if (va && _isSum(n.a)) return false; // (x+2)/2
      return _isExpanded(n.a) && _isExpanded(n.b);
    default: // ^
      if (vb) return false;
      if (va && _unNeg(n.a) is! _Var) return false; // (x+3)^2
      return _isExpanded(n.a) && _isExpanded(n.b);
  }
}

void _factors(_Node n, List<_Node> out) {
  final u = _unNeg(n);
  if (u is _Bin && u.op == '*') {
    _factors(u.a, out);
    _factors(u.b, out);
  } else {
    out.add(u);
  }
}

bool _isFactored(_Node n) {
  final u = _unNeg(n);
  if (u is _Bin && u.op == '^') {
    final e = u.b.eval(const {});
    return _isSum(u.a) && _hasVar(u.a) && !e.isNaN && e >= 2; // (x+3)^2
  }
  final f = <_Node>[];
  _factors(u, f);
  if (f.length < 2) return false;
  return f.any((x) => _isSum(x) && _hasVar(x)); // 2(x+3)・(x+1)(x-1)
}

int? _asInt(_Node n) {
  if (n is! _Num || n.v != n.v.truncateToDouble() || n.v.abs() > 1e12) return null;
  return n.v.toInt();
}

int _gcd(int a, int b) => b == 0 ? a.abs() : _gcd(b, a % b);

bool _isReducedFraction(_Node n) {
  final u = _unNeg(n);
  if (_asInt(u) != null) return true; // 整数
  if (u is! _Bin || u.op != '/') return false;
  final a = _asInt(_unNeg(u.a)), b = _asInt(u.b); // -3/4 は (-3)/4 と読まれる
  return a != null && b != null && b > 1 && a != 0 && _gcd(a, b) == 1;
}

/// 円周率 π を 1 つ含む、整数どうしの積・商の形（`12π`・`3/2π`・`3π/2`・`-π`）。小数の近似（`37.68`）や、π を含まない答えは不可。
/// 約分されているかは見ない。
bool _isInTermsOfPi(_Node n) {
  var pis = 0;
  bool ok(_Node x, {required bool denominator}) {
    if (x is _Pi) {
      pis++;
      return !denominator;
    }
    if (x is _Num) return _asInt(x) != null;
    if (x is _Neg) return ok(x.a, denominator: denominator);
    if (x is _Bin && x.op == '*') return ok(x.a, denominator: denominator) && ok(x.b, denominator: denominator);
    if (x is _Bin && x.op == '/') return ok(x.a, denominator: denominator) && ok(x.b, denominator: true);
    return false;
  }

  return ok(n, denominator: false) && pis == 1;
}

bool _squareFree(int n) {
  for (var d = 2; d * d <= n; d++) {
    if (n % (d * d) == 0) return false;
  }
  return true;
}

bool _isSimplestRadical(_Node n) {
  final u = _unNeg(n);
  if (_asInt(u) != null) return true;
  bool radical(_Node x) {
    if (x is! _Sqrt) return false;
    final k = _asInt(x.a);
    return k != null && k > 1 && _squareFree(k);
  }

  if (radical(u)) return true;
  // k√n（k は 2 以上の整数。1√2 や 0√2 は不可）
  if (u is _Bin && u.op == '*') {
    final k = _asInt(_unNeg(u.a)); // -2√3 は (-2)*√3 と読まれる
    return k != null && k.abs() >= 2 && radical(u.b);
  }
  return false;
}

abstract class _Node {
  double eval(Map<String, double> v);
  _Node bind(Map<String, double> v);
  void collect(Set<String> vars) {}
}

class _Num extends _Node {
  _Num(this.v);
  final double v;
  @override
  double eval(Map<String, double> _) => v;
  @override
  _Node bind(Map<String, double> _) => this;
}

class _Pi extends _Node {
  @override
  double eval(Map<String, double> _) => math.pi;
  @override
  _Node bind(Map<String, double> _) => this;
}

class _Var extends _Node {
  _Var(this.name);
  final String name;
  @override
  double eval(Map<String, double> v) => v[name] ?? double.nan;
  @override
  _Node bind(Map<String, double> v) => v.containsKey(name) ? _Num(v[name]!) : this;
  @override
  void collect(Set<String> vars) => vars.add(name);
}

class _Bin extends _Node {
  _Bin(this.op, this.a, this.b);
  final String op;
  final _Node a, b;
  @override
  _Node bind(Map<String, double> v) => _Bin(op, a.bind(v), b.bind(v));
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
  _Node bind(Map<String, double> v) => _Neg(a.bind(v));
  @override
  double eval(Map<String, double> v) => -a.eval(v);
  @override
  void collect(Set<String> vars) => a.collect(vars);
}

class _Sqrt extends _Node {
  _Sqrt(this.a);
  final _Node a;
  @override
  _Node bind(Map<String, double> v) => _Sqrt(a.bind(v));
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
    } else if (c == 'π' || t.startsWith('pi', i)) {
      out.add('π'); // 円周率（`pi` とも書ける。変数 p と i の積は p*i と書く）
      i += c == 'π' ? 1 : 2;
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

  bool _startsAtom(String? s) => s != null && (s == '(' || s == 'sqrt' || s == 'π' || RegExp(r'^[a-z]$').hasMatch(s));

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
    if (s == 'π') return _Pi();
    final d = double.tryParse(s);
    if (d != null) return _Num(d);
    if (RegExp(r'^[a-z]$').hasMatch(s)) return _Var(s);
    throw FormatException('ここには置けません: $s');
  }
}

/// 数式の答えの判定結果。形の指定を外したときは [wrongForm]（値は合っている）。
enum ExprVerdict { correct, wrongForm, wrongValue, unreadable }

/// 数式の問題 [answer]（正解の式）と [form]（形の指定。無ければ値だけ）に対する入力 [input] の判定。
ExprVerdict judgeExpr(String answer, String input, {String? form}) {
  final got = MathExpr.tryParse(input), want = MathExpr.tryParse(answer);
  if (got == null || want == null) return ExprVerdict.unreadable;
  if (!MathExpr.equivalent(got, want)) return ExprVerdict.wrongValue;
  if (form != null && !got.hasForm(form, want)) return ExprVerdict.wrongForm;
  return ExprVerdict.correct;
}
