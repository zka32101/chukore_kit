import 'dart:convert';

import '../bank/question_bank.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';
import '../util/five_number.dart';
import 'figure.dart';
import 'math_expr.dart';
import 'seeded_random.dart';
import 'solid.dart';
import 'template_text.dart';

/// パラメータの範囲。整数 `{"int":[lo,hi]}` か、候補 `{"oneOf":[…]}`。
class ParamSpec {
  const ParamSpec._(this.lo, this.hi, this.options);

  final int lo, hi;
  final List<double>? options;

  factory ParamSpec.fromJson(String name, Object? j) {
    if (!RegExp(r'^[a-wyz]$').hasMatch(name)) {
      throw FormatException('パラメータ名は x 以外の英小文字 1 字: $name');
    }
    if (j is! Map || j.length != 1) throw FormatException('パラメータ $name は int か oneOf のどちらか 1 つ');
    if (j.containsKey('int')) {
      final r = j['int'];
      if (r is! List || r.length != 2 || r.any((e) => e is! int)) throw FormatException('$name の int は [下限, 上限]（整数）');
      if ((r[0] as int) > (r[1] as int)) throw FormatException('$name の下限が上限より大きい');
      return ParamSpec._(r[0] as int, r[1] as int, null);
    }
    if (j.containsKey('oneOf')) {
      final o = j['oneOf'];
      if (o is! List || o.isEmpty || o.any((e) => e is! num)) throw FormatException('$name の oneOf は数の候補（空は不可）');
      return ParamSpec._(0, 0, [for (final e in o) (e as num).toDouble()]);
    }
    throw FormatException('パラメータ $name は int か oneOf: ${j.keys.first}');
  }

  double draw(SeededRandom r) => options != null ? r.pick(options!) : r.nextInt(lo, hi).toDouble();
}

/// 数列のパラメータ（データの活用）。個数 `n` と各値の範囲を種から決める。名前は英大文字 1 字。
class ListSpec {
  const ListSpec._(this.nLo, this.nHi, this.lo, this.hi);

  final int nLo, nHi, lo, hi;

  factory ListSpec.fromJson(String name, Object? j) {
    if (!RegExp(r'^[A-Z]$').hasMatch(name)) throw FormatException('数列の名前は英大文字 1 字: $name');
    final spec = j is Map && j.length == 1 ? j['list'] : null;
    if (spec is! Map || spec.length != 2) {
      throw FormatException('数列 $name は {"list": {"n": [下限, 上限], "int": [下限, 上限]}}');
    }
    List<int> range(String k) {
      final r = spec[k];
      if (r is! List || r.length != 2 || r.any((e) => e is! int) || (r[0] as int) > (r[1] as int)) {
        throw FormatException('$name の $k は [下限, 上限]（整数）');
      }
      return [r[0] as int, r[1] as int];
    }

    final n = range('n'), v = range('int');
    if (n[0] < 1 || n[1] > 200) throw FormatException('$name の個数は 1〜200');
    return ListSpec._(n[0], n[1], v[0], v[1]);
  }

  List<double> draw(SeededRandom r) {
    final n = r.nextInt(nLo, nHi);
    return [for (var i = 0; i < n; i++) r.nextInt(lo, hi).toDouble()];
  }
}

const _statFunctions = {'sum', 'mean', 'median', 'mode', 'range', 'min', 'max', 'count', 'q1', 'q3', 'iqr'};

/// `stats` の式（`mean(L)`・`count(L)`・`count(L, 10, 20)` など）。数列の名前と、引数の数・パラメータ名を調べる。
({String fn, String list, List<String> args}) _parseStat(String spec, Set<String> lists, Set<String> scalars) {
  final m = RegExp(r'^\s*([a-z][a-z0-9]*)\(\s*([A-Z])\s*((?:,[^,()]*)*)\)\s*$').firstMatch(spec);
  if (m == null) throw FormatException('stats の式は 関数名(数列, …): $spec');
  final fn = m.group(1)!, list = m.group(2)!;
  if (!_statFunctions.contains(fn)) throw FormatException('未対応の関数 $fn（${_statFunctions.join('・')}）: $spec');
  if (!lists.contains(list)) throw FormatException('数列にない名前です: $list（$spec）');
  final args = [for (final a in m.group(3)!.split(',').skip(1)) a.trim()];
  final want = fn == 'count' ? const [0, 2] : const [0];
  if (!want.contains(args.length)) throw FormatException('$fn の引数の数が違います: $spec');
  for (final a in args) {
    if (double.tryParse(a) == null && !scalars.contains(a)) throw FormatException('引数は数かパラメータ名: $a（$spec）');
  }
  return (fn: fn, list: list, args: args);
}

