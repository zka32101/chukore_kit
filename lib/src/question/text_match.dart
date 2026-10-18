import '../l10n/digits.dart';

/// 記述の答えの比較用に表記ゆれをそろえる。
///
/// - 各地の数字・全角の英数記号を半角にする、英字は小文字にする
/// - 空白の並びを 1 つにして前後を除く
/// - 文末の句読点（。．.、,!！?？）を除く
/// - 引用符・ハイフン類の違いをそろえる
/// - [foldKana] が真なら、カタカナをひらがなにそろえる（カタカナで書く指定の問題では偽にする）
String normalizeText(String s, {bool foldKana = true}) {
  final buf = StringBuffer();
  for (final r in normalizeDigits(s).runes) {
    var c = r;
    if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // 全角の ASCII 記号・英数
    if (c == 0x3000) c = 0x20;
    if (foldKana && c >= 0x30A1 && c <= 0x30F6) c -= 0x60; // カタカナ → ひらがな
    if (c == 0x2018 || c == 0x2019 || c == 0x2032) c = 0x27; // ’ ‘ ′ → '
    if (c == 0x201C || c == 0x201D) c = 0x22; // “ ” → "
    if (c == 0x2010 || c == 0x2011 || c == 0x2212 || c == 0x2013) c = 0x2D; // ‐ ‑ − – → -
    buf.writeCharCode(c);
  }
  return buf
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[。.、,!?]+$'), '')
      .trim();
}

/// `text` 問題の正解の書き方: 別解を `|` で区切る（例: `東京|とうきょう|Tokyo`）。
List<String> textAlternatives(String answer) => [for (final a in answer.split('|')) a.trim()];

/// `multi` 問題の正解の書き方: 答える項目を `;` で区切り、各項目の別解を `|` で区切る
/// （例: `織田信長|のぶなが;豊臣秀吉|ひでよし;徳川家康`）。
List<List<String>> multiItems(String answer) => [for (final item in answer.split(';')) textAlternatives(item)];

/// `multi` 問題の入力を項目に分ける。区切りは `;`・`；`・`、`・`,`・`，`・改行。
List<String> splitMultiInput(String input) => [
      for (final p in input.split(RegExp(r'[;；、,，\n\r]')))
        if (p.trim().isNotEmpty) p.trim(),
    ];
