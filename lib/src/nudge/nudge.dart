import '../l10n/strings.dart';
import '../models/models.dart';

/// 通知の種類。優先は [testSoon] > [review] > [streak]。
enum NudgeKind {
  /// テストが近い（今日の分をやろう）。
  testSoon,

  /// 復習の期限が来た問題がある。
  review,

  /// 連続記録が今日途切れそう。
  streak,
}

/// 通知を出す判断。文言は `ChukoreStrings.nudgeTestSoon` / `nudgeReview` / `nudgeStreak`
/// （数字を含まない短い文）。日数や件数は、ここの値を使って呼び出し側が添える。
class NudgeDecision {
  const NudgeDecision(this.kind, {this.daysToTest, this.dueReviews, this.streakDays});

  final NudgeKind kind;
  final int? daysToTest;
  final int? dueReviews;
  final int? streakDays;
}

/// 通知の方針。値は仮決定（ソフトローンチで検証）。
class NudgeSettings {
  const NudgeSettings({
    this.testSoonDays = 7,
    this.dailyWithinDays = 3,
    this.minDueReviews = 3,
    this.minStreak = 3,
    this.minGapDays = 2,
    this.giveUpAfterDays = 14,
  });

  /// テストまでこの日数以内になったら [NudgeKind.testSoon] の対象。
  final int testSoonDays;

  /// テストまでこの日数以内は、間隔を空けずに毎日出してよい。
  final int dailyWithinDays;

  /// 復習の通知を出す、期限が来た問題の最少数。
  final int minDueReviews;

  /// 連続記録の通知を出す、連続日数の最少。
  final int minStreak;

  /// 前回の通知からこの日数は空ける（1 日おき）。うるさくしない。
  final int minGapDays;

  /// 最後に学習してからこの日数を超えたら、テストが近い場合を除いて出さない。
  final int giveUpAfterDays;
}

/// 今日、通知を出すか。出すなら何を出すか（出さないなら null）。1 日 1 件まで。
///
/// 出さない場合:
/// - 今日すでに学習した／今日が忙しい日・お休み（[busyDays]）／テスト当日（過ぎたテストは無視する）
/// - 前回の通知から [NudgeSettings.minGapDays] 日未満（テストまで [NudgeSettings.dailyWithinDays] 日以内を除く）
/// - 長く離れている（[NudgeSettings.giveUpAfterDays] 超。テストが近い場合を除く）。しつこく促さない
/// - 一度も学習していない人には、テストが近いとき以外は出さない
/// - 連続記録がすでに途切れているときは、連続記録の通知を出さない（責める形にしない）
///
/// 日付はローカル暦日。通知を出す時刻・OS の許可・13歳未満への通知の可否（[AgePolicy] などで決める）は、
/// アプリ側の責務。
NudgeDecision? decideNudge({
  required DateTime today,
  required DateTime? lastPracticedOn,
  int streakDays = 0,
  DateTime? testDate,
  int dueReviews = 0,
  DateTime? lastNudgedOn,
  Iterable<BusyDay> busyDays = const [],
  NudgeSettings settings = const NudgeSettings(),
}) {
  final day = dateOnly(today);
  final last = lastPracticedOn == null ? null : dateOnly(lastPracticedOn);
  if (last != null && !last.isBefore(day)) return null; // 今日すでに学習した

  if (busyDays.any((b) => dateOnly(b.date) == day)) return null; // 忙しい日・お休み

  var daysToTest = testDate == null ? null : dateOnly(testDate).difference(day).inDays;
  if (daysToTest == 0) return null; // テスト当日は通知しない（当日チェックの画面がある）
  if (daysToTest != null && daysToTest < 0) daysToTest = null; // 過ぎたテストは無視する

  final testNear = daysToTest != null && daysToTest <= settings.testSoonDays;
  final daily = daysToTest != null && daysToTest <= settings.dailyWithinDays;

  if (!daily && lastNudgedOn != null && day.difference(dateOnly(lastNudgedOn)).inDays < settings.minGapDays) {
    return null;
  }
  if (last != null && day.difference(last).inDays > settings.giveUpAfterDays && !testNear) return null;

  if (testNear) return NudgeDecision(NudgeKind.testSoon, daysToTest: daysToTest);
  if (last == null) return null; // 一度も学習していない人には、テストが近いとき以外は出さない
  if (dueReviews >= settings.minDueReviews) return NudgeDecision(NudgeKind.review, dueReviews: dueReviews);
  // 連続記録は、昨日学習していて今日まだのときだけ「つなげよう」。すでに途切れていたら出さない
  final streakAlive = day.difference(last).inDays == 1;
  if (streakAlive && streakDays >= settings.minStreak) {
    return NudgeDecision(NudgeKind.streak, streakDays: streakDays);
  }
  return null;
}

/// [NudgeKind] に合う文言。
String nudgeText(NudgeKind kind, ChukoreStrings s) => switch (kind) {
      NudgeKind.testSoon => s.nudgeTestSoon,
      NudgeKind.review => s.nudgeReview,
      NudgeKind.streak => s.nudgeStreak,
    };
