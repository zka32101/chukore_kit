/// 対応づけ問題（`match`）の 1 組。左の項目 ID と右の項目 ID。
class MatchPair {
  const MatchPair(this.left, this.right);

  final String left, right;

  /// 答えの書き方 `左:右`。
  @override
  String toString() => '$left:$right';

  @override
  bool operator ==(Object other) => other is MatchPair && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}

final _pairSeparators = RegExp(r'[;；\n\r]');

/// `match` 問題の正解の書き方: 組を `;` で区切り、各組は `左ID:右ID`（例 `a1:b2;a2:b1;a3:b3`）。
/// ID に `:` `;` 空白だけは使えない。書き間違い（コロンが 1 つでない・空の ID・組が無い）は null。
List<MatchPair>? parseMatchAnswer(String answer) {
  final out = <MatchPair>[];
  for (final item in answer.split(';')) {
    final parts = item.trim().split(':');
    if (parts.length != 2) return null;
    final l = parts[0].trim(), r = parts[1].trim();
    if (l.isEmpty || r.isEmpty) return null;
    out.add(MatchPair(l, r));
  }
  return out; // split は 1 項目以上返す。不正な項目は上で null にしている
}

/// `match` 問題の入力を組に分ける。区切りは `;`・`；`・改行。組の中の区切りは `:`・`：`。
/// 読めない項目（コロンが 1 つでない・片方が空）は [MatchPair] にならず、`null` として並ぶ位置に残る（誤りの組として数える）。
List<MatchPair?> parseMatchInput(String input) => [
  for (final raw in input.split(_pairSeparators))
    if (raw.trim().isNotEmpty) _inputPair(raw.trim()),
];

MatchPair? _inputPair(String raw) {
  final parts = raw.split(RegExp(r'[:：]'));
  if (parts.length != 2) return null;
  final l = parts[0].trim(), r = parts[1].trim();
  return l.isEmpty || r.isEmpty ? null : MatchPair(l, r);
}
