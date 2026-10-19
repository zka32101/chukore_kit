import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(String id, String unit) => Question(
      id: id,
      unitId: unit,
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
    );

PickedQuestion p(String id, String unit, [PracticeSlot slot = PracticeSlot.focus]) => PickedQuestion(q(id, unit), slot);

List<String> ids(PracticeSet s) => [for (final i in s.items) i.question.id];

void main() {
  test('単元を順に回して並べ直す。単元の中の順は変えない', () {
    final set = PracticeSet(
      items: [p('a1', 'A'), p('a2', 'A'), p('a3', 'A'), p('b1', 'B'), p('b2', 'B'), p('b3', 'B')],
      shortfall: const {},
    );
    expect(ids(interleaveByUnit(set)), ['a1', 'b1', 'a2', 'b2', 'a3', 'b3']);
  });

  test('先頭の復習枠はそのまま先頭。それ以降を混ぜる。枠は変えない', () {
    final set = PracticeSet(
      items: [
        p('r1', 'B', PracticeSlot.review),
        p('r2', 'B', PracticeSlot.review),
        p('a1', 'A'),
        p('a2', 'A'),
        p('b1', 'B', PracticeSlot.weak),
        p('b2', 'B', PracticeSlot.extra),
      ],
      shortfall: const {PracticeSlot.focus: 2},
    );
    final r = interleaveByUnit(set);
    expect(ids(r), ['r1', 'r2', 'a1', 'b1', 'a2', 'b2']);
    expect([for (final i in r.items) i.slot],
        [PracticeSlot.review, PracticeSlot.review, PracticeSlot.focus, PracticeSlot.weak, PracticeSlot.focus, PracticeSlot.extra]);
    expect(r.shortfall, {PracticeSlot.focus: 2});
  });

  test('単元の出てくる順で回る（単元ID順ではない）。偏りがあれば、残りは続けて出す', () {
    final set = PracticeSet(
      items: [p('z1', 'Z'), p('z2', 'Z'), p('z3', 'Z'), p('z4', 'Z'), p('a1', 'A')],
      shortfall: const {},
    );
    expect(ids(interleaveByUnit(set)), ['z1', 'a1', 'z2', 'z3', 'z4']);
  });

  test('3 つ以上の単元でも、問題の集まりは同じで、続けて同じ単元になるのは偏りのときだけ', () {
    final set = PracticeSet(
      items: [p('a1', 'A'), p('a2', 'A'), p('b1', 'B'), p('b2', 'B'), p('c1', 'C'), p('c2', 'C')],
      shortfall: const {},
    );
    final r = interleaveByUnit(set);
    expect(ids(r), ['a1', 'b1', 'c1', 'a2', 'b2', 'c2']);
    expect(ids(r).toSet(), ids(set).toSet());
    for (var i = 1; i < r.items.length; i++) {
      expect(r.items[i].question.unitId, isNot(r.items[i - 1].question.unitId));
    }
  });

  test('空・復習だけ・1 単元だけは、そのまま。入力は変えない', () {
    expect(interleaveByUnit(const PracticeSet(items: [], shortfall: {})).items, isEmpty);
    final only = PracticeSet(items: [p('r1', 'A', PracticeSlot.review)], shortfall: const {});
    expect(ids(interleaveByUnit(only)), ['r1']);
    final one = PracticeSet(items: [p('a1', 'A'), p('a2', 'A')], shortfall: const {});
    expect(ids(interleaveByUnit(one)), ['a1', 'a2']);
    expect(ids(one), ['a1', 'a2']);
  });
}
