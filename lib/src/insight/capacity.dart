import '../models/models.dart';
import '../planner/planner.dart';
import '../util/median.dart';

enum CapacityAction {
  /// 学習した日が少なく、判断しない。
  insufficient,

  /// 今の量のまま。
  keep,

  /// 実際にこなしている量が少ないので、1 日の量を減らす。
  lower,

  /// 余裕を持ってこなしているので、1 日の量を少し増やす。
  raise,
}

/// 1 日の量（`PlannerConfig.baseQuantity`）の見直し提案。
class CapacitySuggestion {
  const CapacitySuggestion({
    required this.action,
    required this.current,
    required this.suggested,
    required this.typical,
    required this.activeDays,
  });

  final CapacityAction action;
  final int current;
  final int suggested;

  /// 学習した日の、1 日の回答数の中央値（判断しないときは 0）と、学習した日数。
  final int typical;
  final int activeDays;

  /// [base] の 1 日の量だけを [suggested] に替えた設定。
  PlannerConfig applyTo(PlannerConfig base) => PlannerConfig(
        baseQuantity: suggested,
        carryOverRate: base.carryOverRate,
        dailyCapFactor: base.dailyCapFactor,
        lastMinuteDays: base.lastMinuteDays,
        ratios: base.ratios,
        lastMinuteRatios: base.lastMinuteRatios,
      );
}

/// 実際の学習量から、無理なくこなせる 1 日の量を見直す提案を作る。**責めない設計**:
/// 「計画より少ない＝子どもが足りない」ではなく、「計画が重い」と捉えて量を下げる。
///
/// - 数えるのは、[today] までの直近 [windowDays] 日に学習した日（練習の回答がある日）の、1 日の回答数。
///   学習しなかった日（おやすみ）は数えない。中央値を「ふだんの量」とする（模試前の詰め込みなどの外れ値に引きずられない）
/// - 学習した日が [minActiveDays] 日に満たなければ判断しない
/// - ふだんの量と今の量の差が、今の量の 10%（1 以上）以内なら変えない
/// - 変えるときは 1 回に今の量の 20%（1 以上）までだけ動かし、[minBase]〜[maxBase] に収める
///
/// 結果は提案で、反映するか（`applyTo`）はアプリが決める。同じ入力なら同じ結果。
CapacitySuggestion suggestCapacity(
  Iterable<Attempt> attempts, {
  required DateTime today,
  int current = 10,
  int windowDays = 28,
  int minActiveDays = 5,
  int minBase = 5,
  int maxBase = 40,
  String mode = 'practice',
}) {
  if (windowDays < 1 || minActiveDays < 1) throw ArgumentError('windowDays and minActiveDays must be positive');
  if (minBase > maxBase) throw ArgumentError('minBase must not exceed maxBase');
  final end = dateOnly(today);
  final start = end.subtract(Duration(days: windowDays - 1));
  final perDay = <DateTime, int>{};
  for (final a in attempts) {
    if (a.mode != mode) continue;
    final d = dateOnly(a.answeredAt);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    perDay[d] = (perDay[d] ?? 0) + 1;
  }
  if (perDay.length < minActiveDays) {
    return CapacitySuggestion(
        action: CapacityAction.insufficient, current: current, suggested: current, typical: 0, activeDays: perDay.length);
  }
  final typical = median(perDay.values).round();

  final diff = typical - current;
  final dead = (current * 0.1).round().clamp(1, 1 << 30);
  final step = (current * 0.2).round().clamp(1, 1 << 30);
  if (diff.abs() <= dead) {
    return CapacitySuggestion(
        action: CapacityAction.keep, current: current, suggested: current, typical: typical, activeDays: perDay.length);
  }
  final moved = (current + diff.clamp(-step, step)).clamp(minBase, maxBase);
  final action = moved < current ? CapacityAction.lower : (moved > current ? CapacityAction.raise : CapacityAction.keep);
  return CapacitySuggestion(
      action: action, current: current, suggested: moved, typical: typical, activeDays: perDay.length);
}
