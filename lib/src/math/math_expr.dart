import 'dart:math' as math;

/// 数式（`2x+6`・`(x+3)^2`・`1/2`・`√2`）の読み取りと、同じ値かどうかの判定。
/// 純粋な Dart で、式の文字列を木にして、決まった点で値を比べる（記号計算はしない）。
/// 使える記号: 数・英小文字 1 字の変数・`+ - * / ^`・かっこ・`sqrt(…)`・`√`・円周率 `π`（`pi` とも書ける）・
/// `floor(…)`（切り捨て）・`ceil(…)`（切り上げ）・`mod(a, b)`（余り。b が正なら 0 以上 b 未満。b=0 は定義できない）。
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

  /// 変数 [v] だけの一次式 `a v + b` なら (a, b)、違えば（他の変数がある・一次でない）null。
  ({double a, double b})? linearIn(String v) {
    if (variables.any((x) => x != v)) return null;
    final f0 = eval({v: 0}), f1 = eval({v: 1}), f2 = eval({v: 2}), f3 = eval({v: -3});
    if ([f0, f1, f2, f3].any((e) => e.isNaN || e.isInfinite)) return null;
    final a = f1 - f0;
    if ((f2 - (a * 2 + f0)).abs() > 1e-7 || (f3 - (a * -3 + f0)).abs() > 1e-7) return null;
    return (a: a, b: f0);
  }

  /// この式を計算するときに**よくある誤り**で書き換えた式の一覧（誤解の型つき）。式のどの部分（1 か所）に誤りがあるかを変えて作る。
  /// 途中式の判定（[docs/math_foundation.md] §10）で、「前の行から次の行で何を間違えたか」を当てるのに使う。
  /// 型: `distribute_first_only`（`2(x+3)` → `2x+3`）・`minus_paren_first_only`（`5-(x+3)` → `5-x+3`）・`square_of_sum`（`(x+3)^2` → `x^2+9`）・
  /// `fraction_add_denominator`（`1/2+1/3` → `2/5`）・`like_terms_mixup`（`2x+3` → `5x`）・`order_of_operations`（`3+4*2` → `(3+4)*2`）・
  /// `fraction_numerator_partial`（`(a+b)/c` → `a+b/c`）・`sub_negative_sign`（`a-(-b)` → `a-b`）・`sign_rule_product`（積・商の符号を逆にする）・
  /// `neg_square_sign`（`(-a)^2` と `-a^2` の取り違え）。
  List<({String tag, MathExpr expr})> commonMistakes() {
    return [
      for (final m in _mistakes(_root))
        (
          tag: m.tag,
          expr: MathExpr._(
            m.node,
            (() {
              final v = <String>{};
              m.node.collect(v);
              return v.toList()..sort();
            })(),
          ),
        ),
    ];
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

class _Fn extends _Node {
  _Fn(this.name, this.args);
  final String name;
  final List<_Node> args;

  /// 誤差で整数の手前に落ちないよう、整数に十分近い値はその整数にそろえる。
  static double _snap(double x) => (x - x.roundToDouble()).abs() < 1e-9 ? x.roundToDouble() : x;

  @override
  _Node bind(Map<String, double> v) => _Fn(name, [for (final a in args) a.bind(v)]);
  @override
  double eval(Map<String, double> v) {
    final x = args[0].eval(v);
    if (x.isNaN || x.isInfinite) return double.nan;
    switch (name) {
      case 'floor':
        return _snap(x).floorToDouble();
      case 'ceil':
        return _snap(x).ceilToDouble();
      default: // mod
        final y = args[1].eval(v);
        if (y.isNaN || y.isInfinite) return double.nan; // b=0 は Dart の % が NaN にする
        return _snap(x) % _snap(y);
    }
  }

  @override
  void collect(Set<String> vars) {
    for (final a in args) {
      a.collect(vars);
    }
  }
}

const _fnNames = {'floor', 'ceil', 'mod'};

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
    } else if (_fnNames.any((f) => t.startsWith(f, i))) {
      final f = _fnNames.firstWhere((f) => t.startsWith(f, i));
      out.add(f);
      i += f.length;
    } else if (t.startsWith('sqrt', i)) {
      out.add('sqrt');
      i += 4;
    } else if (c == 'π' || t.startsWith('pi', i)) {
      out.add('π'); // 円周率（`pi` とも書ける。変数 p と i の積は p*i と書く）
      i += c == 'π' ? 1 : 2;
    } else if (RegExp(r'[a-z]').hasMatch(c)) {
      out.add(c);
      i++;
    } else if ('+-*/^(),'.contains(c)) {
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

  bool _startsAtom(String? s) => s != null && (s == '(' || s == 'sqrt' || s == 'π' || _fnNames.contains(s) || RegExp(r'^[a-z]$').hasMatch(s));

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
    if (_fnNames.contains(s)) {
      if (peek != '(') throw FormatException('$s の後にはかっこが要ります');
      i++;
      final args = [_expr()];
      if (s == 'mod') {
        if (peek != ',') throw const FormatException('mod は mod(a, b) の形です');
        i++;
        args.add(_expr());
      }
      if (peek != ')') throw const FormatException('かっこが閉じていません');
      i++;
      return _Fn(s, args);
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

bool _isSumNode(_Node n) => n is _Bin && (n.op == '+' || n.op == '-');

bool _isNegativeNumber(_Node n) => n is _Neg || (n is _Num && n.v < 0);

/// [n] の根の部分の誤り（1 か所）。子の中の誤りは [_mistakes] が組み合わせる。
List<({String tag, _Node node})> _mistakesHere(_Node n) {
  final out = <({String tag, _Node node})>[];
  void add(String tag, _Node node) => out.add((tag: tag, node: node));
  if (n is _Bin) {
    final a = n.a, b = n.b;
    switch (n.op) {
      case '*':
        // k(a±b) → ka±b、(a+b)(c+d) → ac+bd
        if (_isSumNode(b) && !_isSumNode(a)) {
          final s = b as _Bin;
          add('distribute_first_only', _Bin(s.op, _Bin('*', a, s.a), s.b));
        }
        if (_isSumNode(a) && !_isSumNode(b)) {
          final s = a as _Bin;
          add('distribute_first_only', _Bin(s.op, _Bin('*', s.a, b), s.b));
        }
        if (_isSumNode(a) && _isSumNode(b)) {
          final s = a as _Bin, t = b as _Bin;
          add('distribute_first_only', _Bin(t.op, _Bin('*', s.a, t.a), _Bin('*', s.b, t.b)));
        }
        add('sign_rule_product', _Neg(n));
      case '/':
        // (a+b)/c → a+b/c
        if (_isSumNode(a)) {
          final s = a as _Bin;
          add('fraction_numerator_partial', _Bin(s.op, s.a, _Bin('/', s.b, b)));
        }
        add('sign_rule_product', _Neg(n));
      case '-':
        // a-(b+c) → a-b+c、a-(b-c) → a-b-c、a-(-b) → a-b
        if (_isSumNode(b)) {
          final s = b as _Bin;
          add('minus_paren_first_only', _Bin(s.op, _Bin('-', a, s.a), s.b));
        }
        if (_isNegativeNumber(b)) {
          add('sub_negative_sign', _Bin('-', a, b is _Neg ? b.a : _Num(-(b as _Num).v)));
        }
      case '^':
        // (a+b)^2 → a^2+b^2、(-a)^2 → -a^2
        if (_isSumNode(a) && b is _Num && b.v == 2) {
          final s = a as _Bin;
          add('square_of_sum', _Bin(s.op, _Bin('^', s.a, b), _Bin('^', s.b, b)));
        }
        if (a is _Neg) add('neg_square_sign', _Neg(_Bin('^', a.a, b)));
    }
    if (n.op == '+' || n.op == '-') {
      // a/b ± c/d → (a±c)/(b±d)
      if (a is _Bin && a.op == '/' && b is _Bin && b.op == '/') {
        add('fraction_add_denominator', _Bin('/', _Bin(n.op, a.a, b.a), _Bin(n.op, a.b, b.b)));
      }
      // kx ± c → (k±c)x（係数と定数をまとめる）
      _Node? coef(_Node t) =>
          t is _Var ? _Num(1) : (t is _Bin && t.op == '*' && t.a is _Num && t.b is _Var ? t.a : null);
      final ca = coef(a), cb = coef(b);
      if (ca != null && b is _Num) {
        add('like_terms_mixup', _Bin('*', _Bin(n.op, ca, b), a is _Var ? a : (a as _Bin).b));
      }
      if (cb != null && a is _Num && n.op == '+') {
        add('like_terms_mixup', _Bin('*', _Bin('+', a, cb), b is _Var ? b : (b as _Bin).b));
      }
      // a ± b*c → (a±b)*c
      if (b is _Bin && b.op == '*') add('order_of_operations', _Bin('*', _Bin(n.op, a, b.a), b.b));
    }
  }
  if (n is _Neg) {
    final a = n.a;
    // -(a+b) → -a+b
    if (_isSumNode(a)) {
      final s = a as _Bin;
      add('minus_paren_first_only', _Bin(s.op, _Neg(s.a), s.b));
    }
    // -a^2 → (-a)^2
    if (a is _Bin && a.op == '^') add('neg_square_sign', _Bin('^', _Neg(a.a), a.b));
  }
  return out;
}

/// [n] の木のどこか 1 か所に誤りを入れた書き換え。
List<({String tag, _Node node})> _mistakes(_Node n) {
  final out = [..._mistakesHere(n)];
  if (n is _Bin) {
    for (final m in _mistakes(n.a)) {
      out.add((tag: m.tag, node: _Bin(n.op, m.node, n.b)));
    }
    for (final m in _mistakes(n.b)) {
      out.add((tag: m.tag, node: _Bin(n.op, n.a, m.node)));
    }
  } else if (n is _Neg) {
    for (final m in _mistakes(n.a)) {
      out.add((tag: m.tag, node: _Neg(m.node)));
    }
  } else if (n is _Sqrt) {
    for (final m in _mistakes(n.a)) {
      out.add((tag: m.tag, node: _Sqrt(m.node)));
    }
  }
  return out;
}
