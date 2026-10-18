import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 20);
DateTime d(int n) => today.add(Duration(days: n)); // n 日後

/// 教科 s ごとに、親 s と葉 s_a・s_b（各 20 問）。
UnitTree tree(Iterable<String> subjects) => UnitTree(1, [
      for (final s in subjects) ...[
        Unit(id: s, subject: s, grade: 1, title: s),
        Unit(id: '${s}_a', subject: s, grade: 1, title: '${s}_a', parentId: s, order: 1, estimatedQuestions: 20),
        Unit(id: '${s}_b', subject: s, grade: 1, title: '${s}_b', parentId: s, order: 2, estimatedQuestions: 20),
      ],
    ]);

TestPlan tp(String s, int daysAhead) => TestPlan(id: s, subject: s, testDate: d(daysAhead), unitIds: [s]);

Map<String, Mastery> mast(Map<String, double> m) => {for (final e in m.entries) e.key: Mastery(unitId: e.key, score: e.value)};

void main() {
  splitTests();
  final five = ['math', 'eng', 'jp', 'sci', 'soc'];

  MultiPlanResult plan(
    List<TestPlan> plans, {
    Map<String, double> mastery = const {},
    List<BusyDay> busy = const [],
    int daily = 30,
    double minShare = 0.1,
    Iterable<String>? subjects,
  }) =>
      buildMultiPlan(
        today: today,
        plans: plans,
        tree: tree(subjects ?? plans.map((p) => p.id)),
        mastery: mast(mastery),
        busyDays: busy,
        dailyQuestions: daily,
        minShare: minShare,
      );

  group('1 教科だけなら buildPlan と同じ', () {
    test('通常・忙しい日・お休み・直前モード・習熟度つきで、各日の内訳が一致する', () {
      final p = tp('math', 14);
      final busy = [BusyDay(d(3)), BusyDay(d(5), BusyKind.off), BusyDay(d(6))];
      final m = {'math_a': 0.8, 'math_b': 0.2};
      final multi = plan([p], mastery: m, busy: busy, daily: 10);
      final single = buildPlan(
        today: today,
        plan: p,
        tree: tree(['math']),
        mastery: mast(m),
        busyDays: busy,
      );
      expect(multi.days.length, single.days.length);
      for (var i = 0; i < single.days.length; i++) {
        final s = single.days[i];
        final got = multi.days[i].byPlan['math'];
        if (s.total == 0) {
          expect(got, isNull, reason: 'day $i: お休みは割り当て無し');
          expect(multi.days[i].total, 0);
          continue;
        }
        expect(got, isNotNull, reason: 'day $i');
        expect((got!.total, got.focus, got.weak, got.review, got.lastMinute, got.daysLeft),
            (s.total, s.focus, s.weak, s.review, s.lastMinute, s.daysLeft),
            reason: 'day $i');
        expect(got.focusByUnit, s.focusByUnit, reason: 'day $i');
      }
      expect(multi.overCapacityPlanIds.isNotEmpty, single.overCapacity);
    });
  });

  group('テストが近い教科を厚く、遠い教科も止めない', () {
    test('近いテストの教科の方が多く、どちらも 0 にならない。合計は予算どおり', () {
      final r = plan([tp('math', 3), tp('eng', 20)]);
      for (final day in r.days.take(4)) {
        expect(day.byPlan['math']!.total, greaterThan(day.byPlan['eng']!.total), reason: '${day.date}');
        expect(day.byPlan['eng']!.total, greaterThan(0));
        expect(day.total, day.byPlan.values.fold<int>(0, (s, x) => s + x.total));
      }
      expect(r.days.first.total, 30);
    });

    test('習熟度が低い教科の方が多い（テスト日が同じなら）', () {
      final r = plan([tp('math', 10), tp('eng', 10)], mastery: {'math_a': 0.9, 'math_b': 0.9, 'eng_a': 0.1, 'eng_b': 0.1});
      final day = r.days.first;
      expect(day.byPlan['eng']!.total, greaterThan(day.byPlan['math']!.total));
    });

    test('教科が多くても、どの教科にも最低限の割り当てがある（minShare）', () {
      final plans = [tp('math', 1), tp('eng', 30), tp('jp', 30), tp('sci', 30), tp('soc', 30)];
      final r = plan(plans, daily: 40);
      final day = r.days.first;
      expect(day.byPlan.keys.toSet(), five.toSet());
      for (final id in ['eng', 'jp', 'sci', 'soc']) {
        expect(day.byPlan[id]!.total, greaterThanOrEqualTo(3), reason: '$id: 40 × 0.1 = 4 問前後');
      }
    });

    test('minShare を 0 にすれば、遠い教科はほとんど割り当てが無い日がある', () {
      final r = plan([tp('math', 1), tp('eng', 40)], minShare: 0);
      expect(r.days.first.byPlan['eng']?.total ?? 0, lessThan(r.days.first.byPlan['math']!.total ~/ 4));
    });

    test('取り組む順は、テストが近い教科が先（同じ日なら ID 順）', () {
      final r = plan([tp('soc', 2), tp('math', 9), tp('eng', 2)]);
      expect(r.days.first.order, ['eng', 'soc', 'math'], reason: 'ID 順なら math が先になるので、近さ優先を確かめられる');
    });

    test('遠い教科にも、予算の minShare ぶん以上が残る（テストが 1 日後の教科があっても）', () {
      final r = plan([tp('math', 1), tp('eng', 40)], daily: 100);
      expect(r.days.first.byPlan['eng']!.total, greaterThanOrEqualTo(10), reason: '100 × 0.1');
    });
  });

  group('テストが終わった教科', () {
    test('終わった翌日からは割り当てず、残りの教科に回る。最後のテストの日までで終わる', () {
      final r = plan([tp('math', 2), tp('eng', 6)], daily: 30);
      expect(r.days.length, 7);
      expect(r.days[2].byPlan.containsKey('math'), isTrue, reason: 'テスト当日は含む');
      expect(r.days[3].byPlan.keys, ['eng']);
      expect(r.days[3].byPlan['eng']!.total, 30, reason: '残りの教科が予算を使う');
      expect(dateOnly(r.days.last.date), dateOnly(d(6)));
    });

    test('すでにテスト日が過ぎた教科は skipped。全部過ぎていれば空', () {
      final r = plan([tp('math', -1), tp('eng', 3)]);
      expect(r.skippedPlanIds, ['math']);
      expect(r.days.first.byPlan.keys, ['eng']);
      expect(plan([tp('math', -2)]).days, isEmpty);
      expect(plan(const []).days, isEmpty);
    });

    test('テストが同じ日の教科は、その日までずっと並行', () {
      final r = plan([tp('math', 4), tp('eng', 4)]);
      for (final day in r.days) {
        expect(day.byPlan.keys.toSet(), {'math', 'eng'});
      }
    });
  });

  group('忙しい日・お休み（全教科共通）', () {
    test('お休みの日は全教科 0。忙しい日は予算が減り、減った分の一部が通常日に上乗せされる（上限あり）', () {
      final busy = [BusyDay(d(1), BusyKind.off), BusyDay(d(2))];
      final r = plan([tp('math', 8), tp('eng', 8)], busy: busy);
      expect(r.days[1].total, 0);
      expect(r.days[1].byPlan, isEmpty);
      expect(r.days[2].total, 9, reason: '30 × 0.3');
      final normal = r.days[0].total;
      expect(normal, greaterThan(30), reason: '上乗せ');
      expect(normal, lessThanOrEqualTo((30 * 1.3).round()), reason: '上限 30 × 1.3');
    });
  });

  group('直前モードと内訳', () {
    test('テストまで 3 日以内は、その教科だけ直前モード（重点 5 : 弱点 5 : 復習 0）', () {
      final r = plan([tp('math', 2), tp('eng', 20)]);
      final m = r.days.first.byPlan['math']!;
      expect(m.lastMinute, isTrue);
      expect(m.review, 0);
      expect(r.days.first.byPlan['eng']!.lastMinute, isFalse);
      for (final day in r.days) {
        for (final x in day.byPlan.values) {
          expect(x.focus + x.weak + x.review, x.total);
          expect(x.focusByUnit.values.fold<int>(0, (s, n) => s + n), x.focus);
        }
      }
    });
  });

  group('範囲が広すぎる教科', () {
    test('割り当ての総量が想定問題数に届かない教科は overCapacity。優先する単元を返す', () {
      // 1 教科 40 問の範囲に対し、予算 5 問/日 × 3 日
      final r = plan([tp('math', 2)], daily: 5, mastery: {'math_a': 0.9, 'math_b': 0.1});
      expect(r.overCapacityPlanIds, ['math']);
      expect(r.priorityUnitIds['math'], ['math_b', 'math_a'], reason: '習熟度の低い単元が先');
    });
    test('十分な予算なら overCapacity は空', () {
      expect(plan([tp('math', 4)], daily: 30).overCapacityPlanIds, isEmpty);
    });
  });

  group('入力の検査と再現性', () {
    test('dailyQuestions・minShare・重複 ID は不正', () {
      expect(() => plan([tp('math', 1)], daily: 0), throwsArgumentError);
      expect(() => plan([tp('math', 1)], minShare: 0.6), throwsArgumentError);
      expect(() => plan([tp('math', 1), tp('math', 2)]), throwsArgumentError);
    });

    test('同じ入力なら同じ結果。教科の渡し順は関係ない', () {
      final a = plan([tp('math', 5), tp('eng', 9), tp('jp', 3)], mastery: {'eng_a': 0.3});
      final b = plan([tp('jp', 3), tp('math', 5), tp('eng', 9)], mastery: {'eng_a': 0.3});
      String show(MultiPlanResult r) => r.days
          .map((x) => x.order.map((id) => '$id:${x.byPlan[id]!.total}/${x.byPlan[id]!.focusByUnit}').join(','))
          .join('|');
      expect(show(a), show(b));
    });

    test('教科ごとの DayPlan はそのまま pickPractice に渡せる', () {
      final r = plan([tp('math', 5), tp('eng', 9)]);
      final dayPlan = r.days.first.byPlan['math']!;
      final questions = [
        for (var i = 0; i < 12; i++)
          Question(
              id: 'q$i',
              unitId: i.isEven ? 'math_a' : 'math_b',
              type: 'choice',
              difficulty: 0.7,
              choices: const ['a', 'b'],
              answer: 'a',
              explanationId: 'e'),
      ];
      final set = pickPractice(plan: dayPlan, questions: questions, mastery: const {}, attempts: const [], today: today);
      expect(set.items.length, lessThanOrEqualTo(dayPlan.total));
      expect(set.items, isNotEmpty);
    });
  });
}

