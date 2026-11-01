import 'median.dart';

/// 五数要約（最小値・第 1 四分位数・中央値・第 3 四分位数・最大値）。箱ひげ図の元になる。
/// パッケージの中だけで使う（公開しない）。
class FiveNumber {
  const FiveNumber(this.min, this.q1, this.median, this.q3, this.max);

  final double min, q1, median, q3, max;

  /// 四分位範囲（q3 − q1）。
  double get iqr => q3 - q1;

  /// 範囲（max − min）。
  double get range => max - min;
}

/// 五数要約（日本の中学校の定義）。データを小さい順に並べ、**中央値でちょうど半分に分けて**（データが奇数個のときは中央値を
/// どちらにも入れない）、下の半分の中央値を第 1 四分位数、上の半分の中央値を第 3 四分位数とする。
/// データは 2 個以上（1 個だと半分が空になる）。足りなければ [ArgumentError]。
FiveNumber fiveNumberSummary(Iterable<num> xs) {
  final s = [for (final x in xs) x.toDouble()]..sort();
  if (s.length < 2) throw ArgumentError('五数要約にはデータが 2 個以上必要です');
  final h = s.length ~/ 2;
  return FiveNumber(s.first, median(s.sublist(0, h)), median(s), median(s.sublist(s.length - h)), s.last);
}
