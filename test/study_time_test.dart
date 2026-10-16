import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt _a(String unit, int ms, {int i = 0}) => Attempt(
      questionId: 'q$i',
      unitId: unit,
      correct: true,
      answeredAt: DateTime(2026, 10, 1, 9, i),
      elapsedMs: ms,
    );

List<Attempt> _many(String unit, int ms, int n) => [for (var i = 0; i < n; i++) _a(unit, ms, i: i)];

DayPlan _day(int d, {int focus = 0, int weak = 0, int review = 0, Map<String, int> byUnit = const {}}) => DayPlan(
      date: DateTime.utc(2026, 10, d),
      daysLeft: 0,
      total: focus + weak + review,
      focus: focus,
      weak: weak,
      review: review,
      focusByUnit: byUnit,
      lastMinute: false,
    );

void main() {
  group('1問あたりの時間', () {
    test('単元の記録が足りれば単元の中央値、足りなければ全体の中央値', () {
      final p = buildPace([..._many('fast', 20000, 5), ..._many('slow', 60000, 5), _a('few', 90000, i: 99)]);
      expect(p.measured, isTrue);
      expect(p.secondsFor('fast'), 20);
      expect(p.secondsFor('slow'), 60);
      // 記録が 1 件の単元は全体の中央値（11 件: 20 秒 5 件・60 秒 5 件・90 秒 1 件 → 中央は 60 秒）
      expect(p.secondsFor('few'), p.overallSeconds);
      expect(p.overallSeconds, 60);
    });

    test('未計測（0）と、席を離れたような長い時間は除く。中央値なので外れ値に強い', () {
      final p = buildPace([
        ..._many('u', 30000, 5),
        _a('u', 0, i: 50),
        _a('u', 3600000, i: 51), // 1 時間
      ]);
      expect(p.secondsFor('u'), 30);
      // 長い時間のほうが多くても、除外するので影響しない（除外しないと中央値が 1 時間になる）
      final many = buildPace([..._many('u', 30000, 5), for (var i = 0; i < 6; i++) _a('u', 3600000, i: 60 + i)]);
      expect(many.secondsFor('u'), 30);
      // 上限ちょうど（300 秒）は含む
      expect(buildPace(_many('u', 300000, 5)).secondsFor('u'), 300);
    });

    test('記録が足りなければ既定値（measured=false）', () {
      final p = buildPace(_many('u', 10000, 4));
      expect(p.measured, isFalse);
      expect(p.overallSeconds, 45);
      expect(p.secondsFor('u'), 45);
      expect(buildPace(const [], defaultSeconds: 60).overallSeconds, 60);
    });
  });

  group('日ごとの学習時間', () {
    final pace = buildPace([..._many('fast', 20000, 5), ..._many('slow', 60000, 5)]); // 全体の中央値は 40 秒

    test('重点枠は単元ごと、弱点枠・復習枠は全体の速さで数える', () {
      final t = estimateDayTimes([
        _day(1, focus: 10, weak: 3, review: 2, byUnit: {'fast': 6, 'slow': 4}),
      ], pace).single;
      // 6×20 + 4×60 + (3+2)×40 = 120 + 240 + 200 = 560 秒
      expect(t.minutes, closeTo(560 / 60, 1e-9));
      expect(t.questions, 15);
    });

    test('弱点枠の係数', () {
      final t = estimateDayTimes([_day(1, weak: 10)], pace, weakFactor: 1.5).single;
      expect(t.minutes, closeTo(10 * 40 * 1.5 / 60, 1e-9));
    });

    test('単元に割り当たらなかった重点枠は全体の速さで数える', () {
      final t = estimateDayTimes([_day(1, focus: 5)], pace).single;
      expect(t.minutes, closeTo(5 * 40 / 60, 1e-9));
    });

    test('5 分きざみで切り上げ。0 分は 0', () {
      expect(DayTime(DateTime.utc(2026, 10, 1), 1, 0.1).roundedMinutes, 5);
      expect(DayTime(DateTime.utc(2026, 10, 1), 1, 5).roundedMinutes, 5);
      expect(DayTime(DateTime.utc(2026, 10, 1), 1, 5.01).roundedMinutes, 10);
      expect(DayTime(DateTime.utc(2026, 10, 1), 0, 0).roundedMinutes, 0);
    });

    test('1日の上限を超える日', () {
      final days = estimateDayTimes([_day(1, review: 30), _day(2, review: 10)], pace); // 20 分・約 6.7 分
      expect(daysOverBudget(days, 15).map((d) => d.date.day), [1]);
      expect(daysOverBudget(days, 20), isEmpty); // ちょうどは超えない
    });
  });

  test('上限の分で解ける問題数', () {
    final pace = buildPace([..._many('fast', 20000, 5), ..._many('slow', 60000, 5)]);
    expect(questionsWithinBudget(10, pace, unitId: 'fast'), 30);
    expect(questionsWithinBudget(10, pace, unitId: 'slow'), 10);
    expect(questionsWithinBudget(10, pace), 15); // 全体 40 秒
    expect(questionsWithinBudget(0, pace), 0);
  });

  test('buildPlan の結果にそのまま使える', () {
    final tree = UnitTree(1, [
      Unit(id: 'a', subject: 'math', grade: 1, title: 'A', estimatedQuestions: 10),
      Unit(id: 'b', subject: 'math', grade: 1, title: 'B', estimatedQuestions: 10),
    ]);
    final plan = TestPlan(id: 'p', subject: 'math', testDate: DateTime(2026, 10, 14), unitIds: const ['a', 'b']);
    final res = buildPlan(today: DateTime(2026, 10, 10), plan: plan, tree: tree);
    final times = estimateDayTimes(res.days, buildPace(const []));
    expect(times.length, res.days.length);
    expect(times.every((t) => t.minutes > 0), isTrue);
    // 既定の 45 秒 × 問題数
    expect(times.first.minutes, closeTo(res.days.first.total * 45 / 60, 1e-9));
  });
}
