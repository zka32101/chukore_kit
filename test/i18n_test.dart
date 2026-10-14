import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ptTests();
  esTests();
  test('言語コードから文言を選ぶ（未対応は英語）', () {
    expect(ChukoreStrings.forLocale('ja').languageCode, 'ja');
    expect(ChukoreStrings.forLocale('ja_JP').languageCode, 'ja');
    expect(ChukoreStrings.forLocale('en-US').languageCode, 'en');
    expect(ChukoreStrings.forLocale('fr').languageCode, 'en');
  });

  test('英語の数の読み上げ', () {
    const en = EnStrings();
    expect(en.gateNumberWords(482), 'four hundred eighty-two');
    expect(en.gateNumberWords(110), 'one hundred ten');
    expect(en.gateNumberWords(305), 'three hundred five');
    expect(en.gateNumberWords(900), 'nine hundred');
    expect(en.gateNumberWords(1000), 'one thousand');
    expect(en.gateNumberWords(819), 'eight hundred nineteen');
  });

  test('保護者ゲートは言語ごとの読み上げで、桁区切りも許容', () {
    const c = GateChallenge(482);
    expect(c.prompt, '四百八十二');
    expect(c.promptFor(const EnStrings()), 'four hundred eighty-two');
    expect(c.verify('482'), isTrue);
    expect(c.verify('４８２'), isTrue);
    expect(c.verify('483'), isFalse);
    expect(GateChallenge(1200).verify('1,200'), isTrue);
    expect(GateChallenge(1200).verify('1.200'), isTrue);
    expect(GateChallenge(1200).verify('1 200'), isTrue);
  });

  test('すべての言語で全100〜999の読み上げが空にならない', () {
    for (final s in const [JaStrings(), EnStrings(), PtStrings(), PtStrings(european: true), EsStrings()]) {
      for (var n = 100; n <= 999; n++) {
        expect(s.gateNumberWords(n).isNotEmpty, isTrue, reason: '${s.languageCode} $n');
      }
    }
  });

  test('成長カードの見出しを英語で出せる。下がっても落ち込ませない', () {
    GrowthCardData d(double? delta, {bool best = false, double? toNext = 5}) => GrowthCardData(
          subjectLabel: 'English',
          level: Level.b,
          pointsToNext: toNext,
          scoreDelta: delta,
          isPersonalBest: best,
          strings: const EnStrings(),
          radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
        );
    expect(d(8).headline, '+8 from last time');
    expect(d(-6).headline, "Let's build from here");
    expect(d(-6).headline.contains('-'), isFalse);
    expect(d(null).headline, 'A great start');
    expect(d(0, best: true).headline, 'New personal best!');
    expect(d(1).nextLine, '5 more points to the next level');
    expect(d(1, toNext: null).nextLine, 'Top level reached!');
  });

  test('週次レポートを英語で出せる（単複も）', () {
    final r = WeeklyReport(
      weekStart: DateTime.utc(2026, 10, 13),
      attemptCount: 1,
      activeDays: 1,
      improvements: const [Improvement('u', 'Verbs', 0.4, 0.7)],
    );
    expect(r.toText(strings: const EnStrings()),
        'This week: 1 day / 1 question\nImproved this week:\n- Verbs (40% -> 70%)');
    final empty = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13), attemptCount: 0, activeDays: 0, improvements: const []);
    expect(empty.toText(strings: const EnStrings()), contains('No new improvements'));
  });

  test('年の表記', () {
    expect(const JaStrings().formatYear(-10000), '前10000年');
    expect(const EnStrings().formatYear(-10000), '10000 BCE');
    expect(const EnStrings().formatYear(1868), '1868 CE');
  });

  test('数値入力: 小数点がカンマの国でも判定できる', () {
    const q = Question(
      id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
      choices: [], answer: '1200.5', explanationId: 'x',
    );
    expect(checkAnswer(q, '1.200,5', decimalSeparator: ',').correct, isTrue);
    expect(checkAnswer(q, '1200,5', decimalSeparator: ',').correct, isTrue);
    expect(checkAnswer(q, '1,200.5').correct, isTrue);
    expect(checkAnswer(q, '1200.5').correct, isTrue);
    expect(checkAnswer(q, '1 200,5', decimalSeparator: ',').correct, isTrue);
    expect(checkAnswer(q, '1200,5').correct, isFalse); // 既定('.')ではカンマは桁区切り=12005
  });

  test('数値入力: マイナス記号の違いを吸収', () {
    const q = Question(
      id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
      choices: [], answer: '-3', explanationId: 'x',
    );
    expect(checkAnswer(q, '−3').correct, isTrue); // U+2212
    expect(checkAnswer(q, '－３').correct, isTrue); // 全角
  });

  testWidgets('英語の読み上げ文言（地図・年表・カード）', (tester) async {
    final handle = tester.ensureSemantics();
    const en = EnStrings();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SizedBox(
            width: 200,
            height: 100,
            child: RegionTapMap(
              regions: [
                MapRegion(id: 'a', label: 'A', rings: [
                  [const GeoPoint(0, 0), const GeoPoint(1, 0), const GeoPoint(1, 1)]
                ]),
              ],
              available: const {'a'},
              answered: false,
              correctId: 'a',
              strings: en,
              onRegionTapped: (_) {},
            ),
          ),
          TimelineOrderList(
            events: const [TimelineEvent(id: 'x', label: 'Event', year: -500)],
            onReordered: (_) {},
            revealYears: true,
            strings: en,
          ),
        ]),
      ),
    ));
    expect(find.bySemanticsLabel('Map. Tap to choose your answer'), findsOneWidget);
    expect(find.text('500 BCE'), findsOneWidget);
    handle.dispose();
  });
}

