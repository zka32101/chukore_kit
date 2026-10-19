import 'dart:math' as math;

import '../models/models.dart';

/// 問題 1 つの、実測の正答率と基準正答率（作った人の見積もり）のずれ。
class DifficultyDrift {
  const DifficultyDrift({
    required this.questionId,
    required this.unitId,
    required this.attempts,
    required this.observed,
    required this.nominal,
    required this.low,
    required this.high,
  });

  final String questionId;
  final String unitId;

  /// 数えた回答の数。
  final int attempts;

  /// 実測の正答率（0〜1）。
  final double observed;

  /// 問題に付いている基準正答率。
  final double nominal;

  /// 実測の正答率の 95% 信頼区間（Wilson）。
  final double low, high;

  /// 実測 − 基準。プラスなら、見積もりより易しかった。
  double get gap => observed - nominal;

  bool get easierThanAssumed => gap > 0;

  /// 見直しの提案値。実測の正答率を 0.05 刻みに丸め、0.05〜0.95 に収める（0 と 1 は偏差値の換算で分散が 0 になるため避ける）。
  double get suggested => ((observed * 20).round() / 20).clamp(0.05, 0.95);
}

/// 単元ごとの、見積もりの偏り。
class UnitCalibration {
  const UnitCalibration({required this.unitId, required this.questions, required this.meanGap});

  final String unitId;

  /// 数えた問題の数（回答が [minAttempts] に届いた問題）。
  final int questions;

  /// 実測 − 基準 の平均。プラスなら、その単元の見積もりが全体に辛かった（実際は易しかった）。
  final double meanGap;
}

class CalibrationReport {
  const CalibrationReport({required this.drifts, required this.units, required this.measured});

  /// 見積もりと大きくずれた問題（ずれの大きい順）。
  final List<DifficultyDrift> drifts;

  /// 単元ごとの偏り（偏りの大きい順）。
  final List<UnitCalibration> units;

  /// 回答が足りて、実測できた問題の数。
  final int measured;
}

/// 回答履歴から、問題ごとの実測の正答率を出し、基準正答率（`Question.difficulty`）と大きくずれた問題を見つける。
///
/// **端末 1 台の履歴では 1 問あたりの回答が少ない**ので、アプリが（個人を特定しない形で）集めた回答の束を渡す想定。
/// 基盤は集めない・送らない。ここは「履歴の束から、ずれた問題の一覧を出す」計算だけを持つ。
///
/// - 数えるのは [mode] の回答（既定は練習。模試は時間制限があって正答率が下がるため別に見る）。
///   ヒントを使った回答は数えない（正解が増えて実測が易しい側にかたよる）。暗記カード（`card`）は対象外
/// - 回答が [minAttempts] 件に満たない問題は判定しない
/// - **ずれ** = 実測の 95% 信頼区間に基準値が入らず（偶然とは言いにくい）、しかも差が [minGap] 以上
/// - 提案値は実測の正答率を 0.05 刻みに丸めたもの（[DifficultyDrift.suggested]）。反映は [recalibrate]
CalibrationReport calibrateDifficulty(
  Iterable<Attempt> attempts,
  Iterable<Question> questions, {
  int minAttempts = 20,
  double minGap = 0.15,
  double z = 1.96,
  String mode = 'practice',
}) {
  if (minAttempts < 1) throw ArgumentError('minAttempts must be positive');
  final byId = {for (final q in questions) q.id: q};
  final total = <String, int>{};
  final right = <String, int>{};
  for (final a in attempts) {
    final q = byId[a.questionId];
    if (q == null || q.type == 'card' || a.mode != mode || a.hintsUsed > 0) continue;
    total[q.id] = (total[q.id] ?? 0) + 1;
    if (a.correct) right[q.id] = (right[q.id] ?? 0) + 1;
  }

  final drifts = <DifficultyDrift>[];
  final byUnit = <String, List<double>>{};
  var measured = 0;
  for (final id in total.keys) {
    final n = total[id]!;
    if (n < minAttempts) continue;
    measured++;
    final q = byId[id]!;
    final p = (right[id] ?? 0) / n;
    final (low, high) = wilsonInterval(p, n, z);
    (byUnit[q.unitId] ??= []).add(p - q.difficulty);
    final outside = q.difficulty < low || q.difficulty > high;
    if (outside && (p - q.difficulty).abs() >= minGap) {
      drifts.add(DifficultyDrift(
        questionId: id,
        unitId: q.unitId,
        attempts: n,
        observed: p,
        nominal: q.difficulty,
        low: low,
        high: high,
      ));
    }
  }
  drifts.sort((a, b) {
    final c = b.gap.abs().compareTo(a.gap.abs());
    return c != 0 ? c : a.questionId.compareTo(b.questionId);
  });
  final units = [
    for (final e in byUnit.entries)
      UnitCalibration(unitId: e.key, questions: e.value.length, meanGap: e.value.fold<double>(0, (s, g) => s + g) / e.value.length),
  ]..sort((a, b) {
      final c = b.meanGap.abs().compareTo(a.meanGap.abs());
      return c != 0 ? c : a.unitId.compareTo(b.unitId);
    });
  return CalibrationReport(drifts: drifts, units: units, measured: measured);
}

/// Wilson の信頼区間（成功率 [p]、試行 [n]、[z] は 95% で 1.96）。復習間隔の調整（`tuneReviewIntervals`）でも使う。
(double, double) wilsonInterval(double p, int n, double z) {
  final z2 = z * z;
  final denom = 1 + z2 / n;
  final center = (p + z2 / (2 * n)) / denom;
  final half = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / denom;
  return ((center - half).clamp(0.0, 1.0), (center + half).clamp(0.0, 1.0));
}

/// [report] の提案値を問題集に反映した写しを返す。内容（基準正答率）を変えるので **version を 1 上げる**
/// （回答履歴の集計が古い内容と混ざらないように。差分更新は `BankDiff`）。ずれの無い問題はそのまま。
List<Question> recalibrate(Iterable<Question> questions, CalibrationReport report) {
  final fix = {for (final d in report.drifts) d.questionId: d.suggested};
  return [
    for (final q in questions)
      fix.containsKey(q.id) && fix[q.id] != q.difficulty
          ? q.copyWith(difficulty: fix[q.id], version: q.version + 1)
          : q,
  ];
}
