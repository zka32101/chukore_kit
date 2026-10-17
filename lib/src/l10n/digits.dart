/// 各地の数字（全角・タイ・デーヴァナーガリー・アラビア・ペルシア）を ASCII の数字にそろえる。
/// アラビア語の小数点（٫）は `.`、桁区切り（٬）と読点（،）は `,` にする。入力の正規化に使う。
String normalizeDigits(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    final c = switch (r) {
      >= 0xFF10 && <= 0xFF19 => r - 0xFF10, // ０-９
      >= 0x0E50 && <= 0x0E59 => r - 0x0E50, // ๐-๙
      >= 0x0966 && <= 0x096F => r - 0x0966, // ०-९
      >= 0x0660 && <= 0x0669 => r - 0x0660, // ٠-٩
      >= 0x06F0 && <= 0x06F9 => r - 0x06F0, // ۰-۹
      _ => -1,
    };
    if (c >= 0) {
      b.write(c);
    } else if (r == 0x066B) {
      b.write('.');
    } else if (r == 0x066C || r == 0x060C) {
      b.write(',');
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}
