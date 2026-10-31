import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatExact', () {
    test('整数・既約分数・書けない値', () {
      expect(formatExact(12), '12');
      expect(formatExact(-12), '-12');
      expect(formatExact(0), '0');
      expect(formatExact(-0.0), '0');
      expect(formatExact(0.5), '1/2');
      expect(formatExact(-0.75), '-3/4');
      expect(formatExact(6 / 4), '3/2');
      expect(formatExact(1 / 3), '1/3');
      expect(formatExact(1 / 999), '1/999');
      expect(formatExact(-7 / 1000), '-7/1000');
      expect(formatExact(1 / 1001), isNull);
      expect(formatExact(0.123456), isNull);
      expect(formatExact(double.nan), isNull);
      expect(formatExact(double.infinity), isNull);
      expect(formatExact(1e13), isNull);
    });
  });

  group('renderTemplateString', () {
    const p = {'a': 3.0, 'b': -4.0, 'c': 0.0};
    test('値・符号つき・かっこつき', () {
      expect(renderTemplateString('{a}(x{+b})', p), '3(x-4)');
      expect(renderTemplateString('{a}x{+a*b}', p), '3x-12');
      expect(renderTemplateString('{a}x{+a*a}', p), '3x+9');
      expect(renderTemplateString('x{+c}', p), 'x+0');
      expect(renderTemplateString('x+{&b}', p), 'x+(-4)');
      expect(renderTemplateString('x+{&a}', p), 'x+3');
      expect(renderTemplateString('{a/4}x', p), '3/4x');
      expect(renderTemplateString('{b/-8}', p), '1/2');
      expect(renderTemplateString('x^2 と y', p), 'x^2 と y');
    });
    test('書き間違いは FormatException', () {
      for (final t in ['{a', 'a}', '{{a}}', '{z}', '{}', '{a+}', '{x}']) {
        expect(() => renderTemplateString(t, p), throwsFormatException, reason: t);
      }
    });
    test('正確に書けない値は InexactValueException', () {
      expect(() => renderTemplateString('{a/b/1000}', {'a': 1.0, 'b': 3.0}), throwsA(isA<InexactValueException>()));
      expect(() => renderTemplateString('{a/c}', p), throwsA(isA<InexactValueException>())); // 0 で割る
      expect(() => renderTemplateString('{sqrt(a)}', p), throwsA(isA<InexactValueException>()));
    });
  });

  group('evalConstraint', () {
    const p = {'a': 3.0, 'b': -4.0};
    test('6 つの比較', () {
      expect(evalConstraint('b != 0', p), isTrue);
      expect(evalConstraint('b == 0', p), isFalse);
      expect(evalConstraint('a != 3', p), isFalse);
      expect(evalConstraint('b == -4', p), isTrue);
      expect(evalConstraint('a < 3', p), isFalse);
      expect(evalConstraint('a <= 3', p), isTrue);
      expect(evalConstraint('a > 3', p), isFalse);
      expect(evalConstraint('a >= 3', p), isTrue);
      expect(evalConstraint('a*a != b*b', p), isTrue);
      expect(evalConstraint('a + b == -1', p), isTrue);
      expect(evalConstraint('a > b', p), isTrue);
    });
    test('計算できない側は偽、書き間違いは FormatException', () {
      expect(evalConstraint('1/(a-3) != 0', p), isFalse);
      expect(() => evalConstraint('a', p), throwsFormatException);
      expect(() => evalConstraint('z > 0', p), throwsFormatException);
      expect(() => evalConstraint('a >', p), throwsFormatException);
    });
  });
}
