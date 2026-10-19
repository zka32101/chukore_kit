import '../l10n/strings.dart';
import '../models/models.dart';
import '../planner/peak_preview.dart';
import '../planner/planner.dart';
import '../practice/eve_guard.dart';
import '../review/spaced_review.dart';
import 'break_suggestion.dart';

/// 「今日」の画面の見出し。優先は 休憩 > テスト当日 > 前日 > 山場の予告 > 今日はここまで > 復習の期限 > はじめよう。
enum TodayHeadline {
  /// 学習の途中で、休憩を勧める。
  breakNow,

  /// テスト当日（落ち着く一言）。
  testDay,

  /// テスト前日（新しいことを増やさない一言）。
  eve,

  /// 数日先に問題の多い日がある。
  peakAhead,

  /// 今日はもう学習した。
  done,

  /// 復習の期限が来た問題がある。
  reviewDue,

  /// これから始める。
  start,
}

/// 「今日」の画面に出す内容を 1 つにまとめたもの。休憩・前日/当日・山場の予告・復習の期限・学習済みかを、
/// 画面が十数個の関数を自分で組み合わせなくて済むように、1 回で求める。
class TodayCard {
  const TodayCard({
    required this.headline,
    required this.practicedToday,
    required this.dueReviews,
    required this.eve,
    required this.peak,
    required this.takeBreak,
  });

  final TodayHeadline headline;
  final bool practicedToday;

  /// 復習の期限が来た問題の数。
  final int dueReviews;
  final EveNotice eve;
  final PeakPreview? peak;
  final BreakSuggestion? takeBreak;

  /// 見出しに添える一言（責めない短い文。数字を含まない）。`done` と `start` は画面側の文言を使うので null。
  String? message(ChukoreStrings strings) => switch (headline) {
        TodayHeadline.breakNow => takeBreak!.text(strings),
        TodayHeadline.testDay => strings.testDayNotice,
        TodayHeadline.eve => strings.eveNotice,
        TodayHeadline.peakAhead => strings.peakAhead,
        TodayHeadline.reviewDue => strings.nudgeReview,
        TodayHeadline.done || TodayHeadline.start => null,
      };

  /// 前日・当日の出題制限をかけるか（`guardLastDays`）。
  bool get guardsPractice => eve != EveNotice.none;
}

/// 「今日」の画面の内容を作る。同じ入力なら同じ結果。
///
/// - [plan]: 計画の日ごとの並び（`buildPlan` の結果）。今日の分から前日/当日と山場の予告を求める。
///   今日の分が無ければ、[testDate] との差で前日/当日を求める
/// - [attempts]: 回答履歴。今日学習したか・休憩の提案・復習の期限の数に使う
/// - [now]: 現在時刻。日付はローカル暦日
/// - 休憩は途中の学習にだけ意味があるので、`suggestBreak` の結果をそのまま使う
TodayCard buildTodayCard({
  required DateTime now,
  required Iterable<Attempt> attempts,
  List<DayPlan> plan = const [],
  DateTime? testDate,
  DateTime? lastBreakSuggestedAt,
  BreakConfig breakConfig = const BreakConfig(),
  ReviewConfig reviewConfig = const ReviewConfig(),
}) {
  final today = dateOnly(now);
  final all = attempts.toList();
  final practicedToday = all.any((a) => a.mode != 'card' && dateOnly(a.answeredAt) == today);

  final todayPlan = plan.where((d) => dateOnly(d.date) == today).firstOrNull;
  final daysLeft = todayPlan?.daysLeft ?? (testDate == null ? null : dateOnly(testDate).difference(today).inDays);
  final eve = daysLeft == null ? EveNotice.none : eveNoticeOf(daysLeft);

  final peak = findPeakAhead(plan, today: today);
  final takeBreak = suggestBreak(all, now: now, lastSuggestedAt: lastBreakSuggestedAt, config: breakConfig);
  final due = dueForReview(buildReviewStates(all, testDate: testDate, config: reviewConfig), today).length;

  final TodayHeadline headline;
  if (takeBreak != null) {
    headline = TodayHeadline.breakNow;
  } else if (eve == EveNotice.testDay) {
    headline = TodayHeadline.testDay;
  } else if (eve == EveNotice.eve) {
    headline = TodayHeadline.eve;
  } else if (peak != null) {
    headline = TodayHeadline.peakAhead;
  } else if (practicedToday) {
    headline = TodayHeadline.done;
  } else if (due > 0) {
    headline = TodayHeadline.reviewDue;
  } else {
    headline = TodayHeadline.start;
  }
  return TodayCard(headline: headline, practicedToday: practicedToday, dueReviews: due, eve: eve, peak: peak, takeBreak: takeBreak);
}
