import 'dart:math' as math;

import '../models/models.dart';
import '../scope/unit_tree.dart';

/// 1日の内訳比率（初期値。ソフトローンチで調整）。
class PlanRatios {
  const PlanRatios(this.focus, this.weak, this.review);

  static const normal = PlanRatios(0.6, 0.3, 0.1);

  /// 直前モード: 範囲全体の総復習＋弱点ノート中心。
  static const lastMinute = PlanRatios(0.5, 0.5, 0.0);

  final double focus, weak, review;
}

class PlannerConfig {
  const PlannerConfig({
    this.baseQuantity = 10,
    this.carryOverRate = 0.5,
    this.dailyCapFactor = 1.3,
    this.lastMinuteDays = 3,
    this.ratios = PlanRatios.normal,
    this.lastMinuteRatios = PlanRatios.lastMinute,
  });

  final int baseQuantity;

  /// 忙しい日で減らした分のうち、通常日へ上乗せする割合。
  final double carryOverRate;

  /// 1日の上限 = baseQuantity × この値。
  final double dailyCapFactor;
  final int lastMinuteDays;
  final PlanRatios ratios, lastMinuteRatios;
}

class DayPlan {
  const DayPlan({
    required this.date,
    required this.daysLeft,
    required this.total,
    required this.focus,
    required this.weak,
    required this.review,
    required this.focusByUnit,
    required this.lastMinute,
  });

  final DateTime date;

  /// テストまでの残り日数（当日 = 0）。
  final int daysLeft;
  final int total;
  final int focus, weak, review;

  /// 重点枠の単元別問題数。
  final Map<String, int> focusByUnit;
  final bool lastMinute;
}

class PlanResult {
  const PlanResult(this.days, this.overCapacity, this.priorityUnitIds);

  final List<DayPlan> days;

  /// 範囲の想定問題数が計画の総量を超えている（無理な量にはしない）。
  final bool overCapacity;

  /// overCapacity のとき、優先して取り組む単元（必要度の高い順）。
  final List<String> priorityUnitIds;
}

/// 単元の必要度 = (1 − mastery) × 問題数の重み ＋ 最近やっていない単元への加点。
double unitNeed(
  Unit unit,
  Mastery? mastery,
  DateTime today, {
  required int maxEstimated,
}) {
  final weight = maxEstimated <= 0 ? 1.0 : unit.estimatedQuestions / maxEstimated;
  final m = mastery?.score ?? 0.0;
  final last = mastery?.lastPracticedAt;
  final idle = last == null
      ? 1.0
      : math.min(1.0, dateOnly(today).difference(dateOnly(last)).inDays / 14);
  return (1 - m) * (weight <= 0 ? 0.1 : weight) + 0.2 * idle;
}

/// 間違えた問題の再出題日（翌日・3日後・7日後。テスト日を超えない範囲）。
List<DateTime> retryDates(DateTime wrongDate, DateTime testDate) {
  final base = dateOnly(wrongDate);
  final end = dateOnly(testDate);
  return [
    for (final d in const [1, 3, 7])
      if (!base.add(Duration(days: d)).isAfter(end)) base.add(Duration(days: d)),
  ];
}

/// テスト日逆算。同じ入力なら同じ結果（乱数・現在時刻に依存しない）。
PlanResult buildPlan({
  required DateTime today,
  required TestPlan plan,
  required UnitTree tree,
  Map<String, Mastery> mastery = const {},
  List<BusyDay> busyDays = const [],
  PlannerConfig config = const PlannerConfig(),
}) {
  final start = dateOnly(today);
  final testDay = dateOnly(plan.testDate);
  final dayCount = testDay.difference(start).inDays + 1;
  if (dayCount <= 0) return const PlanResult([], false, []);

  final busyByDate = {for (final b in busyDays) dateOnly(b.date): b};
  final n = config.baseQuantity;
  final dates = [for (var i = 0; i < dayCount; i++) start.add(Duration(days: i))];
  final factors = [
    for (final d in dates) busyByDate[d]?.factor ?? 1.0,
  ];

  // 減らした分の carryOverRate だけを通常日へ均等に上乗せ（上限あり）。
  final reduced = factors.fold<double>(0, (s, f) => s + n * (1 - f));
  final normalCount = factors.where((f) => f == 1.0).length;
  final cap = n * config.dailyCapFactor;
  final extra = normalCount == 0
      ? 0.0
      : math.min(reduced * config.carryOverRate / normalCount, cap - n);

  final leaves = tree.resolveLeaves(plan.unitIds);
  final maxEst = leaves.fold<int>(0, (m, u) => math.max(m, u.estimatedQuestions));
  final needs = {
    for (final u in leaves)
      u.id: unitNeed(u, mastery[u.id], start, maxEstimated: maxEst),
  };

  final days = <DayPlan>[];
  var totalQuantity = 0;
  for (var i = 0; i < dayCount; i++) {
    final f = factors[i];
    final raw = f == 1.0 ? n + extra : n * f;
    final total = math.min(raw, cap).round();
    final left = dayCount - 1 - i;
    final last = left <= config.lastMinuteDays;
    final r = last ? config.lastMinuteRatios : config.ratios;
    final (:focus, :weak, :review) = splitDay(total, r);
    totalQuantity += total;
    days.add(DayPlan(
      date: dates[i],
      daysLeft: left,
      total: total,
      focus: focus,
      weak: weak,
      review: review,
      focusByUnit: _allocate(
        focus,
        // 直前モードは範囲全体を満遍なく回すため、必要度を平滑化する。
        last ? {for (final e in needs.entries) e.key: e.value + 0.25} : needs,
      ),
      lastMinute: last,
    ));
  }

  final rangeSize = leaves.fold<int>(0, (s, u) => s + u.estimatedQuestions);
  final over = rangeSize > totalQuantity;
  final priority = needs.keys.toList()
    ..sort((a, b) {
      final c = needs[b]!.compareTo(needs[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return PlanResult(days, over, over ? priority : const []);
}

/// 1 日の問題数 [total] を、重点・弱点・復習に分ける。合計は必ず [total] に一致する
/// （四捨五入で重点と弱点が両方切り上がっても、合計を超えない。超える分は弱点から削る）。
({int focus, int weak, int review}) splitDay(int total, PlanRatios r) {
  final focus = math.min(total, (total * r.focus).round());
  final weak = math.min(total - focus, (total * r.weak).round());
  return (focus: focus, weak: weak, review: total - focus - weak);
}

/// 最大剰余法で [total] を重みに比例配分する（同率はキー順）。0 になった項目は含めない。
Map<String, int> allocateByWeight(int total, Map<String, double> weights) => _allocate(total, weights);

Map<String, int> _allocate(int total, Map<String, double> weights) {
  if (total <= 0 || weights.isEmpty) return {};
  final sum = weights.values.fold<double>(0, (s, w) => s + w);
  if (sum <= 0) return {};
  final ids = weights.keys.toList()..sort();
  final out = {for (final id in ids) id: 0};
  final rem = <String, double>{};
  var assigned = 0;
  for (final id in ids) {
    final exact = total * weights[id]! / sum;
    out[id] = exact.floor();
    rem[id] = exact - exact.floor();
    assigned += out[id]!;
  }
  final order = [...ids]..sort((a, b) {
      final c = rem[b]!.compareTo(rem[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  for (var i = 0; assigned < total; i++, assigned++) {
    out[order[i % order.length]] = out[order[i % order.length]]! + 1;
  }
  out.removeWhere((_, v) => v == 0);
  return out;
}
