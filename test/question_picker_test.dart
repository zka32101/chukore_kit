import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 20);

Question q(String id, String unit, double difficulty, {Map<String, String> tags = const {}}) => Question(
      id: id,
      unitId: unit,
      type: 'choice',
      difficulty: difficulty,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e_$id',
      misconceptionTags: tags,
    );

Attempt att(String qid, String unit, bool ok, int daysAgo, {String? chosen, bool? confident}) => Attempt(
      questionId: qid,
      unitId: unit,
      correct: ok,
      chosenId: chosen,
      answeredAt: today.subtract(Duration(days: daysAgo)).add(const Duration(hours: 10)),
      confident: confident,
    );

DayPlan plan({Map<String, int> focus = const {}, int weak = 0, int review = 0}) => DayPlan(
      date: today,
      daysLeft: 10,
      total: focus.values.fold<int>(0, (s, n) => s + n) + weak + review,
      focus: focus.values.fold<int>(0, (s, n) => s + n),
      weak: weak,
      review: review,
      focusByUnit: focus,
      lastMinute: false,
    );

Map<String, Mastery> mast(Map<String, double> m) => {for (final e in m.entries) e.key: Mastery(unitId: e.key, score: e.value)};

List<String> ids(PracticeSet s) => [for (final i in s.items) i.question.id];

