import '../models/models.dart';

/// ケアレスミスと見なした理由。
enum CarelessReason {
  /// その単元で、ふだん正解するときよりずっと速く答えて間違えた（読み飛ばし・早とちりの疑い）。
  tooFast,

  /// 間違えた直後に、同じ問題を正解し直した（分かっているのに取り違えた）。
  quickRetry,
}

/// 誤答1回の見立て。
class MistakeVerdict {
  const MistakeVerdict(this.attempt, this.reasons);

  final Attempt attempt;

  /// ケアレスミスの理由。空なら、理解不足の可能性が高い誤答。
  final Set<CarelessReason> reasons;

  bool get careless => reasons.isNotEmpty;
}

double? _median(List<int> xs) {
  if (xs.isEmpty) return null;
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}

/// 誤答を「ケアレスミスの疑い」と「理解不足の疑い」に分ける。あくまで目安（確定ではない）。
///
/// - [tooFast]: 所要時間が、その単元の正解時の中央値の [fastRatio] 倍未満。単元の正解が [minSamples] 件に
///   満たないときは全単元の正解で代用し、それでも足りなければ判定しない。所要時間 0（未計測）は対象外。
/// - [quickRetry]: 同じ問題の次の回答が [retryWindow] 以内の正解。
/// 結果は誤答だけを、回答の時刻順に返す。決まった入力なら同じ結果。
List<MistakeVerdict> classifyMistakes(
  Iterable<Attempt> attempts, {
  double fastRatio = 0.35,
  int minSamples = 5,
  Duration retryWindow = const Duration(minutes: 10),
}) {
  final sorted = [...attempts]..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));

  final byUnit = <String, List<int>>{};
  final all = <int>[];
  for (final a in sorted) {
    if (a.correct && a.elapsedMs > 0) {
      (byUnit[a.unitId] ??= []).add(a.elapsedMs);
      all.add(a.elapsedMs);
    }
  }
  double? baseline(String unitId) {
    final u = byUnit[unitId] ?? const <int>[];
    if (u.length >= minSamples) return _median(u);
    return all.length >= minSamples ? _median(all) : null;
  }

  // 同じ問題の「次の回答」を引けるようにする
  final nextOfQuestion = <Attempt, Attempt>{};
  final lastSeen = <String, Attempt>{};
  for (final a in sorted) {
    final prev = lastSeen[a.questionId];
    if (prev != null) nextOfQuestion[prev] = a;
    lastSeen[a.questionId] = a;
  }

  final out = <MistakeVerdict>[];
  for (final a in sorted) {
    if (a.correct) continue;
    final reasons = <CarelessReason>{};
    final base = baseline(a.unitId);
    if (base != null && a.elapsedMs > 0 && a.elapsedMs < base * fastRatio) {
      reasons.add(CarelessReason.tooFast);
    }
    final next = nextOfQuestion[a];
    if (next != null && next.correct && next.answeredAt.difference(a.answeredAt) <= retryWindow) {
      reasons.add(CarelessReason.quickRetry);
    }
    out.add(MistakeVerdict(a, reasons));
  }
  return out;
}
