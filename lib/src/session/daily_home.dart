import '../growth/kit_tuning.dart';
import '../growth/real_tests.dart';
import '../growth/score_entry.dart';
import '../models/models.dart';
import '../planner/planner.dart';
import '../practice/eve_guard.dart';
import '../practice/question_picker.dart';
import '../practice/timed_practice.dart';
import '../time/study_time.dart';
import 'learning_step.dart';
import 'today_card.dart';

/// 「今日」の入口。画面に出す内容を 1 回で求めた結果。
class DailyHome {
  const DailyHome({
    required this.card,
    required this.practice,
    required this.estimatedSeconds,
    required this.budgetSeconds,
    required this.scaledDown,
    required this.hasPlanToday,
    required this.guard,
    required this.scorePrompt,
    this.learningStep,
  });

  /// 今日の見出しと一言（休憩・前日/当日・山場の予告・復習の期限・学習済みか）。
  final TodayCard card;

  /// 今日の出題。時間の予算に収め、同じ単元が続かないよう混ぜ、前日・当日は見直しだけに整えたあとのもの。
  final PracticeSet practice;

  /// 出題にかかる時間の見積もり（秒。本人の履歴の中央値から）。
  final double estimatedSeconds;

  /// 時間の予算（秒）。時間を指定しなければ null。
  final int? budgetSeconds;

  /// 予算に合わせて、計画より量を減らしたか。
  final bool scaledDown;

  /// 今日の分が計画にあるか。無ければ（テストが過ぎた・計画が無い）出題は空。
  final bool hasPlanToday;

  /// 前日・当日の制限をかけたときの結果（制限なしなら null）。子どもに見せる一言は `guard.message(strings)`。
  final GuardedPractice? guard;

  /// 今日、点を聞くか（聞かないなら null）。聞いたら `ScorePromptState.markPrompted` で記録すること。
  final ScorePrompt? scorePrompt;

  /// 今日の次の 1 手（レッスン・体験・練習・復習・テスト）。材料 `learning` を渡したときだけ（渡さなければ null）。
  final LearningStep? learningStep;

  /// 予算に収まっているか（時間を指定しなければ常に真）。
  bool get fits => budgetSeconds == null || estimatedSeconds <= budgetSeconds!;
}

/// 「今日」の入口に必要なものを、**1 回の呼び出しで**求める。アプリの結線を短くし、部品の組み合わせの間違いを減らす。
///
/// 内部の流れ（個別に呼んでも同じ結果になる）:
/// 1. `buildTodayCard`: 見出しと一言
/// 2. 出題: [minutes] があれば `pickPracticeForMinutes`（予算に収める。増やさない）、無ければ `pickPractice`
/// 3. `interleaveByUnit`: 同じ単元が続かないよう混ぜる
/// 4. 前日・当日なら `guardLastDays`: 新しい問題を外し、上限を設ける
/// 5. `KitTuning.scorePrompt`: 点を聞くか（テスト後に 1 回だけ。[testDates] を省くと [testDate] を使う）
/// 6. [learning] を渡せば `nextLearningStep`: 今日の次の 1 手（レッスン・体験・練習・復習・テスト）
///
/// 今日の分が計画（[plan]）に無ければ、出題は空（見出しと点の判定は返す）。
/// [now] は端末のローカル時刻（深夜の学習を前日に数えるなら `StudyDay.shift` を通した値と回答を渡す）。
DailyHome buildDailyHome({
  required DateTime now,
  required List<DayPlan> plan,
  required List<Question> questions,
  required Map<String, Mastery> mastery,
  required List<Attempt> attempts,
  DateTime? testDate,
  int? minutes,
  PaceModel? pace,
  KitTuning tuning = const KitTuning(),
  Iterable<DateTime>? testDates,
  Iterable<RealTestRecord> records = const [],
  ScorePromptState promptState = const ScorePromptState(),
  RealTestRecord? baseline,
  Iterable<String>? scopeUnitIds,
  DateTime? lastBreakSuggestedAt,
  int seed = 0,
  PickerConfig pickerConfig = const PickerConfig(),
  LearningContext? learning,
}) {
  final day = dateOnly(now);
  // 今日の次の 1 手（材料があるときだけ）。範囲は scopeUnitIds、無ければ問題のある単元すべて
  final step = learning == null
      ? null
      : nextLearningStep(
          now: now,
          unitIds: scopeUnitIds ?? {for (final q in questions) q.unitId},
          mastery: mastery,
          attempts: attempts,
          questions: questions,
          context: learning,
          testDate: testDate,
        );
  final paceModel = pace ?? buildPace(attempts);
  final card = buildTodayCard(
    now: now,
    attempts: attempts,
    plan: plan,
    testDate: testDate,
    lastBreakSuggestedAt: lastBreakSuggestedAt,
  );
  final prompt = tuning.scorePrompt(
    today: now,
    testDates: testDates ?? (testDate == null ? const [] : [testDate]),
    records: records,
    state: promptState,
    baseline: baseline,
  );

  final todayPlan = plan.where((d) => dateOnly(d.date) == day).firstOrNull;
  if (todayPlan == null) {
    return DailyHome(
      card: card,
      practice: const PracticeSet(items: [], shortfall: {}),
      estimatedSeconds: 0,
      budgetSeconds: minutes == null ? null : minutes * 60,
      scaledDown: false,
      hasPlanToday: false,
      guard: null,
      scorePrompt: prompt,
      learningStep: step,
    );
  }

  PracticeSet set;
  var scaled = false;
  if (minutes != null) {
    final timed = pickPracticeForMinutes(
      minutes: minutes,
      pace: paceModel,
      plan: todayPlan,
      questions: questions,
      mastery: mastery,
      attempts: attempts,
      today: day,
      scopeUnitIds: scopeUnitIds,
      testDate: testDate,
      seed: seed,
      config: pickerConfig,
    );
    set = timed.set;
    scaled = timed.scaledDown;
  } else {
    set = pickPractice(
      plan: todayPlan,
      questions: questions,
      mastery: mastery,
      attempts: attempts,
      today: day,
      scopeUnitIds: scopeUnitIds,
      testDate: testDate,
      seed: seed,
      config: pickerConfig,
    );
  }
  set = interleaveByUnit(set);

  GuardedPractice? guard;
  if (card.guardsPractice) {
    guard = guardLastDays(set, plan: todayPlan, attempts: attempts);
    set = guard.set;
  }

  var seconds = 0.0;
  for (final i in set.items) {
    seconds += paceModel.secondsFor(i.question.unitId);
  }
  return DailyHome(
    card: card,
    practice: set,
    estimatedSeconds: seconds,
    budgetSeconds: minutes == null ? null : minutes * 60,
    scaledDown: scaled,
    hasPlanToday: true,
    guard: guard,
    scorePrompt: prompt,
    learningStep: step,
  );
}
