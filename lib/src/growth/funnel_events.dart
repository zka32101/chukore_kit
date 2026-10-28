import '../insight/difficulty_calibration.dart' show wilsonInterval;
import 'outcome_report.dart';
import 'real_tests.dart';

/// 中学の指標（テスト日の登録率・点の入力率・振り返りの到達率）を数えるための、匿名イベントの名前。
///
/// **基盤は送らない・集めない。** アプリが同じ名前・同じ項目で数えるための約束だけを決める。
/// 項目は [funnelEventSpecs] の許可リストにあるものだけで、点・日付・名前などは持てない。
/// 使うには、法務確認と保護者の同意が済んでいること（[`docs/score_outcome_measurement.md`](../../../docs/score_outcome_measurement.md) §8）。
enum FunnelEventName {
  /// 最初の3問に正解した（Aha）。1人につき1回。
  ahaReached,

  /// テスト日を登録した。
  testDateRegistered,

  /// 点を聞く画面を出した（[ScorePromptKind] の afterTest / baseline）。1テストにつき1回（`decideScorePrompt` が保証）。
  scorePromptShown,

  /// 点の入力をスキップした。
  scorePromptSkipped,

  /// 本番の点を入れた（点は持たず、変化の区分だけ）。
  scoreEntered,

  /// 使う前の点を入れた。
  baselineEntered,

  /// テスト後の振り返りまで進んだ。
  postTestReviewReached,
}

/// 分析ツールに渡す名前（snake_case）。
String funnelEventLabel(FunnelEventName n) =>
    n.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// 項目 1 つの許可（文字列は決まった値のどれか、整数は範囲、真偽値）。
class _Allowed {
  const _Allowed.oneOf(this.values) : min = null, max = null, pattern = null, isBool = false;
  const _Allowed.intRange(this.min, this.max) : values = null, pattern = null, isBool = false;
  const _Allowed.pattern(this.pattern) : values = null, min = null, max = null, isBool = false;
  const _Allowed.boolean() : values = null, min = null, max = null, pattern = null, isBool = true;

  final Set<String>? values;
  final int? min, max;
  final String? pattern;
  final bool isBool;

  String? check(Object? v) {
    if (isBool) return v is bool ? null : '真偽値のみ';
    if (values != null) return v is String && values!.contains(v) ? null : '許可された値のみ（${values!.join('/')}）';
    if (pattern != null) return v is String && RegExp(pattern!).hasMatch(v) ? null : '形が違う（$pattern）';
    return v is int && v >= min! && v <= max! ? null : '$min〜$max の整数のみ';
  }
}

const _common = <String, _Allowed>{
  'subject': _Allowed.pattern(r'^[a-z][a-z0-9_]{0,23}$'),
  'region': _Allowed.pattern(r'^[A-Z]{2}$'),
  'grade': _Allowed.intRange(1, 3),
};

final _kindValues = {for (final k in RealTestKind.values) k.name};
final _bandValues = {for (final b in OutcomeBand.values) b.name};
final _usageValues = {for (final u in UsageBand.values) u.name};

/// イベントごとの、持てる項目の許可リスト（共通の `subject`・`region`・`grade` を除く）。
/// 必須は `grade` 以外のすべて。**ここに無い項目は持てない。**
final Map<FunnelEventName, Map<String, _Allowed>> _specs = {
  FunnelEventName.ahaReached: const {},
  FunnelEventName.testDateRegistered: const {},
  FunnelEventName.scorePromptShown: {
    'kind': _Allowed.oneOf({'afterTest', 'baseline'}),
  },
  FunnelEventName.scorePromptSkipped: {
    'kind': _Allowed.oneOf({'afterTest', 'baseline'}),
  },
  FunnelEventName.scoreEntered: {
    'kind': _Allowed.oneOf(_kindValues),
    'band': _Allowed.oneOf(_bandValues),
    'usage': _Allowed.oneOf(_usageValues),
    'baseline': const _Allowed.boolean(),
  },
  FunnelEventName.baselineEntered: const {},
  FunnelEventName.postTestReviewReached: const {},
};

