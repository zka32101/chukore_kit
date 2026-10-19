import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 1, 10);

Question q(String id) => Question(
      id: id,
      unitId: 'u',
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
    );

DayPlan plan(int daysLeft) => DayPlan(
      date: t0,
      daysLeft: daysLeft,
      total: 20,
      focus: 10,
      weak: 5,
      review: 5,
      focusByUnit: const {'u': 10},
      lastMinute: daysLeft <= 3,
    );

PracticeSet setOf(List<String> ids, {Map<PracticeSlot, int> shortfall = const {}}) => PracticeSet(
      items: [for (var i = 0; i < ids.length; i++) PickedQuestion(q(ids[i]), i < 2 ? PracticeSlot.review : PracticeSlot.focus)],
      shortfall: shortfall,
    );

List<Attempt> seen(Iterable<String> ids) =>
    [for (final id in ids) Attempt(questionId: id, unitId: 'u', correct: true, answeredAt: t0)];

List<String> ids(PracticeSet s) => [for (final i in s.items) i.question.id];

void main() {
  group('いつ効くか', () {
    test('テストまで 2 日以上（と、テストが終わったあと）は、そのまま返す', () {
      final s = setOf(['a', 'b', 'new1']);
      for (final d in [2, 3, 10, -1]) {
        final g = guardLastDays(s, plan: plan(d), attempts: seen(['a', 'b']));
        expect(identical(g.set, s), isTrue, reason: '$d 日前');
        expect(g.notice, EveNotice.none);
        expect(g.message(const JaStrings()), isNull);
        expect([g.removedNew, g.trimmed], [0, 0]);
      }
    });

    test('前日（1 日前）と当日（0 日）に効く', () {
      expect(guardLastDays(setOf(['a']), plan: plan(1), attempts: seen(['a'])).notice, EveNotice.eve);
      expect(guardLastDays(setOf(['a']), plan: plan(0), attempts: seen(['a'])).notice, EveNotice.testDay);
    });
  });

  group('新しい問題を外す', () {
    test('一度も解いていない問題を外し、解いたことのある問題の順は保つ', () {
      final g = guardLastDays(setOf(['r1', 'new1', 'r2', 'new2', 'f1']), plan: plan(1), attempts: seen(['f1', 'r1', 'r2']));
      expect(ids(g.set), ['r1', 'r2', 'f1']);
      expect(g.removedNew, 2);
      expect(g.trimmed, 0);
    });

    test('別モード（模試）の回答でも「解いたことがある」とみなす', () {
      final a = [Attempt(questionId: 'm1', unitId: 'u', correct: false, answeredAt: t0, mode: 'mock')];
      expect(ids(guardLastDays(setOf(['m1', 'x']), plan: plan(1), attempts: a).set), ['m1']);
    });

    test('全部が新しい問題なら空のまま返す（穴埋めしない）。shortfall は変えない', () {
      final g = guardLastDays(setOf(['x', 'y'], shortfall: {PracticeSlot.weak: 3}), plan: plan(0), attempts: const []);
      expect(g.set.items, isEmpty);
      expect(g.set.shortfall, {PracticeSlot.weak: 3});
      expect(g.removedNew, 2);
    });
  });

  group('上限', () {
    final all = [for (var i = 0; i < 20; i++) 'k$i'];

    test('前日は 15 問、当日は 8 問まで。後ろから減らす', () {
      final eve = guardLastDays(setOf(all), plan: plan(1), attempts: seen(all));
      expect(ids(eve.set), all.sublist(0, 15));
      expect(eve.trimmed, 5);
      final day = guardLastDays(setOf(all), plan: plan(0), attempts: seen(all));
      expect(ids(day.set), all.sublist(0, 8));
      expect(day.trimmed, 12);
      expect(day.set.items.first.slot, PracticeSlot.review, reason: '復習は先頭に残る');
    });

    test('ちょうど上限なら減らさない。設定で変えられる', () {
      expect(guardLastDays(setOf(all.sublist(0, 15)), plan: plan(1), attempts: seen(all)).trimmed, 0);
      expect(guardLastDays(setOf(all.sublist(0, 8)), plan: plan(0), attempts: seen(all)).trimmed, 0);
      final c = guardLastDays(setOf(all), plan: plan(1), attempts: seen(all), config: const EveGuardConfig(eveMax: 3, testDayMax: 2));
      expect(ids(c.set), ['k0', 'k1', 'k2']);
    });

    test('新しい問題を外した数と、上限で減らした数は別々に数える', () {
      final mixed = ['n1', ...all.sublist(0, 18), 'n2'];
      final g = guardLastDays(setOf(mixed), plan: plan(1), attempts: seen(all));
      expect(g.removedNew, 2);
      expect(g.trimmed, 3);
      expect(g.set.items.length, 15);
    });
  });

  group('一言', () {
    test('前日と当日で違う文言。全言語にあり、数字を含まない', () {
      const ja = JaStrings();
      expect(guardLastDays(setOf(['a']), plan: plan(1), attempts: seen(['a'])).message(ja), ja.eveNotice);
      expect(guardLastDays(setOf(['a']), plan: plan(0), attempts: seen(['a'])).message(ja), ja.testDayNotice);
      for (final s in ChukoreStrings.supported) {
        for (final t in [s.eveNotice, s.testDayNotice]) {
          expect(t.trim(), isNotEmpty, reason: s.tag);
          expect(RegExp(r'[0-9０-９]').hasMatch(t), isFalse, reason: s.tag);
        }
        expect(s.eveNotice, isNot(s.testDayNotice), reason: s.tag);
      }
    });
  });
}
