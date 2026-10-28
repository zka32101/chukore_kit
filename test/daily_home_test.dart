import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1, 9);

Question q(String id, String unit) => Question(
  id: id,
  unitId: unit,
  type: 'choice',
  difficulty: 0.6,
  choices: const ['a', 'b'],
  answer: 'a',
  explanationId: 'e',
);

final pool = [
  for (final u in ['u1', 'u2'])
    for (var i = 0; i < 8; i++) q('${u}_$i', u),
];

DayPlan day({DateTime? date, int daysLeft = 5, Map<String, int> focus = const {'u1': 3, 'u2': 3}}) => DayPlan(
  date: date ?? dateOnly(today),
  daysLeft: daysLeft,
  total: focus.values.fold(0, (a, b) => a + b),
  focus: focus.values.fold(0, (a, b) => a + b),
  weak: 0,
  review: 0,
  focusByUnit: focus,
  lastMinute: false,
);

Attempt a(String id, String unit, DateTime when) =>
    Attempt(questionId: id, unitId: unit, correct: true, answeredAt: when);

DailyHome home({
  List<DayPlan>? plan,
  int? minutes,
  List<Attempt> attempts = const [],
  PaceModel? pace,
  DateTime? testDate,
  Iterable<DateTime>? testDates,
  ScorePromptState state = const ScorePromptState(),
  RealTestRecord? baseline,
  KitTuning tuning = const KitTuning(),
  DateTime? now,
}) => buildDailyHome(
  now: now ?? today,
  plan: plan ?? [day()],
  questions: pool,
  mastery: const {},
  attempts: attempts,
  testDate: testDate,
  minutes: minutes,
  pace: pace,
  testDates: testDates,
  promptState: state,
  baseline: baseline,
  tuning: tuning,
);

