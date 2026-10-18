import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 1, 10);

Question q(String id, {String unit = 'u1', String type = 'choice', Map<String, String> tags = const {}}) => Question(
      id: id,
      unitId: unit,
      type: type,
      difficulty: 0.5,
      choices: const ['a', 'b', 'c', 'd'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: tags,
    );

/// 問題 [qid] で、選択肢ごとの選択回数 [counts] の履歴を作る。
List<Attempt> picks(String qid, Map<String, int> counts, {String mode = 'practice', int hints = 0, String unit = 'u1'}) => [
      for (final e in counts.entries)
        for (var i = 0; i < e.value; i++)
          Attempt(
            questionId: qid,
            unitId: unit,
            correct: e.key == 'a',
            answeredAt: t0.add(Duration(minutes: i)),
            chosenId: e.key,
            mode: mode,
            hintsUsed: hints,
          ),
    ];

void main() {
  group('旗の判定', () {
    test('popularUntagged: 型の無い誤答が誤答の 25% 以上かつ 5 回以上', () {
      final r = analyzeDistractors(picks('x', {'a': 40, 'b': 30, 'c': 20, 'd': 10}), [q('x')]);
      expect(r.single.flags, {DistractorFlag.popularUntagged});
      expect(r.single.popularUntagged.map((o) => o.id), ['b', 'c'],
          reason: 'd は 10/60=16.7% で足りない');
    });

    test('型が付いている誤答は popularUntagged にしない', () {
      final r = analyzeDistractors(picks('x', {'a': 40, 'b': 30, 'c': 20, 'd': 10}), [q('x', tags: {'b': 't1', 'c': 't2'})]);
      expect(r, isEmpty);
    });

    test('回数が minChosen に満たなければ立たない（割合は高くても）', () {
      // 誤答 6 のうち b=4（67%）だが 5 回未満
      final r = analyzeDistractors(picks('x', {'a': 35, 'b': 4, 'c': 1}), [q('x')]);
      expect(r.single.flags, isNot(contains(DistractorFlag.popularUntagged)));
      final r2 = analyzeDistractors(picks('x', {'a': 35, 'b': 4, 'c': 1}), [q('x')], minChosen: 4);
      expect(r2.single.flags, contains(DistractorFlag.popularUntagged));
    });

    test('境界: 誤答の割合がちょうど 25% なら立つ。正解と同数なら beatsAnswer にしない', () {
      final r = analyzeDistractors(picks('x', {'a': 30, 'b': 5, 'c': 15}), [q('x', tags: {'c': 't'})]);
      expect(r.single.popularUntaggedIds, {'b'});
      final tie = analyzeDistractors(picks('x', {'a': 10, 'b': 10, 'c': 5, 'd': 5}), [q('x', tags: {'b': 't', 'c': 't', 'd': 't'})]);
      expect(tie, isEmpty);
    });

    test('neverChosen: 1 回も選ばれない誤答がある', () {
      final r = analyzeDistractors(picks('x', {'a': 30, 'b': 10, 'c': 10}), [q('x', tags: {'b': 't', 'c': 't'})]);
      expect(r.single.flags, {DistractorFlag.neverChosen});
      expect(r.single.options.firstWhere((o) => o.id == 'd').chosen, 0);
    });

    test('beatsAnswer: 誤答が正解より多い', () {
      final r = analyzeDistractors(picks('x', {'a': 10, 'b': 25, 'c': 3, 'd': 2}), [q('x', tags: {'b': 't', 'c': 't', 'd': 't'})]);
      expect(r.single.flags, {DistractorFlag.beatsAnswer});
      expect(r.single.correctRate, closeTo(0.25, 1e-9));
      expect(r.single.shareOfWrong('b'), closeTo(25 / 30, 1e-9));
      expect(r.single.shareOfWrong('a'), 0, reason: '正解は誤答の割合に含めない');
    });

    test('気になる点が無い問題は返さない', () {
      final r = analyzeDistractors(picks('x', {'a': 40, 'b': 8, 'c': 7, 'd': 5}), [q('x', tags: {'b': 't', 'c': 't', 'd': 't'})]);
      expect(r, isEmpty);
    });
  });

  group('数える回答', () {
    final tagged = q('x', tags: {'b': 't', 'c': 't'}); // d が 0 回なら neverChosen
    final base = {'a': 30, 'b': 10, 'c': 10};

    test('minAttempts 未満は調べない', () {
      expect(analyzeDistractors(picks('x', {'a': 15, 'b': 10, 'c': 4}), [tagged]), isEmpty);
      expect(analyzeDistractors(picks('x', {'a': 15, 'b': 10, 'c': 5}), [tagged]), hasLength(1));
    });

    test('ヒントを使った回答・別モード・選択肢にないIDは数えない', () {
      final noise = [
        ...picks('x', {'d': 50}, hints: 1),
        ...picks('x', {'d': 50}, mode: 'mock'),
        ...picks('x', {'zzz': 50}),
        Attempt(questionId: 'x', unitId: 'u1', correct: false, answeredAt: t0),
      ];
      final r = analyzeDistractors([...picks('x', base), ...noise], [tagged]);
      expect(r.single.attempts, 50);
      expect(r.single.options.firstWhere((o) => o.id == 'd').chosen, 0);
      expect(analyzeDistractors([...picks('x', {'a': 30, 'b': 10, 'c': 10}, mode: 'mock')], [tagged]), isEmpty);
      expect(analyzeDistractors(picks('x', {'a': 30, 'b': 10, 'c': 10}, mode: 'mock'), [tagged], mode: 'mock'), hasLength(1));
    });

    test('choice・map だけを調べる', () {
      final qs = [q('x', type: 'numeric', tags: {'b': 't', 'c': 't'}), q('m', type: 'map', tags: {'b': 't', 'c': 't'})];
      final r = analyzeDistractors([...picks('x', base), ...picks('m', base)], qs);
      expect(r.map((e) => e.questionId), ['m']);
    });

    test('minAttempts が 1 未満ならエラー', () {
      expect(() => analyzeDistractors(const [], const [], minAttempts: 0), throwsArgumentError);
    });
  });

  group('並びと単元ごとの集計', () {
    test('旗の数 → 回答数 → 問題ID（ID順と回答数順が逆になるよう仕込む）', () {
      final tags = {'b': 't', 'c': 't'};
      final qs = [q('a_few', tags: tags), q('b_many', tags: tags), q('c_two', tags: {'b': 't'})];
      final a = [
        ...picks('a_few', {'a': 30, 'b': 10, 'c': 10}), // neverChosen 1 つ・50 回
        ...picks('b_many', {'a': 40, 'b': 20, 'c': 20}), // neverChosen 1 つ・80 回
        // 旗 2 つ: c が popular かつ正解より多い、d は 0 回
        ...picks('c_two', {'a': 5, 'b': 15, 'c': 20}),
      ];
      expect(analyzeDistractors(a, qs).map((e) => e.questionId), ['c_two', 'b_many', 'a_few']);
      final c = analyzeDistractors(a, qs).first;
      expect(c.flags, {DistractorFlag.neverChosen, DistractorFlag.beatsAnswer, DistractorFlag.popularUntagged});
    });

    test('untaggedCandidatesByUnit: popularUntagged のある問題を単元ごとに。多い単元が先', () {
      final qs = [
        q('p1', unit: 'a_unit'),
        q('p2', unit: 'z_unit'),
        q('p3', unit: 'z_unit'),
        q('n1', unit: 'z_unit', tags: {'b': 't', 'c': 't', 'd': 't'}),
      ];
      final a = [
        for (final id in ['p1', 'p2', 'p3', 'n1']) ...picks(id, {'a': 40, 'b': 30, 'c': 20, 'd': 10}, unit: 'x'),
      ];
      final by = untaggedCandidatesByUnit(analyzeDistractors(a, qs));
      expect(by.keys.toList(), ['z_unit', 'a_unit']);
      expect(by['z_unit']!.map((e) => e.questionId).toSet(), {'p2', 'p3'});
    });
  });
}
