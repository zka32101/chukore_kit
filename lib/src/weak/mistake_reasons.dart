import '../models/models.dart';

/// 誤答の理由の自己申告の集計。
class MistakeReasonSummary {
  const MistakeReasonSummary({required this.counts, required this.unreported});

  /// 理由ごとの誤答の数（0 の理由も含む）。
  final Map<LossReason, int> counts;

  /// 理由を答えなかった誤答の数。
  final int unreported;

  /// 申告のあった誤答の数。
  int get reported => counts.values.fold<int>(0, (s, n) => s + n);

  /// 誤答の総数。
  int get total => reported + unreported;

  /// いちばん多い理由（申告が無ければ null。同数なら [LossReason] の並び順で先のもの）。
  LossReason? get top {
    LossReason? best;
    for (final r in LossReason.values) {
      if (counts[r]! > 0 && (best == null || counts[r]! > counts[best]!)) best = r;
    }
    return best;
  }

  /// 申告のあった誤答のうち、[reason] の割合（申告が無ければ 0）。
  double shareOf(LossReason reason) => reported == 0 ? 0 : counts[reason]! / reported;
}

/// 誤答の理由の自己申告を数える。正解の回答は数えない。[unitId] で単元を、[since]（その日以降）で期間を絞れる。
/// 理由は答えなくてよいので、[MistakeReasonSummary.unreported] も一緒に返す
/// （申告の少なさから「うっかりが多い」などと決めつけないため、割合は申告のあった分で見る）。
MistakeReasonSummary summarizeMistakeReasons(
  Iterable<Attempt> attempts, {
  String? unitId,
  DateTime? since,
}) {
  final from = since == null ? null : dateOnly(since);
  final counts = {for (final r in LossReason.values) r: 0};
  var unreported = 0;
  for (final a in attempts) {
    if (a.correct) continue;
    if (unitId != null && a.unitId != unitId) continue;
    if (from != null && dateOnly(a.answeredAt).isBefore(from)) continue;
    final r = a.reason;
    if (r == null) {
      unreported++;
    } else {
      counts[r] = counts[r]! + 1;
    }
  }
  return MistakeReasonSummary(counts: counts, unreported: unreported);
}
