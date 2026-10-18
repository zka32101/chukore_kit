import '../models/models.dart';

/// ヒントの使い方の集計。「自力で解けた」と「ヒントを使って解けた」を分けて見る。
class HintUsage {
  const HintUsage({
    required this.correct,
    required this.correctWithHints,
    required this.wrong,
    required this.wrongWithHints,
    required this.hintsShown,
  });

  /// 正解の数と、そのうちヒントを使った数。
  final int correct, correctWithHints;

  /// 誤答の数と、そのうちヒントを使った数。
  final int wrong, wrongWithHints;

  /// 見たヒントの延べ数。
  final int hintsShown;

  int get total => correct + wrong;

  /// 正解のうち、ヒントなしで（自力で）解けた割合（正解が 1 つも無ければ null）。
  double? get independentRate => correct == 0 ? null : (correct - correctWithHints) / correct;

  /// 回答のうちヒントを使った割合（回答が無ければ null）。
  double? get hintRate => total == 0 ? null : (correctWithHints + wrongWithHints) / total;
}

/// ヒントの使い方を数える。[unitId] で単元を、[since]（その日以降）で期間を、[mode] で出題の種類を絞れる。
/// 模試（`mock`）ではヒントを出さないので、ふつうは `mode: 'practice'` で見る。
HintUsage summarizeHintUsage(
  Iterable<Attempt> attempts, {
  String? unitId,
  DateTime? since,
  String? mode,
}) {
  final from = since == null ? null : dateOnly(since);
  var correct = 0, correctWith = 0, wrong = 0, wrongWith = 0, shown = 0;
  for (final a in attempts) {
    if (unitId != null && a.unitId != unitId) continue;
    if (mode != null && a.mode != mode) continue;
    if (from != null && dateOnly(a.answeredAt).isBefore(from)) continue;
    shown += a.hintsUsed;
    if (a.correct) {
      correct++;
      if (a.hintsUsed > 0) correctWith++;
    } else {
      wrong++;
      if (a.hintsUsed > 0) wrongWith++;
    }
  }
  return HintUsage(
    correct: correct,
    correctWithHints: correctWith,
    wrong: wrong,
    wrongWithHints: wrongWith,
    hintsShown: shown,
  );
}
