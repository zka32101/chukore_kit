import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pl = PlStrings();

  test('pl を選べる。小数点はカンマ', () {
    expect(ChukoreStrings.forLocale('pl-PL').languageCode, 'pl');
    expect(pl.formatNumber(2.5), '2,5');
  });

  test('数の読み上げ: 10〜19・百・千の形', () {
    const expected = {
      1: 'jeden',
      11: 'jedenaście',
      14: 'czternaście',
      20: 'dwadzieścia',
      21: 'dwadzieścia jeden',
      100: 'sto',
      200: 'dwieście',
      300: 'trzysta',
      500: 'pięćset',
      482: 'czterysta osiemdziesiąt dwa',
      1000: 'tysiąc',
      2000: 'dwa tysiące',
      4000: 'cztery tysiące',
      5000: 'pięć tysięcy',
      9000: 'dziewięć tysięcy',
      1012: 'tysiąc dwanaście',
      2345: 'dwa tysiące trzysta czterdzieści pięć',
      9999: 'dziewięć tysięcy dziewięćset dziewięćdziesiąt dziewięć',
    };
    for (final e in expected.entries) {
      expect(pl.gateNumberWords(e.key), e.value, reason: '${e.key}');
    }
    expect(() => pl.gateNumberWords(0), throwsRangeError);
    expect(() => pl.gateNumberWords(10000), throwsRangeError);
  });

  test('1〜9999 はすべて空でなく、互いに違う読み', () {
    final seen = <String>{};
    for (var n = 1; n <= 9999; n++) {
      final w = pl.gateNumberWords(n);
      expect(w.trim().isNotEmpty && !w.contains('  '), isTrue, reason: '$n');
      expect(seen.add(w), isTrue, reason: '$n: $w');
    }
  });

  test('複数形: 1 だけが単数形。21・101 は複数形。12〜14 は「それ以外」', () {
    String q(int n) => PlStrings.plural(n, 'pytanie', 'pytania', 'pytań');
    expect([for (final n in [1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 102, 112]) q(n)], [
      'pytanie', 'pytania', 'pytania', 'pytań', 'pytań', 'pytań', 'pytań',
      'pytań', 'pytania', 'pytań', 'pytań', 'pytania', 'pytań',
    ]);
    expect(pl.solvableValue(3), '3 pytania');
    expect(pl.streakDays(1), '1 dzień z rzędu');
    expect(pl.streakDays(5), '5 dni z rzędu');
    expect(pl.nextLevel('1'), 'Do następnego poziomu brakuje 1 punktu');
    expect(pl.nextLevel('4'), 'Do następnego poziomu brakuje 4 punktów');
  });

  test('年の表記', () {
    expect(pl.formatYear(-500), '500 r. p.n.e.');
    expect(pl.formatYear(1945), '1945 r.');
  });
}
