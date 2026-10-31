import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

bool eq(String a, String b) => MathExpr.equivalent(MathExpr.parse(a), MathExpr.parse(b));

Question q(String answer) => Question(
  id: 'q',
  unitId: 'u',
  type: 'expr',
  difficulty: 0.5,
  choices: const [],
  answer: answer,
  explanationId: 'e',
);

void main() {
  formTests();
  group('読み取り', () {
    test('優先順位・右結合・単項マイナス', () {
      double v(String s, [Map<String, double> m = const {}]) => MathExpr.parse(s).eval(m);
      expect(v('1+2*3'), 7);
      expect(v('2^3^2'), 512);
      expect(v('-2^2'), -4);
      expect(v('2^-1'), 0.5);
      expect(v('8/4/2'), 1);
      expect(v('(1+2)*3'), 9);
    });
    test('省略した掛け算と記号の表記ゆれ', () {
      expect(MathExpr.parse('2x').eval({'x': 5}), 10);
      expect(MathExpr.parse('2(x+1)').eval({'x': 2}), 6);
      expect(MathExpr.parse('(x+1)(x-1)').eval({'x': 3}), 8);
      expect(MathExpr.parse('３ｘ＋２').eval({'x': 1}), 5);
      expect(MathExpr.parse('x²').eval({'x': 4}), 16);
      expect(MathExpr.parse('6÷3×2').eval({}), 4);
      expect(MathExpr.parse('5−2').eval({}), 3);
      expect(MathExpr.parse('√9').eval({}), 3);
      expect(MathExpr.parse('sqrt(x+1)').eval({'x': 3}), 2);
    });
    test('読めない式は FormatException（tryParse は null）', () {
      for (final s in ['', '2+', '(1', '1)', 'x2', '2 3', '1..2', '2@3', 'X', '*3']) {
        expect(() => MathExpr.parse(s), throwsFormatException, reason: s);
        expect(MathExpr.tryParse(s), isNull, reason: s);
      }
    });
    test('変数は辞書順に重複なく', () {
      expect(MathExpr.parse('y+x*y').variables, ['x', 'y']);
    });
    test('定義できない値は NaN', () {
      expect(MathExpr.parse('1/0').eval({}).isNaN, isTrue);
      expect(MathExpr.parse('sqrt(-1)').eval({}).isNaN, isTrue);
      expect(MathExpr.parse('x').eval({}).isNaN, isTrue);
    });
  });

  group('同値判定', () {
    test('展開・因数分解・約分・分数と小数', () {
      expect(eq('2x+6', '2(x+3)'), isTrue);
      expect(eq('(x+3)^2', 'x^2+6x+9'), isTrue);
      expect(eq('(x+1)(x-1)', 'x^2-1'), isTrue);
      expect(eq('1/2', '0.5'), isTrue);
      expect(eq('2/4', '1/2'), isTrue);
      expect(eq('x/x*3', '3'), isTrue); // 定義域は同じ（x=0 は比べない）
      expect(eq('a+b', 'b+a'), isTrue);
    });
    test('よくある誤りは別の式', () {
      expect(eq('(x+3)^2', 'x^2+9'), isFalse);
      expect(eq('2x+6', '2x+3'), isFalse);
      expect(eq('x^2', 'x'), isFalse);
      expect(eq('x^2', '2x'), isFalse);
      expect(eq('-x^2', '(-x)^2'), isFalse);
      expect(eq('x', 'y'), isFalse);
      expect(eq('1/3', '0.333'), isFalse);
    });
    test('定義域が違う式は別の式', () {
      expect(eq('sqrt(x)', 'x'), isFalse);
      expect(eq('1/(x-2)', '1/(x-2)+0*sqrt(x-100)'), isFalse);
    });
    test('どこでも定義できない式は同じと認めない', () {
      expect(eq('sqrt(-1-x^2)', 'sqrt(-1-x^2)'), isFalse);
    });
  });

  group('問題タイプ expr', () {
    test('checkAnswer: 同じ値なら正解、読めない入力は不正解', () {
      expect(checkAnswer(q('2x+6'), '2(x+3)').correct, isTrue);
      expect(checkAnswer(q('2x+6'), 'x*2+6').correct, isTrue);
      expect(checkAnswer(q('2x+6'), '2x+3').correct, isFalse);
      expect(checkAnswer(q('2x+6'), '2x+').correct, isFalse);
      expect(checkAnswer(q('2x+6'), '').correct, isFalse);
      expect(checkAnswer(q('1/2'), '0.5').correct, isTrue);
    });
    test('検証: 読めない正解はエラー、選択肢は警告', () {
      final tree = UnitTree(1, [Unit(id: 'u', subject: 'math', grade: 1, title: 'u', estimatedQuestions: 5)]);
      List<String> codes(Question x) => validateQuestionBank(questions: [x], tree: tree).map((i) => i.code).toList();
      expect(codes(q('2x+6')), isNot(contains('expr_answer_invalid')));
      expect(codes(q('2x+')), contains('expr_answer_invalid'));
      expect(codes(q('2x+')), isNot(contains('unknown_type')));
    });
  });
}

