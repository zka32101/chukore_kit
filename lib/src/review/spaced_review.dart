import '../models/models.dart';

/// 間隔反復の設定。箱（box）が上がるほど、次に出すまでの間隔が伸びる。
class ReviewConfig {
  const ReviewConfig({this.intervalDays = const [1, 3, 7, 14, 30]});

  /// 箱ごとの間隔（日）。最後の箱に着いたらそれ以上は伸びない。
  final List<int> intervalDays;

  int get maxBox => intervalDays.length - 1;
}

/// 問題1つの復習状態。
class ReviewState {
  const ReviewState({
    required this.questionId,
    required this.unitId,
    required this.box,
    required this.lapses,
    required this.lastAnsweredOn,
    required this.dueOn,
  });

  final String questionId;
  final String unitId;

  /// 0 = 直近で間違えた（または 1 回正解）。大きいほど定着している。
  final int box;

  /// 間違えた回数（定着した後に間違えた場合も数える）。
  final int lapses;
  final DateTime lastAnsweredOn;

  /// 次に出す日（日付だけ）。
  final DateTime dueOn;

  /// [today] 時点で何日遅れているか（期日前は負）。
  int overdueDays(DateTime today) => dateOnly(today).difference(dueOn).inDays;

  bool isDue(DateTime today) => overdueDays(today) >= 0;
}

/// 回答履歴から、問題ごとの復習日を作る（正解で箱が上がり間隔が伸び、不正解で箱 0 に戻って翌日）。
/// [testDate] を渡すと、復習日はテスト日を超えない（テストまでに必ず 1 回は当たる）。
/// 同じ入力なら同じ結果（乱数・現在時刻に依存しない）。
Map<String, ReviewState> buildReviewStates(
  Iterable<Attempt> attempts, {
  DateTime? testDate,
  ReviewConfig config = const ReviewConfig(),
}) {
  if (config.intervalDays.isEmpty) throw ArgumentError('intervalDays が空です');
  final sorted = [...attempts]..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
  final box = <String, int>{};
  final lapses = <String, int>{};
  final unit = <String, String>{};
  final last = <String, DateTime>{};
  for (final a in sorted) {
    final q = a.questionId;
    unit[q] = a.unitId;
    last[q] = a.answeredAt;
    if (a.correct) {
      final b = box[q];
      box[q] = b == null ? 0 : (b + 1 > config.maxBox ? config.maxBox : b + 1);
    } else {
      box[q] = 0;
      lapses[q] = (lapses[q] ?? 0) + 1;
    }
  }
  final limit = testDate == null ? null : dateOnly(testDate);
  return {
    for (final q in box.keys)
      q: () {
        final answeredOn = dateOnly(last[q]!);
        var due = answeredOn.add(Duration(days: config.intervalDays[box[q]!]));
        // テスト日を超えない。ただし最後に解いた日より前にはしない。
        if (limit != null && due.isAfter(limit)) {
          due = limit.isBefore(answeredOn) ? answeredOn : limit;
        }
        return ReviewState(
          questionId: q,
          unitId: unit[q]!,
          box: box[q]!,
          lapses: lapses[q] ?? 0,
          lastAnsweredOn: answeredOn,
          dueOn: due,
        );
      }(),
  };
}

/// [today] に復習する問題。遅れている順 → 箱が低い順 → 問題ID順。[limit] で件数を絞れる。
List<ReviewState> dueForReview(
  Map<String, ReviewState> states,
  DateTime today, {
  int? limit,
  Set<String>? unitIds,
}) {
  final due = [
    for (final s in states.values)
      if (s.isDue(today) && (unitIds == null || unitIds.contains(s.unitId))) s,
  ]..sort((a, b) {
      final c = b.overdueDays(today).compareTo(a.overdueDays(today));
      if (c != 0) return c;
      final d = a.box.compareTo(b.box);
      return d != 0 ? d : a.questionId.compareTo(b.questionId);
    });
  return limit == null || limit >= due.length ? due : due.sublist(0, limit);
}