/// 集計。最頻値が複数のときは NaN（数列は 1 個以上なので空にはならない）。`count(L, lo, hi)` は lo 以上 hi 未満の個数。
double _evalStat(
  ({String fn, String list, List<String> args}) s,
  Map<String, List<double>> lists,
  Map<String, double> v,
) {
  final d = lists[s.list]!;
  double arg(String a) => double.tryParse(a) ?? v[a]!;
  final sorted = [...d]..sort();
  switch (s.fn) {
    case 'sum':
      return d.reduce((a, b) => a + b);
    case 'mean':
      return d.reduce((a, b) => a + b) / d.length;
    case 'median':
      final n = sorted.length;
      return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    case 'mode':
      final counts = <double, int>{};
      for (final x in d) {
        counts[x] = (counts[x] ?? 0) + 1;
      }
      final top = counts.values.reduce((a, b) => a > b ? a : b);
      final modes = [
        for (final e in counts.entries)
          if (e.value == top) e.key,
      ];
      return modes.length == 1 ? modes.first : double.nan;
    case 'range':
      return sorted.last - sorted.first;
    case 'q1' || 'q3' || 'iqr': // 四分位数（中学校の定義）。データが 1 個のときは求められないので NaN
      if (d.length < 2) return double.nan;
      final f = fiveNumberSummary(d);
      return switch (s.fn) { 'q1' => f.q1, 'q3' => f.q3, _ => f.iqr };
    case 'min':
      return sorted.first;
    case 'max':
      return sorted.last;
    default: // count
      if (s.args.isEmpty) return d.length.toDouble();
      final lo = arg(s.args[0]), hi = arg(s.args[1]);
      return d.where((x) => x >= lo && x < hi).length.toDouble();
  }
}

/// 選択肢の図 1 つ。図の仕様 1 つか、式で番号を選ぶ複数の仕様（`{"pick": {"index": "式", "of": [図, …]}}`）。
class FigureChoice {
  const FigureChoice._(this.one, this.index, this.of);

  final FigureTemplate? one;
  final String? index;
  final List<FigureTemplate> of;

  factory FigureChoice.fromJson(String id, Object? j, Set<String> known) {
    if (j is! Map) throw FormatException('$id: figures の値は図のオブジェクト');
    if (j.containsKey('pick')) {
      final p = j['pick'];
      if (j.length != 1 ||
          p is! Map ||
          p.length != 2 ||
          p['index'] is! String ||
          p['of'] is! List ||
          (p['of'] as List).length < 2) {
        throw FormatException('$id: pick は {"index": 式, "of": [図, 図, …]}（図は 2 つ以上）');
      }
      final e = MathExpr.tryParse(p['index'] as String);
      if (e == null || e.variables.any((v) => !known.contains(v))) {
        throw FormatException('$id: pick の index が不正: ${p['index']}');
      }
      return FigureChoice._(null, p['index'] as String, [
        for (final f in p['of'] as List) FigureTemplate.fromJson(Map<String, dynamic>.from(f as Map), known),
      ]);
    }
    return FigureChoice._(FigureTemplate.fromJson(Map<String, dynamic>.from(j), known), null, const []);
  }

  Figure? resolve(Map<String, double> values, String Function(String) render) {
    final one = this.one;
    if (one != null) return one.resolve(values, render);
    final i = MathExpr.parse(index!).eval(values);
    if (i.isNaN || i != i.roundToDouble() || i < 0 || i >= of.length) return null;
    return of[i.toInt()].resolve(values, render);
  }
}

/// 型から作った 1 つの変種。
class Variant {
  const Variant({
    required this.question,
    required this.seed,
    required this.params,
    required this.display,
    this.lists = const {},
    this.figure,
    this.choiceFigures = const {},
    this.sceneId,
    this.animation,
  });

