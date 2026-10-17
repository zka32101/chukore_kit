import '../models/models.dart';

/// 年輪の1か月分。[days] はその月に学習した日数。
class RingMonth {
  const RingMonth(this.year, this.month, this.days);

  final int year, month, days;

  /// `2026-10` の形（言語に依らない数字の表記。読み上げの文言に渡す）。
  String get label => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// その月の学習日の割合 0〜1（年輪の太さ）。
  double get ratio => days / daysInMonth;

  @override
  bool operator ==(Object other) =>
      other is RingMonth && other.year == year && other.month == month && other.days == days;

  @override
  int get hashCode => Object.hash(year, month, days);
}

/// G7 成長の年輪。毎日の学習が積み重なり、休んでも消えない。
class GrowthRings {
  const GrowthRings(this.months, this.totalDays);

  /// 古い月から順に、最初の学習月から今月まで切れ目なく並ぶ（学習しなかった月も細い輪として残る）。
  final List<RingMonth> months;

  /// これまでに学習した日数の合計。減らない。
  final int totalDays;

  /// 中身が同じなら等しい（画面が、同じ年輪を作り直されるたびに描き直さないため）。
  @override
  bool operator ==(Object other) {
    if (other is! GrowthRings || other.totalDays != totalDays || other.months.length != months.length) {
      return false;
    }
    for (var i = 0; i < months.length; i++) {
      if (other.months[i] != months[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(totalDays, Object.hashAll(months));
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
