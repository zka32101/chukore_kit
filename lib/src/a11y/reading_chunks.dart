/// 長い文章（解説・問題文）を、読みやすい長さのまとまりに分ける。
///
/// 文末（`。！？!?.` と、改行）で区切り、[maxChars] 文字を超えないようにまとめる。
/// 1 文が [maxChars] を超えるときは、読点（`、,，;；`）で、それも無ければ文字数で切る。
/// 空（改行だけ）のまとまりは作らない。
/// 「1 画面に出す量を減らす」「読み上げを区切る」「ゆっくり読みたい子向けに 1 文ずつ見せる」ための材料。
List<String> splitForReading(String text, {int maxChars = 60}) {
  if (maxChars < 1) throw ArgumentError('maxChars must be positive');
  final sentences = <String>[];
  final buf = StringBuffer();
  const enders = '。！？!?.\n';
  final runes = text.trim().runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    buf.write(ch);
    if (!enders.contains(ch)) continue;
    // 英語のピリオドは、直後が空白（か文末）のときだけ文末
    final next = i + 1 < runes.length ? String.fromCharCode(runes[i + 1]) : '';
    if (ch == '.' && next != '' && next.trim().isNotEmpty) continue;
    // 閉じかっこ・連続した句読点は同じ文に含める
    while (i + 1 < runes.length && '」』）)”"!?！？。'.contains(String.fromCharCode(runes[i + 1]))) {
      buf.write(String.fromCharCode(runes[++i]));
    }
    // 文末のあとの空白は、その文につける（次のまとまりの先頭に空白が来ないように）
    while (i + 1 < runes.length && ' \t　'.contains(String.fromCharCode(runes[i + 1]))) {
      buf.write(String.fromCharCode(runes[++i]));
    }
    sentences.add(buf.toString());
    buf.clear();
  }
  if (buf.isNotEmpty) sentences.add(buf.toString());

  final pieces = <String>[];
  for (final s in sentences) {
    pieces.addAll(_cut(s, maxChars));
  }
  final out = <String>[];
  var cur = '';
  for (final p in pieces) {
    if (cur.isNotEmpty && cur.runes.length + p.runes.length > maxChars) {
      out.add(cur);
      cur = '';
    }
    cur += p;
  }
  if (cur.isNotEmpty) out.add(cur);
  return [for (final o in out) if (o.trim().isNotEmpty) o];
}

List<String> _cut(String s, int max) {
  final r = s.runes.toList();
  if (r.length <= max) return [s];
  const commas = '、,，;；';
  final out = <String>[];
  var start = 0;
  while (r.length - start > max) {
    var cut = -1;
    for (var i = start + max - 1; i > start; i--) {
      if (commas.contains(String.fromCharCode(r[i]))) {
        cut = i + 1;
        break;
      }
    }
    if (cut == -1) cut = start + max;
    out.add(String.fromCharCodes(r.sublist(start, cut)));
    start = cut;
  }
  if (start < r.length) out.add(String.fromCharCodes(r.sublist(start)));
  return out;
}
