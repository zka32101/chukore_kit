/// 中央値。偶数個なら真ん中 2 つの平均。空なら [ArgumentError]。
/// パッケージの中だけで使う（公開しない）。整数にしたいときは `.round()`（四捨五入）。
double median(Iterable<num> xs) {
  final s = xs.toList()..sort();
  if (s.isEmpty) throw ArgumentError('median of an empty list');
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}