  /// 出題・判定に使う問題（ID は `{templateId}~{seed}`）。
  final Question question;

  /// 題材の場面（現実の具体例。型に `scene` があるとき。`scenes.json` の ID）。
  final String? sceneId;

  /// 時間で変わる図（型の `figure` に `animation` があるとき）。[figure] はその最後のコマ。
  final FigureAnimation? animation;
  final int seed;

  /// 図（型に `figure` があるとき）。画面が描くか、`figure.toSvg()` で SVG にする。
  final Figure? figure;

  /// 選択肢が図の問題（型に `figures` があるとき）の、選択肢の ID → 図。`question.choices` の各 ID に対応する。
  final Map<String, Figure> choiceFigures;

  /// 引いた数列（データの活用の型。画面が表・ヒストグラムを描くのに使う）。
  final Map<String, List<double>> lists;

  /// 引いたパラメータと、`stats`・`derived` で計算した値。
  final Map<String, double> params;

  /// 画面に出す数式の文字列（型の `display` を差し込んだもの）。問題文の文章はコンテンツ側が持つ。
  final Map<String, String> display;
}

/// 文言 [text]（問題文・解説・レッスンの説明）の `{…}` に、変種 [v] の値を差し込む。
/// `{p}`・`{q}` のように型の `display` の名前ならその表示の文字列、そうでなければ式（`{c-b}`・`{+b}`・`{$r*r}`・`{~L}`）として
/// 型と同じ書き方で値を入れる（整数か既約分数。書けない値は [InexactValueException]、知らない名前は [FormatException]）。
String renderVariantText(String text, Variant v) => text.replaceAllMapped(RegExp(r'\{([^{}]*)\}'), (m) {
  final body = m.group(1)!;
  return v.display[body] ?? renderTemplateString('{$body}', v.params, lists: v.lists);
});

/// 変種の ID `{templateId}~{seed}` を分ける。変種でなければ null。
({String templateId, int seed})? parseVariantId(String id) {
  final m = RegExp(r'^([A-Za-z0-9_]+)~(\d+)$').firstMatch(id);
  if (m == null) return null;
  final seed = int.tryParse(m.group(2)!);
  return seed == null ? null : (templateId: m.group(1)!, seed: seed);
}

/// 問題の型。パラメータを種から決め、答えと誤答を式から計算して [Question] を作る（設計は docs/math_variants_design.md）。
class MathTemplate {
  MathTemplate._({
    required this.id,
    required this.templateVersion,
    required this.unitId,
    required this.type,
    required this.form,
    required this.difficulty,
    required this.params,
    required this.lists,
    required this.stats,
    required this.derived,
    required this.figure,
    required this.figures,
    required this.constraints,
    required this.sceneId,
    required this.plausible,
    required this.display,
    required this.answer,
    required this.choices,
    required this.wrong,
    required this.explanationId,
  });

  final String id;
  final int templateVersion;
  final String unitId;
  final String type;
  final String? form;
  final double difficulty;
  final Map<String, ParamSpec> params;
  final Map<String, ListSpec> lists;

  /// 数列から求める値（名前は英小文字 1 字 → `mean(L)` など）。
  final Map<String, String> stats;
  final Map<String, String> derived;

  /// 図の仕様（平面図形）。無ければ null。
  final FigureTemplate? figure;

  /// 選択肢が図の問題の、選択肢の ID → 図の仕様（どれにするかを式で選ぶ `pick` もある）。
  final Map<String, FigureChoice> figures;
  final List<String> constraints;

  /// 題材の場面の ID（現実の具体例）。無ければ null。
  final String? sceneId;

  /// 現実にありえる値の範囲（名前 → [下限, 上限]）。変種はすべてこの範囲に入る（外れる引き方は引き直す）。`scene` が要る。
  final Map<String, ({double lo, double hi})> plausible;
  final Map<String, String> display;
  final String answer;
  final List<String> choices;
  final List<({String expr, String tag})> wrong;
  final String explanationId;

  static const maxAttempts = 50;
  static final _tag = RegExp(r'^[a-z0-9_]+$');
  static const _keys = {
    'id',
    'templateVersion',
    'unitId',
    'type',
    'form',
    'difficulty',
    'params',
    'stats',
    'derived',
    'figure',
    'figures',
    'constraints', //
    'scene', 'plausible',
    'display', 'answer', 'choices', 'wrong', 'explanationId',
  };

