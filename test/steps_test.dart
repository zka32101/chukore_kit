import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

SolutionCheck chk(List<String> l, {String? target, String? form}) => checkSolutionSteps(l, target: target, form: form);

void main() {
  group('MathEquation', () {
    MathEquation eq(String s) => MathEquation.parse(s);

    test('読み取り: 全角の ＝・両辺・変数。書き間違いは FormatException', () {
      final e = eq('2x+3＝11');
      expect(e.variables, ['x']);
      expect(e.residual({'x': 4}), 0);
      for (final bad in ['2x+3', '1=2=3', '2x<=4', '2x>=4', '2x==4', 'x=>3', '=3', '3=', 'x!=3', '2x+=3']) {
        expect(() => MathEquation.parse(bad), throwsFormatException, reason: bad);
      }
    });
    test('同じ解: 移項・両辺に同じ数・両辺を 0 でない数でわる／かける・整理した形', () {
      bool same(String a, String b) => MathEquation.equivalent(eq(a), eq(b));
      expect(same('2x+3=11', '2x=11-3'), isTrue);
      expect(same('2x+3=11', '2x=8'), isTrue);
      expect(same('2x=8', 'x=4'), isTrue);
      expect(same('2x=8', '4=x'), isTrue);
      expect(same('2x+3=11', '-2x-3=-11'), isTrue); // 両辺に -1 をかける
      expect(same('x/2=3', 'x=6'), isTrue);
      expect(same('3(x-1)=2x+5', '3x-3=2x+5'), isTrue);
      expect(same('3x-3=2x+5', 'x=8'), isTrue);
      expect(same('x=x', '2=2'), isTrue); // どちらも恒等式
    });
    test('違う解: 移項の符号・割り算の誤り・解が増える変形（変数をかける）・恒等式と矛盾', () {
      bool same(String a, String b) => MathEquation.equivalent(eq(a), eq(b));
      expect(same('2x+3=11', '2x=11+3'), isFalse);
      expect(same('2x=8', 'x=8'), isFalse);
      expect(same('2x=8', 'x=16'), isFalse);
      expect(same('x=2', 'x*x=2*x'), isFalse); // x=0 も解になってしまう
      expect(same('x=x', 'x=x+1'), isFalse);
      expect(same('x=x', 'x=2'), isFalse);
      expect(same('x^2=4', 'x=2'), isFalse); // 解が減る
      expect(same('x=2', 'y=2'), isFalse);
    });
    test('定義できる点が少なくて比べられない式は、同じとは言わない', () {
      final e = eq('sqrt(x-7.9)=1');
      expect(MathEquation.equivalent(e, e), isFalse); // x=8 の 1 点しか定義できない
      expect(MathEquation.equivalent(eq('sqrt(x)=1'), eq('sqrt(x)=1')), isTrue);
    });
    test('linear: 一次式 a x + b（左辺 − 右辺）。一次でない・他の変数があれば null', () {
      expect(eq('3x+2=x-4').linear('x'), (a: 2.0, b: 6.0));
      expect(eq('x=8').linear('x'), (a: 1.0, b: -8.0));
      expect(eq('x^2=4').linear('x'), isNull);
      expect(eq('x+y=4').linear('x'), isNull);
      expect(eq('1/x=4').linear('x'), isNull);
      expect(eq('2=2').linear('x'), (a: 0.0, b: 0.0));
    });
    test('解の形 isSolvedForm: x=数／数=x だけ', () {
      expect(eq('x=4').isSolvedForm, isTrue);
      expect(eq('4=x').isSolvedForm, isTrue);
      expect(eq('x=-3/2').isSolvedForm, isTrue);
      expect(eq('x=11-3').isSolvedForm, isTrue); // 右辺が数の式（計算は途中）でも、解の形
      expect(eq('2x=8').isSolvedForm, isFalse);
      expect(eq('x+0=4').isSolvedForm, isFalse); // x だけではない
      expect(eq('x+1=4').isSolvedForm, isFalse);
      expect(eq('x=x').isSolvedForm, isFalse);
      expect(eq('x=y').isSolvedForm, isFalse);
      expect(eq('3=4').isSolvedForm, isFalse);
    });
  });

  group('commonMistakes', () {
    Map<String, Set<String>> tags(String src, List<String> ofValues) => {
      for (final m in MathExpr.parse(src).commonMistakes()) m.tag: {...?null},
    };
    bool has(String src, String tag, String result) => MathExpr.parse(
      src,
    ).commonMistakes().any((m) => m.tag == tag && MathExpr.equivalent(m.expr, MathExpr.parse(result)));

    test('分配・かっこの符号・2乗・分数・まとめ違い・計算の順・符号の積', () {
      expect(has('2(x+3)', 'distribute_first_only', '2x+3'), isTrue);
      expect(has('(x+3)*2', 'distribute_first_only', '2x+3'), isTrue);
      expect(has('2(x-3)', 'distribute_first_only', '2x-3'), isTrue);
      expect(has('(x+1)(x+2)', 'distribute_first_only', 'x^2+2'), isTrue);
      expect(has('5-(x+3)', 'minus_paren_first_only', '5-x+3'), isTrue);
      expect(has('5-(x-3)', 'minus_paren_first_only', '5-x-3'), isTrue);
      expect(has('-(x+3)', 'minus_paren_first_only', '-x+3'), isTrue);
      expect(has('(x+3)^2', 'square_of_sum', 'x^2+9'), isTrue);
      expect(has('(x-3)^2', 'square_of_sum', 'x^2-9'), isTrue);
      expect(MathExpr.parse('(x+3)^3').commonMistakes().map((m) => m.tag), isNot(contains('square_of_sum'))); // 2 乗だけ
      expect(has('1/2+1/3', 'fraction_add_denominator', '2/5'), isTrue);
      expect(has('2x+3', 'like_terms_mixup', '5x'), isTrue);
      expect(has('x+3', 'like_terms_mixup', '4x'), isTrue);
      expect(has('3+2x', 'like_terms_mixup', '5x'), isTrue);
      expect(has('3+4*2', 'order_of_operations', '(3+4)*2'), isTrue);
      expect(has('3-4*2', 'order_of_operations', '(3-4)*2'), isTrue);
      expect(has('(a+b)/c', 'fraction_numerator_partial', 'a+b/c'), isTrue);
      expect(has('5-(-3)', 'sub_negative_sign', '5-3'), isTrue);
      expect(has('(-3)*4', 'sign_rule_product', '12'), isTrue);
      expect(has('12/(-4)', 'sign_rule_product', '3'), isTrue);
      expect(has('(-3)^2', 'neg_square_sign', '-9'), isTrue);
      expect(has('-3^2', 'neg_square_sign', '9'), isTrue);
    });
    test('式の一部（内側）の誤りも作る。正しい書き換えは含まない', () {
      expect(has('2(x+3)+5', 'distribute_first_only', '2x+3+5'), isTrue);
      expect(has('7-(2(x+1))', 'distribute_first_only', '7-(2x+1)'), isTrue);
      expect(has('sqrt(2(x+3))', 'distribute_first_only', 'sqrt(2x+3)'), isTrue);
      expect(has('-(2(x+3))', 'distribute_first_only', '-(2x+3)'), isTrue);
      // 正しい展開 2x+6 は誤りの一覧に入らない
      for (final m in MathExpr.parse('2(x+3)').commonMistakes()) {
        expect(MathExpr.equivalent(m.expr, MathExpr.parse('2x+6')), isFalse, reason: m.tag);
      }
      expect(MathExpr.parse('x').commonMistakes(), isEmpty);
      expect(MathExpr.parse('12').commonMistakes(), isEmpty);
      expect(MathExpr.parse('π').commonMistakes(), isEmpty);
      // 誤りの式の変数が数えられている
      final m = MathExpr.parse('a*(x+b)').commonMistakes().firstWhere((e) => e.tag == 'distribute_first_only');
      expect(m.expr.variables, ['a', 'b', 'x']);
    });
    test('linearIn', () {
      expect(MathExpr.parse('3x+2').linearIn('x'), (a: 3.0, b: 2.0));
      expect(MathExpr.parse('2(x-1)').linearIn('x'), (a: 2.0, b: -2.0));
      expect(MathExpr.parse('x^2').linearIn('x'), isNull);
      expect(MathExpr.parse('x+y').linearIn('x'), isNull);
      expect(MathExpr.parse('1/x').linearIn('x'), isNull);
      expect(MathExpr.parse('5').linearIn('x'), (a: 0.0, b: 5.0));
      expect(tags('x', const []), isEmpty);
    });
  });

  group('checkSolutionSteps: 式の変形', () {
    test('正しい展開の途中式は全部 ok で、目標・形に着く', () {
      final r = chk(['3(x+2)-(x-4)', '3x+6-x+4', '2x+10'], target: '2x+10', form: 'expanded');
      expect(r.kind, LineKind.expression);
      expect(r.allOk, isTrue);
      expect(r.firstProblem, isNull);
      expect(r.verdicts.map((v) => v.status), everyElement(LineStatus.ok));
      expect(r.reachedTarget, isTrue);
      expect(r.finalWrongForm, isFalse);
      expect(r.tag, isNull);
    });
    test('最初に壊れた行と誤解の型を返す。それ以降の行は前の行（書かれたとおり）との比較', () {
      final r = chk(['2(x+3)', '2x+3', '2x+6']);
      expect(r.firstProblem, 1);
      expect(r.verdicts[1].status, LineStatus.broken);
      expect(r.verdicts[1].tag, 'distribute_first_only');
      expect(r.tag, 'distribute_first_only');
      expect(r.verdicts[2].status, LineStatus.broken); // 2x+3 → 2x+6 も同じでない
      expect(r.verdicts[2].tag, isNull);
      expect(r.allOk, isFalse);
    });
    test('誤りが元に戻れば、その行は ok（前の行との比較）', () {
      final r = chk(['2(x+3)', '2x+3', '2x+3']);
      expect(r.verdicts.map((v) => v.status), [LineStatus.ok, LineStatus.broken, LineStatus.ok]);
      expect(r.firstProblem, 1);
    });
    test('誤りの型を当てられない誤りは tag なし。式の誤りの当たり: かっこ・2乗・まとめ違い', () {
      expect(chk(['5-(x+3)', '5-x+3']).tag, 'minus_paren_first_only');
      expect(chk(['(x+3)^2', 'x^2+9']).tag, 'square_of_sum');
      expect(chk(['2x+3', '5x']).tag, 'like_terms_mixup');
      expect(chk(['3+4*2', '14']).tag, 'order_of_operations');
      expect(chk(['(-3)*4', '12']).tag, 'sign_rule_product');
      expect(chk(['(-3)^2', '-9']).tag, 'neg_square_sign');
      expect(chk(['2(x+3)', '100x']).tag, isNull);
      expect(chk(['2(x+3)', '100x']).verdicts[1].status, LineStatus.broken);
    });
    test('数の計算の途中式', () {
      final ok = chk(['(-3)*4+5', '-12+5', '-7'], target: '-7');
      expect(ok.allOk, isTrue);
      expect(ok.reachedTarget, isTrue);
      final bad = chk(['(-3)*4+5', '12+5', '17']);
      expect(bad.firstProblem, 1);
      expect(bad.tag, 'sign_rule_product');
    });
    test('着かなかった・形が違う・途中で壊れていれば目標に着いたと言わない', () {
      expect(chk(['2(x+3)', '2x+6'], target: '2x+7').reachedTarget, isFalse);
      final f = chk(['2(x+3)', '2(x+3)'], target: '2x+6', form: 'expanded');
      expect(f.reachedTarget, isFalse);
      expect(f.finalWrongForm, isTrue);
      expect(f.allOk, isTrue);
      final broken = chk(['2(x+3)', '2x+3', '2x+6'], target: '2x+6');
      expect(broken.reachedTarget, isFalse); // 最後は目標と同じでも、途中で壊れている
      expect(chk(['2(x+3)', '2x+6']).reachedTarget, isFalse); // 目標を渡していない
    });
  });

  group('checkSolutionSteps: 方程式', () {
    test('正しい解き方は全部 ok で、解の形で着く', () {
      final r = chk(['2x+3=11', '2x=11-3', '2x=8', 'x=4'], target: 'x=4');
      expect(r.kind, LineKind.equation);
      expect(r.allOk, isTrue);
      expect(r.reachedTarget, isTrue);
      expect(r.finalNotSolved, isFalse);
    });
    test('解の形まで整理していない', () {
      final r = chk(['2x+3=11', '2x=8'], target: 'x=4');
      expect(r.allOk, isTrue);
      expect(r.reachedTarget, isFalse);
      expect(r.finalNotSolved, isTrue);
    });
    test('移項の符号の誤り', () {
      for (final bad in ['2x=11+3', '2x+3-3=11+3']) {
        final r = chk(['2x+3=11', bad]);
        expect(r.firstProblem, 1, reason: bad);
      }
      expect(chk(['2x+3=11', '2x=11+3']).tag, 'move_term_sign');
      expect(chk(['x+5=2x-1', 'x-2x=-1+5']).tag, 'move_term_sign'); // 右の 2x を符号を変えずに左へ… は x+2x
      expect(chk(['3x-4=x+6', '3x=x+6-4']).tag, 'move_term_sign');
      expect(chk(['3x=x+8', '3x+x=8']).tag, 'move_term_sign');
      expect(chk(['3x+2=x+8', '3x+2+8=x']).tag, 'move_term_sign'); // 右の定数を、符号を変えずに左へ
      expect(chk(['3x+2=x+8', '2=x+8+3x']).tag, 'move_term_sign'); // 左の x の項を、符号を変えずに右へ
      expect(chk(['3x=x+8', '3x-x=8']).tag, isNull); // 正しい移項
      expect(chk(['3x=x+8', '3x-x=8']).allOk, isTrue);
    });
    test('割り算の誤り: 割り忘れ・かけてしまう・逆数・符号', () {
      expect(chk(['2x=8', 'x=8']).tag, 'forgot_to_divide');
      expect(chk(['2x=8', 'x=16']).tag, 'multiplied_instead_of_divide');
      expect(chk(['2x=8', 'x=1/4']).tag, 'divide_reversed');
      expect(chk(['2x=8', 'x=-4']).tag, 'sign_flip');
      expect(chk(['2x=8', 'x=5']).tag, isNull);
      expect(chk(['x=8', 'x=8']).allOk, isTrue);
      // 係数が 1 なら、割り忘れ・かけ間違いは起きない（符号の誤りだけ）
      expect(chk(['x=8', 'x=-8']).tag, 'sign_flip');
      expect(chk(['x=8', 'x=9']).tag, isNull);
      expect(chk(['x+1=x+4', 'x=3']).tag, isNull); // x の項が消える式からは、割り算の誤りと言わない
    });
    test('片方の辺の式の誤り（かっこをはずす・まとめる）', () {
      expect(chk(['3(x-1)=2x+5', '3x-1=2x+5']).tag, 'distribute_first_only');
      expect(chk(['x+5=2(x-1)', 'x+5=2x-1']).tag, 'distribute_first_only');
      expect(chk(['3(x-1)=2x+5', '3x-3=2x+5', 'x=8'], target: 'x=8').reachedTarget, isTrue);
    });
    test('全角の ＝・空白・左右入れ替えも同じ解', () {
      final r = chk(['2x+3＝11', ' 2x = 8 ', '4 = x'], target: 'x＝4');
      expect(r.allOk, isTrue);
      expect(r.reachedTarget, isTrue);
    });
    test('誤りの型が決まらない（一次方程式でない・式が複雑）誤りは tag なし', () {
      final r = chk(['x^2=4', 'x=2']);
      expect(r.firstProblem, 1);
      expect(r.tag, isNull);
    });
  });

  group('checkSolutionSteps: 読めない・種類が違う・空', () {
    test('読めない行・式と方程式の混在', () {
      final r = chk(['2x+3=11', '2x=', 'x=4']);
      expect(r.verdicts[1].status, LineStatus.unreadable);
      expect(r.firstProblem, 1);
      expect(r.verdicts[2].status, LineStatus.ok); // 読めない行は比較の相手にならず、最後に読めた行と比べる
      final m = chk(['2x+3', '2x=8']);
      expect(m.verdicts[1].status, LineStatus.kindMismatch);
      expect(m.firstProblem, 1);
      expect(chk(['2x+3=11', '2x+3<=11']).verdicts[1].status, LineStatus.unreadable);
      expect(chk(['2x+3', '2x+']).verdicts[1].status, LineStatus.unreadable);
      expect(chk(['', '2x']).verdicts[0].status, LineStatus.unreadable);
    });
    test('最初の行が読めなければ、次の行が最初の行になる', () {
      final r = chk(['??', '2x+3', '2x+3']);
      expect(r.verdicts[0].status, LineStatus.unreadable);
      expect(r.verdicts[1].status, LineStatus.ok);
      expect(r.verdicts[2].status, LineStatus.ok);
      expect(r.kind, LineKind.expression);
    });
    test('空の一覧・1 行だけ', () {
      final e = chk(const []);
      expect(e.kind, isNull);
      expect(e.allOk, isTrue);
      expect(e.reachedTarget, isFalse);
      final one = chk(['x=4'], target: 'x=4');
      expect(one.allOk, isTrue);
      expect(one.reachedTarget, isTrue);
    });
    test('目標の種類が違えば着かない', () {
      expect(chk(['2x+3=11', 'x=4'], target: '4').reachedTarget, isFalse);
      expect(chk(['2(x+3)', '2x+6'], target: 'x=4').reachedTarget, isFalse);
      expect(chk(['2(x+3)', '2x+6'], target: '2x+').reachedTarget, isFalse);
    });
  });
}
