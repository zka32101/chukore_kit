import 'planner.dart';
import '../util/median.dart';

/// これから来る「山場」（ほかの日より問題数が多い日）の予告。
class PeakPreview {
  const PeakPreview({required this.date, required this.daysAhead, required this.total, required this.typical});

  final DateTime date;

  /// 今日から数えた日数（明日 = 1）。
  final int daysAhead;

  /// その日の問題数と、ふだん（計画の中央値）の問題数。
  final int total, typical;
}

/// 計画 [days]（日付順）から、今日の後 [lookahead] 日以内にある最初の山場を返す（無ければ null）。
///
/// 山場 = その日の問題数が、ふだん（問題のある日の中央値）の [ratio] 倍以上で、かつ [minExtra] 問以上多い日。
/// 直前の追い込み（`lastMinute`）の日は、もともと詰めるための日なので予告しない。
/// 文言は `ChukoreStrings.peakAhead`（数字を含まない、責めない一文）。**不安をあおらないよう、
/// 近づいたときに 1 度だけ出す**のは呼び出し側（`decideNudge` と同様）。
PeakPreview? findPeakAhead(
  List<DayPlan> days, {
  required DateTime today,
  int lookahead = 3,
  double ratio = 1.5,
  int minExtra = 5,
}) {
  if (lookahead < 1) throw ArgumentError('lookahead must be positive');
  final base = DateTime(today.year, today.month, today.day);
  final totals = [for (final d in days) if (d.total > 0 && !d.lastMinute) d.total]..sort();
  if (totals.isEmpty) return null;
  final typical = median(totals).round();
  for (final d in days) {
    final ahead = DateTime(d.date.year, d.date.month, d.date.day).difference(base).inDays;
    if (ahead < 1 || ahead > lookahead || d.lastMinute) continue;
    if (d.total >= typical * ratio && d.total - typical >= minExtra) {
      return PeakPreview(date: d.date, daysAhead: ahead, total: d.total, typical: typical);
    }
  }
  return null;
}
