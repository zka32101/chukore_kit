import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ptTests();
  esTests();
  frTests();
  koZhTests();
  test('言語コードから文言を選ぶ（未対応は英語）', () {
    expect(ChukoreStrings.forLocale('ja').languageCode, 'ja');
    expect(ChukoreStrings.forLocale('ja_JP').languageCode, 'ja');
    expect(ChukoreStrings.forLocale('en-US').languageCode, 'en');
    expect(ChukoreStrings.forLocale('de').languageCode, 'en');
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
    for (final s in const [JaStrings(), EnStrings(), PtStrings(), PtStrings(european: true), EsStrings(), FrStrings(), FrStrings(septanteNonante: true), KoStrings(), ZhStrings(), ZhStrings(traditional: true)]) {
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

void frTests() {
  group('フランス語', () {
    test('forLocale: fr は標準、fr-BE・fr-CH は septante/nonante', () {
      expect(ChukoreStrings.forLocale('fr'), isA<FrStrings>());
      expect((ChukoreStrings.forLocale('fr-FR') as FrStrings).septanteNonante, isFalse);
      expect((ChukoreStrings.forLocale('fr_BE') as FrStrings).septanteNonante, isTrue);
      expect((ChukoreStrings.forLocale('fr-CH') as FrStrings).septanteNonante, isTrue);
      expect(ChukoreStrings.forLocale('fr-CA').decimalSeparator, ',');
    });

    test('数の読み上げ（cent・vingt の s、et un、70〜99）', () {
      const fr = FrStrings();
      expect(fr.gateNumberWords(482), 'quatre cent quatre-vingt-deux');
      expect(fr.gateNumberWords(100), 'cent');
      expect(fr.gateNumberWords(101), 'cent un');
      expect(fr.gateNumberWords(200), 'deux cents');
      expect(fr.gateNumberWords(201), 'deux cent un');
      expect(fr.gateNumberWords(221), 'deux cent vingt et un');
      expect(fr.gateNumberWords(222), 'deux cent vingt-deux');
      expect(fr.gateNumberWords(271), 'deux cent soixante et onze');
      expect(fr.gateNumberWords(272), 'deux cent soixante-douze');
      expect(fr.gateNumberWords(277), 'deux cent soixante-dix-sept');
      expect(fr.gateNumberWords(280), 'deux cent quatre-vingts');
      expect(fr.gateNumberWords(281), 'deux cent quatre-vingt-un');
      expect(fr.gateNumberWords(300), 'trois cents');
      expect(fr.gateNumberWords(370), 'trois cent soixante-dix');
      expect(fr.gateNumberWords(391), 'trois cent quatre-vingt-onze');
      expect(fr.gateNumberWords(397), 'trois cent quatre-vingt-dix-sept');
      expect(fr.gateNumberWords(116), 'cent seize');
      expect(fr.gateNumberWords(117), 'cent dix-sept');
      expect(fr.gateNumberWords(999), 'neuf cent quatre-vingt-dix-neuf');
      expect(fr.gateNumberWords(1000), 'mille');
      expect(fr.gateNumberWords(1500), 'mille cinq cents');
      expect(fr.gateNumberWords(1981), 'mille neuf cent quatre-vingt-un');
      expect(fr.gateNumberWords(2000), 'deux mille');
      expect(fr.gateNumberWords(2080), 'deux mille quatre-vingts');
      expect(fr.gateNumberWords(2100), 'deux mille cent');
    });

    test('ベルギー・スイス式', () {
      const be = FrStrings(septanteNonante: true);
      expect(be.gateNumberWords(472), 'quatre cent septante-deux');
      expect(be.gateNumberWords(171), 'cent septante et un');
      expect(be.gateNumberWords(391), 'trois cent nonante et un');
      expect(be.gateNumberWords(399), 'trois cent nonante-neuf');
      expect(be.gateNumberWords(380), 'trois cent quatre-vingts');
    });

    test('成長カード: 1,5 は単数、約物の前は改行されない空白、下がっても落ち込ませない', () {
      GrowthCardData d(double? delta, {double? toNext = 5, bool best = false}) => GrowthCardData(
            subjectLabel: 'Anglais',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            isPersonalBest: best,
            strings: const FrStrings(),
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, '+2,5 depuis la dernière fois');
      expect(d(-4).headline, 'Repartons de là pour progresser');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, best: true).headline, 'Nouveau record personnel !');
      expect(d(null, toNext: 1).nextLine, 'Plus que 1 point pour le niveau suivant');
      expect(d(null, toNext: 1.5).nextLine, 'Plus que 1,5 point pour le niveau suivant');
      expect(d(null, toNext: 2).nextLine, 'Plus que 2 points pour le niveau suivant');
      expect(d(null, toNext: 7.5).nextLine, 'Plus que 7,5 points pour le niveau suivant');
      expect(d(1, toNext: null).nextLine, 'Niveau maximal atteint !');
    });

    test('レポート・年・単複（0 と 1 は単数）', () {
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 0,
        activeDays: 1,
        improvements: const [Improvement('u', 'Verbes', 0.4, 0.7)],
      );
      expect(r.toText(strings: const FrStrings()),
          'Cette semaine : 1 jour / 0 question\nProgrès de la semaine :\n- Verbes (40 % -> 70 %)');
      expect(const FrStrings().formatYear(-500), '500 av. J.-C.');
      expect(const FrStrings().formatYear(1789), '1789 apr. J.-C.');
      expect(const FrStrings().solvableValue(1), '1 question');
      expect(const FrStrings().solvableValue(3), '3 questions');
      expect(const FrStrings().streakDays(1), '1 jour de suite');
    });

    test('数値入力: 小数点カンマ・空白区切り（1 200,5）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const FrStrings().decimalSeparator;
      expect(checkAnswer(q, '1 200,5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1 200,5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200,5', decimalSeparator: sep).correct, isTrue);
    });
  });
}

