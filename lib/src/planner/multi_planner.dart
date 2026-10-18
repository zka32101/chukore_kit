import 'dart:math' as math;

import '../models/models.dart';
import '../scope/unit_tree.dart';
import 'planner.dart';

/// 1 日分の、複数のテストにまたがる計画。
class MultiDayPlan {
  const MultiDayPlan({required this.date, required this.total, required this.byPlan, required this.order});

  final DateTime date;

  /// この日の問題数の合計（`byPlan` の合計と同じ。お休みの日は 0）。
  final int total;

  /// テスト（`TestPlan.id`）ごとの、この日の計画。この日に割り当てが無いテストは含まない。
  /// 各 [DayPlan] はそのまま `pickPractice` に渡せる。
  final Map<String, DayPlan> byPlan;

  /// この日に取り組む順（テストが近いものが先、同じ日なら ID 順）。
  final List<String> order;
}

/// 複数のテストの同時計画。
class MultiPlanResult {
  const MultiPlanResult({
    required this.days,
    required this.overCapacityPlanIds,
    required this.priorityUnitIds,
    required this.skippedPlanIds,
  });

  /// 今日から最後のテストの日まで、1 日ずつ。
  final List<MultiDayPlan> days;

  /// 範囲の想定問題数が、割り当てられた総量を超えるテスト（無理な量にはしない）。
  final List<String> overCapacityPlanIds;

  /// 上のテストごとに、優先して取り組む単元（必要度の高い順）。
  final Map<String, List<String>> priorityUnitIds;

  /// すでにテスト日が過ぎていたため、計画に入れなかったテスト。
  final List<String> skippedPlanIds;
}