  /// 読めなければ [FormatException]（未知のキー・型違い・範囲外を含む）。
  factory MathTemplate.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('未知のキー: ${unknown.join(', ')}');
    String str(String k) {
      final v = j[k];
      if (v is! String || v.isEmpty) throw FormatException('$k は空でない文字列');
      return v;
    }

    final id = str('id');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('id は英数字と _ だけ: $id');
    final version = j['templateVersion'];
    if (version is! int || version < 1) throw FormatException('$id: templateVersion は 1 以上の整数');
    final type = str('type');
    if (type != 'expr' && type != 'choice') throw FormatException('$id: type は expr か choice');
    final form = j['form'];
    if (form != null && (form is! String || !knownExprForms.contains(form) || type != 'expr')) {
      throw FormatException('$id: form は expr の型だけで、${knownExprForms.join('・')} のどれか');
    }
    final diff = j['difficulty'];
    if (diff is! num || diff < 0 || diff > 1) throw FormatException('$id: difficulty は 0〜1');
    final rawParams = j['params'];
    if (rawParams is! Map || rawParams.isEmpty) throw FormatException('$id: params が必要です');
    final params = {
      for (final e in rawParams.entries)
        if (!RegExp(r'^[A-Z]$').hasMatch(e.key as String))
          e.key as String: ParamSpec.fromJson(e.key as String, e.value),
    };
    final lists = {
      for (final e in rawParams.entries)
        if (RegExp(r'^[A-Z]$').hasMatch(e.key as String)) e.key as String: ListSpec.fromJson(e.key as String, e.value),
    };

    Map<String, String> strMap(String k, {bool required = false}) {
      final v = j[k];
      if (v == null) {
        if (required) throw FormatException('$id: $k が必要です');
        return const {};
      }
      if (v is! Map || v.values.any((e) => e is! String) || (required && v.isEmpty)) {
        throw FormatException('$id: $k は 文字列の対応表');
      }
      return {for (final e in v.entries) e.key as String: e.value as String};
    }

