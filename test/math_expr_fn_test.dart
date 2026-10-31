import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

double v(String s, [Map<String, double> m = const {}]) => MathExpr.parse(s).eval(m);

void main() {
  group('floor・ceil', () {
    test('切り捨て・切り上げ（負の数は数直線の向き）', () {
      expect(v('floor(2.7)'), 2);
      expect(v('floor(-2.1)'), -3);
      expect(v('ceil(2.1)'), 3);
      expect(v('ceil(-2.7)'), -2);
      expect(v('floor(3)'), 3);
      expect(v('ceil(3)'), 3);
    });

    test('世紀: ceil(year/100)', () {
      expect(v('ceil(y/100)', {'y': 1868}), 19);
      expect(v('ceil(y/100)', {'y': 1900}), 19);
      expect(v('ceil(y/100)', {'y': 1901}), 20);
      expect(v('ceil(y/100)', {'y': 2000}), 20);
    });

    test('誤差で整数の手前に落ちない', () {
      expect(v('ceil(0.1*3*10)'), 3); // 0.1*3*10 = 3.0000000000000004（そのまま切り上げると 4）
      expect(v('floor(0.3/0.1)'), 3); // 2.9999999999999996（そのまま切り捨てると 2）
      expect(v('floor(0.1*3*10)'), 3);
      expect(v('ceil(0.3/0.1)'), 3);
      expect(v('floor(1/3*3)'), 1);
      expect(v('floor(2.999)'), 2);
      expect(v('ceil(3.001)'), 4);
    });

    test('かっこの中に式・入れ子・前後の計算', () {
      expect(v('2floor(x/2)+1', {'x': 7}), 7);
      expect(v('floor(ceil(2.5)/2)'), 1);
      expect(v('-floor(2.5)'), -2);
      expect(v('floor(2.5)^2'), 4);
    });

    test('定義できない値は NaN', () {
      expect(v('floor(1/0)').isNaN, isTrue);
      expect(v('ceil(sqrt(-1))').isNaN, isTrue);
    });
  });

  group('mod', () {
    test('余りは 0 以上 b 未満（b が正）', () {
      expect(v('mod(7, 3)'), 1);
      expect(v('mod(-7, 3)'), 2);
      expect(v('mod(6, 3)'), 0);
      expect(v('mod(7.5, 2)'), 1.5);
      expect(v('mod(7, -3)'), 1);
    });

    test('時刻・曜日のような周期', () {
      expect(v('mod(h+9, 24)', {'h': 20}), 5);
      expect(v('mod(d, 7)', {'d': 100}), 2);
    });

    test('b が 0 は NaN。誤差の整数にそろえる', () {
      expect(v('mod(5, 0)').isNaN, isTrue);
      expect(v('mod(0.1*3*10, 3)'), 0);
      expect(v('mod(7, 0.1*3*10)'), 1); // 割る数も整数にそろえる（そのままだと 0.9999999999999996）
      expect(v('mod(5, 10^999)').isNaN, isTrue);
      expect(v('floor(10^999)').isNaN, isTrue);
      expect(v('ceil(10^999)').isNaN, isTrue);
      expect(v('mod(1, 0.1*3)'), closeTo(0.1, 1e-9));
    });
  });

  group('読み取りと同値判定', () {
    test('形の誤り', () {
      for (final s in ['floor', 'floor 2', 'floor(2', 'floor()', 'mod(2)', 'mod(2,3', 'mod(2,3,4)', 'mod 3', '2,3', '(2,3)', 'ceil(,2)', 'mod(,2)', 'floor 2 3)', 'mod(2 5 3)', 'mod(2, 5 3)']) {
        expect(MathExpr.tryParse(s), isNull, reason: s);
      }
    });

    test('全角・変数の収集・束縛', () {
      expect(MathExpr.parse('ｆｌｏｏｒ(ｘ／２)').eval({'x': 5}), 2);
      expect(MathExpr.parse('mod(a, b)').variables, ['a', 'b']);
      expect(MathExpr.parse('floor(x/2)').bind({'x': 9}).eval(const {}), 4);
      expect(MathExpr.parse('mod(x, 5)+y').variables, ['x', 'y']);
    });

    test('同値: 世紀の式どうし・別の書き方', () {
      bool eq(String a, String b) => MathExpr.equivalent(MathExpr.parse(a), MathExpr.parse(b));
      expect(eq('floor(x)', 'floor(x)'), isTrue);
      expect(eq('floor(x)', 'ceil(x)'), isFalse);
      expect(eq('mod(x, 5)', 'x-5floor(x/5)'), isTrue);
    });

    test('式の問題（expr）として判定できる', () {
      final q = Question(
        id: 'q', unitId: 'u', type: 'expr', difficulty: .5, choices: const [], answer: 'mod(x, 5)', explanationId: 'e');
      expect(checkAnswer(q, 'x-5floor(x/5)').correct, isTrue);
      expect(checkAnswer(q, 'x-5ceil(x/5)').correct, isFalse);
    });
  });
}