void main() {
  // u1: 難しさ（基準正答率）が 0.9 〜 0.4 の 6 問
  final u1 = [
    q('a1', 'u1', 0.9),
    q('a2', 'u1', 0.8),
    q('a3', 'u1', 0.7),
    q('a4', 'u1', 0.6),
    q('a5', 'u1', 0.5),
    q('a6', 'u1', 0.4),
  ];

  PracticeSet pick(
    DayPlan p,
    List<Question> qs, {
    Map<String, double> mastery = const {},
    List<Attempt> attempts = const [],
    Iterable<String>? scope,
    int seed = 0,
  }) =>
      pickPractice(
        plan: p,
        questions: qs,
        mastery: mast(mastery),
        attempts: attempts,
        today: today,
        scopeUnitIds: scope,
        seed: seed,
      );

  group('重点枠: 習熟度に合う難しさ', () {
    test('習熟度が低いとやさしい問題、高いと歯ごたえのある問題', () {
      final low = pick(plan(focus: {'u1': 2}), u1, mastery: {'u1': 0.0});
      expect(ids(low).toSet(), {'a1', 'a2'});
      final high = pick(plan(focus: {'u1': 2}), u1, mastery: {'u1': 1.0});
      // 当てたい基準正答率は 0.5。a5(0.5) が最も近く、次の 1 問は同じ距離の a4(0.6)・a6(0.4) のどちらか
      expect(ids(high).contains('a5'), isTrue);
      expect(ids(high).toSet().intersection({'a4', 'a6'}).length, 1);
      expect(ids(high).contains('a1') || ids(high).contains('a2'), isFalse);
    });

    test('単元の中はやさしい順に並ぶ', () {
      final r = pick(plan(focus: {'u1': 3}), u1, mastery: {'u1': 0.5});
      final d = [for (final i in r.items) i.question.difficulty];
      expect(d, [...d]..sort((a, b) => b.compareTo(a)));
    });

    test('単元ごとに必要な数。単元ID順', () {
      final qs = [...u1, q('b1', 'u2', 0.7), q('b2', 'u2', 0.6)];
      final r = pick(plan(focus: {'u2': 1, 'u1': 2}), qs, mastery: {'u1': 0.5, 'u2': 0.5});
      expect(r.items.map((i) => i.question.unitId), ['u1', 'u1', 'u2']);
      expect(r.items.every((i) => i.slot == PracticeSlot.focus), isTrue);
    });
  });

  group('最近の履歴', () {
    test('最近正解した問題は後回し（他に選べるうちは出ない）', () {
      final r = pick(plan(focus: {'u1': 2}), u1,
          mastery: {'u1': 0.0}, attempts: [att('a1', 'u1', true, 1), att('a2', 'u1', true, 2)]);
      expect(ids(r).toSet(), {'a3', 'a4'}, reason: 'a1・a2 は 3 日以内に正解済み');
    });

    test('3 日たったら対象に戻る（当てたい難しさに近い問題が優先される）', () {
      final two = [q('near', 'u1', 0.85), q('far', 'u1', 0.5)];
      // 習熟度 0 の当てたい基準正答率は 0.85。1 日前に正解 → 後回し、3 日前に正解 → 通常どおり
      expect(ids(pick(plan(focus: {'u1': 1}), two, attempts: [att('near', 'u1', true, 1)])), ['far']);
      expect(ids(pick(plan(focus: {'u1': 1}), two, attempts: [att('near', 'u1', true, 3)])), ['near']);
    });

    test('他に問題が無ければ、最近正解した問題も出す', () {
      final r = pick(plan(focus: {'u1': 2}), [u1[0], u1[1]], attempts: [att('a1', 'u1', true, 0), att('a2', 'u1', true, 0)]);
      expect(ids(r).toSet(), {'a1', 'a2'});
      expect(r.shortfall, isEmpty);
    });

    test('同じ難しさなら、未出題が先、次に長く解いていない問題', () {
      final same = [q('x1', 'u1', 0.7), q('x2', 'u1', 0.7), q('x3', 'u1', 0.7)];
      final r = pick(plan(focus: {'u1': 2}), same,
          attempts: [att('x1', 'u1', false, 9), att('x2', 'u1', false, 20)]);
      expect(ids(r).toSet(), {'x3', 'x2'}, reason: '未出題の x3、次に古い x2');
    });
  });

  group('復習枠', () {
    test('期限が来た問題を、遅れている順に出す。期限前は出ない', () {
      final qs = [...u1];
      final attempts = [
        att('a1', 'u1', true, 10), // 1 日後が期限 → 9 日遅れ
        att('a2', 'u1', true, 4), // 3 日遅れ
        att('a3', 'u1', true, 0), // 期限は明日
      ];
      final r = pick(plan(review: 5), qs, attempts: attempts);
      final reviewIds = [for (final i in r.items) if (i.slot == PracticeSlot.review) i.question.id];
      expect(reviewIds, ['a1', 'a2'], reason: 'a3 は期限が明日');
      expect(ids(r).length, 5, reason: '足りない 3 問は補充される');
    });

    test('復習が先頭に並ぶ', () {
      final r = pick(plan(focus: {'u1': 1}, review: 1), u1, attempts: [att('a6', 'u1', true, 5)]);
      expect(r.items.map((i) => i.slot), [PracticeSlot.review, PracticeSlot.focus]);
      expect(r.items.first.question.id, 'a6');
    });
  });

  group('弱点枠', () {
    final tagged = [
      q('t1', 'u1', 0.7, tags: {'b': 'sign_error'}),
      q('t2', 'u1', 0.6, tags: {'b': 'sign_error'}),
      q('t3', 'u1', 0.7, tags: {'b': 'unit_error'}),
      q('t4', 'u1', 0.6, tags: {'b': 'unit_error'}),
    ];

    test('誤解の型ごとに 1 問ずつ回して選ぶ。自信ありの誤答が多い型が先', () {
      final attempts = [
        att('t1', 'u1', false, 8, chosen: 'b', confident: false),
        att('t3', 'u1', false, 9, chosen: 'b', confident: true),
        att('t4', 'u1', false, 10, chosen: 'b', confident: true),
      ];
      final r = pick(plan(weak: 3), tagged, attempts: attempts);
      expect(r.items.every((i) => i.slot == PracticeSlot.weak), isTrue);
      // unit_error（自信ありの誤答 2 回）が先。型を交互に回すので sign_error の問題も入る
      final tags = [for (final i in r.items) i.question.misconceptionTags['b']];
      expect(tags.take(2).toSet(), {'unit_error', 'sign_error'});
      expect(tags.first, 'unit_error');
      expect(ids(r).toSet().length, 3, reason: '重複しない');
    });

    test('自信ありの誤答が同数なら、最近間違えた型が先', () {
      final attempts = [
        att('t1', 'u1', false, 10, chosen: 'b'), // sign_error: 10 日前
        att('t3', 'u1', false, 2, chosen: 'b'), // unit_error: 2 日前
      ];
      final r = pick(plan(weak: 1), tagged, attempts: attempts);
      expect(r.items.single.question.misconceptionTags['b'], 'unit_error');
    });

    test('克服した弱点は出さない', () {
      final attempts = [
        att('t1', 'u1', false, 12, chosen: 'b'),
        att('t1', 'u1', true, 6),
        att('t1', 'u1', true, 5),
        att('t1', 'u1', true, 4),
      ];
      final r = pick(plan(weak: 2), tagged, attempts: attempts);
      expect(r.countOf(PracticeSlot.weak), 0, reason: '弱点枠には出さない');
      expect(r.countOf(PracticeSlot.extra), 2, reason: '足りない分は補充になる');
    });

    test('間違えた問題そのものも弱点（型が無い選択肢）', () {
      final r = pick(plan(weak: 1), [...u1], attempts: [att('a3', 'u1', false, 2, chosen: 'b')]);
      expect(ids(r), ['a3']);
    });
  });

  group('枠をまたぐ', () {
    test('同じ問題を 2 つの枠で出さない', () {
      final qs = [q('t1', 'u1', 0.7, tags: {'b': 'sign_error'}), q('t2', 'u1', 0.5)];
      final attempts = [att('t1', 'u1', false, 5, chosen: 'b')]; // 弱点でもあり、復習の期限も来ている
      final r = pick(plan(review: 1, weak: 1), qs, attempts: attempts);
      expect(ids(r), ['t1', 't2'], reason: '復習で出した t1 を弱点で重ねない。足りない分は補充になる');
      expect(r.items.map((i) => i.slot), [PracticeSlot.review, PracticeSlot.extra]);
    });

    test('足りない枠は習熟度の低い単元から補充し、足りなかった数を減らす', () {
      final qs = [...u1, q('b1', 'u2', 0.7), q('b2', 'u2', 0.7)];
      final r = pick(plan(focus: {'u1': 1}, weak: 2), qs, mastery: {'u1': 0.8, 'u2': 0.1});
      expect(r.countOf(PracticeSlot.focus), 1);
      expect(r.countOf(PracticeSlot.extra), 2);
      expect(r.items.where((i) => i.slot == PracticeSlot.extra).map((i) => i.question.unitId).toSet(), {'u2'});
      expect(r.shortfall, isEmpty);
    });

    test('問題が尽きたら shortfall に残る', () {
      final r = pick(plan(focus: {'u1': 4}, weak: 3), [u1[0], u1[1]]);
      expect(r.items.length, 2);
      expect(r.shortfall.values.fold<int>(0, (s, n) => s + n), 5);
    });

    test('範囲外の単元の問題は出さない', () {
      final qs = [...u1, q('z1', 'zz', 0.7)];
      final r = pick(plan(weak: 0, review: 0, focus: {'u1': 6}), qs, scope: ['u1']);
      expect(ids(r).contains('z1'), isFalse);
    });
  });

  group('再現性', () {
    test('同じ入力なら同じ結果', () {
      final same = [for (var i = 0; i < 8; i++) q('s$i', 'u1', 0.7)];
      final a = pick(plan(focus: {'u1': 4}), same, seed: 7);
      final b = pick(plan(focus: {'u1': 4}), same, seed: 7);
      expect(ids(a), ids(b));
    });

    test('seed を変えると、同じ難しさの中の選び方だけが変わる', () {
      final same = [for (var i = 0; i < 8; i++) q('s$i', 'u1', 0.7)];
      final seeds = {for (var s = 0; s < 20; s++) ids(pick(plan(focus: {'u1': 3}), same, seed: s)).join(',')};
      expect(seeds.length, greaterThan(1));
      // 難しさの違う問題は、seed に関わらず近い方が選ばれる
      final clear = [q('near', 'u1', 0.85), q('far', 'u1', 0.4)];
      for (var s = 0; s < 10; s++) {
        expect(ids(pick(plan(focus: {'u1': 1}), clear, seed: s)), ['near'], reason: 'seed=$s');
      }
    });
  });
}
