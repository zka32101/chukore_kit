import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const it = ItStrings();

  test('it を選べる。小数点はカンマ', () {
    expect(ChukoreStrings.forLocale('it-IT').languageCode, 'it');
    expect(ChukoreStrings.forLocale('it-CH').languageCode, 'it');
    expect(it.formatNumber(2.5), '2,5');
  });

  test('数の読み上げ: 母音の省略・アクセント・千', () {
    const expected = {
      1: 'uno',
      3: 'tre',
      10: 'dieci',
      13: 'tredici',
      21: 'ventuno',
      23: 'ventitré',
      28: 'ventotto',
      31: 'trentuno',
      43: 'quarantatré',
      88: 'ottantotto',
      100: 'cento',
      101: 'centouno',
      103: 'centotré',
      108: 'centotto',
      113: 'centotredici',
      180: 'centottanta',
      181: 'centottantuno',
      280: 'duecentottanta',
      482: 'quattrocentottantadue',
      1000: 'mille',
      1003: 'milletré',
      1013: 'milletredici',
      1100: 'millecento',
      2000: 'duemila',
      3003: 'tremilatré',
      9999: 'novemilanovecentonovantanove',
    };
    for (final e in expected.entries) {
      expect(it.gateNumberWords(e.key), e.value, reason: '${e.key}');
    }
    expect(() => it.gateNumberWords(0), throwsRangeError);
    expect(() => it.gateNumberWords(10000), throwsRangeError);
  });

  test('1〜9999 はすべて空でなく、互いに違う読み', () {
    final seen = <String>{};
    for (var n = 1; n <= 9999; n++) {
      final w = it.gateNumberWords(n);
      expect(w.isNotEmpty && !w.contains(' '), isTrue, reason: '$n');
      expect(seen.add(w), isTrue, reason: '$n: $w');
    }
  });

  test('複数形・年の表記', () {
    expect(it.streakDays(1), '1 giorno di fila');
    expect(it.streakDays(3), '3 giorni di fila');
    expect(it.solvableValue(1), '1 domanda');
    expect(it.solvableValue(5), '5 domande');
    expect(it.nextLevel('1'), 'Manca 1 punto al livello successivo');
    expect(it.nextLevel('3'), 'Mancano 3 punti al livello successivo');
    expect(it.formatYear(-500), '500 a.C.');
    expect(it.formatYear(1945), '1945 d.C.');
  });
}
