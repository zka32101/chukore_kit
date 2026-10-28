import '../models/models.dart';
import '../planner/planner.dart';
import '../time/study_time.dart';
import 'question_picker.dart';

/// 時間の予算に合わせた今日の出題。
class TimedPracticeSet {
  const TimedPracticeSet({
    required this.set,
    required this.estimatedSeconds,
    required this.budgetSeconds,
    required this.scaledDown,
  });

  final PracticeSet set;

  /// かかる時間の見積もり（秒）。本人の履歴から求めた 1 問あたりの時間（`PaceModel`）の合計。
  final double estimatedSeconds;

  /// 予算（秒）。
  final int budgetSeconds;

  /// 今日の計画より量を減らしたか。
  final bool scaledDown;

  /// 予算に収まっているか。1 問だけでも予算を超える場合は、1 問を出して偽になる。
  bool get fits => estimatedSeconds <= budgetSeconds;
}

double _seconds(PracticeSet set, PaceModel pace) {
  var sum = 0.0;
  for (final i in set.items) {
    sum += pace.secondsFor(i.question.unitId);
  }
  return sum;
}

/// 今日の計画 [plan] の出題を、[minutes] 分に収まるように選ぶ。「今日は 5 分」のように、量でなく時間で選ばせないための窓口。
///
/// - 計画どおりの出題が予算に収まれば、`pickPractice` と同じ結果（**足りない分を埋めて増やすことはしない**。時間の上限を守る）
/// - 収まらなければ、復習・弱点・単元ごとの重点の**比率を保ったまま**数を減らす（最大剰余法。同じ端数なら 復習 → 弱点 → 単元ID順）。
///   そのうえで、実際に選んだ問題の見積もりが予算を超えるなら、後ろ（補充・弱点）から外す
/// - 1 問も出ないことはない（1 問だけでも予算を超えるときは 1 問を出し、[TimedPracticeSet.fits] は偽）
/// - 見積もりは `PaceModel`（本人の履歴の中央値。履歴が無ければ既定値）
TimedPracticeSet pickPracticeForMinutes({
  required int minutes,
  required PaceModel pace,
  required DayPlan plan,
  required List<Question> questions,
  required Map<String, Mastery> mastery,
  required List<Attempt> attempts,
  required DateTime today,
  Iterable<String>? scopeUnitIds,
  DateTime? testDate,
  int seed = 0,
  PickerConfig config = const PickerConfig(),
}) {
  if (minutes < 1) throw ArgumentError('minutes must be positive');
  final budget = minutes * 60;

  PracticeSet pick(DayPlan p) => pickPractice(
    plan: p,
    questions: questions,
    mastery: mastery,
    attempts: attempts,
    today: today,
    scopeUnitIds: scopeUnitIds,
    testDate: testDate,
    seed: seed,
    config: config,
  );

  final full = pick(plan);
  final fullSeconds = _seconds(full, pace);
  if (fullSeconds <= budget || full.items.length <= 1) {
    return TimedPracticeSet(set: full, estimatedSeconds: fullSeconds, budgetSeconds: budget, scaledDown: false);
  }

  // 計画の数を、時間の比で減らす（比率を保つ）。
  final ratio = budget / fullSeconds;
  var set = pick(_scale(plan, ratio));
  var items = [...set.items];
  var seconds = _seconds(set, pace);
  while (items.length > 1 && seconds > budget) {
    seconds -= pace.secondsFor(items.removeLast().question.unitId);
  }
  set = PracticeSet(items: items, shortfall: set.shortfall);
  return TimedPracticeSet(set: set, estimatedSeconds: seconds, budgetSeconds: budget, scaledDown: true);
}

/// 計画の各枠の数を [ratio]（0〜1）倍する。合計は floor(元の合計 × ratio)（最低 1）で、端数は大きい順に割り当てる。
DayPlan _scale(DayPlan plan, double ratio) {
  final keys = <String>['review', 'weak', ...(plan.focusByUnit.keys.toList()..sort()).map((u) => 'u:$u')];
  int countOf(String k) => k == 'review'
      ? plan.review
      : k == 'weak'
      ? plan.weak
      : plan.focusByUnit[k.substring(2)]!;
  final counts = {for (final k in keys) k: countOf(k)};
  final sum = counts.values.fold<int>(0, (s, n) => s + n);
  var target = (sum * ratio + 1e-9).floor();
  if (target < 1 && sum > 0) target = 1;
  final ideal = {for (final k in keys) k: counts[k]! * ratio};
  final out = {for (final k in keys) k: ideal[k]!.floor()};
  var left = target - out.values.fold<int>(0, (s, n) => s + n);
  final order = [...keys]
    ..sort((a, b) {
      final fa = ideal[a]! - ideal[a]!.floor(), fb = ideal[b]! - ideal[b]!.floor();
      final c = fb.compareTo(fa);
      return c != 0 ? c : keys.indexOf(a).compareTo(keys.indexOf(b));
    });
  for (final k in order) {
    if (left <= 0) break;
    if (out[k]! < counts[k]!) {
      out[k] = out[k]! + 1;
      left--;
    }
  }
  final focus = {
    for (final k in keys)
      if (k.startsWith('u:') && out[k]! > 0) k.substring(2): out[k]!,
  };
  final review = out['review'] ?? 0, weak = out['weak'] ?? 0;
  final focusSum = focus.values.fold<int>(0, (s, n) => s + n);
  return DayPlan(
    date: plan.date,
    daysLeft: plan.daysLeft,
    total: review + weak + focusSum,
    focus: focusSum,
    weak: weak,
    review: review,
    focusByUnit: focus,
    lastMinute: plan.lastMinute,
  );
}
