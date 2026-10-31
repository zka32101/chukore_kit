import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree _tree() => UnitTree(1, [
      Unit(id: 'g', subject: 'math', grade: 1, title: 'G'),
      Unit(id: 'a', subject: 'math', grade: 1, title: 'A', parentId: 'g'),
      Unit(id: 'b', subject: 'math', grade: 1, title: 'B', parentId: 'g'),
      Unit(id: 'c', subject: 'math', grade: 1, title: 'C'),
    ]);

Question _q(String id, String unit, double d, {Map<String, String> tags = const {}, String type = 'choice'}) =>
    Question(
      id: id, unitId: unit, type: type, difficulty: d,
      choices: const ['x', 'y', 'z'], answer: 'x', explanationId: 'e', misconceptionTags: tags,
    );

List<Question> _bank() => [
      for (var i = 0; i < 6; i++) _q('a-e$i', 'a', 0.1),
      for (var i = 0; i < 8; i++) _q('a-n$i', 'a', 0.5),
      for (var i = 0; i < 6; i++) _q('b-n$i', 'b', 0.5),
      for (var i = 0; i < 4; i++) _q('b-h$i', 'b', 0.9),
      for (var i = 0; i < 9; i++) _q('c-n$i', 'c', 0.5),
    ];

int _count(UnitTest t, bool Function(double) f) => t.questions.where((q) => f(q.difficulty)).length;

final isArgumentError = isA<ArgumentError>();

