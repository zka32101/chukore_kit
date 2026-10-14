import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree _tree() => UnitTree(1, const [
      Unit(id: 'g', subject: 'en', grade: 1, title: 'G'),
      Unit(id: 'u1', subject: 'en', grade: 1, parentId: 'g', title: 'U1', estimatedQuestions: 10),
      Unit(id: 'u2', subject: 'en', grade: 1, parentId: 'g', title: 'U2', estimatedQuestions: 10),
    ]);

Question _q({
  String id = 'q1',
  String unit = 'u1',
  String type = 'choice',
  double difficulty = .5,
  List<String> choices = const ['a', 'b', 'c'],
  String answer = 'a',
  String explanation = 'x',
  Map<String, String> tags = const {},
  int version = 1,
}) =>
    Question(
      id: id, unitId: unit, type: type, difficulty: difficulty, choices: choices,
      answer: answer, explanationId: explanation, misconceptionTags: tags, version: version,
    );

Set<String> _codes(List<ValidationIssue> i) => i.map((e) => e.code).toSet();

List<ValidationIssue> _check(List<Question> qs, {List<MistakeLine> lines = const [], bool tree = true}) =>
    validateQuestionBank(questions: qs, tree: tree ? _tree() : null, mistakeLines: lines);

void main() {
  test('サンプル（docs/samples）は誤りなし。形式の説明とずれていないことを保証する', () {
    final units = jsonDecode(File('docs/samples/units.sample.json').readAsStringSync()) as Map<String, dynamic>;
    final bankJson = jsonDecode(File('docs/samples/questions.sample.json').readAsStringSync()) as Map<String, dynamic>;
    final tree = UnitTree.fromJson(units);
    final bank = parseQuestionBank(bankJson);
    expect(bank.issues, isEmpty);
    final issues = validateQuestionBank(
        questions: bank.questions, tree: tree, mistakeLines: bank.mistakeLines);
    expect(issues, isEmpty, reason: issues.join('\n'));
    expect(validateUnitList([for (final u in units['units'] as List) Unit.fromJson(u as Map<String, dynamic>)]), isEmpty);
  });

  group('問題', () {
    test('正常な問題は問題なし（全単元に問題あり）', () {
      expect(_check([_q(), _q(id: 'q2', unit: 'u2')]), isEmpty);
    });

    test('ID の重複・未対応タイプ・説明なし・version', () {
      final c = _codes(_check([
        _q(id: 'd'), _q(id: 'd', unit: 'u2'),
        _q(id: 't', type: 'hologram'),
        _q(id: 'e', explanation: ' '),
        _q(id: 'v', version: 0),
      ]));
      expect(c, containsAll(['duplicate_question_id', 'unknown_type', 'explanation_missing', 'bad_version']));
    });

    test('選択式: 選択肢が少ない・重複・正解が無い', () {
      expect(_codes(_check([_q(choices: ['a'], answer: 'a')])), contains('choices_too_few'));
      expect(_codes(_check([_q(choices: ['a', 'a', 'b'])])), contains('choices_duplicate'));
      expect(_codes(_check([_q(answer: 'z')])), contains('answer_not_in_choices'));
      expect(_codes(_check([_q(type: 'map', answer: 'z')])), contains('answer_not_in_choices'));
    });

    test('数値: 読めない正解は誤り、カンマ・小数は可', () {
      expect(_codes(_check([_q(type: 'numeric', choices: [], answer: 'abc')])), contains('numeric_answer_invalid'));
      expect(_check([_q(type: 'numeric', choices: [], answer: '1,200.5'), _q(id: 'q2', unit: 'u2')]), isEmpty);
    });

    test('並べ替え・年表: 順序と選択肢の食い違い', () {
      expect(_codes(_check([_q(type: 'order', choices: ['a', 'b'], answer: 'a')])), contains('order_too_few'));
      expect(_codes(_check([_q(type: 'order', choices: ['a', 'b'], answer: 'a,a')])), contains('order_duplicate'));
      expect(_codes(_check([_q(type: 'timeline', choices: ['a', 'b'], answer: 'a,c')])),
          contains('order_choices_mismatch'));
      expect(_check([_q(type: 'timeline', choices: ['b', 'a'], answer: 'a,b'), _q(id: 'q2', unit: 'u2')]), isEmpty);
    });

    test('誤解の型: 選択肢に無い・正解に付いている・書式・対象外タイプ', () {
      expect(_codes(_check([_q(tags: {'z': 'sign_error'})])), contains('tag_choice_missing'));
      expect(_codes(_check([_q(tags: {'a': 'sign_error'})])), contains('tag_on_answer'));
      expect(_codes(_check([_q(tags: {'b': 'Sign-Error'})])), contains('tag_format'));
      final c = _check([_q(type: 'numeric', choices: [], answer: '1', tags: {'b': 'sign_error'})]);
      expect(_codes(c), contains('tags_ignored'));
      expect(c.firstWhere((i) => i.code == 'tags_ignored').isError, isFalse);
    });

    test('基準正答率が 0 / 1 は警告（誤りではない）', () {
      final c = _check([_q(difficulty: 1), _q(id: 'q2', unit: 'u2')]);
      expect(_codes(c), {'difficulty_extreme'});
      expect(hasErrors(c), isFalse);
    });

    test('単元: ツリーに無い（誤り）・葉でない・問題が無い（警告）', () {
      expect(_codes(_check([_q(unit: 'nope')])), contains('unit_missing'));
      final notLeaf = _check([_q(unit: 'g')]);
      expect(_codes(notLeaf), containsAll(['unit_not_leaf', 'unit_empty']));
      expect(hasErrors(notLeaf), isFalse);
      // ツリーなしなら単元の検査はしない
      expect(_check([_q(unit: 'nope')], tree: false), isEmpty);
    });

    test('誤りが先に並ぶ', () {
      final issues = _check([_q(difficulty: 0), _q(id: 'x', answer: 'z', unit: 'u2')]);
      expect(issues.first.isError, isTrue);
      expect(issues.last.isError, isFalse);
    });
  });

  group('まちがいキャラ', () {
    final q = _q(tags: {'b': 'third_person_s'});
    MistakeLine line({
      String id = 'm1', String tag = 'third_person_s', String qid = 'q1', String src = 'b',
      List<String> fix = const ['x', 'y'], String correct = 'x', String statement = 's', String explanation = 'e',
    }) =>
        MistakeLine(
          id: id, tag: tag, questionId: qid, sourceChoiceId: src, statement: statement,
          fixChoices: fix, correctChoice: correct, explanation: explanation,
        );

    List<ValidationIssue> check(MistakeLine l) =>
        validateQuestionBank(questions: [q], tree: null, mistakeLines: [l]);

    test('正常', () => expect(check(line()), isEmpty));

    test('元の問題・型・選択肢のつながり', () {
      expect(_codes(check(line(qid: 'none'))), contains('mistake_question_missing'));
      expect(_codes(check(line(tag: 'other_tag'))), contains('mistake_tag_mismatch'));
      expect(_codes(check(line(src: 'c'))), contains('mistake_source_mismatch'));
    });

    test('直す選択肢・セリフ・説明・ID', () {
      expect(_codes(check(line(fix: ['x']))), contains('mistake_choices_too_few'));
      expect(_codes(check(line(fix: ['x', 'x']))), contains('mistake_choices_duplicate'));
      expect(_codes(check(line(correct: 'z'))), contains('mistake_correct_not_in_choices'));
      expect(_codes(check(line(statement: ''))), contains('mistake_statement_empty'));
      expect(_codes(check(line(explanation: ' '))), contains('mistake_explanation_empty'));
      expect(
        _codes(validateQuestionBank(questions: [q], tree: null, mistakeLines: [line(), line()])),
        contains('duplicate_mistake_line_id'),
      );
    });
  });

  group('単元の一覧', () {
    Unit u(String id, {String? parent, int est = 5}) =>
        Unit(id: id, subject: 'en', grade: 1, title: id, parentId: parent, estimatedQuestions: est);

    test('正常', () => expect(validateUnitList([u('a', est: 0), u('b', parent: 'a')]), isEmpty));

    test('重複・親なし・循環・負の件数', () {
      expect(_codes(validateUnitList([u('a'), u('a')])), contains('duplicate_unit_id'));
      expect(_codes(validateUnitList([u('a', parent: 'zzz')])), contains('unit_parent_missing'));
      expect(_codes(validateUnitList([u('a', parent: 'b'), u('b', parent: 'a')])), contains('unit_cycle'));
      expect(_codes(validateUnitList([u('a', est: -1)])), contains('unit_negative_count'));
    });

    test('葉で estimatedQuestions が 0 は警告', () {
      final i = validateUnitList([u('a', est: 0)]);
      expect(_codes(i), {'unit_no_estimate'});
      expect(hasErrors(i), isFalse);
    });
  });

  group('JSON の読み込み', () {
    test('壊れた項目は報告して飛ばし、残りは読む', () {
      final r = parseQuestionBank({
        'questions': [
          {'id': 'ok', 'unitId': 'u1', 'type': 'choice', 'difficulty': 0.5, 'choices': ['a', 'b'], 'answer': 'a', 'explanationId': 'x'},
          {'id': 'no_answer', 'unitId': 'u1', 'type': 'choice', 'difficulty': 0.5, 'choices': ['a', 'b'], 'explanationId': 'x'},
          {'id': 'bad_difficulty', 'unitId': 'u1', 'type': 'choice', 'difficulty': 1.5, 'choices': ['a', 'b'], 'answer': 'a', 'explanationId': 'x'},
          'not an object',
        ],
        'mistakeLines': [
          {'id': 'm_broken'},
        ],
      });
      expect(r.questions.map((q) => q.id), ['ok']);
      expect(r.issues.length, 4);
      expect(r.issues.every((i) => i.code == 'malformed'), isTrue);
      expect(r.issues.map((i) => i.subjectId), containsAll(['no_answer', 'bad_difficulty', 'm_broken']));
    });

    test('malformed の理由は、欠けた項目名・範囲・型が分かる', () {
      String why(Map<String, dynamic> bank) => parseQuestionBank(bank).issues.single.message;
      final base = {'id': 'q', 'unitId': 'u', 'type': 'choice', 'difficulty': 0.5, 'choices': ['a', 'b'], 'answer': 'a', 'explanationId': 'x'};
      expect(why({'questions': [Map.of(base)..remove('answer')..remove('explanationId')]}), contains('answer, explanationId'));
      expect(why({'questions': [Map.of(base)..['difficulty'] = 1.5]}), contains('0〜1'));
      expect(why({'questions': [Map.of(base)..['choices'] = 'abc']}), contains('型が違います'));
      expect(why({'questions': ['x']}), contains('オブジェクトではありません'));
      expect(why({'mistakeLines': [{'id': 'm'}]}), allOf(contains('tag'), contains('fixChoices')));
    });

    test('Question の JSON 往復', () {
      final q = _q(tags: {'b': 'x_y'});
      final back = Question.fromJson(q.toJson());
      expect(back.toJson(), q.toJson());
      expect(back.misconceptionTags, {'b': 'x_y'});
    });

    test('キーが無ければ空の問題集', () {
      final r = parseQuestionBank({});
      expect(r.questions, isEmpty);
      expect(r.issues, isEmpty);
    });
  });
}
