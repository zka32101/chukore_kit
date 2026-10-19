import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 9, 1, 10);

Question q(String id, {double difficulty = 0.5, Map<String, String> tags = const {}}) => Question(
      id: id,
      unitId: 'u1',
      type: 'choice',
      difficulty: difficulty,
      choices: const ['a', 'b', 'c', 'd'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: tags,
    );

/// 問題 [qid] の選択肢ごとの選択回数。
List<Attempt> picks(String qid, Map<String, int> counts) => [
      for (final e in counts.entries)
        for (var i = 0; i < e.value; i++)
          Attempt(questionId: qid, unitId: 'u1', correct: e.key == 'a', answeredAt: t0, chosenId: e.key),
    ];

void main() {
  test('回答が無ければ「直すところは無い」。何も出ない', () {
    final r = buildQualityReport(const [], [q('x')]);
    expect(r.isClean, isTrue);
    expect(r.attemptCount, 0);
    expect(r.questionCount, 1);
    final md = r.toMarkdown();
    expect(md, contains('回答 0 件 / 問題 1 問'));
    expect(md, contains('直すところは見つかりませんでした'));
    expect(md, isNot(contains('## ')));
  });

  test('難易度のずれ・誤答の選択肢・型の候補が、それぞれの節に出る', () {
    // 基準 0.9 なのに実測 40%（ずれ）。b（50%）と c（33%）が誤答の 25% 以上・型なし（型の候補・popularUntagged）。d（17%）は足りない
    final a = picks('x', {'a': 40, 'b': 30, 'c': 20, 'd': 10});
    final r = buildQualityReport(a, [q('x', difficulty: 0.9)]);
    expect(r.isClean, isFalse);
    expect(r.calibration.drifts.single.questionId, 'x');
    expect(r.distractors.single.flags, contains(DistractorFlag.popularUntagged));
    expect(r.tagDrafts.first.optionId, 'b');
    final md = r.toMarkdown();
    expect(md, contains('回答 100 件 / 問題 1 問'));
    expect(md, contains('## 難易度のずれ'));
    expect(md, contains('| x | u1 | 100 | 40% | 90% | 0.40 |'));
    expect(md, contains('## 誤答の選択肢'));
    expect(md, contains('型の無い人気の誤答'));
    expect(md, contains('## 誤解の型の候補'));
    expect(md, contains('| x | b | 30 | 50% | `t_u1_x_b` |'));
    expect(md, isNot(contains('## 復習間隔の提案')), reason: '復習の回答が足りず、提案は無い');
    expect(md, contains('難易度のずれ 1 / 誤答の選択肢 1 / 誤解の型の候補 2 / 復習間隔の変更 0'));
  });

  test('問題が違えば別々に数える。基準どおりで旗も無い問題は出ない', () {
    final a = [...picks('ok', {'a': 40, 'b': 8, 'c': 7, 'd': 5}), ...picks('bad', {'a': 10, 'b': 25, 'c': 3, 'd': 2})];
    final r = buildQualityReport(a, [
      q('ok', difficulty: 0.67, tags: {'b': 't', 'c': 't', 'd': 't'}),
      q('bad', difficulty: 0.25, tags: {'b': 't', 'c': 't', 'd': 't'}),
    ]);
    expect(r.distractors.map((d) => d.questionId), ['bad']);
    expect(r.calibration.drifts, isEmpty);
    expect(r.toMarkdown(), isNot(contains('| ok |')));
  });

  test('旗が無くても、難易度のずれだけで「直すところ」になる', () {
    final a = picks('x', {'a': 40, 'b': 10, 'c': 10, 'd': 10}); // 正答率 57%。誤答は均等で型もある
    final r = buildQualityReport(a, [q('x', difficulty: 0.9, tags: {'b': 't', 'c': 't', 'd': 't'})]);
    expect(r.distractors, isEmpty);
    expect(r.isClean, isFalse);
  });

  test('選ばれない誤答・正解より人気の誤答は、それぞれの名前で出る', () {
    final a = [...picks('n', {'a': 30, 'b': 10, 'c': 10}), ...picks('p', {'a': 10, 'b': 25, 'c': 3, 'd': 2})];
    final tags = {'b': 't', 'c': 't', 'd': 't'};
    final md = buildQualityReport(a, [q('n', difficulty: 0.6, tags: tags), q('p', difficulty: 0.25, tags: tags)]).toMarkdown();
    expect(md, contains('| n | u1 | 50 | 60% | 選ばれない誤答 |'));
    expect(md, contains('| p | u1 | 40 | 25% | 誤答が正解より人気 |'));
  });

  test('表は maxRows 行まで。残りは「ほか N 件」', () {
    final a = [for (var i = 0; i < 5; i++) ...picks('q$i', {'a': 40, 'b': 30, 'c': 20, 'd': 10})];
    final r = buildQualityReport(a, [for (var i = 0; i < 5; i++) q('q$i', difficulty: 0.9)]);
    final md = r.toMarkdown(maxRows: 2);
    expect(md, contains('（ほか 3 件）'));
    expect(RegExp(r'\| q\d \| u1 \| 100 \|').allMatches(md.split('## 誤答の選択肢').first).length, 2);
    final sections = md.split('## ');
    int rows(String title, RegExp row) => row.allMatches(sections.firstWhere((x) => x.startsWith(title))).length;
    expect(rows('誤答の選択肢', RegExp(r'\| q\d \| u1 \|')), 2);
    expect(rows('誤解の型の候補', RegExp(r'\| q\d \| [bc] \|')), 2);
    // 型の候補は 5 問 × 2 = 10 行。10 行まで出せば「ほか」は付かない
    expect(r.toMarkdown(maxRows: 10), isNot(contains('ほか')));
    expect(r.toMarkdown(maxRows: 9), contains('（ほか 1 件）'));
  });

  test('復習間隔の変更があれば提案の節が出る', () {
    // 箱 1 で 40 問中 10 問しか思い出せない → 間隔を短くする提案
    final a = [
      for (var i = 0; i < 40; i++) ...[
        Attempt(questionId: 'r$i', unitId: 'u1', correct: true, answeredAt: t0),
        Attempt(questionId: 'r$i', unitId: 'u1', correct: true, answeredAt: t0.add(const Duration(days: 1))),
        Attempt(questionId: 'r$i', unitId: 'u1', correct: i < 10, answeredAt: t0.add(const Duration(days: 4))),
      ],
    ];
    final r = buildQualityReport(a, [for (var i = 0; i < 40; i++) q('r$i')]);
    expect(r.tuning.changed, isTrue);
    final md = r.toMarkdown();
    expect(md, contains('## 復習間隔の提案'));
    expect(md, contains('| 1 | 40 | 25% | 3 | 2 |'));
    expect(md, contains('復習間隔の変更 1'));
    expect(md, isNot(contains('| 2 | 0 |')), reason: '変わらない箱は載せない');
  });
}
