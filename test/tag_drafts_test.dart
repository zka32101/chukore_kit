import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 1, 10);

Question q(String id, {String unit = 'u1', Map<String, String> tags = const {}, int version = 1}) => Question(
      id: id,
      unitId: unit,
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b', 'c', 'd'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: tags,
      version: version,
    );

List<Attempt> picks(String qid, Map<String, int> counts, {String unit = 'u1'}) => [
      for (final e in counts.entries)
        for (var i = 0; i < e.value; i++)
          Attempt(questionId: qid, unitId: unit, correct: e.key == 'a', answeredAt: t0, chosenId: e.key),
    ];

void main() {
  group('下書き', () {
    test('人気の型なし誤答ごとに作る。多い順（同数は問題ID→選択肢ID）。型名は検証を通る形', () {
      final qs = [q('z1'), q('a1', unit: 'Unit-2')];
      final a = [
        ...picks('z1', {'a': 40, 'b': 30, 'c': 20, 'd': 10}), // b 30, c 20
        ...picks('a1', {'a': 40, 'b': 20, 'c': 20, 'd': 20}, unit: 'Unit-2'), // b,c,d 各 20
      ];
      final d = suggestTagDrafts(analyzeDistractors(a, qs));
      expect([for (final x in d) '${x.questionId}/${x.optionId}'], ['z1/b', 'a1/b', 'a1/c', 'a1/d', 'z1/c']);
      expect(d.first.chosen, 30);
      expect(d.first.shareOfWrong, closeTo(0.5, 1e-9));
      expect(d[1].suggestedTag, 't_unit_2_a1_b', reason: '大文字・記号は小文字と _ にする');
      for (final x in d) {
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(x.suggestedTag), isTrue, reason: x.suggestedTag);
      }
    });

    test('型が付いた誤答・旗の無い問題からは作らない', () {
      final r = analyzeDistractors(picks('x', {'a': 40, 'b': 30, 'c': 20, 'd': 10}), [q('x', tags: {'b': 't', 'c': 't'})]);
      expect(suggestTagDrafts(r), isEmpty);
      expect(suggestTagDrafts(const []), isEmpty);
    });
  });

  group('反映', () {
    test('型を付けて version を 1 上げる。付けた問題だけ', () {
      final out = applyTagDrafts([q('x', version: 3), q('y')], [(questionId: 'x', optionId: 'b', tag: 'my_tag')]);
      expect(out[0].misconceptionTags, {'b': 'my_tag'});
      expect(out[0].version, 4);
      expect(out[1].version, 1);
    });

    test('正解の選択肢・存在しない選択肢・すでに型がある選択肢には付けない（そのまま返す）', () {
      final base = q('x', tags: {'b': 'old'});
      final out = applyTagDrafts([base], [
        (questionId: 'x', optionId: 'a', tag: 'bad'),
        (questionId: 'x', optionId: 'zzz', tag: 'bad'),
        (questionId: 'x', optionId: 'b', tag: 'new'),
        (questionId: 'nope', optionId: 'c', tag: 'bad'),
      ]);
      expect(identical(out.single, base), isTrue);
    });

    test('既存の型を残して足す', () {
      final out = applyTagDrafts([q('x', tags: {'b': 'old'})], [(questionId: 'x', optionId: 'c', tag: 'new_tag')]);
      expect(out.single.misconceptionTags, {'b': 'old', 'c': 'new_tag'});
      expect(out.single.version, 2);
    });
  });
}
