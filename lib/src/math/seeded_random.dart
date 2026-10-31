/// 種から決まった列を返す乱数（xorshift32）。同じ種なら、端末・Web・Dart の版が変わっても同じ列になる。
/// `dart:math` の `Random(seed)` は列が実装に依存するため使わない（問題 ID に結びつく変種の再現に必要）。
/// すべての演算を 32bit に収めてあるので、Web の整数でも同じ結果になる。
class SeededRandom {
  SeededRandom(int seed) : _s = _mask(seed ^ 0x9E3779B9) {
    if (_s == 0) _s = 1;
    for (var i = 0; i < 8; i++) {
      nextUint32(); // 連続した小さい種でも列が離れるようにならす
    }
  }

  int _s;

  static int _mask(int x) => x & 0xFFFFFFFF;

  /// 0 以上 2^32 未満の整数。
  int nextUint32() {
    var x = _s;
    x = _mask(x ^ (x << 13));
    x = x ^ (x >> 17);
    x = _mask(x ^ (x << 5));
    _s = x == 0 ? 1 : x;
    return _s;
  }

  /// [lo] 以上 [hi] 以下の整数。
  int nextInt(int lo, int hi) {
    if (hi < lo) throw ArgumentError('hi < lo: $lo..$hi');
    return lo + nextUint32() % (hi - lo + 1);
  }

  /// 候補から 1 つ。
  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('候補が空です');
    return items[nextUint32() % items.length];
  }
}