void ptTests() {
  group('ポルトガル語', () {
    test('forLocale: pt / pt-BR はブラジル式、pt-PT は欧州式', () {
      expect(ChukoreStrings.forLocale('pt'), isA<PtStrings>());
      expect((ChukoreStrings.forLocale('pt-BR') as PtStrings).european, isFalse);
      expect((ChukoreStrings.forLocale('pt_PT') as PtStrings).european, isTrue);
      expect(ChukoreStrings.forLocale('PT-pt'), isA<PtStrings>());
    });

    test('数の読み上げ', () {
      const pt = PtStrings();
      expect(pt.gateNumberWords(482), 'quatrocentos e oitenta e dois');
      expect(pt.gateNumberWords(100), 'cem');
      expect(pt.gateNumberWords(101), 'cento e um');
      expect(pt.gateNumberWords(110), 'cento e dez');
      expect(pt.gateNumberWords(900), 'novecentos');
      expect(pt.gateNumberWords(999), 'novecentos e noventa e nove');
      expect(pt.gateNumberWords(1000), 'mil');
      expect(pt.gateNumberWords(1020), 'mil e vinte');
      expect(pt.gateNumberWords(1500), 'mil e quinhentos');
      expect(pt.gateNumberWords(1340), 'mil trezentos e quarenta');
      expect(pt.gateNumberWords(2005), 'dois mil e cinco');
    });

    test('pt-BR と pt-PT の綴りの違い', () {
      expect(const PtStrings().gateNumberWords(816), 'oitocentos e dezesseis');
      expect(const PtStrings(european: true).gateNumberWords(816), 'oitocentos e dezasseis');
      expect(const PtStrings().gateNumberWords(219), 'duzentos e dezenove');
      expect(const PtStrings(european: true).gateNumberWords(217), 'duzentos e dezassete');
    });

    test('保護者ゲートの読み上げ・入力（1.200 や 1 200 の桁区切りも可）', () {
      const c = GateChallenge(482);
      expect(c.promptFor(const PtStrings()), 'quatrocentos e oitenta e dois');
      expect(c.verify('482'), isTrue);
      expect(GateChallenge(1200).verify('1.200'), isTrue);
    });

    test('成長カード: 小数点はカンマ、下がっても落ち込ませない', () {
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'Inglês',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: const PtStrings(),
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, '+2,5 desde a última vez');
      expect(d(8).headline, '+8 desde a última vez');
      expect(d(-4).headline, 'Vamos crescer a partir daqui');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 7.5).nextLine, 'Faltam 7,5 pontos para o próximo nível');
      expect(d(1, toNext: null).nextLine, 'Nível máximo alcançado!');
      expect(d(null).headline, 'Um ótimo começo');
    });

    test('レポート・年・単複', () {
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 1,
        improvements: const [Improvement('u', 'Verbos', 0.4, 0.7)],
      );
      expect(r.toText(strings: const PtStrings()),
          'Esta semana: 1 dia / 12 questões\nEvoluiu esta semana:\n- Verbos (40% -> 70%)');
      expect(const PtStrings().formatYear(-500), '500 a.C.');
      expect(const PtStrings().formatYear(1822), '1822 d.C.');
      expect(const PtStrings().solvableValue(1), '1 questão');
      expect(const PtStrings().streakDays(3), '3 dias seguidos');
    });

    test('数値入力: ブラジル式（1.200,5）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      expect(checkAnswer(q, '1.200,5', decimalSeparator: ',').correct, isTrue);
      expect(checkAnswer(q, '1200,5', decimalSeparator: ',').correct, isTrue);
    });
  });
}

