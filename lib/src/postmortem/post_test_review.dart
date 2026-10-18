import 'dart:math' as math;

import '../bank/question_bank.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';

/// 実際のテストでの1単元ぶんの失点。
class TestLoss {
  const TestLoss(this.unitId, this.lostPoints, this.reason);

  final String unitId;

  /// その単元で落とした点（100点満点換算）。
  final double lostPoints;
  final LossReason reason;
}

/// テスト後の振り返りの入力。単元ごとの失点を本人（または保護者）が入れる。
class PostTestReview {
  const PostTestReview({
    required this.testDate,
    required this.score,
    required this.losses,
    this.maxScore = 100,
  });

  final DateTime testDate;
  final double score;
  final double maxScore;
  final List<TestLoss> losses;
}

/// 単元別の失点のまとめ。
class UnitLoss {
  const UnitLoss(this.unitId, this.lostPoints, this.byReason);

  final String unitId;
  final double lostPoints;
  final Map<LossReason, double> byReason;

  /// 理解不足・忘れ（学び直しが要る失点）。
  double get needsRelearning =>
      (byReason[LossReason.dontKnow] ?? 0) + (byReason[LossReason.forgot] ?? 0);
}

/// 振り返りの結果。
class PostTestReport {
  const PostTestReport({
    required this.lostTotal,
    required this.byUnit,
    required this.byReason,
    required this.recoverablePoints,
    required this.relearnPoints,
    required this.consistent,
    required this.attempts,
    required this.adjustedMastery,
    required this.issues,
  });

  /// 失点の合計。
  final double lostTotal;

  /// 失点の多い単元から（同点は単元ID順）。
  final List<UnitLoss> byUnit;

  /// 理由別の失点の合計。
  final Map<LossReason, double> byReason;

  /// 次は取り戻しやすい失点（ケアレス・時間切れ）。見直しの習慣や時間配分で防げる。
  final double recoverablePoints;

  /// 学び直しが要る失点（理解不足・忘れ）。
  final double relearnPoints;

  /// 入力した失点の合計が、満点と得点の差（落とした点）と合っているか。
  /// 大きくずれていたら入力の見直しを促す目安にする。
  final bool consistent;

  /// 履歴に残す回答（`mode: 'real_test'`、不正解として 1 単元 1 件）。理解不足・忘れの単元だけ。
  /// ケアレス・時間切れは入れない。履歴に保存すると、以後の習熟度や弱点の計算に効く。
  /// （[adjustedMastery] と二重にならないよう、どちらか一方を使う。保存した後は計算し直した習熟度を使う。）
  final List<Attempt> attempts;

  /// 失点の単元の習熟度を、その場で下げた版。`buildPlan(mastery: ...)` に渡すと、次の計画でその単元が重くなる。
  /// 履歴を保存せずに、すぐ計画へ反映したいときに使う。
  final Map<String, Mastery> adjustedMastery;

  /// 入力の問題（単元がツリーに無い・葉ではない・失点が負など）。
  final List<ValidationIssue> issues;

  bool get hasErrors => issues.any((i) => i.isError);
}

/// テスト後の振り返りを作る。実際のテストの問題は問題集に無いので、単元ごとの失点で扱う。
///
/// - 失点が 0 以下・単元がツリーに無い・葉でない項目は、`issues` に報告して集計から外す。
/// - 習熟度は、理解不足・忘れの失点 1 点につき [penaltyPerPoint] だけ下げる（下げ幅は [maxPenalty] まで）。
///   ケアレス・時間切れは理解不足ではないので下げない。
/// - 同じ入力なら同じ結果。
PostTestReport buildPostTestReview(
  PostTestReview review, {
  UnitTree? tree,
  Map<String, Mastery> mastery = const {},
  double penaltyPerPoint = 0.04,
  double maxPenalty = 0.5,
}) {
  final issues = <ValidationIssue>[];
  final perUnit = <String, Map<LossReason, double>>{};
  for (final l in review.losses) {
    if (!(l.lostPoints > 0)) {
      issues.add(ValidationIssue(IssueSeverity.error, 'loss_not_positive', l.unitId, '失点は 0 より大きくしてください'));
      continue;
    }
    if (tree != null) {
      final u = tree[l.unitId];
      if (u == null) {
        issues.add(ValidationIssue(IssueSeverity.error, 'unit_missing', l.unitId, '単元 ${l.unitId} が単元ツリーにありません'));
        continue;
      }
      if (!tree.isLeaf(u.id)) {
        issues.add(ValidationIssue(IssueSeverity.error, 'unit_not_leaf', l.unitId, '単元 ${l.unitId} は葉ではありません（細かい単元で入力してください）'));
        continue;
      }
    }
    final m = perUnit.putIfAbsent(l.unitId, () => {});
    m[l.reason] = (m[l.reason] ?? 0) + l.lostPoints;
  }

  final byUnit = [
    for (final e in perUnit.entries)
      UnitLoss(e.key, e.value.values.fold(0.0, (s, v) => s + v), e.value),
  ]..sort((a, b) {
      final c = b.lostPoints.compareTo(a.lostPoints);
      return c != 0 ? c : a.unitId.compareTo(b.unitId);
    });

  final byReason = <LossReason, double>{};
  for (final u in byUnit) {
    for (final e in u.byReason.entries) {
      byReason[e.key] = (byReason[e.key] ?? 0) + e.value;
    }
  }
  final lostTotal = byUnit.fold(0.0, (s, u) => s + u.lostPoints);
  final recoverable = (byReason[LossReason.careless] ?? 0) + (byReason[LossReason.timeShort] ?? 0);
  final relearn = (byReason[LossReason.dontKnow] ?? 0) + (byReason[LossReason.forgot] ?? 0);
  final expectedLost = review.maxScore - review.score;
  // 端数や、部分点の数え方のずれは許す（満点の 5% まで）
  final consistent = (lostTotal - expectedLost).abs() <= review.maxScore * 0.05;

  final adjusted = {...mastery};
  final attempts = <Attempt>[];
  for (final u in byUnit) {
    final need = u.needsRelearning;
    if (need <= 0) continue;
    final base = mastery[u.unitId];
    final penalty = math.min(maxPenalty, need * penaltyPerPoint);
    adjusted[u.unitId] = Mastery(
      unitId: u.unitId,
      score: math.max(0.0, (base?.score ?? 0.5) - penalty),
      lastPracticedAt: base?.lastPracticedAt,
    );
    attempts.add(Attempt(
      questionId: 'real:${dateOnly(review.testDate).toIso8601String().substring(0, 10)}:${u.unitId}',
      unitId: u.unitId,
      correct: false,
      answeredAt: review.testDate,
      mode: 'real_test',
    ));
  }

  return PostTestReport(
    lostTotal: lostTotal,
    byUnit: byUnit,
    byReason: byReason,
    recoverablePoints: recoverable,
    relearnPoints: relearn,
    consistent: consistent,
    attempts: attempts,
    adjustedMastery: adjusted,
    issues: issues,
  );
}
