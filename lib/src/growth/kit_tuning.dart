import 'dart:convert';

import '../models/models.dart';
import '../ports/ports.dart';
import 'funnel_events.dart';
import 'outcome_report.dart';
import 'outcome_summary.dart';
import 'real_tests.dart';
import 'score_entry.dart';

/// 本番の点まわりのしきい値をまとめたもの。**値はすべて暫定**で、ソフトローンチの結果を見る**前に**決めて版（[version]）を付けて記録する。
///
/// 値を変えたら [version] を上げる。区分（変化・使った量）の境界が変わるので、版が違う報告は混ぜて集計しない
/// （[OutcomeReport.tuning]・[tallyOutcomes]）。変更の理由と日付は `docs/score_outcome_measurement.md` に残す。
///
/// ```json
/// {"version": 1, "outcomeNoise": 0.03, "outcomeBig": 0.1, "usageMidFrom": 4, "usageHighFrom": 12,
///  "lookbackDays": 28, "promptWindowDays": 14, "promptMatchDays": 3, "minCell": 30, "funnelMinN": 30}
/// ```
class KitTuning {
  const KitTuning({
    this.version = 1,
    this.outcomeNoise = 0.03,
    this.outcomeBig = 0.10,
    this.usageMidFrom = 4,
    this.usageHighFrom = 12,
    this.lookbackDays = 28,
    this.promptWindowDays = 14,
    this.promptMatchDays = 3,
    this.minCell = 30,
    this.funnelMinN = 30,
  });

  /// 版（1 以上）。値を変えたら上げる。
  final int version;

  /// これ以内の変化（満点比）は「ほぼ同じ」。
  final double outcomeNoise;

  /// これを超える変化は「大きく」上がった／下がった。
  final double outcomeBig;

  /// 使った量の区分: テスト前の学習日数がこの日数以上で「中」「多」。
  final int usageMidFrom, usageHighFrom;

  /// 使った量を数える、テスト前の日数。
  final int lookbackDays;

  /// 点を聞くのは、テスト日の翌日からこの日数以内。
  final int promptWindowDays;

  /// テスト日の前後この日数以内に記録があれば聞かない。
  final int promptMatchDays;

  /// 集計の 1 マスの最小件数（これ未満は返さない）。
  final int minCell;

  /// 割合の分母の最小件数（これ未満は返さない）。
  final int funnelMinN;

  static const _keys = {
    'version', 'outcomeNoise', 'outcomeBig', 'usageMidFrom', 'usageHighFrom', 'lookbackDays',
    'promptWindowDays', 'promptMatchDays', 'minCell', 'funnelMinN', //
  };

  /// JSON から読む。省略した項目は既定値。書き間違い・範囲外は [FormatException]（黙って無視しない）。
  factory KitTuning.fromJson(Object? root) {
    if (root is! Map) throw const FormatException('しきい値: 最上位はオブジェクトにしてください');
    for (final k in root.keys) {
      if (!_keys.contains(k)) throw FormatException('しきい値: 未知のキー "$k"');
    }
    const d = KitTuning();
    int intOf(String k, int def, int min, int max) {
      final v = root[k];
      if (v == null) return def;
      if (v is! int || v < min || v > max) throw FormatException('しきい値: $k は $min〜$max の整数です ($v)');
      return v;
    }

    double numOf(String k, double def, double min, double max) {
      final v = root[k];
      if (v == null) return def;
      if (v is! num || v < min || v > max) throw FormatException('しきい値: $k は $min〜$max の数です ($v)');
      return v.toDouble();
    }

    final t = KitTuning(
      version: intOf('version', d.version, 1, 9999),
      outcomeNoise: numOf('outcomeNoise', d.outcomeNoise, 0, 0.5),
      outcomeBig: numOf('outcomeBig', d.outcomeBig, 0, 1),
      usageMidFrom: intOf('usageMidFrom', d.usageMidFrom, 1, 365),
      usageHighFrom: intOf('usageHighFrom', d.usageHighFrom, 2, 365),
      lookbackDays: intOf('lookbackDays', d.lookbackDays, 1, 365),
      promptWindowDays: intOf('promptWindowDays', d.promptWindowDays, 1, 365),
      promptMatchDays: intOf('promptMatchDays', d.promptMatchDays, 0, 30),
      minCell: intOf('minCell', d.minCell, 1, 10000),
      funnelMinN: intOf('funnelMinN', d.funnelMinN, 1, 10000),
    );
    if (t.outcomeBig <= t.outcomeNoise) throw const FormatException('しきい値: outcomeBig は outcomeNoise より大きくしてください');
    if (t.usageHighFrom <= t.usageMidFrom) {
      throw const FormatException('しきい値: usageHighFrom は usageMidFrom より大きくしてください');
    }
    if (t.usageHighFrom > t.lookbackDays) throw const FormatException('しきい値: usageHighFrom は lookbackDays 以下にしてください');
    return t;
  }

  factory KitTuning.parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('しきい値の JSON が読めません: ${e.message}');
    }
    return KitTuning.fromJson(root);
  }

  Map<String, Object> toJson() => {
    'version': version,
    'outcomeNoise': outcomeNoise,
    'outcomeBig': outcomeBig,
    'usageMidFrom': usageMidFrom,
    'usageHighFrom': usageHighFrom,
    'lookbackDays': lookbackDays,
    'promptWindowDays': promptWindowDays,
    'promptMatchDays': promptMatchDays,
    'minCell': minCell,
    'funnelMinN': funnelMinN,
  };

  /// このしきい値で、本番の点の変化を求める（[buildOutcomeSummary]）。
  OutcomeSummary outcomeSummary(
    Iterable<RealTestRecord> records,
    Iterable<Attempt> attempts, {
    RealTestRecord? baseline,
    RealTestKind kind = RealTestKind.regular,
    StudyDay studyDay = const StudyDay(),
  }) => buildOutcomeSummary(
    records,
    attempts,
    baseline: baseline,
    kind: kind,
    noise: outcomeNoise,
    lookbackDays: lookbackDays,
    studyDay: studyDay,
  );

  /// このしきい値で、外へ出す報告を作る（[buildOutcomeReports]）。報告に版が入る。
  List<OutcomeReport> outcomeReports(
    OutcomeSummary summary, {
    required String subject,
    required String region,
    int? grade,
  }) => buildOutcomeReports(
    summary,
    subject: subject,
    region: region,
    grade: grade,
    noise: outcomeNoise,
    big: outcomeBig,
    midFrom: usageMidFrom,
    highFrom: usageHighFrom,
    tuning: version,
  );

  /// このしきい値で集計する（[tallyOutcomes]）。
  List<OutcomeCell> tally(Iterable<OutcomeReport> reports) => tallyOutcomes(reports, minCell: minCell);

  /// このしきい値で割合を求める（[funnelRates]）。
  FunnelRates rates(Map<String, int> counts) => funnelRates(counts, minN: funnelMinN);

  /// このしきい値で、今日点を聞くか決める（[decideScorePrompt]）。
  ScorePrompt? scorePrompt({
    required DateTime today,
    required Iterable<DateTime> testDates,
    required Iterable<RealTestRecord> records,
    ScorePromptState state = const ScorePromptState(),
    RealTestRecord? baseline,
  }) => decideScorePrompt(
    today: today,
    testDates: testDates,
    records: records,
    state: state,
    baseline: baseline,
    windowDays: promptWindowDays,
    matchDays: promptMatchDays,
  );
}
