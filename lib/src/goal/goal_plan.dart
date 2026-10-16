import 'dart:math' as math;

import '../models/models.dart';
import '../scope/unit_tree.dart';

/// 目標に近づくために伸ばす単元1つ。
class GoalStep {
  const GoalStep({
    required this.unitId,
    required this.currentMastery,
    required this.targetMastery,
    required this.gainPoints,
  });

  final String unitId;
  final double currentMastery;

  /// 目標のためにここまで伸ばす。
  final double targetMastery;

  /// 伸ばしたときに増える見込みの点（100点満点換算）。
  final double gainPoints;
}

/// 目標点からの逆算の結果。
class GoalPlan {
  const GoalPlan({
    required this.currentScore,
    required this.targetScore,
    required this.maxPossible,
    required this.steps,
  });

  /// 今の習熟度から見込む点（範囲の単元を問題数の重みで平均）。あくまで目安。
  final double currentScore;
  final double targetScore;

  /// 全部の単元を [GoalPlan] の上限（既定 0.9）まで伸ばしたときの見込み点。
  final double maxPossible;

  /// 伸ばす単元（効果の大きい順）。目標に届いていれば空。
  final List<GoalStep> steps;

  /// 目標との差（届いていれば 0）。
  double get gap => math.max(0, targetScore - currentScore);

  bool get achieved => currentScore >= targetScore;

  /// 習熟度の上限まで伸ばしても目標に届かない。
  bool get unreachable => !achieved && maxPossible < targetScore;

  /// 伸ばす単元のID（効果の大きい順）。重点的に取り組む単元として、出題や表示に使う。
  List<String> get unitIds => [for (final s in steps) s.unitId];
}

/// 目標点 [targetScore]（100点満点）から、どの単元をどこまで伸ばせばよいかを逆算する。
///
/// 見込み点 = 100 × Σ(単元の重み × 習熟度) ÷ Σ(重み)。重みは単元の想定問題数（0 以下は 1）。
/// 習熟度の記録が無い単元は 0（未学習）として扱う。
/// 伸ばす単元は「習熟度を [masteryCap] まで上げたときに増える点」が大きい順に選び、
/// 目標に届くところで止める（最後の単元は必要な分だけ伸ばす）。上限まで伸ばしても届かないときは
/// 全単元を上限まで伸ばす案と `unreachable` を返す。同じ入力なら同じ結果。
GoalPlan buildGoalPlan({
  required UnitTree tree,
  required Iterable<String> unitIds,
  required Map<String, Mastery> mastery,
  required double targetScore,
  double masteryCap = 0.9,
}) {
  if (!(targetScore > 0 && targetScore <= 100)) {
    throw ArgumentError('targetScore は 0 より大きく 100 以下にしてください');
  }
  if (!(masteryCap > 0 && masteryCap <= 1)) {
    throw ArgumentError('masteryCap は 0 より大きく 1 以下にしてください');
  }
  final leaves = tree.resolveLeaves(unitIds);
  if (leaves.isEmpty) {
    return GoalPlan(currentScore: 0, targetScore: targetScore, maxPossible: 0, steps: const []);
  }
  double weightOf(Unit u) => u.estimatedQuestions <= 0 ? 1.0 : u.estimatedQuestions.toDouble();
  final total = leaves.fold<double>(0, (s, u) => s + weightOf(u));
  double m(Unit u) => (mastery[u.id]?.score ?? 0).clamp(0.0, 1.0);

  final current = 100 * leaves.fold<double>(0, (s, u) => s + weightOf(u) * m(u)) / total;
  // 習熟度が上限を超えている単元は、それ以上は伸ばさない（上限のまま数える）
  final maxPossible =
      100 * leaves.fold<double>(0, (s, u) => s + weightOf(u) * math.max(m(u), masteryCap)) / total;

  final candidates = [
    for (final u in leaves)
      if (m(u) < masteryCap) (u: u, gain: 100 * weightOf(u) * (masteryCap - m(u)) / total),
  ]..sort((a, b) {
      final c = b.gain.compareTo(a.gain);
      return c != 0 ? c : a.u.id.compareTo(b.u.id);
    });

  final steps = <GoalStep>[];
  var need = targetScore - current;
  for (final c in candidates) {
    if (need <= 1e-9) break;
    final take = math.min(need, c.gain);
    final cur = m(c.u);
    steps.add(GoalStep(
      unitId: c.u.id,
      currentMastery: cur,
      targetMastery: cur + (masteryCap - cur) * (take / c.gain),
      gainPoints: take,
    ));
    need -= take;
  }
  return GoalPlan(currentScore: current, targetScore: targetScore, maxPossible: maxPossible, steps: steps);
}
