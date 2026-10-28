import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

Question q(String id, String unit) => Question(
  id: id,
  unitId: unit,
  type: 'choice',
  difficulty: 0.6,
  choices: const ['a', 'b'],
  answer: 'a',
  explanationId: 'e',
);

List<Question> pool() => [
  for (final u in ['u1', 'u2'])
    for (var i = 0; i < 8; i++) q('${u}_$i', u),
];

DayPlan plan({int review = 0, int weak = 0, Map<String, int> focus = const {}}) => DayPlan(
  date: today,
  daysLeft: 5,
  total: review + weak + focus.values.fold(0, (a, b) => a + b),
  focus: focus.values.fold(0, (a, b) => a + b),
  weak: weak,
  review: review,
  focusByUnit: focus,
  lastMinute: false,
);

PaceModel pace(double all, {Map<String, double> by = const {}}) => PaceModel(by, all, measured: true);

TimedPracticeSet pick(int minutes, DayPlan p, PaceModel pc, {List<Attempt> attempts = const []}) =>
    pickPracticeForMinutes(
      minutes: minutes,
      pace: pc,
      plan: p,
      questions: pool(),
      mastery: const {},
      attempts: attempts,
      today: today,
    );

void main() {
  test('計画が予算に収まれば pickPractice と同じ結果で、増やさない', () {
    final p = plan(focus: {'u1': 6});
    final r = pick(10, p, pace(60)); // 6問×60秒=360秒 ≤ 600秒
    final base = pickPractice(plan: p, questions: pool(), mastery: const {}, attempts: const [], today: today);
    expect(r.set.questions.map((e) => e.id), base.questions.map((e) => e.id));
    expect(r.scaledDown, false);
    expect(r.fits, true);
    expect(r.estimatedSeconds, 360);
    expect(r.budgetSeconds, 600);
    final long = pick(60, p, pace(60));
    expect(long.set.items, hasLength(6), reason: '予算が余っても計画より増やさない');
  });

  test('収まらなければ数を減らし、予算に収める（6問×60秒を3分 → 3問）', () {
    final r = pick(3, plan(focus: {'u1': 6}), pace(60));
    expect(r.set.items, hasLength(3));
    expect(r.scaledDown, true);
    expect(r.fits, true);
    expect(r.estimatedSeconds, 180);
  });

  test('単元ごとの比率を保って減らす。時間は単元ごとの1問あたりの時間で見積もる', () {
    // u1: 30秒×4 + u2: 90秒×4 = 480秒。予算 240秒 → 比 0.5 → u1 2問・u2 2問
    final r = pick(4, plan(focus: {'u1': 4, 'u2': 4}), pace(60, by: {'u1': 30, 'u2': 90}));
    expect(r.set.items.where((i) => i.question.unitId == 'u1'), hasLength(2));
    expect(r.set.items.where((i) => i.question.unitId == 'u2'), hasLength(2));
    expect(r.estimatedSeconds, 240);
    expect(r.fits, true);
  });

  test('復習と重点の比率を保つ（復習2＋重点2 を半分に → 復習1＋重点1）', () {
    // 単元 u1 を 10日前に解いて復習の期限が来ている状態にする
    final attempts = [
      for (final id in ['u1_0', 'u1_1'])
        Attempt(questionId: id, unitId: 'u1', correct: true, answeredAt: DateTime(2026, 9, 20)),
    ];
    final p = plan(review: 2, focus: {'u2': 2});
    final full = pick(60, p, pace(60), attempts: attempts);
    expect(full.set.countOf(PracticeSlot.review), 2, reason: '前提: 期限の来た復習が2問ある');
    final r = pick(2, p, pace(60), attempts: attempts);
    expect(r.set.countOf(PracticeSlot.review), 1);
    expect(r.set.countOf(PracticeSlot.focus), 1);
    expect(r.set.items, hasLength(2));
  });

  test('端数があっても合計は予算に収まる最大（2単元 4・3 を 7問→5問）', () {
    final r = pick(5, plan(focus: {'u1': 4, 'u2': 3}, weak: 0), pace(60)); // 7問420秒 → 予算300 → ratio 0.714 → 5問
    expect(r.set.items, hasLength(5));
    expect(r.fits, true);
  });

  test('見積もりが予算とちょうど等しいときは減らさない（6問×60秒＝6分）', () {
    final r = pick(6, plan(focus: {'u1': 6}), pace(60));
    expect(r.set.items, hasLength(6));
    expect(r.scaledDown, false);
    expect(r.fits, true);
    expect(r.estimatedSeconds, 360);
  });

  test('数を減らしてもまだ超えるときは、後ろから外して予算に収める', () {
    // u1: 180秒×3 + u2: 60秒×1 = 600秒。予算 300秒 → 比 0.5 → 2問（端数は単元ID順で u1 に付く）→ u1 が2問で360秒 → 後ろを外して1問
    final r = pick(5, plan(focus: {'u1': 3, 'u2': 1}), pace(60, by: {'u1': 180, 'u2': 60}));
    expect(r.set.items, hasLength(1));
    expect(r.fits, true);
    expect(r.estimatedSeconds, 180);
    expect(r.scaledDown, true);
  });

  test('1問も出ないことはない。1問でも予算を超えるなら1問を出して fits は偽', () {
    final r = pick(1, plan(focus: {'u1': 4}), pace(200));
    expect(r.set.items, hasLength(1));
    expect(r.fits, false);
    expect(r.estimatedSeconds, 200);
  });

  test('今日の計画が空なら空（エラーにしない）', () {
    final r = pick(5, plan(), pace(60));
    expect(r.set.items, isEmpty);
    expect(r.fits, true);
    expect(r.scaledDown, false);
  });

  test('minutes が1未満ならエラー。同じ入力なら同じ結果', () {
    expect(() => pick(0, plan(focus: {'u1': 2}), pace(60)), throwsArgumentError);
    final p = plan(focus: {'u1': 6, 'u2': 6});
    final a = pick(4, p, pace(60)).set.questions.map((e) => e.id).toList();
    final b = pick(4, p, pace(60)).set.questions.map((e) => e.id).toList();
    expect(a, b);
  });
}