void koZhTests() {
  group('韓国語', () {
    test('forLocale', () {
      expect(ChukoreStrings.forLocale('ko'), isA<KoStrings>());
      expect(ChukoreStrings.forLocale('ko-KR'), isA<KoStrings>());
    });

    test('数の読み上げ（漢字語。百・十の前の「일」は言わない）', () {
      const ko = KoStrings();
      expect(ko.gateNumberWords(10), '십');
      expect(ko.gateNumberWords(11), '십일');
      expect(ko.gateNumberWords(100), '백');
      expect(ko.gateNumberWords(101), '백일');
      expect(ko.gateNumberWords(110), '백십');
      expect(ko.gateNumberWords(111), '백십일');
      expect(ko.gateNumberWords(482), '사백팔십이');
      expect(ko.gateNumberWords(999), '구백구십구');
      expect(ko.gateNumberWords(1000), '천');
      expect(ko.gateNumberWords(1200), '천이백');
      expect(ko.gateNumberWords(2025), '이천이십오');
    });

    test('成長カード・レポート・年', () {
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: '영어',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: const KoStrings(),
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(8).headline, '지난번보다 +8점');
      expect(d(-3).headline, '여기서부터 다시 키워 봐요');
      expect(d(-3).headline.contains('-'), isFalse);
      expect(d(null).nextLine, '다음 레벨까지 5점');
      expect(d(1, toNext: null).nextLine, '최고 레벨 달성!');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', '동사', 0.4, 0.7)],
      );
      expect(r.toText(strings: const KoStrings()),
          '이번 주 학습: 3일 / 12문제\n이번 주 성장한 부분:\n- 동사 (40% -> 70%)');
      expect(const KoStrings().formatYear(-500), '기원전 500년');
      expect(const KoStrings().formatYear(1945), '1945년');
    });
  });

  group('中国語', () {
    test('forLocale: 簡体が既定、繁体は Hant・TW・HK・MO。スクリプトが地域に優先', () {
      expect((ChukoreStrings.forLocale('zh') as ZhStrings).traditional, isFalse);
      expect((ChukoreStrings.forLocale('zh-CN') as ZhStrings).traditional, isFalse);
      expect((ChukoreStrings.forLocale('zh_Hans') as ZhStrings).traditional, isFalse);
      expect((ChukoreStrings.forLocale('zh-Hant') as ZhStrings).traditional, isTrue);
      expect((ChukoreStrings.forLocale('zh-TW') as ZhStrings).traditional, isTrue);
      expect((ChukoreStrings.forLocale('zh_HK') as ZhStrings).traditional, isTrue);
      expect((ChukoreStrings.forLocale('zh-Hant-TW') as ZhStrings).traditional, isTrue);
      expect((ChukoreStrings.forLocale('zh-Hans-TW') as ZhStrings).traditional, isFalse);
      expect(const ZhStrings().tag, 'zh-Hans');
      expect(const ZhStrings(traditional: true).tag, 'zh-Hant');
    });

    test('数の読み上げ（零の入れ方、十・一十）', () {
      const zh = ZhStrings();
      expect(zh.gateNumberWords(15), '十五');
      expect(zh.gateNumberWords(100), '一百');
      expect(zh.gateNumberWords(101), '一百零一');
      expect(zh.gateNumberWords(105), '一百零五');
      expect(zh.gateNumberWords(110), '一百一十');
      expect(zh.gateNumberWords(115), '一百一十五');
      expect(zh.gateNumberWords(482), '四百八十二');
      expect(zh.gateNumberWords(999), '九百九十九');
      expect(zh.gateNumberWords(1000), '一千');
      expect(zh.gateNumberWords(1005), '一千零五');
      expect(zh.gateNumberWords(1010), '一千零一十');
      expect(zh.gateNumberWords(1200), '一千二百');
      expect(zh.gateNumberWords(2025), '二千零二十五');
      // 簡体・繁体で同じ字
      expect(const ZhStrings(traditional: true).gateNumberWords(482), '四百八十二');
    });

    test('簡体と繁体で字体が違う', () {
      const hans = ZhStrings();
      const hant = ZhStrings(traditional: true);
      expect(hans.cardTitle('英语'), '英语 成长卡片');
      expect(hant.cardTitle('英語'), '英語 成長卡片');
      expect(hans.solvableValue(5), '5题');
      expect(hant.solvableValue(5), '5題');
      expect(hans.streakDays(3), '连续3天');
      expect(hant.streakDays(3), '連續3天');
      expect(hans.headlineDown, '从这里再出发吧');
      expect(hant.headlineDown, '從這裡再出發吧');
      expect(hans.mapSemantics, '地图。点击选择答案');
      expect(hant.mapSemantics, '地圖。點選以選擇答案');
    });

    test('成長カード・レポート・年（下がっても落ち込ませない）', () {
      GrowthCardData d(double? delta, {double? toNext = 5, ChukoreStrings s = const ZhStrings()}) =>
          GrowthCardData(
            subjectLabel: '英语',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: s,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(8).headline, '比上次 +8分');
      expect(d(2.5).headline, '比上次 +2.5分');
      expect(d(-3).headline, '从这里再出发吧');
      expect(d(-3).headline.contains('-'), isFalse);
      expect(d(null).nextLine, '距离下一级还差5分');
      expect(d(null, s: const ZhStrings(traditional: true)).nextLine, '距離下一級還差5分');
      expect(d(1, toNext: null).nextLine, '已达到最高等级！');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', '动词', 0.4, 0.7)],
      );
      expect(r.toText(strings: const ZhStrings()),
          '本周学习：3天 / 12题\n本周进步的地方：\n- 动词（40% -> 70%）');
      expect(const ZhStrings().formatYear(-221), '公元前221年');
    });
  });
}