    final stats = strMap('stats');
    for (final e in stats.entries) {
      if (params.containsKey(e.key) || !RegExp(r'^[a-wyz]$').hasMatch(e.key)) {
        throw FormatException('$id: stats の名前が不正: ${e.key}');
      }
      _parseStat(e.value, lists.keys.toSet(), params.keys.toSet());
    }
    final derived = strMap('derived');
    for (final n in derived.keys) {
      if (params.containsKey(n) || stats.containsKey(n) || !RegExp(r'^[a-wyz]$').hasMatch(n)) {
        throw FormatException('$id: derived の名前が不正: $n');
      }
    }
    final rawFigure = j['figure'];
    if (rawFigure != null && rawFigure is! Map) throw FormatException('$id: figure はオブジェクト');
    final constraints = [for (final c in (j['constraints'] as List? ?? const [])) c as String];
    final rawScene = j['scene'];
    if (rawScene != null && (rawScene is! String || !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(rawScene))) {
      throw FormatException('$id: scene は場面の ID（英数字と _）');
    }
    final rawPlausible = j['plausible'];
    final plausible = <String, ({double lo, double hi})>{};
    if (rawPlausible != null) {
      if (rawScene == null) throw FormatException('$id: plausible は scene と一緒に書きます');
      if (rawPlausible is! Map || rawPlausible.isEmpty) throw FormatException('$id: plausible は 名前 → [下限, 上限]');
      for (final e in rawPlausible.entries) {
        final v = e.value;
        if (v is! List || v.length != 2 || v.any((x) => x is! num) || (v[0] as num) > (v[1] as num)) {
          throw FormatException('$id: plausible の ${e.key} は [下限, 上限]（下限 ≤ 上限の数）');
        }
        plausible[e.key as String] = (lo: (v[0] as num).toDouble(), hi: (v[1] as num).toDouble());
      }
    }
    final choices = [for (final c in (j['choices'] as List? ?? const [])) c as String];
    final rawFigures = j['figures'];
    final figures = <String, FigureChoice>{};
    if (rawFigures != null) {
      if (type != 'choice') throw FormatException('$id: figures は choice の型だけ');
      if (rawFigures is! Map) throw FormatException('$id: figures は 選択肢の ID → 図');
      if (choices.any((c) => c.contains('{')) ||
          rawFigures.keys.toSet().difference(choices.toSet()).isNotEmpty ||
          choices.toSet().difference(rawFigures.keys.toSet()).isNotEmpty) {
        throw FormatException('$id: figures のキーは choices と同じ（choices は {…} を含めない ID）');
      }
      final known = {...params.keys, ...stats.keys, ...derived.keys};
      for (final e in rawFigures.entries) {
        figures[e.key as String] = FigureChoice.fromJson(id, e.value, known);
      }
    }
    if (type == 'choice' && choices.length < 2) throw FormatException('$id: choice の型は choices が 2 つ以上');
    if (type == 'expr' && choices.isNotEmpty) throw FormatException('$id: expr の型に choices は使えません');
    final wrong = <({String expr, String tag})>[];
    for (final w in (j['wrong'] as List? ?? const [])) {
      if (w is! Map || w['expr'] is! String || w['tag'] is! String || w.length != 2) {
        throw FormatException('$id: wrong は {"expr":…,"tag":…}');
      }
      if (!_tag.hasMatch(w['tag'] as String)) throw FormatException('$id: タグは小文字・数字・アンダースコア: ${w['tag']}');
      wrong.add((expr: w['expr'] as String, tag: w['tag'] as String));
    }
    final t = MathTemplate._(
      id: id,
      templateVersion: version,
      unitId: str('unitId'),
      type: type,
      form: form as String?,
      difficulty: diff.toDouble(),
      params: params,
      lists: lists,
      stats: stats,
      derived: derived,
      figures: figures,
      figure: rawFigure == null
          ? null
          : FigureTemplate.fromJson(Map<String, dynamic>.from(rawFigure as Map), {
              ...params.keys,
              ...stats.keys,
              ...derived.keys,
            }),
      constraints: constraints,
      sceneId: rawScene as String?,
      plausible: plausible,
      display: strMap('display', required: true),
      answer: str('answer'),
      choices: choices,
      wrong: wrong,
      explanationId: str('explanationId'),
    );
    t._precheck();
    return t;
  }

  /// 型の書き間違いを、乱数を使わずに見つける（式の文字、比較の有無）。
  void _precheck() {
    final known = {...params.keys, ...stats.keys, ...derived.keys};
    final fakeLists = {
      for (final k in lists.keys) k: <double>[1, 2, 3],
    };
    void check(String text) {
      final re = RegExp(r'\{[+&$]*([^{}]*)\}');
      for (final m in re.allMatches(text)) {
        if (RegExp(r'^~?[A-Z]$').hasMatch(m.group(1)!)) continue; // 数列（renderTemplateString の確認で名前を見る）
        final e = MathExpr.tryParse(m.group(1)!);
        if (e == null) throw FormatException('$id: {…} の式が読めません: ${m.group(0)}');
        final bad = e.variables.where((v) => !known.contains(v));
        if (bad.isNotEmpty) throw FormatException('$id: パラメータにない文字 ${bad.join()}: ${m.group(0)}');
      }
      try {
        renderTemplateString(text, {for (final k in known) k: 1.0}, lists: fakeLists); // { と } の対応
      } on InexactValueException {
        // 値は実際のパラメータで決まるので、ここでは書式だけ見る
      }
    }

    for (final t in [...display.values, answer, ...choices, ...wrong.map((w) => w.expr)]) {
      check(t);
    }
    for (final e in derived.values) {
      final x = MathExpr.tryParse(e);
      if (x == null || x.variables.any((v) => !known.contains(v))) throw FormatException('$id: derived の式が不正: $e');
    }
    final unknownPlausible = plausible.keys.where((k) => !known.contains(k));
    if (unknownPlausible.isNotEmpty) {
      throw FormatException('$id: plausible に型にない名前: ${unknownPlausible.join(', ')}');
    }
    final fake = {for (final k in known) k: 1.0};
    for (final c in constraints) {
      evalConstraint(c, fake);
    }
  }

  /// 種 [seed] の変種。制約・誤答の重複などで合わないパラメータは引き直す。
  /// [maxAttempts] 回で決まらなければ [StateError]（`template_unsatisfiable`）。
  Variant generate(int seed) {
    final rng = SeededRandom(seed);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final values = <String, double>{for (final e in params.entries) e.key: e.value.draw(rng)};
      final drawn = <String, List<double>>{for (final e in lists.entries) e.key: e.value.draw(rng)};
      for (final e in stats.entries) {
        values[e.key] = _evalStat(_parseStat(e.value, lists.keys.toSet(), params.keys.toSet()), drawn, values);
      }
      for (final e in derived.entries) {
        values[e.key] = MathExpr.parse(e.value).eval(values);
      }
      if (values.values.any((v) => v.isNaN || v.isInfinite)) continue;
      if (!constraints.every((c) => evalConstraint(c, values))) continue;
      if (plausible.entries.any((e) => !(values[e.key]! >= e.value.lo && values[e.key]! <= e.value.hi))) continue;
      try {
        final v = _build(seed, values, drawn, rng);
        if (v != null) return v;
      } on InexactValueException {
        continue;
      }
    }
    throw StateError('template_unsatisfiable: $id（$maxAttempts 回引き直しても条件に合いません）');
  }

  Variant? _build(int seed, Map<String, double> values, Map<String, List<double>> drawn, SeededRandom rng) {
    String r(String t) => renderTemplateString(t, values, lists: drawn);
    final disp = {for (final e in display.entries) e.key: r(e.value)};
    final ans = r(answer);
    final tags = <String, String>{};
    var shown = <String>[];
    if (type == 'expr') {
      final want = MathExpr.parse(ans);
      final seen = <MathExpr>[want];
      for (final w in wrong) {
        final text = r(w.expr);
        final e = MathExpr.tryParse(text);
        if (e == null || seen.any((o) => MathExpr.equivalent(o, e))) return null; // 正解や他の誤答と同値
        seen.add(e);
        tags[text] = w.tag;
      }
      // すでに目標の形になっている式を出題してしまう引き方（例 3(x+0)）は問題にならないので引き直す
      final f = form;
      if (f != null) {
        for (final d in disp.values) {
          final de = MathExpr.tryParse(d);
          if (de != null && MathExpr.equivalent(de, want) && de.hasForm(f, want)) return null;
        }
      }
    } else {
      shown = [for (final c in choices) r(c)];
      if (shown.toSet().length != shown.length) return null; // 選択肢の重複
      if (!shown.contains(ans)) throw FormatException('$id: 答え $ans が選択肢にありません');
      for (final w in wrong) {
        final text = r(w.expr);
        if (!shown.contains(text)) throw FormatException('$id: 誤答 $text が選択肢にありません');
        if (text == ans) return null;
        tags[text] = w.tag;
      }
      // 選択肢の並びも種で決める（正解の位置を固定しない）
      for (var i = shown.length - 1; i > 0; i--) {
        final j = rng.nextInt(0, i);
        final t = shown[i];
        shown[i] = shown[j];
        shown[j] = t;
      }
    }
    final choiceFigures = <String, Figure>{};
    for (final e in figures.entries) {
      final f = e.value.resolve(values, r);
      if (f == null) return null; // 描けない図が選択肢にある
      choiceFigures[e.key] = f;
    }
    Figure? fig;
    FigureAnimation? anim;
    if (figure != null) {
      fig = figure!.resolve(values, r);
      if (fig == null) return null; // 図が枠の外・点が重なる・角が作れない
      if (figure!.animation != null) {
        anim = figure!.animate(values, r);
        if (anim == null) return null; // どれかのコマが描けない
      }
    }
    return Variant(
      sceneId: sceneId,
      animation: anim,
      figure: fig,
      choiceFigures: choiceFigures,
      question: Question(
        id: '$id~$seed',
        unitId: unitId,
        type: type,
        difficulty: difficulty,
        choices: shown,
        answer: ans,
        explanationId: explanationId,
        misconceptionTags: tags,
        version: templateVersion,
        form: form,
      ),
      seed: seed,
      params: Map.unmodifiable(values),
      lists: {for (final e in drawn.entries) e.key: List.unmodifiable(e.value)},
      display: Map.unmodifiable(disp),
    );
  }
}

