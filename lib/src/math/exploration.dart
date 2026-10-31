import 'dart:convert';

import '../bank/question_bank.dart';
import '../scope/unit_tree.dart';
import 'math_expr.dart';

/// 動かせるパラメータ（スライダー）。`min` から `step` ずつの格子の上の値だけを取る。
class ExplorationParam {
  const ExplorationParam({
    required this.name,
    required this.min,
    required this.max,
    required this.step,
    required this.initial,
  });

  final String name;
  final double min, max, step, initial;

  factory ExplorationParam.fromJson(Map<String, dynamic> j) {
    final name = j['name'];
    if (name is! String || !RegExp(r'^[a-wyz]$').hasMatch(name)) {
      throw FormatException('パラメータ名は x 以外の英小文字 1 字: $name');
    }
    double num_(String k) {
      final v = j[k];
      if (v is! num || v.isNaN || v.isInfinite) throw FormatException('$name: $k は数');
      return v.toDouble();
    }

    final min = num_('min'), max = num_('max'), step = num_('step'), initial = num_('initial');
    if (!(step > 0) || step > max - min) throw FormatException('$name: step は 0 より大きく、範囲（max - min）以下');
    final p = ExplorationParam(name: name, min: min, max: max, step: step, initial: initial);
    if (!p.onGrid(initial)) throw FormatException('$name: initial は格子（min から step ごと）の上の値');
    if (p.count > 10000) throw FormatException('$name: 格子が多すぎます');
    return p;
  }

  /// 格子の点の数。
  int get count => ((max - min) / step + 1e-9).floor() + 1;

  /// 格子の値の一覧。
  List<double> get values => [for (var i = 0; i < count; i++) _round(min + i * step)];

  bool onGrid(double v) {
    if (v < min - 1e-9 || v > max + 1e-9) return false;
    final k = (v - min) / step;
    return (k - k.roundToDouble()).abs() < 1e-9 && k.round() < count;
  }

  /// 最も近い格子の値にする（範囲外は端）。
  double snap(double v) {
    final k = ((v - min) / step).round().clamp(0, count - 1);
    return _round(min + k * step);
  }

  static double _round(double v) => (v * 1e9).roundToDouble() / 1e9;
}

/// 予想の問い。選択肢は ID（文言はコンテンツ側）。
class ExplorationPrediction {
  const ExplorationPrediction({required this.promptId, required this.choices, required this.answer});

  final String promptId;
  final List<String> choices;
  final String answer;
}

/// 体験型の教材 1 つ（設計は docs/math_foundation.md §4）。式のパラメータを動かして変化を確かめる。
/// 基盤が持つのは**仕様・グラフの点の計算・予想と目標の判定**まで。画面（スライダー・グラフ）はアプリ側。
/// 体験は習熟度に直接加点しない（体験後の確認問題で測る）。
class Exploration {
  Exploration._({
    required this.id,
    required this.version,
    required this.unitId,
    required this.kind,
    required this.promptId,
    required this.expr,
    required this.params,
    required this.predict,
    required this.goal,
    required this.explanationId,
  }) : _expr = MathExpr.parse(expr),
       _goal = goal == null ? null : MathExpr.parse(goal);

  final String id;
  final int version;
  final String unitId;
  final String kind;
  final String promptId;

  /// 動かす式（`x` が横軸、他の文字はパラメータ）。
  final String expr;
  final List<ExplorationParam> params;
  final ExplorationPrediction? predict;

  /// 目標の式（`x` の式）。パラメータを動かしてこれと同じ関数にする。無ければ自由に動かす教材。
  final String? goal;
  final String explanationId;
  final MathExpr _expr;
  final MathExpr? _goal;

  static const knownKinds = {'slider_graph'};
  static const _keys = {
    'id',
    'version',
    'unitId',
    'kind',
    'promptId',
    'expr',
    'params',
    'predict',
    'goal',
    'explanationId',
  };

  factory Exploration.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('未知のキー: ${unknown.join(', ')}');
    String str(Map m, String k, String where) {
      final v = m[k];
      if (v is! String || v.isEmpty) throw FormatException('$where: $k は空でない文字列');
      return v;
    }

    final id = str(j, 'id', '教材');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('id は英数字と _ だけ: $id');
    final version = j['version'];
    if (version is! int || version < 1) throw FormatException('$id: version は 1 以上の整数');
    final kind = str(j, 'kind', id);
    if (!knownKinds.contains(kind)) throw FormatException('$id: 未対応の kind: $kind');
    final rawParams = j['params'];
    if (rawParams is! List || rawParams.isEmpty) throw FormatException('$id: params が必要です');
    final params = [for (final p in rawParams) ExplorationParam.fromJson(Map<String, dynamic>.from(p as Map))];
    if (params.map((p) => p.name).toSet().length != params.length) throw FormatException('$id: パラメータ名が重複');

    final expr = str(j, 'expr', id);
    final parsed = MathExpr.tryParse(expr);
    if (parsed == null) throw FormatException('$id: expr が読めません: $expr');
    final names = params.map((p) => p.name).toSet();
    final bad = parsed.variables.where((v) => v != 'x' && !names.contains(v));
    if (bad.isNotEmpty) throw FormatException('$id: expr に宣言のない文字: ${bad.join()}');
    final unused = names.where((n) => !parsed.variables.contains(n));
    if (unused.isNotEmpty) throw FormatException('$id: 使われていないパラメータ: ${unused.join()}');