void main() {
  test('時間を指定しないとき: pickPractice → interleaveByUnit と同じ出題。制限・予算なし', () {
    final h = home();
    final manual = interleaveByUnit(
      pickPractice(plan: day(), questions: pool, mastery: const {}, attempts: const [], today: dateOnly(today)),
    );
    expect(h.practice.questions.map((e) => e.id), manual.questions.map((e) => e.id));
    expect(h.practice.items, hasLength(6));
    expect(h.hasPlanToday, true);
    expect(h.guard, isNull);
    expect(h.budgetSeconds, isNull);
    expect(h.scaledDown, false);
    expect(h.fits, true);
    expect(h.card.headline, buildTodayCard(now: today, attempts: const [], plan: [day()]).headline);
  });

  test('同じ単元が続かないよう混ぜてある', () {
    final ids = home().practice.questions.map((e) => e.unitId).toList();
    var runs = 0;
    for (var i = 1; i < ids.length; i++) {
      if (ids[i] == ids[i - 1]) runs++;
    }
    expect(runs, lessThan(4), reason: '混ぜなければ u1,u1,u1,u2,u2,u2 で連続が4回');
  });

  test('時間を指定すると、予算に収まるよう量を減らす。見積もりは最終の出題から求める', () {
    final h = home(minutes: 3, pace: PaceModel(const {}, 60, measured: true));
    expect(h.practice.items, hasLength(3));
    expect(h.budgetSeconds, 180);
    expect(h.estimatedSeconds, 180);
    expect(h.scaledDown, true);
    expect(h.fits, true);
    final roomy = home(minutes: 60, pace: PaceModel(const {}, 60, measured: true));
    expect(roomy.practice.items, hasLength(6), reason: '予算が余っても増やさない');
    expect(roomy.scaledDown, false);
    expect(roomy.estimatedSeconds, 360);
  });

  test('1問でも予算を超えるときは、1問を出して fits が偽', () {
    final h = home(minutes: 1, pace: PaceModel(const {}, 200, measured: true));
    expect(h.practice.items, hasLength(1));
    expect(h.estimatedSeconds, 200);
    expect(h.fits, false);
  });

  test('今日の分が計画に無ければ、出題は空。見出しと点の判定は返す', () {
    final h = home(plan: [day(date: dateOnly(today).add(const Duration(days: 1)))], minutes: 5);
    expect(h.hasPlanToday, false);
    expect(h.practice.items, isEmpty);
    expect(h.estimatedSeconds, 0);
    expect(h.budgetSeconds, 300);
    expect(h.fits, true);
    expect(h.guard, isNull);
    expect(h.card, isNotNull);
    expect(home(plan: const []).practice.items, isEmpty);
  });

  group('前日・当日の制限', () {
    final old = DateTime(2026, 9, 20, 12);

    test('前日は解いたことのある問題だけ。制限の結果と一言が付く', () {
      final attempts = [a('u1_0', 'u1', old), a('u1_1', 'u1', old)];
      final h = home(
        plan: [
          day(daysLeft: 1, focus: const {'u1': 4}),
        ],
        attempts: attempts,
        testDate: dateOnly(today).add(const Duration(days: 1)),
      );
      expect(h.card.guardsPractice, true);
      expect(h.guard, isNotNull);
      expect(h.guard!.notice, EveNotice.eve);
      expect(h.practice.questions.every((e) => {'u1_0', 'u1_1'}.contains(e.id)), true, reason: '新しい問題は外す');
      expect(h.guard!.removedNew, greaterThan(0));
      expect(h.guard!.message(const JaStrings()), const JaStrings().eveNotice);
    });

    test('見積もりは、制限をかけたあとの出題から求める', () {
      final attempts = [a('u1_0', 'u1', old), a('u1_1', 'u1', old)];
      final h = home(
        plan: [
          day(daysLeft: 1, focus: const {'u1': 4}),
        ],
        attempts: attempts,
        pace: PaceModel(const {}, 50, measured: true),
      );
      expect(h.estimatedSeconds, h.practice.items.length * 50);
    });

    test('一度も解いていなければ、前日の出題は空（穴埋めしない）', () {
      final h = home(
        plan: [
          day(daysLeft: 1, focus: const {'u1': 4}),
        ],
      );
      expect(h.practice.items, isEmpty);
      expect(h.guard, isNotNull);
    });

    test('前日・当日以外は制限しない', () {
      expect(home(plan: [day(daysLeft: 2)]).guard, isNull);
    });
  });

  group('点を聞く', () {
    final base = RealTestRecord(DateTime(2026, 1, 1), 50);
    final test0 = dateOnly(today).subtract(const Duration(days: 1)); // 昨日がテスト

    test('テストの翌日に聞く。聞いたあとは聞かない。計画が無くても判定は返る', () {
      final h = home(testDates: [test0], baseline: base, plan: const []);
      expect(h.hasPlanToday, false);
      expect(h.scorePrompt?.kind, ScorePromptKind.afterTest);
      final asked = const ScorePromptState().markPrompted(h.scorePrompt!, today);
      expect(
        home(testDates: [test0], baseline: base, state: asked, now: today.add(const Duration(days: 1))).scorePrompt,
        isNull,
      );
    });

    test('testDate だけを渡しても、testDates の代わりに使う。使い始めは「使う前の点」を聞く', () {
      expect(home(testDate: test0, baseline: base).scorePrompt?.kind, ScorePromptKind.afterTest);
      expect(home().scorePrompt?.kind, ScorePromptKind.baseline);
      expect(home(baseline: base).scorePrompt, isNull);
    });

    test('しきい値の設定束に従う（聞く期間を短くすると聞かない）', () {
      final longAgo = dateOnly(today).subtract(const Duration(days: 10));
      expect(home(testDates: [longAgo], baseline: base).scorePrompt, isNotNull);
      expect(
        home(testDates: [longAgo], baseline: base, tuning: const KitTuning(promptWindowDays: 5)).scorePrompt,
        isNull,
      );
    });
  });
}
