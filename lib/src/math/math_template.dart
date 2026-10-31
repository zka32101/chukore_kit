import 'dart:convert';

import '../bank/question_bank.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';
import 'math_expr.dart';
import 'seeded_random.dart';
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

/// 型から作った 1 つの変種。
class Variant {
  const Variant({required this.question, required this.seed, required this.params, required this.display});

  /// 出題・判定に使う問題（ID は `{templateId}~{seed}`）。
  final Question question;
  final int seed;

  /// 引いたパラメータと、`derived` で計算した値。
  final Map<String, double> params;

  /// 画面に出す数式の文字列（型の `display` を差し込んだもの）。問題文の文章はコンテンツ側が持つ。
  final Map<String, String> display;
}

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
    required this.derived,
    required this.constraints,
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
  final Map<String, String> derived;
  final List<String> constraints;
  final Map<String, String> display;
  final String answer;
  final List<String> choices;
  final List<({String expr, String tag})> wrong;
  final String explanationId;

  static const maxAttempts = 50;
  static final _tag = RegExp(r'^[a-z0-9_]+$');
  static const _keys = {
    'id', 'templateVersion', 'unitId', 'type', 'form', 'difficulty', 'params', 'derived', 'constraints', //
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
    final params = {for (final e in rawParams.entries) e.key as String: ParamSpec.fromJson(e.key as String, e.value)};

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

    final derived = strMap('derived');
    for (final n in derived.keys) {
      if (params.containsKey(n) || !RegExp(r'^[a-wyz]$').hasMatch(n)) throw FormatException('$id: derived の名前が不正: $n');
    }
    final constraints = [for (final c in (j['constraints'] as List? ?? const [])) c as String];
    final choices = [for (final c in (j['choices'] as List? ?? const [])) c as String];
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
      derived: derived,
      constraints: constraints,
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
    final known = {...params.keys, ...derived.keys};
    void check(String text) {
      final re = RegExp(r'\{[+&]?([^{}]*)\}');
      for (final m in re.allMatches(text)) {
        final e = MathExpr.tryParse(m.group(1)!);
        if (e == null) throw FormatException('$id: {…} の式が読めません: ${m.group(0)}');
        final bad = e.variables.where((v) => !known.contains(v));
        if (bad.isNotEmpty) throw FormatException('$id: パラメータにない文字 ${bad.join()}: ${m.group(0)}');
      }
      try {
        renderTemplateString(text, {for (final k in known) k: 1.0}); // { と } の対応
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
      for (final e in derived.entries) {
        values[e.key] = MathExpr.parse(e.value).eval(values);
      }
      if (values.values.any((v) => v.isNaN || v.isInfinite)) continue;
      if (!constraints.every((c) => evalConstraint(c, values))) continue;
      try {
        final v = _build(seed, values, rng);
        if (v != null) return v;
      } on InexactValueException {
        continue;
      }
    }
    throw StateError('template_unsatisfiable: $id（$maxAttempts 回引き直しても条件に合いません）');
  }

  Variant? _build(int seed, Map<String, double> values, SeededRandom rng) {
    String r(String t) => renderTemplateString(t, values);
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
    return Variant(
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
/// `template_answer_dup`（警告: 変種の答えが半分以上かぶる＝範囲が狭い）。
List<ValidationIssue> validateTemplates(TemplateSet set, {required UnitTree tree, int count = 40}) {
  final issues = <ValidationIssue>[];
  final questions = <Question>[];
  for (final t in set.templates) {
    final mine = <Question>[];
    try {
      for (var s = 1; s <= count; s++) {
        mine.add(t.generate(s).question);
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
    if (mine.map((q) => q.answer).toSet().length * 2 < count) {
      issues.add(
        ValidationIssue(
          IssueSeverity.warning,
          'template_answer_dup',
          t.id,
          '$count 個の変種で答えが ${mine.map((q) => q.answer).toSet().length} 通りしかありません（パラメータの範囲が狭い）',
        ),
      );
    }
    questions.addAll(mine);
  }
  issues.addAll(validateQuestionBank(questions: questions, tree: tree));
  return issues;
}
