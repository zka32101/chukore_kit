import '../models/models.dart';
import '../planner/planner.dart';

/// 1問あたりにかかる時間の見積もり（本人の履歴から）。
class PaceModel {
  const PaceModel(this.secondsByUnit, this.overallSeconds, {required this.measured});

  /// 単元ID → 1問あたりの秒（中央値）。単元の記録が足りない単元は入らない。
  final Map<String, double> secondsByUnit;

  /// 全体の中央値（秒）。記録が足りなければ既定値。
  final double overallSeconds;

  /// 履歴から求めた値か（false なら既定値で見積もっている）。
  final bool measured;

  double secondsFor(String unitId) => secondsByUnit[unitId] ?? overallSeconds;
}

double _median(List<int> xs) {
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}

/// 回答履歴から 1問あたりの時間を求める。所要時間 0（未計測）と [maxSeconds] 超（席を離れた等）は除く。
/// 単元の記録が [minSamples] 件以上ならその単元の中央値、足りなければ全体の中央値、
/// 全体も足りなければ [defaultSeconds]。
PaceModel buildPace(
  Iterable<Attempt> attempts, {
  double defaultSeconds = 45,
  int minSamples = 5,
  double maxSeconds = 300,
}) {
  final byUnit = <String, List<int>>{};
  final all = <int>[];
  for (final a in attempts) {
    if (a.elapsedMs <= 0 || a.elapsedMs > maxSeconds * 1000) continue;
    (byUnit[a.unitId] ??= []).add(a.elapsedMs);
    all.add(a.elapsedMs);
  }
  final measured = all.length >= minSamples;
  return PaceModel(
    {
      if (measured)
        for (final e in byUnit.entries)
          if (e.value.length >= minSamples) e.key: _median(e.value) / 1000,
    },
    measured ? _median(all) / 1000 : defaultSeconds,
    measured: measured,
  );
}

/// 1日ぶんの学習時間の見積もり。
class DayTime {
  const DayTime(this.date, this.questions, this.minutes);

  final DateTime date;
  final int questions;

  /// 見積もりの分（小数）。
  final double minutes;

  /// 5分きざみで切り上げた分（表示用）。
  int get roundedMinutes => minutes <= 0 ? 0 : ((minutes / 5).ceil() * 5);
}

/// 日ごとの計画から、学習時間を見積もる。重点枠は単元ごとの速さ、弱点枠と復習枠は全体の速さ。
/// [weakFactor] は弱点枠が通常より何倍かかるか（既定は同じ）。
List<DayTime> estimateDayTimes(
  Iterable<DayPlan> days,
  PaceModel pace, {
  double weakFactor = 1.0,
}) {
  return [
    for (final d in days)
      () {
        var sec = 0.0;
        var focusAssigned = 0;
        for (final e in d.focusByUnit.entries) {
          sec += e.value * pace.secondsFor(e.key);
          focusAssigned += e.value;
        }
        // 重点枠で単元に割り当たらなかった分（範囲が空など）は全体の速さで数える
        sec += (d.focus - focusAssigned).clamp(0, d.focus) * pace.overallSeconds;
        sec += d.weak * pace.overallSeconds * weakFactor;
        sec += d.review * pace.overallSeconds;
        return DayTime(d.date, d.total, sec / 60);
      }(),
  ];
}

/// 1日の上限（分）を超える日。
List<DayTime> daysOverBudget(Iterable<DayTime> days, double budgetMinutes) =>
    [for (final d in days) if (d.minutes > budgetMinutes) d];

/// [minutes] 分で解ける問題数（切り捨て）。[unitId] を渡すとその単元の速さで数える。
int questionsWithinBudget(double minutes, PaceModel pace, {String? unitId}) {
  if (minutes <= 0) return 0;
  final sec = unitId == null ? pace.overallSeconds : pace.secondsFor(unitId);
  return sec <= 0 ? 0 : (minutes * 60 / sec).floor();
}
