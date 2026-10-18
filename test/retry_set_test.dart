import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 20);

Question q(String id, {Map<String, String> tags = const {}, String unit = 'u1'}) => Question(
      id: id,
      unitId: unit,
      type: 'choice',
      difficulty: 0.6,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e_$id',
      misconceptionTags: tags,
    );

Attempt att(String qid, bool ok, int daysAgo, {String? chosen, bool? confident, int elapsedMs = 20000}) => Attempt(
      questionId: qid,
      unitId: 'u1',
      correct: ok,
      chosenId: chosen,
      answeredAt: today.subtract(Duration(days: daysAgo)).add(const Duration(hours: 10)),
      confident: confident,
      elapsedMs: elapsedMs,
    );

List<String> ids(RetrySet s) => [for (final x in s.questions) x.id];

void main() {
  const sign = {'b': 'sign_error'};
  const unit = {'b': 'unit_error'};
  final qs = [
    q('s1', tags: sign),
    q('s2', tags: sign),
    q('s3', tags: sign),
    q('s4', tags: sign),
    q('u1', tags: unit),
    q('u2', tags: unit),
    q('plain'),
  ];

  List<RetrySet> build(List<Attempt> attempts, {int perSet = 5, bool includeOvercome = false}) =>
      buildRetrySets(attempts: attempts, questions: qs, perSet: perSet, includeOvercome: includeOvercome);

  group('セットの中身', () {
    test('型ごとに 1 セット。未出題 → 間違えた問題（最近順）→ 解いたことのある問題（古い順）', () {
      final attempts = [
        att('s1', false, 9, chosen: 'b'), // 間違えた（古い）
        att('s2', false, 3, chosen: 'b'), // 間違えた（最近）
        att('s3', true, 20), // 解いたことがある（正解）
        // s4 は未出題
      ];
      final sets = build(attempts);
      expect(sets.map((s) => s.key), ['tag:sign_error']);
      expect(ids(sets.single), ['s4', 's2', 's1', 's3']);
      expect(sets.single.isTag, isTrue);
    });

    test('解いたことのある問題は、古く解いた順（忘れかけた問題が先）', () {
      final sets = build([
        att('s1', false, 2, chosen: 'b'),
        att('s3', true, 20),
        att('s4', true, 40),
        att('s2', true, 30),
      ]);
      expect(ids(sets.single), ['s1', 's4', 's2', 's3'], reason: '未出題は無し → 間違えた s1 → 古い順に s4(40日前)・s2(30日前)・s3(20日前)');
    });

    test('perSet で問題数を絞る。先頭は未出題の問題（答えを覚えただけで通れない）', () {
      final sets = build([att('s1', false, 5, chosen: 'b')], perSet: 2);
      expect(ids(sets.single), ['s2', 's3'], reason: '未出題を先に。s1（間違えた問題）は後ろ');
    });

    test('問題が少ない型は、あるものだけ', () {
      final sets = buildRetrySets(
        attempts: [att('s1', false, 2, chosen: 'b')],
        questions: [q('s1', tags: sign)],
      );
      expect(ids(sets.single), ['s1']);
    });

    test('型の無い選択肢の誤答は、その問題 1 問のセット', () {
      final sets = build([att('plain', false, 1, chosen: 'b')]);
      expect(sets.single.key, 'q:plain');
      expect(sets.single.isTag, isFalse);
      expect(ids(sets.single), ['plain']);
    });
  });

  group('セットの並びと対象', () {
    test('自信ありで誤答が多い型が先。同数なら最近間違えた型が先', () {
      final attempts = [
        att('s1', false, 1, chosen: 'b', confident: false), // sign_error: 最近だが自信なし
        att('u1', false, 8, chosen: 'b', confident: true), // unit_error: 古いが自信あり
      ];
      final sets = build(attempts);
      expect(sets.map((s) => s.key), ['tag:unit_error', 'tag:sign_error']);
      expect(sets.first.hasConfidentMistakes, isTrue);
      expect(sets.last.hasConfidentMistakes, isFalse);

      final tie = build([att('s1', false, 5, chosen: 'b'), att('u1', false, 2, chosen: 'b')]);
      expect(tie.map((s) => s.key), ['tag:unit_error', 'tag:sign_error']);
    });

    test('克服した型は含めない。includeOvercome で後ろに付く', () {
      final attempts = [
        att('s1', false, 12, chosen: 'b'),
        att('s1', true, 6),
        att('s1', true, 5),
        att('s1', true, 4),
        att('u1', false, 2, chosen: 'b'),
      ];
      expect(build(attempts).map((s) => s.key), ['tag:unit_error']);
      expect(build(attempts, includeOvercome: true).map((s) => s.key), ['tag:unit_error', 'tag:sign_error']);
    });

    test('ケアレスミスの疑いの誤答は、誤解として数えない（既定）', () {
      // sign_error の問題は、正解の回答が長め（40 秒）。その単元の中央値の 35% 未満（10 秒）で間違えた → ケアレス
      final attempts = [
        for (var i = 0; i < 6; i++) att('plain', true, 30 - i, elapsedMs: 40000),
        att('s1', false, 1, chosen: 'b', elapsedMs: 3000),
      ];
      expect(build(attempts), isEmpty);
    });

    test('間違いが無ければ空。問題集に無い問題の誤答は無視', () {
      expect(build(const []), isEmpty);
      expect(build([att('ghost', false, 1, chosen: 'b')]), isEmpty);
    });

    test('perSet は 1 以上', () {
      expect(() => build(const [], perSet: 0), throwsArgumentError);
    });
  });

  test('同じ入力なら同じ結果。履歴の順は関係ない', () {
    final attempts = [
      att('s1', false, 9, chosen: 'b'),
      att('s2', false, 3, chosen: 'b'),
      att('u1', false, 5, chosen: 'b', confident: true),
    ];
    String show(List<RetrySet> x) => x.map((s) => '${s.key}:${ids(s).join(',')}').join('|');
    expect(show(build(attempts)), show(build(attempts.reversed.toList())));
  });

  group('共有の関数', () {
    test('questionsForWeakEntry: 型は同じ型の問題すべて、問題単位はその問題だけ', () {
      final tag = WeakEntry(key: 'tag:sign_error', tag: 'sign_error', wrongCount: 1, lastWrongAt: today, overcome: false);
      final one = WeakEntry(key: 'q:plain', questionId: 'plain', wrongCount: 1, lastWrongAt: today, overcome: false);
      expect(questionsForWeakEntry(tag, qs).map((x) => x.id), ['s1', 's2', 's3', 's4']);
      expect(questionsForWeakEntry(one, qs).map((x) => x.id), ['plain']);
    });

    test('prioritizeWeak: 克服済みは除く（includeOvercome で後ろ）', () {
      WeakEntry e(String key, {int conf = 0, int daysAgo = 1, bool overcome = false}) => WeakEntry(
          key: key, tag: key, wrongCount: 1, confidentWrongCount: conf, lastWrongAt: today.subtract(Duration(days: daysAgo)), overcome: overcome);
      final list = [e('c', overcome: true), e('a', daysAgo: 5), e('b', conf: 2, daysAgo: 9)];
      expect(prioritizeWeak(list).map((x) => x.key), ['b', 'a']);
      expect(prioritizeWeak(list, includeOvercome: true).map((x) => x.key), ['b', 'a', 'c']);
    });
  });
}