void esTests() {
  group('スペイン語', () {
    test('forLocale: es は小数点カンマ、es-MX などは小数点ドット', () {
      expect(ChukoreStrings.forLocale('es'), isA<EsStrings>());
      expect(ChukoreStrings.forLocale('es-ES').decimalSeparator, ',');
      expect(ChukoreStrings.forLocale('es_AR').decimalSeparator, ',');
      expect(ChukoreStrings.forLocale('es-MX').decimalSeparator, '.');
      expect(ChukoreStrings.forLocale('es-US').decimalSeparator, '.');
      expect(const EsStrings(decimalComma: false).decimalSeparator, '.');
    });

    test('数の読み上げ', () {
      const es = EsStrings();
      expect(es.gateNumberWords(482), 'cuatrocientos ochenta y dos');
      expect(es.gateNumberWords(100), 'cien');
      expect(es.gateNumberWords(101), 'ciento uno');
      expect(es.gateNumberWords(115), 'ciento quince');
      expect(es.gateNumberWords(121), 'ciento veintiuno');
      expect(es.gateNumberWords(122), 'ciento veintidós');
      expect(es.gateNumberWords(130), 'ciento treinta');
      expect(es.gateNumberWords(500), 'quinientos');
      expect(es.gateNumberWords(716), 'setecientos dieciséis');
      expect(es.gateNumberWords(999), 'novecientos noventa y nueve');
      expect(es.gateNumberWords(1000), 'mil');
      expect(es.gateNumberWords(1500), 'mil quinientos');
      expect(es.gateNumberWords(2025), 'dos mil veinticinco');
    });

    test('成長カード: 小数点と単数形、下がっても落ち込ませない', () {
      GrowthCardData d(double? delta, {double? toNext = 5, ChukoreStrings s = const EsStrings()}) =>
          GrowthCardData(
            subjectLabel: 'Inglés',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: s,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, '+2,5 desde la última vez');
      expect(d(2.5, s: const EsStrings(decimalComma: false)).headline, '+2.5 desde la última vez');
      expect(d(-4).headline, 'Sigamos creciendo desde aquí');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 1).nextLine, 'Falta 1 punto para el siguiente nivel');
      expect(d(null, toNext: 7.5).nextLine, 'Faltan 7,5 puntos para el siguiente nivel');
      expect(d(1, toNext: null).nextLine, '¡Nivel máximo alcanzado!');
    });

    test('レポート・年・単複', () {
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 1,
        activeDays: 3,
        improvements: const [Improvement('u', 'Verbos', 0.4, 0.7)],
      );
      expect(r.toText(strings: const EsStrings()),
          'Esta semana: 3 días / 1 pregunta\nMejoraste esta semana:\n- Verbos (40% -> 70%)');
      expect(const EsStrings().formatYear(-500), '500 a. C.');
      expect(const EsStrings().formatYear(1810), '1810 d. C.');
      expect(const EsStrings().streakDays(1), '1 día seguido');
    });

    test('数値入力は strings.decimalSeparator をそのまま渡せる', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      const es = EsStrings();
      const mx = EsStrings(decimalComma: false);
      expect(checkAnswer(q, '1.200,5', decimalSeparator: es.decimalSeparator).correct, isTrue);
      expect(checkAnswer(q, '1,200.5', decimalSeparator: mx.decimalSeparator).correct, isTrue);
    });
  });

  test('単数形: 英語・ポルトガル語も 1 点のとき単数', () {
    expect(const EnStrings().nextLevel('1'), '1 more point to the next level');
    expect(const PtStrings().nextLevel('1'), 'Falta 1 ponto para o próximo nível');
    expect(const PtStrings().nextLevel('3'), 'Faltam 3 pontos para o próximo nível');
  });
}
