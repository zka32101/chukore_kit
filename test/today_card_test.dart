import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 20, 18, 0);
final today = DateTime(2026, 10, 20);

Attempt at(String q, DateTime t, {bool ok = true, String mode = 'practice', int ms = 5000}) =>
    Attempt(questionId: q, unitId: 'u', correct: ok, answeredAt: t, elapsedMs: ms, mode: mode);

/// 今日の計画から数えて [totals]（先頭が今日）。テストは最後の日。
List<DayPlan> plan(List<int> totals) => [
      for (var i = 0; i < totals.length; i++)
        DayPlan(
          date: today.add(Duration(days: i)),
          daysLeft: totals.length - 1 - i,
          total: totals[i],
          focus: totals[i],
          weak: 0,
          review: 0,
          focusByUnit: const {},
          lastMinute: false,
        ),
    ];

// テストまで遠く、山場も無い計画
List<DayPlan> calm() => plan(List.filled(12, 10));

/// 3 時間前に 1 件だけ解いた（今日学習済み。休憩は勧めない）
List<Attempt> practicedEarlier() => [at('q1', DateTime(2026, 10, 20, 10))];

/// 5 分前までに 4 問続けて間違えた（休憩を勧める）
List<Attempt> mistakeStreak() => [for (var i = 0; i < 4; i++) at('m$i', now.subtract(Duration(minutes: 8 - i)), ok: false)];

TodayCard card(List<Attempt> a, {List<DayPlan>? p, DateTime? testDate}) =>
    buildTodayCard(now: now, attempts: a, plan: p ?? calm(), testDate: testDate);

void main() {
  group('見出しの選び方', () {
    test('何も無ければ「はじめよう」。学習済みなら「今日はここまで」', () {
      expect(card(const []).headline, TodayHeadline.start);
      expect(card(practicedEarlier()).headline, TodayHeadline.done);
      expect(card(practicedEarlier()).practicedToday, isTrue);
    });

    test('復習の期限が来た問題があれば reviewDue（学習済みでなければ）。件数も返す', () {
      final a = [at('r1', DateTime(2026, 10, 18, 10), ok: false), at('r2', DateTime(2026, 10, 18, 10), ok: false)];
      final c = card(a);
      expect(c.headline, TodayHeadline.reviewDue);
      expect(c.dueReviews, 2);
      expect(card([...a, ...practicedEarlier()]).headline, TodayHeadline.done, reason: '学習済みなら、これ以上は勧めない');
    });

    test('暗記カードだけの日は「学習した」に数えない', () {
      expect(card([at('c1', DateTime(2026, 10, 20, 10), mode: 'card')]).practicedToday, isFalse);
    });

    test('山場が近ければ peakAhead（学習済みでも出す）', () {
      final p = plan([10, 10, 10, 30, 10, 10, 10, 10, 10, 10, 10, 10]);
      expect(card(const [], p: p).headline, TodayHeadline.peakAhead);
      expect(card(practicedEarlier(), p: p).headline, TodayHeadline.peakAhead);
      expect(card(const [], p: p).peak!.daysAhead, 3);
    });

    test('前日・当日は eve / testDay。山場や復習より優先', () {
      final eve = plan([10, 40]); // 今日が前日
      final c = card([at('r1', DateTime(2026, 10, 18), ok: false)], p: eve);
      expect(c.headline, TodayHeadline.eve);
      expect(c.eve, EveNotice.eve);
      expect(c.guardsPractice, isTrue);
      final day = plan([10]); // 今日が当日
      expect(card(const [], p: day).headline, TodayHeadline.testDay);
      expect(card(const [], p: day).guardsPractice, isTrue);
      expect(card(const []).guardsPractice, isFalse);
    });

    test('計画に今日が無いときは、テスト日との差で前日・当日を求める', () {
      expect(card(const [], p: const [], testDate: DateTime(2026, 10, 21)).headline, TodayHeadline.eve);
      expect(card(const [], p: const [], testDate: DateTime(2026, 10, 20)).headline, TodayHeadline.testDay);
      expect(card(const [], p: const [], testDate: DateTime(2026, 10, 25)).headline, TodayHeadline.start);
      expect(card(const [], p: const [], testDate: DateTime(2026, 10, 10)).headline, TodayHeadline.start, reason: '過ぎたテスト');
    });

    test('計画に過ぎた日が含まれていても、今日の分を使う', () {
      DayPlan day(DateTime d, int left) =>
          DayPlan(date: d, daysLeft: left, total: 10, focus: 10, weak: 0, review: 0, focusByUnit: const {}, lastMinute: false);
      final p = [day(today.subtract(const Duration(days: 1)), 2), day(today, 1), day(today.add(const Duration(days: 1)), 0)];
      expect(card(const [], p: p).headline, TodayHeadline.eve, reason: '先頭（昨日）ではなく今日の分');
    });

    test('テスト日までに復習日が収まるよう、復習の期限の数にもテスト日を反映する', () {
      final a = [at('d1', DateTime(2026, 10, 18, 10)), at('d1', DateTime(2026, 10, 19, 10))]; // 2 回正解で箱 1（3 日後が復習日）
      expect(card(a, p: const [], testDate: DateTime(2026, 10, 20)).dueReviews, 1, reason: 'テスト日の今日に繰り上がる');
      expect(card(a, p: const [], testDate: DateTime(2026, 11, 20)).dueReviews, 0);
    });

    test('休憩を勧める状況なら、何よりも先に breakNow', () {
      final c = card(mistakeStreak(), p: plan([10]));
      expect(c.headline, TodayHeadline.breakNow);
      expect(c.takeBreak!.reason, BreakReason.mistakeStreak);
      expect(c.eve, EveNotice.testDay, reason: '前日・当日の情報は別に残る');
    });
  });

  group('一言', () {
    test('見出しごとの文言。done と start は null', () {
      const ja = JaStrings();
      expect(card(mistakeStreak()).message(ja), ja.breakMistakes);
      expect(card(const [], p: plan([10])).message(ja), ja.testDayNotice);
      expect(card(const [], p: plan([10, 40])).message(ja), ja.eveNotice);
      expect(card(const [], p: plan([10, 10, 10, 30, 10, 10, 10, 10, 10, 10, 10, 10])).message(ja), ja.peakAhead);
      expect(card([at('r1', DateTime(2026, 10, 18), ok: false)]).message(ja), ja.nudgeReview);
      expect(card(practicedEarlier()).message(ja), isNull);
      expect(card(const []).message(ja), isNull);
    });
  });

  test('休憩の再提案の間隔（lastBreakSuggestedAt）を渡せる', () {
    final c = buildTodayCard(now: now, attempts: mistakeStreak(), plan: calm(), lastBreakSuggestedAt: now.subtract(const Duration(minutes: 5)));
    expect(c.takeBreak, isNull);
    expect(c.headline, isNot(TodayHeadline.breakNow));
  });
}
