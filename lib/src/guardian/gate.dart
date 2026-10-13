import 'dart:math' as math;

const _digits = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/// 1〜9999 を漢数字にする（例: 482 → 四百八十二、110 → 百十）。
String toKanji(int n) {
  if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
  final b = StringBuffer();
  void unit(int d, String u) {
    if (d == 0) return;
    if (d != 1) b.write(_digits[d]);
    b.write(u);
  }

  unit(n ~/ 1000, '千');
  unit(n % 1000 ~/ 100, '百');
  unit(n % 100 ~/ 10, '十');
  b.write(_digits[n % 10]);
  return b.toString();
}

/// 保護者ゲートの問題。長押し(3秒)の後に表示し、漢数字を算用数字で入力させる。
/// 目的は誤操作の防止であり、同意の代わりではない。
class GateChallenge {
  const GateChallenge(this.value);

  static const holdDuration = Duration(seconds: 3);

  final int value;

  String get prompt => toKanji(value);

  /// 全角数字・前後の空白を許容して判定する。
  bool verify(String input) {
    final normalized = input.trim().replaceAllMapped(
        RegExp('[０-９]'), (m) => '${m[0]!.codeUnitAt(0) - 0xFF10}');
    return int.tryParse(normalized) == value;
  }

  /// 100〜999 の3桁（百の位が必ず入る）。[random] を渡すとテストで固定できる。
  factory GateChallenge.random([math.Random? random]) =>
      GateChallenge(100 + (random ?? math.Random.secure()).nextInt(900));
}