void main() {
  test('10 問なら やさしい3 : ふつう5 : 難しい2、やさしい→ふつう→難しいの順', () {
    final t = buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 10);
    expect(t.questions.length, 10);
    expect(_count(t, (d) => d < 1 / 3), 3);
    expect(_count(t, (d) => d >= 1 / 3 && d < 2 / 3), 5);
    expect(_count(t, (d) => d >= 2 / 3), 2);
    final ds = [for (final q in t.questions) q.difficulty];
    expect(ds, [...ds]..sort());
    expect(t.exam.timeLimit, isNull);
    expect(t.shortfall, isFalse);
  });

  test('帯ごとの境界: 1/3 はふつう、2/3 は難しい', () {
    final qs = [
      for (var i = 0; i < 5; i++) _q('lo$i', 'a', 0.33),
      for (var i = 0; i < 5; i++) _q('m$i', 'a', 1 / 3),
      for (var i = 0; i < 5; i++) _q('h$i', 'a', 2 / 3),
    ];
    final t = buildUnitTest(
        questions: qs, tree: _tree(), unitIds: ['a'], count: 10, difficultyMix: const [1, 0, 0]);
    expect(t.questions.where((q) => q.id.startsWith('lo')).length, 5);
    final t2 = buildUnitTest(
        questions: qs, tree: _tree(), unitIds: ['a'], count: 5, difficultyMix: const [0, 1, 0]);
    expect(t2.questions.every((q) => q.id.startsWith('m')), isTrue);
    final t3 = buildUnitTest(
        questions: qs, tree: _tree(), unitIds: ['a'], count: 5, difficultyMix: const [0, 0, 1]);
    expect(t3.questions.every((q) => q.id.startsWith('h')), isTrue);
  });

  test('本数が割り切れないときは最大剰余法（7 問 → 2:4:1）', () {
    final t = buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 7);
    expect(_count(t, (d) => d < 1 / 3), 2);
    expect(_count(t, (d) => d >= 1 / 3 && d < 2 / 3), 4);
    expect(_count(t, (d) => d >= 2 / 3), 1);
  });

  test('ある帯の問題が足りなければ他の帯で埋める。全部足りなければ shortfall', () {
    final qs = [for (var i = 0; i < 12; i++) _q('n$i', 'a', 0.5)];
    final t = buildUnitTest(questions: qs, tree: _tree(), unitIds: ['a'], count: 10);
    expect(t.questions.length, 10);
    final few = buildUnitTest(questions: qs.take(6).toList(), tree: _tree(), unitIds: ['a'], count: 10);
    expect(few.questions.length, 6);
    expect(few.shortfall, isTrue);
    expect(few.exam.requestedCount, 10);
  });

  test('範囲外・暗記カード・除外は出ない', () {
    final qs = [..._bank(), for (var i = 0; i < 5; i++) _q('card$i', 'a', 0.1, type: 'card')];
    final t = buildUnitTest(
        questions: qs, tree: _tree(), unitIds: ['a'], count: 15, excludeQuestionIds: {'a-n0'});
    expect(t.questions.every((q) => q.unitId == 'a' && q.type != 'card' && q.id != 'a-n0'), isTrue);
    expect(t.questions.length, 13);
  });

  test('誤解の型をなるべく満遍なく入れる（型を持つ問題を優先）', () {
    final qs = [
      for (var i = 0; i < 10; i++) _q('plain$i', 'a', 0.5),
      _q('t1', 'a', 0.5, tags: {'y': 'move_term_sign'}),
      _q('t2', 'a', 0.5, tags: {'y': 'forgot_to_divide'}),
      _q('t3', 'a', 0.9, tags: {'y': 'sign_flip', 'z': 'like_terms_mixup'}),
      _q('t4', 'a', 0.1, tags: {'y': 'move_term_sign'}),
    ];
    final t = buildUnitTest(questions: qs, tree: _tree(), unitIds: ['a'], count: 5);
    expect(t.coveredTags, {'move_term_sign', 'forgot_to_divide', 'sign_flip', 'like_terms_mixup'});
    expect(t.missedTags, isEmpty);
  });

  test('問題数が少なくて入らなかった型は missedTags に出る', () {
    final qs = [
      for (var i = 0; i < 3; i++) _q('t$i', 'a', 0.5, tags: {'y': 'tag$i'}),
      for (var i = 0; i < 6; i++) _q('u$i', 'a', 0.5, tags: {'y': 'other$i'}),
    ];
    final t = buildUnitTest(questions: qs, tree: _tree(), unitIds: ['a'], count: 5);
    expect(t.coveredTags.length, 5);
    expect(t.missedTags.length, 4);
    expect(t.coveredTags.intersection(t.missedTags), isEmpty);
  });

  test('単元が偏りすぎない（同じ条件なら出題の少ない単元を先に）', () {
    final qs = [
      for (var i = 0; i < 10; i++) _q('a$i', 'a', 0.5),
      for (var i = 0; i < 10; i++) _q('b$i', 'b', 0.5),
    ];
    final t = buildUnitTest(
        questions: qs, tree: _tree(), unitIds: ['g'], count: 10, difficultyMix: const [0, 1, 0]);
    final a = t.questions.where((q) => q.unitId == 'a').length;
    expect(a, 5);
  });

  test('同じ入力なら同じ結果、seed が違えば別の選び方', () {
    List<String> ids(int seed) => [
          for (final q in buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], seed: seed).questions) q.id
        ];
    expect(ids(1), ids(1));
    expect(ids(1), isNot(ids(2)));
  });

  test('問題が 0 件でも落ちない', () {
    final t = buildUnitTest(questions: const [], tree: _tree(), unitIds: ['a']);
    expect(t.questions, isEmpty);
    expect(t.shortfall, isTrue);
  });

  test('引数の検査', () {
    expect(() => buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 4), throwsArgumentError);
    expect(() => buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 16), throwsArgumentError);
    buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 5);
    buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], count: 15);
    for (final mix in [
      [1, 2],
      [0, 0, 0],
      [1, -1, 2],
    ]) {
      expect(() => buildUnitTest(questions: _bank(), tree: _tree(), unitIds: ['g'], difficultyMix: mix),
          throwsA(allOf(isArgumentError, isNot(isA<RangeError>()))));
    }
  });

  group('採点', () {
    final at = DateTime(2026, 11, 1, 10);
    UnitTest make() => buildUnitTest(
        questions: [
          for (var i = 0; i < 10; i++)
            _q('q$i', 'a', 0.5, tags: {'y': 'tag${i % 2}'}),
        ],
        tree: _tree(),
        unitIds: ['a'],
        count: 10);

    Map<String, String> answers(UnitTest t, int right) => {
          for (var i = 0; i < t.questions.length; i++) t.questions[i].id: i < right ? 'x' : 'y',
        };

    test('8 割で できた、5 割で もう少し、それ未満で 復習しよう', () {
      final t = make();
      expect(scoreUnitTest(t, answers(t, 10), answeredAt: at).level, UnitTestLevel.done);
      expect(scoreUnitTest(t, answers(t, 8), answeredAt: at).level, UnitTestLevel.done);
      expect(scoreUnitTest(t, answers(t, 7), answeredAt: at).level, UnitTestLevel.almost);
      expect(scoreUnitTest(t, answers(t, 5), answeredAt: at).level, UnitTestLevel.almost);
      expect(scoreUnitTest(t, answers(t, 4), answeredAt: at).level, UnitTestLevel.review);
      expect(scoreUnitTest(t, const {}, answeredAt: at).level, UnitTestLevel.review);
    });

    test('履歴の mode は unit_test。誤答の型が数えられる', () {
      final t = make();
      final r = scoreUnitTest(t, answers(t, 6), answeredAt: at);
      expect(r.exam.attempts.every((a) => a.mode == 'unit_test'), isTrue);
      expect(r.exam.correct, 6);
      expect(r.mistakeTags.values.fold<int>(0, (s, n) => s + n), 4);
      expect(r.mistakeTags.keys.toSet(), {'tag0', 'tag1'});
    });

    test('未回答や鍵にない誤答は型に数えない', () {
      final t = make();
      final r = scoreUnitTest(t, {t.questions.first.id: 'z'}, answeredAt: at);
      expect(r.mistakeTags, isEmpty);
      final r2 = scoreUnitTest(t, {t.questions.first.id: 'y'}, answeredAt: at);
      expect(r2.mistakeTags.values.single, 1);
    });

    test('模試の採点は従来どおり mode=mock', () {
      final t = make();
      final r = scoreMockExam(t.exam, answers(t, 3), answeredAt: at);
      expect(r.attempts.every((a) => a.mode == 'mock'), isTrue);
    });
  });
}