/// イベント [name] が持てる項目名（共通の `subject`・`region`・`grade` を含む）。
Set<String> funnelEventKeys(FunnelEventName name) => {..._common.keys, ..._specs[name]!.keys};

/// 項目の問題の一覧（空なら問題なし）。
List<String> validateFunnelProps(FunnelEventName name, Map<String, Object?> props) {
  final spec = {..._common, ..._specs[name]!};
  final problems = <String>[];
  for (final k in props.keys) {
    if (!spec.containsKey(k)) problems.add('許可されていない項目 "$k"');
  }
  for (final e in spec.entries) {
    if (!props.containsKey(e.key)) {
      if (e.key != 'grade') problems.add('必須の項目 "${e.key}" が無い');
      continue;
    }
    if (e.key == 'grade' && props[e.key] == null) continue;
    final why = e.value.check(props[e.key]);
    if (why != null) problems.add('"${e.key}": $why');
  }
  return problems;
}

/// 匿名の 1 イベント。許可リストに合わないものは作れない（[ArgumentError]）。
class FunnelEvent {
  FunnelEvent(this.name, Map<String, Object?> props) : props = Map.unmodifiable(props) {
    final problems = validateFunnelProps(name, props);
    if (problems.isNotEmpty) throw ArgumentError('${funnelEventLabel(name)}: ${problems.join('、')}');
  }

  /// 本番の点を入れたイベント。点は持たず、[OutcomeReport] の粗い区分だけを使う。
  factory FunnelEvent.scoreEntered(OutcomeReport r) => FunnelEvent(FunnelEventName.scoreEntered, {
    'subject': r.subject,
    'region': r.region,
    if (r.grade != null) 'grade': r.grade,
    'kind': r.kind.name,
    'band': r.band.name,
    'usage': r.usage.name,
    'baseline': r.hasBaseline,
  });

  final FunnelEventName name;
  final Map<String, Object?> props;

  Map<String, Object?> toJson() => {'event': funnelEventLabel(name), ...props};
}

/// 割合 1 つ（イベント数どうしの比）と 95% 信頼区間。
class FunnelRate {
  const FunnelRate({required this.n, required this.hits, required this.rate, required this.low, required this.high});

  /// 分母（イベント数）。
  final int n;
  final int hits;
  final double rate, low, high;
}

/// 集計結果。分母が [minN] に満たない割合は null（少数から判断しない）。
class FunnelRates {
  const FunnelRates({this.scoreEntry, this.reviewReach});

  /// 点の入力率 = 点を入れた ÷ 点を聞く画面を出した。
  final FunnelRate? scoreEntry;

  /// 振り返りの到達率 = 振り返りまで進んだ ÷ 点を入れた。
  final FunnelRate? reviewReach;
}

FunnelRate? _rate(int hits, int n, int minN) {
  if (n < minN) return null;
  final h = hits > n ? n : hits;
  final p = h / n;
  final (low, high) = wilsonInterval(p, n, 1.96);
  return FunnelRate(n: n, hits: h, rate: p, low: low, high: high);
}

/// イベント名（[funnelEventLabel]）ごとの件数から、点の入力率と振り返りの到達率を求める。
///
/// **件数はイベントの数で、人数ではない**（匿名なので人は数えない）。点を聞く画面は 1 テストにつき 1 回までなので、
/// 入力率は「聞いたうち入れた割合」として読める。分母が [minN]（既定 30）未満の割合は返さない。
/// `testDateRegistered` と `ahaReached` は単位（回数と人数）が違うので、割合にしない。
FunnelRates funnelRates(Map<String, int> counts, {int minN = 30}) {
  if (minN < 1) throw ArgumentError('minN must be positive');
  int c(FunnelEventName n) => counts[funnelEventLabel(n)] ?? 0;
  return FunnelRates(
    scoreEntry: _rate(c(FunnelEventName.scoreEntered), c(FunnelEventName.scorePromptShown), minN),
    reviewReach: _rate(c(FunnelEventName.postTestReviewReached), c(FunnelEventName.scoreEntered), minN),
  );
}
