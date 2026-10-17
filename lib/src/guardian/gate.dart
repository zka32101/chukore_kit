import 'dart:math' as math;

import '../l10n/strings.dart';

/// 1〜9999 を漢数字にする（例: 482 → 四百八十二、110 → 百十）。
String toKanji(int n) => const JaStrings().gateNumberWords(n);

/// 保護者ゲートの問題。長押し(3秒)の後に表示し、数の読み上げ表記を算用数字で入力させる。
/// 読み上げ表記は言語ごと（日本語は漢数字、英語は英単語）。
/// 目的は誤操作の防止であり、同意の代わりではない。
class GateChallenge {
  const GateChallenge(this.value);

  static const holdDuration = Duration(seconds: 3);

  final int value;

  /// 日本語（漢数字）の読み上げ。
  String get prompt => const JaStrings().gateNumberWords(value);

  /// 指定した言語の読み上げ（例: en なら "four hundred eighty-two"）。
  String promptFor(ChukoreStrings strings) => strings.gateNumberWords(value);

  /// 全角数字・タイ数字（๐〜๙）・デーヴァナーガリー数字（०〜९）・前後の空白・桁区切り（, . 空白）を許容して判定する。
  bool verify(String input) {
    final normalized = input
        .trim()
        .replaceAllMapped(RegExp('[０-９]'), (m) => '${m[0]!.codeUnitAt(0) - 0xFF10}')
        .replaceAllMapped(RegExp('[๐-๙]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0E50}')
        .replaceAllMapped(RegExp('[०-९]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0966}')
        .replaceAll(RegExp(r'[\s,，.．\u00A0\u202F]'), '');
    return int.tryParse(normalized) == value;
  }

  /// 100〜999 の3桁（百の位が必ず入る）。[random] を渡すとテストで固定できる。
  factory GateChallenge.random([math.Random? random]) =>
      GateChallenge(100 + (random ?? math.Random.secure()).nextInt(900));
}
