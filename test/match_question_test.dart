
import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(String answer, {List<String>? choices, Map<String, String> tags = const {}}) => Question(
  id: 'm1',
  unitId: 'u',
  type: 'match',
  difficulty: 0.5,
  choices: choices ?? const ['a', 'b', 'c', 'x', 'y', 'z'],
  answer: answer,
  explanationId: 'e',
  misconceptionTags: tags,
);

void main() {
  group('parseMatchAnswer / parseMatchInput', () {
    test('正解の書き方: 左:右 を ; で区切る。前後の空白は無視', () {
      expect(parseMatchAnswer('a:x;b:y;c:z'), [
        const MatchPair('a', 'x'),
        const MatchPair('b', 'y'),
        const MatchPair('c', 'z'),
      ]);
      expect(parseMatchAnswer(' a : x ; b : y '), [const MatchPair('a', 'x'), const MatchPair('b', 'y')]);
      expect(const MatchPair('a', 'x').toString(), 'a:x');
      expect(const MatchPair('a', 'x'), const MatchPair('a', 'x'));
      expect(const MatchPair('a', 'x') == const MatchPair('a', 'y'), isFalse);
      expect(const MatchPair('a', 'x').hashCode, const MatchPair('a', 'x').hashCode);
    });
    test('書き間違いは null（コロンが 1 つでない・空の ID・組が無い）', () {
      for (final bad in ['', 'a', 'a:', ':x', 'a:x:y', 'a:x;', 'a:x;;b:y', ';', 'a:x;b']) {
        expect(parseMatchAnswer(bad), isNull, reason: '"$bad"');
      }
    });
    test('入力: ; ； 改行で区切り、: ： で左右を分ける。読めない項目は null として残る', () {
      expect(parseMatchInput('a:x;b：y；c:z\nd:w'), [
        const MatchPair('a', 'x'),
        const MatchPair('b', 'y'),
        const MatchPair('c', 'z'),
        const MatchPair('d', 'w'),
      ]);
      expect(parseMatchInput('a:x\nb:y'), [const MatchPair('a', 'x'), const MatchPair('b', 'y')]);
      expect(parseMatchInput('a:x;;  ;b:y'), [const MatchPair('a', 'x'), const MatchPair('b', 'y')]);
      expect(parseMatchInput('a:x;b;c:;:d;e:f:g'), <MatchPair?>[const MatchPair('a', 'x'), null, null, null, null]);
      expect(parseMatchInput(''), isEmpty);
    });
  });

  group('判定 checkAnswer', () {
    final question = q('a:x;b:y;c:z');
    test('全部合えば正解。順不同・全角・空白・改行でもよい', () {
      for (final input in ['a:x;b:y;c:z', 'c:z;a:x;b:y', ' b:y ; c:z ; a:x', 'a：x；b：y；c：z', 'a:x\nb:y\nc:z']) {
        final r = checkAnswer(question, input);
        expect(r.correct, isTrue, reason: input);
        expect(r.score, 1.0);
        expect(r.misconceptionTag, isNull);
      }
    });
    test('一部だけ合う: 部分点（合い − 誤り）÷ 全組。0 を下回らない', () {
      expect(checkAnswer(question, 'a:x;b:y').correct, isFalse);
      expect(checkAnswer(question, 'a:x;b:y').score, closeTo(2 / 3, 1e-9));
      expect(checkAnswer(question, 'a:x').score, closeTo(1 / 3, 1e-9));
      expect(checkAnswer(question, 'a:x;b:z').score, 0.0); // 合い 1 − 誤り 1
      expect(checkAnswer(question, 'a:x;b:y;c:y').score, closeTo(1 / 3, 1e-9)); // 合い 2 − 誤り 1
      expect(checkAnswer(question, 'a:y;b:z;c:x').score, 0.0);
      expect(checkAnswer(question, '').score, 0.0);
      expect(checkAnswer(question, '').correct, isFalse);
    });
    test('余分な組があると正解にならない（全部合っていても、誤りの組があれば）', () {
      final r = checkAnswer(question, 'a:x;b:y;c:z;a:y');
      expect(r.correct, isFalse);
      expect(r.score, closeTo(2 / 3, 1e-9)); // 合い 3 − 誤り 1
    });
    test('同じ組の重ね書きは加点も減点もしない', () {
      expect(checkAnswer(question, 'a:x;a:x;b:y;c:z').correct, isTrue);
      expect(checkAnswer(question, 'a:x;a:x;a:x').score, closeTo(1 / 3, 1e-9));
      expect(checkAnswer(question, 'a:y;a:y').score, 0.0);
    });
    test('読み込めない項目は誤りの組として数える。ID の大文字小文字は区別する', () {
      expect(checkAnswer(question, 'a:x;b:y;c:z;oops').correct, isFalse);
      expect(checkAnswer(question, 'a:x;b:y;c:z;oops').score, closeTo(2 / 3, 1e-9));
      expect(checkAnswer(question, 'a:x;b:y;oops;oops').score, 0.0); // 読めない項目 2 つは別々に数える（合い 2 − 誤り 2）
      expect(checkAnswer(question, 'A:x;b:y;c:z').correct, isFalse);
    });
    test('誤りの組のタグ: 入力の並びで最初のものを返す。正解にはタグを付けない', () {
      final t = q('a:x;b:y;c:z', tags: {'a:y': 'swap_ab', 'b:x': 'swap_ab', 'c:x': 'other'});
      expect(checkAnswer(t, 'a:y;b:x;c:z').misconceptionTag, 'swap_ab');
      expect(checkAnswer(t, 'c:x;a:y;b:z').misconceptionTag, 'other');
      expect(checkAnswer(t, 'a:x;b:y;c:y').misconceptionTag, isNull); // タグのない誤り
      expect(checkAnswer(t, 'a:x;b:y;c:z').misconceptionTag, isNull);
      expect(checkAnswer(t, 'a:x;b:y').misconceptionTag, isNull); // 足りないだけ
    });
    test('正解が書き間違いの問題は不正解', () {
      expect(checkAnswer(q('a:x;b'), 'a:x;b:y').correct, isFalse);
    });
  });

  group('検証', () {
    final tree = UnitTree(1, [Unit(id: 'u', subject: 'x', grade: 1, title: 'u', estimatedQuestions: 5)]);
    List<String> codes(Question x) => validateQuestionBank(questions: [x], tree: tree).map((i) => i.code).toList();

    test('正常な問題は問題なし（タグ付きでも）', () {
      expect(codes(q('a:x;b:y;c:z')), isEmpty);
      expect(codes(q('a:x;b:y;c:z', tags: {'a:y': 'swap_ab'})), isEmpty);
      expect(knownQuestionTypes, contains('match'));
    });
    test('書き間違い・2 組未満', () {
      expect(codes(q('a:x;b')), contains('match_answer_invalid'));
      expect(codes(q('a:x', choices: ['a', 'x'])), contains('match_too_few'));
    });
    test('左右の ID の重複・重なり（1 対 1 の対応でない）', () {
      expect(codes(q('a:x;a:y', choices: ['a', 'x', 'y'])), contains('match_left_duplicate'));
      expect(codes(q('a:x;b:x', choices: ['a', 'b', 'x'])), contains('match_right_duplicate'));
      expect(codes(q('a:b;b:c', choices: ['a', 'b', 'c'])), contains('match_side_overlap'));
    });
    test('choices は左右の ID すべて（過不足なし）', () {
      expect(codes(q('a:x;b:y', choices: ['a', 'b', 'x'])), contains('match_choices_mismatch')); // 足りない
      expect(codes(q('a:x;b:y', choices: ['a', 'b', 'x', 'y', 'z'])), contains('match_choices_mismatch')); // 余分
      expect(codes(q('a:x;b:y', choices: ['a', 'b', 'x', 'y'])), isEmpty);
      expect(codes(q('a:x;b:y', choices: ['a', 'b', 'x', 'x'])), contains('choices_duplicate'));
    });
    test('タグの組: 1 組の形・正解の組には付けない・左右がこの問題にある・書式', () {
      expect(codes(q('a:x;b:y;c:z', tags: {'a:x': 'bad_tag'})), contains('tag_on_answer'));
      expect(codes(q('a:x;b:y;c:z', tags: {'a:': 'swap'})), contains('match_tag_pair_invalid'));
      expect(codes(q('a:x;b:y;c:z', tags: {'a:y;b:x': 'swap'})), contains('match_tag_pair_invalid'));
      expect(codes(q('a:x;b:y;c:z', tags: {'q:y': 'swap'})), contains('match_tag_pair_invalid'));
      expect(codes(q('a:x;b:y;c:z', tags: {'a:q': 'swap'})), contains('match_tag_pair_invalid'));
      expect(codes(q('a:x;b:y;c:z', tags: {'a:y': 'Bad Tag'})), contains('tag_format'));
      expect(codes(q('a:x;b:y;c:z', tags: {'a:y': 'swap'})), isNot(contains('tags_ignored')));
    });
    test('JSON から読めて、形式の説明の例（docs/question_bank_format.md）どおりに判定される', () {
      final bank = parseQuestionBank({
        'version': 1,
        'questions': [
          {
            'id': 'en1_be_002',
            'unitId': 'u',
            'type': 'match',
            'difficulty': 0.7,
            'choices': ['I', 'you', 'he', 'am', 'are', 'is'],
            'answer': 'I:am;you:are;he:is',
            'explanationId': 'exp_en1_be_002',
            'misconceptionTags': {'I:is': 'be_agreement', 'he:are': 'be_agreement'},
          },
        ],
      });
      expect(bank.issues, isEmpty);
      final m = bank.questions.single;
      expect(validateQuestionBank(questions: [m], tree: tree), isEmpty);
      expect(checkAnswer(m, m.answer).correct, isTrue);
      expect(checkAnswer(m, 'I:is;you:are;he:is').misconceptionTag, 'be_agreement');
      expect(Question.fromJson(m.toJson()).answer, m.answer);
    });
  });
}