/// 型の集まり（`templates.json`）。
class TemplateSet {
  const TemplateSet(this.templates);

  final List<MathTemplate> templates;

  /// 形式名のない単純な JSON: `{"version":1,"templates":[…]}`。読めなければ [FormatException]。
  factory TemplateSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('型の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('型の JSON はオブジェクトです');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['templates'];
    if (raw is! List) throw const FormatException('templates が必要です');
    final out = [for (final t in raw) MathTemplate.fromJson(Map<String, dynamic>.from(t as Map))];
    final ids = <String>{};
    for (final t in out) {
      if (!ids.add(t.id)) throw FormatException('id が重複しています: ${t.id}');
    }
    return TemplateSet(out);
  }

  /// 各型から種 1..[count] の変種を作る（生成できない型は [StateError]）。
  List<Variant> expand({int count = 40}) => [
    for (final t in templates)
      for (var s = 1; s <= count; s++) t.generate(s),
  ];
}

/// 型を検証する: 各型を種 1..[count] で展開し、展開した問題集に [validateQuestionBank] をかける。
/// 型ごとのコード: `template_unsatisfiable`（制約が厳しすぎる、表示がすでに目標の形、など）・`template_expression_invalid`（エラー）、
/// `template_answer_dup`（警告: 変種の答え［選択肢が図の型は選択肢の並びと図］が半分以上かぶる＝範囲が狭い）、
/// `template_net_mismatch`（エラー: 展開図の選択肢で、正解だけが立方体の展開図になっていない）。
List<ValidationIssue> validateTemplates(TemplateSet set, {required UnitTree tree, int count = 40}) {
  final issues = <ValidationIssue>[];
  final questions = <Question>[];
  for (final t in set.templates) {
    final mine = <Question>[];
    final looks = <String>[]; // 変種の見かけ（答え。選択肢が図の型は、選択肢の並びと図）
    try {
      for (var s = 1; s <= count; s++) {
        final v = t.generate(s);
        mine.add(v.question);
        looks.add(
          t.figures.isEmpty
              ? v.question.answer
              : '${v.question.choices.join(',')}|${v.question.choices.map((c) => v.choiceFigures[c]!.toSvg()).join('|')}',
        );
      }
    } on StateError catch (e) {
      issues.add(ValidationIssue(IssueSeverity.error, 'template_unsatisfiable', t.id, '$e'));
      continue;
    } on FormatException catch (e) {
      final degenerate = e.message.contains('template_degenerate');
      issues.add(
        ValidationIssue(
          IssueSeverity.error,
          degenerate ? 'template_degenerate' : 'template_expression_invalid',
          t.id,
          e.message,
        ),
      );
      continue;
    }
    final badNet = netMismatch(t, count);
    if (badNet != null) {
      issues.add(ValidationIssue(IssueSeverity.error, 'template_net_mismatch', t.id, badNet));
    }
    if (looks.toSet().length * 2 < count) {
      issues.add(
        ValidationIssue(
          IssueSeverity.warning,
          'template_answer_dup',
          t.id,
          '$count 個の変種で${t.figures.isEmpty ? '答え' : '選択肢の図'}が ${looks.toSet().length} 通りしかありません（パラメータの範囲が狭い）',
        ),
      );
    }
    questions.addAll(mine);
  }
  issues.addAll(validateQuestionBank(questions: questions, tree: tree));
  return issues;
}

/// 選択肢がすべて展開図（`net/cells`）の型で、正解の選択肢だけが立方体の展開図になっているか。違えば理由、よければ null。
/// 選択肢の図が展開図でない型は見ない。
String? netMismatch(MathTemplate t, int count) {
  if (t.figures.isEmpty) return null;
  for (var s = 1; s <= count; s++) {
    final Variant v;
    try {
      v = t.generate(s);
    } on StateError {
      return null; // 生成できないことは別のコードで報告する
    } on FormatException {
      return null;
    }
    if (v.choiceFigures.isEmpty || v.choiceFigures.values.any((f) => f.cells == null)) return null;
    final nets = [
      for (final e in v.choiceFigures.entries)
        if (isCubeNet(e.value.cells!)) e.key,
    ];
    if (nets.length != 1 || nets.single != v.question.answer) {
      return '種 $s: 立方体の展開図になる選択肢が ${nets.isEmpty ? 'ありません' : nets.join('・')}（正解は ${v.question.answer}）';
    }
  }
  return null;
}