/// buildPlan（1 教科）にも同じ内訳の計算を使う。
void splitTests() {
  group('splitDay: 重点・弱点・復習の内訳は合計に一致する', () {
    test('どの合計・どの比率でも一致し、負にならない', () {
      for (final r in [PlanRatios.normal, PlanRatios.lastMinute]) {
        for (var total = 0; total <= 60; total++) {
          final s = splitDay(total, r);
          expect(s.focus + s.weak + s.review, total, reason: 'total=$total');
          expect(s.focus >= 0 && s.weak >= 0 && s.review >= 0, isTrue, reason: 'total=$total');
        }
      }
    });
    test('これまでと同じ値になる（切り上げが重ならない場合）', () {
      expect(splitDay(10, PlanRatios.normal), (focus: 6, weak: 3, review: 1));
      expect(splitDay(5, PlanRatios.normal), (focus: 3, weak: 2, review: 0));
      expect(splitDay(10, PlanRatios.lastMinute), (focus: 5, weak: 5, review: 0));
    });
    test('重点と弱点が両方切り上がる奇数の合計は、弱点を削って合計を守る', () {
      expect(splitDay(5, PlanRatios.lastMinute), (focus: 3, weak: 2, review: 0));
    });
    test('buildPlan の全日で、内訳の合計が total に一致する', () {
      final r = buildPlan(
        today: today,
        plan: tp('math', 14),
        tree: tree(['math']),
        busyDays: [BusyDay(d(11)), BusyDay(d(12))],
        config: const PlannerConfig(baseQuantity: 5),
      );
      for (final day in r.days) {
        expect(day.focus + day.weak + day.review, day.total, reason: '${day.date}');
      }
    });
  });
}
