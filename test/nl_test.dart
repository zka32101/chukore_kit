import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nl = NlStrings();

  test('nl を選べる。小数点はカンマ', () {
    expect(ChukoreStrings.forLocale('nl-NL').languageCode, 'nl');
    expect(ChukoreStrings.forLocale('nl-BE').languageCode, 'nl');
    expect(nl.formatNumber(2.5), '2,5');
  });

  test('数の読み上げ: 一の位 + en + 十の位、twee・drie は ën', () {
    const expected = {
      1: 'een',
      11: 'elf',
      13: 'dertien',
      20: 'twintig',
      21: 'eenentwintig',
      22: 'tweeëntwintig',
      23: 'drieëntwintig',
      24: 'vierentwintig',
      27: 'zevenentwintig',
      28: 'achtentwintig',
      33: 'drieëndertig',
      99: 'negenennegentig',
      100: 'honderd',
      101: 'honderdeen',
      102: 'honderdtwee',
      200: 'tweehonderd',
      482: 'vierhonderdtweeëntachtig',
      1000: 'duizend',
      1001: 'duizendeen',
      1100: 'duizendhonderd',
      2012: 'tweeduizendtwaalf',
      9999: 'negenduizendnegenhonderdnegenennegentig',
    };
    for (final e in expected.entries) {
      expect(nl.gateNumberWords(e.key), e.value, reason: '${e.key}');
    }
    expect(() => nl.gateNumberWords(0), throwsRangeError);
    expect(() => nl.gateNumberWords(10000), throwsRangeError);
  });

  test('1〜9999 はすべて空でなく、互いに違う読み', () {
    final seen = <String>{};
    for (var n = 1; n <= 9999; n++) {
      final w = nl.gateNumberWords(n);
      expect(w.isNotEmpty && !w.contains(' '), isTrue, reason: '$n');
      expect(seen.add(w), isTrue, reason: '$n: $w');
    }
  });

  test('複数形・年の表記', () {
    expect(nl.streakDays(1), '1 dag op rij');
    expect(nl.streakDays(3), '3 dagen op rij');
    expect(nl.solvableValue(1), '1 vraag');
    expect(nl.solvableValue(5), '5 vragen');
    expect(nl.nextLevel('1'), 'Nog 1 punt tot het volgende niveau');
    expect(nl.nextLevel('3'), 'Nog 3 punten tot het volgende niveau');
    expect(nl.formatYear(-500), '500 v.Chr.');
    expect(nl.formatYear(1945), '1945 n.Chr.');
  });
}
