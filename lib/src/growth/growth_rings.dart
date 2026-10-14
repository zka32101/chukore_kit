import '../models/models.dart';

/// 年輪の1か月分。[days] はその月に学習した日数。
class RingMonth {
  const RingMonth(this.year, this.month, this.days);

  final int year, month, days;

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// その月の学習日の割合 0〜1（年輪の太さ）。
  double get ratio => days / daysInMonth;
}

/// G7 成長の年輪。毎日の学習が積み重なり、休んでも消えない。
class GrowthRings {
  const GrowthRings(this.months, this.totalDays);

  /// 古い月から順に、最初の学習月から今月まで切れ目なく並ぶ（学習しなかった月も細い輪として残る）。
  final List<RingMonth> months;

  /// これまでに学習した日数の合計。減らない。
  final int totalDays;
}

/// 学習した日の一覧から年輪を作る。同じ日は1日と数える。[now] を渡すと今月までの輪を作る。
GrowthRings buildGrowthRings(Iterable<DateTime> activeDays, {DateTime? now}) {
  final days = {for (final d in activeDays) dateOnly(d)};
  if (days.isEmpty) return const GrowthRings([], 0);

  final perMonth = <int, int>{}; // year*12 + (month-1) → 日数
  for (final d in days) {
    final key = d.year * 12 + d.month - 1;
    perMonth[key] = (perMonth[key] ?? 0) + 1;
  }
  final first = perMonth.keys.reduce((a, b) => a < b ? a : b);
  var last = perMonth.keys.reduce((a, b) => a > b ? a : b);
  if (now != null) {
    final n = now.year * 12 + now.month - 1;
    if (n > last) last = n;
  }
  return GrowthRings([
    for (var k = first; k <= last; k++) RingMonth(k ~/ 12, k % 12 + 1, perMonth[k] ?? 0),
  ], days.length);
}
