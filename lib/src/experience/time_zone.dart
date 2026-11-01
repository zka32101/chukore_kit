/// 時差の計算（経度 15 度で 1 時間。東へ行くほど時刻は進む）。時差ダイヤルの表示と問題の正解づくりに使う。
/// 標準時の経度（日本は東経 135 度）で考える。サマータイムは扱わない。
library;

/// 経度 [lon]（東経は正、西経は負）の標準時の、経度 0 度との時差（時間）。15 度ごとに 1 時間（最も近い整数）。
int timeOffsetHours(double lon) {
  if (lon.isNaN || lon < -180 || lon > 180) throw ArgumentError('経度は -180〜180');
  return (lon / 15).round();
}

/// ある地点の時刻 [hour]（0 以上 24 未満の整数の時）に対する、別の地点の時刻。
class LocalTime {
  const LocalTime(this.hour, this.dayOffset);

  /// 0〜23 時。
  final int hour;

  /// 基準の地点の日付からの日数のずれ（-1: 前日、0: 同じ日、1: 翌日）。
  final int dayOffset;
}

/// 経度 [fromLon] で [hour] 時のとき、経度 [toLon] は何時か（日付のずれつき）。
LocalTime localTimeAt({required int hour, required double fromLon, required double toLon}) {
  if (hour < 0 || hour > 23) throw ArgumentError('hour は 0〜23');
  final total = hour + timeOffsetHours(toLon) - timeOffsetHours(fromLon);
  final day = (total / 24).floor();
  return LocalTime(total - day * 24, day);
}