/// 5 教科などの定期テストが同じ時期に来る場合の、同時計画。同じ入力なら同じ結果。
///
/// 1 日に解ける問題数 [dailyQuestions] を、その日まだテストが残っている教科（[TestPlan]）に割り振る。
/// - **近いテストを厚く**: 重みは「1 ÷ (テストまでの日数 + 1)」×「残りの学習量（(1 − 習熟度) × 想定問題数 の合計）」。
///   習熟度が低く範囲が広い教科ほど多く、テストが近い教科ほど多くなる
/// - **遠い教科も止めない**: どの教科にも、その日の予算の [minShare] 以上（教科が多いときは均等割りまで）は残す
/// - **忙しい日・お休み**: 全教科で共通（`BusyDay`）。減らした分の [PlannerConfig.carryOverRate] を通常日に上乗せ
///   （上限は dailyQuestions × [PlannerConfig.dailyCapFactor]）。お休みの日は全教科 0
/// - 教科ごとの 1 日の内訳（重点・弱点・復習、重点の単元別）は、`buildPlan` と同じ決め方
///   （テストまで [PlannerConfig.lastMinuteDays] 日以内は直前モード）
/// - あるテストが終わった翌日からは、その教科には割り当てず、残りの教科に回る
///
/// 1 つのテストだけを渡し、[dailyQuestions] を `PlannerConfig.baseQuantity` に合わせると、`buildPlan` と同じ結果になる。
MultiPlanResult buildMultiPlan({
  required DateTime today,
  required List<TestPlan> plans,
  required UnitTree tree,
  Map<String, Mastery> mastery = const {},
  List<BusyDay> busyDays = const [],
  int dailyQuestions = 30,
  double minShare = 0.1,
  PlannerConfig config = const PlannerConfig(),
}) {
  if (dailyQuestions <= 0) throw ArgumentError('dailyQuestions must be positive');
  if (minShare < 0 || minShare > 0.5) throw ArgumentError('minShare は 0〜0.5');
  final start = dateOnly(today);

  final active = <TestPlan>[];
  final skipped = <String>[];
  for (final p in [...plans]..sort((a, b) => a.id.compareTo(b.id))) {
    if (dateOnly(p.testDate).isBefore(start)) {
      skipped.add(p.id);
    } else {
      active.add(p);
    }
  }
  if (active.isEmpty) {
    return MultiPlanResult(days: const [], overCapacityPlanIds: const [], priorityUnitIds: const {}, skippedPlanIds: skipped);
  }
  if (active.map((p) => p.id).toSet().length != active.length) {
    throw ArgumentError('TestPlan.id が重複しています');
  }

  final lastDay = active.map((p) => dateOnly(p.testDate)).reduce((a, b) => a.isAfter(b) ? a : b);
  final dayCount = lastDay.difference(start).inDays + 1;
  final dates = [for (var i = 0; i < dayCount; i++) start.add(Duration(days: i))];

  // 忙しい日・お休み（buildPlan と同じ上乗せ）
  final busyByDate = {for (final b in busyDays) dateOnly(b.date): b};
  final n = dailyQuestions;
  final factors = [for (final d in dates) busyByDate[d]?.factor ?? 1.0];
  final reduced = factors.fold<double>(0, (s, f) => s + n * (1 - f));
  final normalCount = factors.where((f) => f == 1.0).length;
  final cap = n * config.dailyCapFactor;
  final extra = normalCount == 0 ? 0.0 : math.min(reduced * config.carryOverRate / normalCount, cap - n);

  // 教科ごとの葉の単元・必要度・残りの学習量
  final leavesOf = {for (final p in active) p.id: tree.resolveLeaves(p.unitIds)};
  final needsOf = <String, Map<String, double>>{};
  final workOf = <String, double>{};
  for (final p in active) {
    final leaves = leavesOf[p.id]!;
    final maxEst = leaves.fold<int>(0, (m, u) => math.max(m, u.estimatedQuestions));
    needsOf[p.id] = {for (final u in leaves) u.id: unitNeed(u, mastery[u.id], start, maxEstimated: maxEst)};
    workOf[p.id] = leaves.fold<double>(
      0,
      (s, u) => s + (1 - (mastery[u.id]?.score ?? 0).clamp(0.0, 1.0)) * (u.estimatedQuestions <= 0 ? 1 : u.estimatedQuestions),
    );
  }

  final days = <MultiDayPlan>[];
  final allocatedTotal = {for (final p in active) p.id: 0};
  for (var i = 0; i < dayCount; i++) {
    final date = dates[i];
    final f = factors[i];
    final raw = f == 1.0 ? n + extra : n * f;
    final total = math.min(raw, cap).round();

    final today_ = [for (final p in active) if (!dateOnly(p.testDate).isBefore(date)) p];
    if (total <= 0 || today_.isEmpty) {
      days.add(MultiDayPlan(date: date, total: 0, byPlan: const {}, order: const []));
      continue;
    }

    int daysLeft(TestPlan p) => dateOnly(p.testDate).difference(date).inDays;
    // 重み: 近いテスト × 残りの学習量。学習量が 0（すべて習得済み）でも 0 にはしない
    final weights = {
      for (final p in today_) p.id: (1 / (daysLeft(p) + 1)) * (workOf[p.id]! + 1),
    };
    final sumW = weights.values.fold<double>(0, (s, w) => s + w);
    final share = math.min(minShare, 0.5 / today_.length);
    final floor = share * today_.length;
    final blended = {
      for (final e in weights.entries) e.key: (1 - floor) * e.value / sumW + share,
    };
    final quota = allocateByWeight(total, blended);

    final byPlan = <String, DayPlan>{};
    for (final p in today_) {
      final q = quota[p.id] ?? 0;
      if (q <= 0) continue;
      final left = daysLeft(p);
      final last = left <= config.lastMinuteDays;
      final r = last ? config.lastMinuteRatios : config.ratios;
      final (:focus, :weak, :review) = splitDay(q, r);
      final needs = needsOf[p.id]!;
      byPlan[p.id] = DayPlan(
        date: date,
        daysLeft: left,
        total: q,
        focus: focus,
        weak: weak,
        review: review,
        focusByUnit: allocateByWeight(
          focus,
          last ? {for (final e in needs.entries) e.key: e.value + 0.25} : needs,
        ),
        lastMinute: last,
      );
      allocatedTotal[p.id] = allocatedTotal[p.id]! + q;
    }
    final order = byPlan.keys.toList()
      ..sort((a, b) {
        final c = byPlan[a]!.daysLeft.compareTo(byPlan[b]!.daysLeft);
        return c != 0 ? c : a.compareTo(b);
      });
    days.add(MultiDayPlan(
      date: date,
      total: byPlan.values.fold<int>(0, (s, d) => s + d.total),
      byPlan: byPlan,
      order: order,
    ));
  }

  final over = <String>[];
  final priority = <String, List<String>>{};
  for (final p in active) {
    final rangeSize = leavesOf[p.id]!.fold<int>(0, (s, u) => s + u.estimatedQuestions);
    if (rangeSize > allocatedTotal[p.id]!) {
      over.add(p.id);
      final needs = needsOf[p.id]!;
      priority[p.id] = needs.keys.toList()
        ..sort((a, b) {
          final c = needs[b]!.compareTo(needs[a]!);
          return c != 0 ? c : a.compareTo(b);
        });
    }
  }
  return MultiPlanResult(days: days, overCapacityPlanIds: over, priorityUnitIds: priority, skippedPlanIds: skipped);
}