void formTests() {
  bool f(String form, String input, [String? ref]) => MathExpr.parse(input).hasForm(form, MathExpr.parse(ref ?? input));

  group('答えの形', () {
    test('expanded: 積・かっこ・同類項を残した式は不可', () {
      expect(f('expanded', 'x^2+6x+9'), isTrue);
      expect(f('expanded', '2x+6'), isTrue);
      expect(f('expanded', 'x/2+3'), isTrue);
      expect(f('expanded', '2(x+3)', '2x+6'), isFalse);
      expect(f('expanded', '(x+3)^2', 'x^2+6x+9'), isFalse);
      expect(f('expanded', '(x+1)(x-1)', 'x^2-1'), isFalse);
      expect(f('expanded', 'x*x-1', 'x^2-1'), isFalse);
      expect(f('expanded', '-(x+3)', '-x-3'), isFalse);
      expect(f('expanded', 'x-(y+1)', 'x-y-1'), isFalse);
      expect(f('expanded', '(x+2)/2', 'x/2+1'), isFalse);
      expect(f('expanded', '1/x', 'x'), isFalse);
      expect(f('expanded', 'x+x+3', '2x+3'), isFalse); // 同類項のまとめ忘れ
      expect(f('expanded', '3+2x', '2x+3'), isTrue); // 順は問わない
    });
    test('factored: 変数を含む和の因数をもつ積、または和のべき', () {
      expect(f('factored', '2(x+3)'), isTrue);
      expect(f('factored', '(x+1)(x-1)'), isTrue);
      expect(f('factored', 'x(x+1)'), isTrue);
      expect(f('factored', '-(x+1)(x-1)'), isTrue);
      expect(f('factored', '(x+3)^2'), isTrue);
      expect(f('factored', '2x+6'), isFalse);
      expect(f('factored', '2x'), isFalse);
      expect(f('factored', 'x^2'), isFalse);
      expect(f('factored', '(x+3)^1'), isFalse);
    });
    test('reduced_fraction: 既約で分母は2以上の整数（整数もよい）', () {
      expect(f('reduced_fraction', '1/2'), isTrue);
      expect(f('reduced_fraction', '-3/4'), isTrue);
      expect(f('reduced_fraction', '3'), isTrue);
      expect(f('reduced_fraction', '2/4'), isFalse);
      expect(f('reduced_fraction', '4/2'), isFalse);
      expect(f('reduced_fraction', '3/1'), isFalse);
      expect(f('reduced_fraction', '0.5'), isFalse);
      expect(f('reduced_fraction', '1/-2'), isFalse);
      expect(f('reduced_fraction', '0/5'), isFalse);
    });
    test('simplest_radical: 根号の中は2以上の平方因数なし', () {
      expect(f('simplest_radical', '√2'), isTrue);
      expect(f('simplest_radical', '3√2'), isTrue);
      expect(f('simplest_radical', '-2√3'), isTrue);
      expect(f('simplest_radical', '5'), isTrue);
      expect(f('simplest_radical', '√8'), isFalse);
      expect(f('simplest_radical', '2√12'), isFalse);
      expect(f('simplest_radical', '1√2'), isFalse);
      expect(f('simplest_radical', '√1'), isFalse);
      expect(f('simplest_radical', 'sqrt(x)'), isFalse);
      expect(f('simplest_radical', '1.5'), isFalse);
    });
    test('未対応の形は ArgumentError', () {
      expect(() => f('nope', 'x'), throwsArgumentError);
    });
  });

  group('judgeExpr と問題', () {
    test('値が合って形が違うと wrongForm（値が違えば wrongValue）', () {
      expect(judgeExpr('2x+6', '2(x+3)'), ExprVerdict.correct);
      expect(judgeExpr('2x+6', '2(x+3)', form: 'expanded'), ExprVerdict.wrongForm);
      expect(judgeExpr('2x+6', '6+2x', form: 'expanded'), ExprVerdict.correct);
      expect(judgeExpr('2x+6', '2x+7', form: 'expanded'), ExprVerdict.wrongValue);
      expect(judgeExpr('2x+6', '2x+', form: 'expanded'), ExprVerdict.unreadable);
      expect(judgeExpr('1/2', '2/4', form: 'reduced_fraction'), ExprVerdict.wrongForm);
      expect(judgeExpr('1/2', '0.5', form: 'reduced_fraction'), ExprVerdict.wrongForm);
    });
    test('checkAnswer は form を見る。JSON の往復と差分にも入る', () {
      final qf = Question.fromJson({
        'id': 'q',
        'unitId': 'u',
        'type': 'expr',
        'difficulty': 0.5,
        'answer': '2x+6',
        'explanationId': 'e',
        'form': 'expanded',
      });
      expect(qf.form, 'expanded');
      expect(checkAnswer(qf, '2x+6').correct, isTrue);
      expect(checkAnswer(qf, '2(x+3)').correct, isFalse);
      expect(Question.fromJson(qf.toJson()).form, 'expanded');
      expect(qf.copyWith(version: 2).form, 'expanded');
      expect(q('2x+6').toJson().containsKey('form'), isFalse);
      final diff = BankDiff.between(
        [qf],
        [
          Question.fromJson({...qf.toJson(), 'form': null, 'version': 2}),
        ],
      );
      expect(diff.changed, hasLength(1));
    });
    test('検証: 未対応の形・正解が形を満たさない・expr 以外の form', () {
      final tree = UnitTree(1, [Unit(id: 'u', subject: 'math', grade: 1, title: 'u', estimatedQuestions: 5)]);
      List<String> codes(Question x) => validateQuestionBank(questions: [x], tree: tree).map((i) => i.code).toList();
      Question mk(String type, String answer, String? form) => Question.fromJson({
        'id': 'q',
        'unitId': 'u',
        'type': type,
        'difficulty': 0.5,
        'answer': answer,
        'explanationId': 'e',
        'choices': type == 'choice' ? ['a', 'b'] : [],
        'form': ?form,
      });
      expect(codes(mk('expr', '2x+6', 'expanded')), isEmpty);
      expect(codes(mk('expr', '2x+6', 'nope')), contains('unknown_form'));
      expect(codes(mk('expr', '2(x+3)', 'expanded')), contains('answer_form_mismatch'));
      expect(codes(mk('expr', '2/4', 'reduced_fraction')), contains('answer_form_mismatch'));
      expect(codes(mk('choice', 'a', 'expanded')), contains('form_ignored'));
    });
  });
}
