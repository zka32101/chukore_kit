import '../models/models.dart';
import '../review/spaced_review.dart';
import 'difficulty_calibration.dart' show wilsonInterval;

/// 箱ごとの調整の結論。
enum IntervalAction {
  /// 回答が足りず判断しない。
  insufficient,

  /// 今の間隔のまま。
  keep,

  /// 忘れている（思い出せない）ことが多いので、間隔を短くする。
  shorten,

  /// ほぼ確実に思い出せているので、間隔を長くする。
  lengthen,
}

/// 箱 1 つの、復習したときの正答率（思い出せた割合）。
class BoxRetention {
  const BoxRetention({
    required this.box,
    required this.attempts,
    required this.retention,
    required this.low,
    required this.high,
    required this.action,
    required this.oldDays,
    required this.newDays,
  });

  final int box;

  /// 数えた回答の数と、そのうち正解の割合、95% 信頼区間（Wilson）。
  final int attempts;
  final double retention;
  final double low, high;
  final IntervalAction action;
  final int oldDays, newDays;
}

class ReviewTuning {
  const ReviewTuning({required this.config, required this.boxes});

  /// 調整後の設定。変更が無ければ元と同じ間隔。
  final ReviewConfig config;

  /// 箱 1 以降の結果（箱 0 の「間違えた翌日」は固定）。
  final List<BoxRetention> boxes;

  bool get changed => boxes.any((b) => b.oldDays != b.newDays);
}

/// 復習したときの正答率から、箱ごとの間隔を**1 段だけ**調整する提案を作る。
///
/// 数えるのは、箱 1 以降の問題を、期日の日以降〜期日の [maxLateRatio] 倍までの間に復習した [mode] の回答
/// （期日前はまだ忘れていないので、遅れすぎは忘れて当然なので、数えない）。ヒントを使った回答は数えない。
/// 判断は信頼区間で行う（回答が [minAttempts] 件に満たない箱は判断しない）:
/// - 区間の上端が [shortenBelow] 未満 → 忘れすぎ。間隔を 25% 短くする
/// - 区間の下端が [lengthenAbove] より上 → 余裕がある。間隔を 25% 長くする
/// - 間隔は箱が上がるほど必ず長く保つ（直前の箱より 1 日以上長い）。そのため、判断しない箱の間隔も押し上げられることがある
///
/// **端末 1 台の履歴では箱ごとの回答が少ない**ので、匿名で集めた束か、長く使った人の履歴で使う想定。
/// 結果を勝手に反映せず、`config` を設定に渡すかどうかはアプリが決める（子どもごとに変えるか全体で変えるかも）。
/// 同じ入力なら同じ結果。
ReviewTuning tuneReviewIntervals(
  Iterable<Attempt> attempts, {
  ReviewConfig config = const ReviewConfig(),
  int minAttempts = 30,
  double shortenBelow = 0.8,
  double lengthenAbove = 0.9,
  double maxLateRatio = 1.5,
  String mode = 'practice',
}) {
  if (config.intervalDays.isEmpty) throw ArgumentError('intervalDays が空です');
  if (minAttempts < 1) throw ArgumentError('minAttempts must be positive');
  final days = config.intervalDays;
  final byQ = <String, List<Attempt>>{};
  for (final a in attempts) {
    byQ.putIfAbsent(a.questionId, () => []).add(a);
  }
  final right = List<int>.filled(days.length, 0);
  final total = List<int>.filled(days.length, 0);
  for (final list in byQ.values) {
    list.sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
    int? box;
    DateTime? last;
    for (final a in list) {
      final day = dateOnly(a.answeredAt);
      if (box != null && a.mode == mode && a.hintsUsed == 0) {
        final gap = day.difference(last!).inDays;
        final due = days[box];
        if (gap >= due && gap <= due * maxLateRatio) {
          total[box]++;
          if (a.correct) right[box]++;
        }
      }
      // 箱の動かし方は buildReviewStates と同じ
      if (a.correct) {
        if (a.confident == false || a.hintsUsed > 0) {
          box = box ?? 0;
        } else {
          box = box == null ? 0 : (box + 1 > config.maxBox ? config.maxBox : box + 1);
        }
      } else {
        box = 0;
      }
      last = day;
    }
  }

  final result = <BoxRetention>[];
  final newDays = [...days];
  for (var b = 1; b < days.length; b++) {
    final n = total[b];
    final p = n == 0 ? 0.0 : right[b] / n;
    final (low, high) = n == 0 ? (0.0, 1.0) : wilsonInterval(p, n, 1.96);
    var action = IntervalAction.insufficient;
    var d = days[b];
    if (n >= minAttempts) {
      if (high < shortenBelow) {
        action = IntervalAction.shorten;
        d = (days[b] * 0.75).round();
      } else if (low > lengthenAbove) {
        action = IntervalAction.lengthen;
        d = (days[b] * 1.25).round();
      } else {
        action = IntervalAction.keep;
      }
    }
    // 前の箱より必ず長く、1 日以上
    final floor = newDays[b - 1] + 1;
    if (d < floor) d = floor;
    newDays[b] = d;
    result.add(BoxRetention(
      box: b,
      attempts: n,
      retention: p,
      low: low,
      high: high,
      action: action,
      oldDays: days[b],
      newDays: d,
    ));
  }
  return ReviewTuning(config: ReviewConfig(intervalDays: newDays), boxes: result);
}
