import 'dart:math' as math;

import 'assess.dart';

/// 匿名集計（段階2）。個々の提出は持たず、件数・合計・平方和の3値だけで平均と標準偏差を導く。
/// app_common_kit の exam_stats と同じ形。資格IDの代わりに教科・学年・単元に読み替える。
class ExamAggregate {
  const ExamAggregate({required this.count, required this.sum, required this.sumSq});

  static const empty = ExamAggregate(count: 0, sum: 0, sumSq: 0);

  final int count;
  final double sum, sumSq;

  double get mean => count == 0 ? 0 : sum / count;

  /// 母分散。浮動小数点誤差で負になった場合は0に丸める。
  double get variance => count == 0 ? 0 : math.max(0, sumSq / count - mean * mean);

  double get stdDev => math.sqrt(variance);

  /// 1件の提出を加えた集計（書き込みは増分3値のみ）。
  ExamAggregate add(double score) =>
      ExamAggregate(count: count + 1, sum: sum + score, sumSq: sumSq + score * score);
}

/// 集計のキー。出題配分が変わったら [examVersion] を上げ、混ぜて集計しない。
/// 単元別にしたい場合は [unitGroup] を指定する。
String examStatsKey({
  required String subject,
  required int grade,
  required int examVersion,
  String? unitGroup,
}) =>
    [subject, 'g$grade', if (unitGroup != null) unitGroup, 'v$examVersion'].join('_');

/// 段階2の偏差値。集計が [minSamples] 件（既定100）未満、または分散0なら null。
/// 人数・順位は返さない。
DeviationEstimate? deviationFromAggregate(
  ExamAggregate aggregate,
  double score, {
  int minSamples = 100,
}) {
  if (aggregate.count < minSamples || aggregate.stdDev == 0) return null;
  return DeviationEstimate(50 + 10 * (score - aggregate.mean) / aggregate.stdDev);
}

/// 段階1（基準正答率からの換算）と段階2を切り替える。段階2が出せない間は段階1。
DeviationEstimate selectDeviation({
  required List<double> baseRates,
  required int score,
  ExamAggregate? aggregate,
}) =>
    (aggregate == null ? null : deviationFromAggregate(aggregate, score.toDouble())) ??
    estimateDeviation(baseRates, score);
