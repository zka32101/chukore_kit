import '../models/models.dart';
import '../util/median.dart';

/// ケアレスミスと見なした理由。
enum CarelessReason {
  /// その単元で、ふだん正解するときよりずっと速く答えて間違えた（読み飛ばし・早とちりの疑い）。
  tooFast,

  /// 間違えた直後に、同じ問題を正解し直した（分かっているのに取り違えた）。
  quickRetry,

  /// 本人が「うっかり」と申告した（`Attempt.reason` が `LossReason.careless`）。
  selfReported,

  /// 本人が「時間が足りなかった」と申告した。知識の不足ではないので、誤解としては数えない。
  timeShort,
}

/// 誤答1回の見立て。
class MistakeVerdict {
  const MistakeVerdict(this.attempt, this.reasons);

  final Attempt attempt;

  /// ケアレスミスの理由。空なら、理解不足の可能性が高い誤答。
  final Set<CarelessReason> reasons;

  bool get careless => reasons.isNotEmpty;
}

/// 誤答を「ケアレスミスの疑い」と「理解不足の疑い」に分ける。あくまで目安（確定ではない）。
///
/// **本人の申告（`Attempt.reason`）があれば、推定より優先する。**
/// 「うっかり」「時間が足りなかった」なら知識の不足ではない誤答、「わからなかった」「忘れていた」なら
/// 速く答えた・すぐ正解し直したとしても理解不足の側（推定の理由は付けない）。申告が無い誤答だけ、下の推定で見立てる。
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
  // 単元ごとの中央値は、誤答のたびに求めると履歴の件数の 2 乗に比例して遅くなる（10 万件で十数秒）ので、1 度だけ求める
  final overall = all.length >= minSamples && all.isNotEmpty ? median(all) : null;
  final baselines = <String, double?>{};
  double? baseline(String unitId) => baselines.putIfAbsent(unitId, () {
        final u = byUnit[unitId] ?? const <int>[];
        if (u.length >= minSamples) return u.isEmpty ? null : median(u);
        return overall;
      });

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
    final said = a.reason;
    if (said != null) {
      // 本人の申告を優先する
      switch (said) {
        case LossReason.careless:
          reasons.add(CarelessReason.selfReported);
        case LossReason.timeShort:
          reasons.add(CarelessReason.timeShort);
        case LossReason.dontKnow || LossReason.forgot:
          break;
      }
      out.add(MistakeVerdict(a, reasons));
      continue;
    }
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
