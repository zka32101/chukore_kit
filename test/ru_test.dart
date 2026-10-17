import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ru = RuStrings();

  test('ru を選べる。小数点はカンマ', () {
    expect(ChukoreStrings.forLocale('ru-RU').languageCode, 'ru');
    expect(ru.decimalSeparator, ',');
    expect(ru.formatNumber(2.5), '2,5');
  });

  test('数の読み上げ: 11〜19・千は女性形・桁の組み合わせ', () {
    expect(ru.gateNumberWords(1), 'один');
    expect(ru.gateNumberWords(11), 'одиннадцать');
    expect(ru.gateNumberWords(21), 'двадцать один');
    expect(ru.gateNumberWords(100), 'сто');
    expect(ru.gateNumberWords(482), 'четыреста восемьдесят два');
    expect(ru.gateNumberWords(1000), 'одна тысяча');
    expect(ru.gateNumberWords(2012), 'две тысячи двенадцать');
    expect(ru.gateNumberWords(5000), 'пять тысяч');
    expect(ru.gateNumberWords(9999), 'девять тысяч девятьсот девяносто девять');
    expect(() => ru.gateNumberWords(10000), throwsRangeError);
  });

  test('複数形: 1 / 2〜4 / 5 以上、11〜14 は 5 以上の形', () {
    String d(int n) => RuStrings.plural(n, 'день', 'дня', 'дней');
    expect([for (final n in [1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111]) d(n)], [
      'день', 'дня', 'дня', 'дней', 'дней', 'дней', 'дней', 'день', 'дня', 'дней', 'день', 'дней',
    ]);
    expect(ru.streakDays(3), '3 дня подряд');
    expect(ru.solvableValue(11), '11 вопросов');
  });

  test('年の表記', () {
    expect(ru.formatYear(-500), '500 г. до н. э.');
    expect(ru.formatYear(1945), '1945 г.');
  });
}