    ExplorationPrediction? predict;
    final rp = j['predict'];
    if (rp != null) {
      if (rp is! Map || rp.keys.any((k) => !{'promptId', 'choices', 'answer'}.contains(k))) {
        throw FormatException('$id: predict は promptId・choices・answer');
      }
      final ch = rp['choices'];
      if (ch is! List || ch.length < 2 || ch.any((e) => e is! String || e.isEmpty)) {
        throw FormatException('$id: predict.choices は 2 つ以上の ID');
      }
      final choices = [for (final c in ch) c as String];
      if (choices.toSet().length != choices.length) throw FormatException('$id: predict.choices が重複');
      final answer = str(rp, 'answer', '$id.predict');
      if (!choices.contains(answer)) throw FormatException('$id: predict.answer が choices にありません');
      predict = ExplorationPrediction(promptId: str(rp, 'promptId', '$id.predict'), choices: choices, answer: answer);
    }
    String? goal;
    final rg = j['goal'];
    if (rg != null) {
      if (rg is! Map || rg.length != 1 || rg['expr'] is! String) throw FormatException('$id: goal は {"expr":…}');
      goal = rg['expr'] as String;
      final g = MathExpr.tryParse(goal);
      if (g == null) throw FormatException('$id: goal が読めません: $goal');
      if (g.variables.any((v) => v != 'x')) throw FormatException('$id: goal は x だけの式');
    }
    return Exploration._(
      id: id,
      version: version,
      unitId: str(j, 'unitId', id),
      kind: kind,
      promptId: str(j, 'promptId', id),
      expr: expr,
      params: params,
      predict: predict,
      goal: goal,
      explanationId: str(j, 'explanationId', id),
    );
  }

  /// 最初に置くパラメータの値。
  Map<String, double> get initialValues => {for (final p in params) p.name: p.initial};

  /// [values] の各値を格子に合わせ、足りないものは初期値にした値（画面の操作の結果を整える）。
  Map<String, double> normalize(Map<String, double> values) => {
    for (final p in params) p.name: values.containsKey(p.name) ? p.snap(values[p.name]!) : p.initial,
  };

  /// グラフの点。[xMin] から [xMax] まで [count] 点（両端を含む）。定義できない点は y が NaN。
  List<({double x, double y})> sample(
    Map<String, double> values, {
    required double xMin,
    required double xMax,
    int count = 101,
  }) {
    if (!(xMin < xMax) || count < 2) throw ArgumentError('xMin < xMax、count は 2 以上');
    final v = normalize(values);
    return [
      for (var i = 0; i < count; i++)
        () {
          final x = xMin + (xMax - xMin) * i / (count - 1);
          final y = _expr.eval({...v, 'x': x});
          return (x: x, y: y.isInfinite ? double.nan : y);
        }(),
    ];
  }

  /// パラメータが [values] のとき、式が目標と同じ関数になっているか。目標が無ければ偽。
  bool goalReached(Map<String, double> values) {
    final g = _goal;
    if (g == null) return false;
    return MathExpr.equivalent(_expr.bind(normalize(values)), g);
  }

  /// 目標を満たす格子上のパラメータの組（最大 [limit] 個）。ヒントや、目標に届くかの検証に使う。
  List<Map<String, double>> goalSolutions({int limit = 5}) {
    final g = _goal;
    if (g == null) return const [];
    final out = <Map<String, double>>[];
    final axes = [for (final p in params) p.values];
    var total = 1;
    for (final a in axes) {
      total *= a.length;
      if (total > 200000) throw StateError('格子が大きすぎて全探索できません: $id');
    }
    final idx = List.filled(params.length, 0);
    while (out.length < limit) {
      final m = {for (var i = 0; i < params.length; i++) params[i].name: axes[i][idx[i]]};
      if (MathExpr.equivalent(_expr.bind(m), g)) out.add(m);
      var k = params.length - 1;
      while (k >= 0 && ++idx[k] == axes[k].length) {
        idx[k] = 0;
        k--;
      }
      if (k < 0) break;
    }
    return out;
  }

  /// 予想の答え合わせ。予想の問いが無い教材、選択肢にない ID は null。
  bool? checkPrediction(String choiceId) {
    final p = predict;
    if (p == null || !p.choices.contains(choiceId)) return null;
    return choiceId == p.answer;
  }
}

/// 体験型教材の集まり（`explorations.json`）。
class ExplorationSet {
  const ExplorationSet(this.explorations);

  final List<Exploration> explorations;

  /// `{"version":1,"explorations":[…]}`。読めなければ [FormatException]。
  factory ExplorationSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('体験型の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('体験型の JSON はオブジェクトです');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['explorations'];
    if (raw is! List) throw const FormatException('explorations が必要です');
    final out = [for (final e in raw) Exploration.fromJson(Map<String, dynamic>.from(e as Map))];
    final ids = <String>{};
    for (final e in out) {
      if (!ids.add(e.id)) throw FormatException('id が重複しています: ${e.id}');
    }
    return ExplorationSet(out);
  }
}

/// 体験型教材の検証。`exploration_unit_missing`（単元がない）・`exploration_goal_unreachable`
/// （格子の上のどの組でも目標にならない）・`exploration_initial_is_goal`（最初から目標を満たしている）はエラー。
List<ValidationIssue> validateExplorations(ExplorationSet set, {required UnitTree tree}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) => issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  for (final e in set.explorations) {
    if (tree[e.unitId] == null) err('exploration_unit_missing', e.id, '単元 ${e.unitId} がありません');
    if (e.goal != null) {
      if (e.goalReached(e.initialValues)) {
        err('exploration_initial_is_goal', e.id, '最初の値がすでに目標を満たしています');
      }
      try {
        if (e.goalSolutions(limit: 1).isEmpty) {
          err('exploration_goal_unreachable', e.id, '格子の上のどの値でも目標 ${e.goal} になりません');
        }
      } on StateError catch (s) {
        err('exploration_goal_unreachable', e.id, s.message);
      }
    }
  }
  return issues;
}
