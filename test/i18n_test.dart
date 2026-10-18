import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ptTests();
  esTests();
  frTests();
  koZhTests();
  idTests();
  viTests();
  deTests();
  trTests();
  thTests();
  hiTests();
  formatNumberTests();
  test('言語コードから文言を選ぶ（未対応は英語）', () {
    expect(ChukoreStrings.forLocale('ja').languageCode, 'ja');
    expect(ChukoreStrings.forLocale('ja_JP').languageCode, 'ja');
    expect(ChukoreStrings.forLocale('en-US').languageCode, 'en');
    expect(ChukoreStrings.forLocale('pl').languageCode, 'en');
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

void idTests() {
  group('インドネシア語', () {
    test('forLocale: id・id-ID・旧式の in', () {
      expect(ChukoreStrings.forLocale('id'), isA<IdStrings>());
      expect(ChukoreStrings.forLocale('id-ID'), isA<IdStrings>());
      expect(ChukoreStrings.forLocale('in'), isA<IdStrings>());
      expect(ChukoreStrings.forLocale('in_ID'), isA<IdStrings>());
      expect(const IdStrings().tag, 'id');
    });

    test('数の読み上げ（seratus・sebelas・belas・puluh・seribu）', () {
      const id = IdStrings();
      expect(id.gateNumberWords(482), 'empat ratus delapan puluh dua');
      expect(id.gateNumberWords(100), 'seratus');
      expect(id.gateNumberWords(101), 'seratus satu');
      expect(id.gateNumberWords(110), 'seratus sepuluh');
      expect(id.gateNumberWords(111), 'seratus sebelas');
      expect(id.gateNumberWords(115), 'seratus lima belas');
      expect(id.gateNumberWords(120), 'seratus dua puluh');
      expect(id.gateNumberWords(200), 'dua ratus');
      expect(id.gateNumberWords(321), 'tiga ratus dua puluh satu');
      expect(id.gateNumberWords(999), 'sembilan ratus sembilan puluh sembilan');
      expect(id.gateNumberWords(1000), 'seribu');
      expect(id.gateNumberWords(1001), 'seribu satu');
      expect(id.gateNumberWords(1500), 'seribu lima ratus');
      expect(id.gateNumberWords(2025), 'dua ribu dua puluh lima');
      expect(id.gateNumberWords(9999), 'sembilan ribu sembilan ratus sembilan puluh sembilan');
      expect(() => id.gateNumberWords(0), throwsRangeError);
    });

    test('1〜9999 のすべてで、典型的な誤り（satu ratus・satu puluh・satu belas・satu ribu・空白の乱れ）が出ない', () {
      const id = IdStrings();
      for (var n = 1; n <= 9999; n++) {
        final w = id.gateNumberWords(n);
        expect(w, isNotEmpty, reason: '$n');
        expect(w, equals(w.trim()), reason: '$n 前後の空白: "$w"');
        expect(w.contains('  '), isFalse, reason: '$n 二重の空白: "$w"');
        for (final wrong in ['satu ratus', 'satu puluh', 'satu belas', 'satu ribu', 'sepuluh satu']) {
          expect(w.contains(wrong), isFalse, reason: '$n に "$wrong": "$w"');
        }
      }
      // 区切りの数: 下3桁の読みを足し上げたものと一致（桁の取りこぼしが無い）
      expect(id.gateNumberWords(5050), 'lima ribu lima puluh');
      expect(id.gateNumberWords(1010), 'seribu sepuluh');
      expect(id.gateNumberWords(7000), 'tujuh ribu');
    });

    test('保護者ゲート: 読み上げと、ドットの桁区切り（1.200）', () {
      expect(const GateChallenge(482).promptFor(const IdStrings()), 'empat ratus delapan puluh dua');
      expect(const GateChallenge(1200).verify('1.200'), isTrue);
    });

    test('小数点はカンマ。成長カード・レポート・年', () {
      const id = IdStrings();
      expect(id.decimalSeparator, ',');
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'Bahasa Inggris',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: id,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, '+2,5 dari sebelumnya');
      expect(d(-4).headline, 'Mari tingkatkan lagi dari sini');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 7.5).nextLine, '7,5 poin lagi menuju level berikutnya');
      expect(d(1, toNext: null).nextLine, 'Level tertinggi tercapai!');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', 'Kata kerja', 0.4, 0.7)],
      );
      expect(r.toText(strings: id),
          'Minggu ini: 3 hari / 12 soal\nYang meningkat minggu ini:\n- Kata kerja (40% -> 70%)');
      expect(id.formatYear(-500), '500 SM');
      expect(id.formatYear(1945), '1945 M');
      expect(id.solvableValue(1), '1 soal'); // 複数形は無い
      expect(id.streakDays(1), '1 hari berturut-turut');
    });

    test('数値入力: 1.200,5（ドットが桁区切り、カンマが小数点）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const IdStrings().decimalSeparator;
      expect(checkAnswer(q, '1.200,5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200,5', decimalSeparator: sep).correct, isTrue);
    });

    test('持ち物の既定の項目・プリント・偏差値の名称', () {
      const id = IdStrings();
      expect(id.checklistDefaults.first, ('pencil', 'Alat tulis'));
      expect(id.checklistDefaults.length, 6);
      expect(id.deviationLabel, 'Indeks skor dalam aplikasi');
      expect(id.deviationNote, contains('50'));
      expect(formatDeviationRange(const DeviationEstimate(55), id), '50–60');
    });
  });
}

void viTests() {
  group('ベトナム語', () {
    test('forLocale: vi・vi-VN', () {
      expect(ChukoreStrings.forLocale('vi'), isA<ViStrings>());
      expect(ChukoreStrings.forLocale('vi-VN'), isA<ViStrings>());
      expect(ChukoreStrings.forLocale('vi_VN'), isA<ViStrings>());
      expect(const ViStrings().tag, 'vi');
    });

    test('数の読み上げ（mười・mốt・lăm・lẻ・không trăm・nghìn）', () {
      const vi = ViStrings();
      expect(vi.gateNumberWords(482), 'bốn trăm tám mươi hai');
      expect(vi.gateNumberWords(100), 'một trăm');
      expect(vi.gateNumberWords(101), 'một trăm lẻ một');
      expect(vi.gateNumberWords(105), 'một trăm lẻ năm');
      expect(vi.gateNumberWords(110), 'một trăm mười');
      expect(vi.gateNumberWords(111), 'một trăm mười một');
      expect(vi.gateNumberWords(115), 'một trăm mười lăm');
      expect(vi.gateNumberWords(120), 'một trăm hai mươi');
      expect(vi.gateNumberWords(121), 'một trăm hai mươi mốt');
      expect(vi.gateNumberWords(124), 'một trăm hai mươi bốn');
      expect(vi.gateNumberWords(125), 'một trăm hai mươi lăm');
      expect(vi.gateNumberWords(555), 'năm trăm năm mươi lăm');
      expect(vi.gateNumberWords(999), 'chín trăm chín mươi chín');
      expect(vi.gateNumberWords(1000), 'một nghìn');
      expect(vi.gateNumberWords(1001), 'một nghìn không trăm lẻ một');
      expect(vi.gateNumberWords(1010), 'một nghìn không trăm mười');
      expect(vi.gateNumberWords(1500), 'một nghìn năm trăm');
      expect(vi.gateNumberWords(2025), 'hai nghìn không trăm hai mươi lăm');
      expect(vi.gateNumberWords(9999), 'chín nghìn chín trăm chín mươi chín');
      expect(() => vi.gateNumberWords(0), throwsRangeError);
    });

    test('1〜9999 のすべてで、典型的な誤り（một mươi・mươi một・mười năm・lẻ mười・空白の乱れ）が出ない', () {
      const vi = ViStrings();
      for (var n = 1; n <= 9999; n++) {
        final w = vi.gateNumberWords(n);
        expect(w, isNotEmpty, reason: '$n');
        expect(w, equals(w.trim()), reason: '$n 前後の空白: "$w"');
        expect(w.contains('  '), isFalse, reason: '$n 二重の空白: "$w"');
        for (final wrong in ['một mươi', 'mươi một', 'mươi năm', 'mười năm', 'lẻ mười', 'lẻ lăm', 'không trăm không']) {
          expect(w.contains(wrong), isFalse, reason: '$n に "$wrong": "$w"');
        }
        // 千の位より下で百の位が 0 のときだけ「không trăm」が出る
        expect(w.contains('không trăm'), n >= 1000 && n % 1000 != 0 && n % 1000 < 100, reason: '$n: "$w"');
      }
    });

    test('保護者ゲート: 読み上げと、ドットの桁区切り（1.200）', () {
      expect(const GateChallenge(482).promptFor(const ViStrings()), 'bốn trăm tám mươi hai');
      expect(const GateChallenge(1200).verify('1.200'), isTrue);
    });

    test('小数点はカンマ。成長カード・レポート・年', () {
      const vi = ViStrings();
      expect(vi.decimalSeparator, ',');
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'Tiếng Anh',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: vi,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, '+2,5 so với lần trước');
      expect(d(-4).headline, 'Cùng tiến lên từ đây nhé');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 7.5).nextLine, '7,5 điểm nữa để lên cấp tiếp theo');
      expect(d(1, toNext: null).nextLine, 'Đã đạt cấp cao nhất!');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', 'Động từ', 0.4, 0.7)],
      );
      expect(r.toText(strings: vi),
          'Tuần này: 3 ngày / 12 câu\nNhững điều tiến bộ trong tuần này:\n- Động từ (40% -> 70%)');
      expect(vi.formatYear(-500), '500 TCN');
      expect(vi.formatYear(1945), 'năm 1945');
      expect(vi.solvableValue(1), '1 câu'); // 複数形は無い
    });

    test('数値入力: 1.200,5（ドットが桁区切り、カンマが小数点）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const ViStrings().decimalSeparator;
      expect(checkAnswer(q, '1.200,5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200,5', decimalSeparator: sep).correct, isTrue);
    });

    test('持ち物の既定の項目・偏差値の名称', () {
      const vi = ViStrings();
      expect(vi.checklistDefaults.first, ('pencil', 'Bút và bút chì'));
      expect(vi.checklistDefaults.length, 6);
      expect(vi.deviationLabel, 'Chỉ số điểm trong ứng dụng');
      expect(vi.deviationNote, contains('50'));
      expect(formatDeviationRange(const DeviationEstimate(55), vi), '50–60');
    });
  });
}

void deTests() {
  group('ドイツ語', () {
    test('forLocale: de・de-DE・de-AT、スイスは de-CH・de-LI', () {
      expect(ChukoreStrings.forLocale('de'), isA<DeStrings>());
      expect(ChukoreStrings.forLocale('de-DE'), isA<DeStrings>());
      expect((ChukoreStrings.forLocale('de-AT') as DeStrings).swiss, isFalse);
      expect((ChukoreStrings.forLocale('de_CH') as DeStrings).swiss, isTrue);
      expect((ChukoreStrings.forLocale('de-LI') as DeStrings).swiss, isTrue);
      expect(const DeStrings().tag, 'de');
      expect(const DeStrings(swiss: true).tag, 'de-CH');
    });

    test('数の読み上げ（一語に続ける。einundzwanzig・eins・sechzehn・dreißig）', () {
      const de = DeStrings();
      expect(de.gateNumberWords(482), 'vierhundertzweiundachtzig');
      expect(de.gateNumberWords(100), 'einhundert');
      expect(de.gateNumberWords(101), 'einhunderteins');
      expect(de.gateNumberWords(111), 'einhundertelf');
      expect(de.gateNumberWords(116), 'einhundertsechzehn');
      expect(de.gateNumberWords(117), 'einhundertsiebzehn');
      expect(de.gateNumberWords(121), 'einhunderteinundzwanzig');
      expect(de.gateNumberWords(130), 'einhundertdreißig');
      expect(de.gateNumberWords(200), 'zweihundert');
      expect(de.gateNumberWords(371), 'dreihunderteinundsiebzig');
      expect(de.gateNumberWords(999), 'neunhundertneunundneunzig');
      expect(de.gateNumberWords(1000), 'eintausend');
      expect(de.gateNumberWords(1100), 'eintausendeinhundert');
      expect(de.gateNumberWords(1001), 'eintausendeins');
      expect(de.gateNumberWords(2025), 'zweitausendfünfundzwanzig');
      expect(de.gateNumberWords(9999), 'neuntausendneunhundertneunundneunzig');
      expect(() => de.gateNumberWords(0), throwsRangeError);
    });

    test('スイス式は ß を使わない（dreissig）', () {
      const ch = DeStrings(swiss: true);
      expect(ch.gateNumberWords(130), 'einhundertdreissig');
      expect(ch.gateNumberWords(437), 'vierhundertsiebenunddreissig');
      expect(const DeStrings().gateNumberWords(30), 'dreißig');
    });

    test('1〜9999 のすべてで、典型的な誤り（einsund・eineund・空白・ß の混在）が出ない', () {
      for (final de in const [DeStrings(), DeStrings(swiss: true)]) {
        for (var n = 1; n <= 9999; n++) {
          final w = de.gateNumberWords(n);
          expect(w, isNotEmpty, reason: '$n');
          expect(w.contains(' '), isFalse, reason: '$n に空白: "$w"');
          expect(w.contains('einsund'), isFalse, reason: '$n: "$w"');
          expect(w.contains('eineund'), isFalse, reason: '$n: "$w"');
          expect(w.contains('einhunderteinhundert'), isFalse, reason: '$n: "$w"');
          expect(w.contains('ß'), de.swiss ? isFalse : (w.contains('dreißig')), reason: '$n: "$w"');
          // 末尾が 1 のとき: 一の位だけなら「eins」、二十以上は「…einundzwanzig」のように und でつながる
          if (n % 10 == 1 && n % 100 != 11) {
            expect(w.endsWith('eins') || w.contains('einund'), isTrue, reason: '$n: "$w"');
          }
        }
      }
    });

    test('保護者ゲート: 読み上げと、ドットの桁区切り（1.200）', () {
      expect(const GateChallenge(482).promptFor(const DeStrings()), 'vierhundertzweiundachtzig');
      expect(const GateChallenge(1200).verify('1.200'), isTrue);
    });

    test('小数点はカンマ（スイスはドット）。複数形と年', () {
      const de = DeStrings();
      expect(de.decimalSeparator, ',');
      expect(const DeStrings(swiss: true).decimalSeparator, '.');
      GrowthCardData d(ChukoreStrings s, double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'Englisch',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: s,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(de, 2.5).headline, '+2,5 gegenüber dem letzten Mal');
      expect(d(const DeStrings(swiss: true), 2.5).headline, '+2.5 gegenüber dem letzten Mal');
      expect(d(de, -4).headline, 'Von hier aus geht es weiter nach oben');
      expect(d(de, -4).headline.contains('-'), isFalse);
      expect(d(de, null, toNext: 7.5).nextLine, 'Noch 7,5 Punkte bis zur nächsten Stufe');
      expect(d(de, 1, toNext: null).nextLine, 'Höchste Stufe erreicht!');
      expect(de.solvableValue(1), '1 Aufgabe');
      expect(de.solvableValue(3), '3 Aufgaben');
      expect(de.streakDays(1), '1 Tag in Folge');
      expect(de.streakDays(5), '5 Tage in Folge');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 1,
        activeDays: 1,
        improvements: const [Improvement('u', 'Verben', 0.4, 0.7)],
      );
      expect(r.toText(strings: de),
          'Diese Woche: 1 Tag / 1 Aufgabe\nDas hat sich diese Woche verbessert:\n- Verben (40% -> 70%)');
      expect(de.formatYear(-500), '500 v. Chr.');
      expect(de.formatYear(1945), '1945');
    });

    test('数値入力: 1.200,5（ドットが桁区切り、カンマが小数点）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const DeStrings().decimalSeparator;
      expect(checkAnswer(q, '1.200,5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200,5', decimalSeparator: sep).correct, isTrue);
    });

    test('持ち物の既定の項目・偏差値の名称', () {
      const de = DeStrings();
      expect(de.checklistDefaults.first, ('pencil', 'Stifte'));
      expect(de.checklistDefaults.length, 6);
      expect(de.deviationLabel, 'Punkte-Index in der App');
      expect(de.deviationNote, contains('50'));
      expect(formatDeviationRange(const DeviationEstimate(55), de), '50–60');
    });
  });
}

void trTests() {
  group('トルコ語', () {
    test('forLocale: tr・tr-TR', () {
      expect(ChukoreStrings.forLocale('tr'), isA<TrStrings>());
      expect(ChukoreStrings.forLocale('tr-TR'), isA<TrStrings>());
      expect(ChukoreStrings.forLocale('TR_tr'), isA<TrStrings>());
      expect(const TrStrings().tag, 'tr');
    });

    test('数の読み上げ（yüz・bin は「bir」を付けない。分けて書く）', () {
      const tr = TrStrings();
      expect(tr.gateNumberWords(482), 'dört yüz seksen iki');
      expect(tr.gateNumberWords(100), 'yüz');
      expect(tr.gateNumberWords(101), 'yüz bir');
      expect(tr.gateNumberWords(110), 'yüz on');
      expect(tr.gateNumberWords(200), 'iki yüz');
      expect(tr.gateNumberWords(321), 'üç yüz yirmi bir');
      expect(tr.gateNumberWords(555), 'beş yüz elli beş');
      expect(tr.gateNumberWords(999), 'dokuz yüz doksan dokuz');
      expect(tr.gateNumberWords(1000), 'bin');
      expect(tr.gateNumberWords(1001), 'bin bir');
      expect(tr.gateNumberWords(1500), 'bin beş yüz');
      expect(tr.gateNumberWords(2025), 'iki bin yirmi beş');
      expect(tr.gateNumberWords(9999), 'dokuz bin dokuz yüz doksan dokuz');
      expect(() => tr.gateNumberWords(0), throwsRangeError);
    });

    test('1〜9999 のすべてで、典型的な誤り（bir yüz・bir bin・空白の乱れ）が出ない', () {
      const tr = TrStrings();
      for (var n = 1; n <= 9999; n++) {
        final w = tr.gateNumberWords(n);
        expect(w, isNotEmpty, reason: '$n');
        expect(w, equals(w.trim()), reason: '$n 前後の空白: "$w"');
        expect(w.contains('  '), isFalse, reason: '$n 二重の空白: "$w"');
        expect(w.startsWith('bir yüz') || w.startsWith('bir bin') || w.contains(' bir yüz') || w.contains(' bir bin'),
            isFalse, reason: '$n: "$w"');
      }
    });

    test('保護者ゲート: 読み上げと、ドットの桁区切り（1.200）', () {
      expect(const GateChallenge(482).promptFor(const TrStrings()), 'dört yüz seksen iki');
      expect(const GateChallenge(1200).verify('1.200'), isTrue);
    });

    test('小数点はカンマ。成長カード・レポート（%が前）・年', () {
      const tr = TrStrings();
      expect(tr.decimalSeparator, ',');
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'İngilizce',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: tr,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, 'Geçen seferden +2,5');
      expect(d(-4).headline, 'Buradan yeniden yükselelim');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 7.5).nextLine, 'Bir sonraki seviyeye 7,5 puan kaldı');
      expect(d(1, toNext: null).nextLine, 'En yüksek seviyeye ulaşıldı!');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', 'Fiiller', 0.4, 0.7)],
      );
      expect(r.toText(strings: tr),
          'Bu hafta: 3 gün / 12 soru\nBu hafta gelişenler:\n- Fiiller (%40 -> %70)');
      expect(tr.formatYear(-500), 'M.Ö. 500');
      expect(tr.formatYear(1945), '1945');
      expect(tr.solvableValue(1), '1 soru'); // 数詞のあとは単数形
      expect(tr.solvableValue(5), '5 soru');
    });

    test('数値入力: 1.200,5（ドットが桁区切り、カンマが小数点）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const TrStrings().decimalSeparator;
      expect(checkAnswer(q, '1.200,5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200,5', decimalSeparator: sep).correct, isTrue);
    });

    test('持ち物の既定の項目・偏差値の名称', () {
      const tr = TrStrings();
      expect(tr.checklistDefaults.first, ('pencil', 'Kalemler'));
      expect(tr.checklistDefaults.length, 6);
      expect(tr.deviationLabel, 'Uygulama içi puan endeksi');
      expect(tr.deviationNote, contains('50'));
      expect(formatDeviationRange(const DeviationEstimate(55), tr), '50–60');
    });
  });
}

void thTests() {
  group('タイ語', () {
    test('forLocale: th・th-TH', () {
      expect(ChukoreStrings.forLocale('th'), isA<ThStrings>());
      expect(ChukoreStrings.forLocale('th-TH'), isA<ThStrings>());
      expect(const ThStrings().tag, 'th');
    });

    test('数の読み上げ（สิบ・ยี่สิบ・เอ็ด。単語の間に空白を入れない）', () {
      const th = ThStrings();
      expect(th.gateNumberWords(1), 'หนึ่ง');
      expect(th.gateNumberWords(10), 'สิบ');
      expect(th.gateNumberWords(11), 'สิบเอ็ด');
      expect(th.gateNumberWords(21), 'ยี่สิบเอ็ด');
      expect(th.gateNumberWords(482), 'สี่ร้อยแปดสิบสอง');
      expect(th.gateNumberWords(100), 'หนึ่งร้อย');
      expect(th.gateNumberWords(101), 'หนึ่งร้อยเอ็ด');
      expect(th.gateNumberWords(110), 'หนึ่งร้อยสิบ');
      expect(th.gateNumberWords(111), 'หนึ่งร้อยสิบเอ็ด');
      expect(th.gateNumberWords(120), 'หนึ่งร้อยยี่สิบ');
      expect(th.gateNumberWords(121), 'หนึ่งร้อยยี่สิบเอ็ด');
      expect(th.gateNumberWords(125), 'หนึ่งร้อยยี่สิบห้า');
      expect(th.gateNumberWords(999), 'เก้าร้อยเก้าสิบเก้า');
      expect(th.gateNumberWords(1000), 'หนึ่งพัน');
      expect(th.gateNumberWords(1001), 'หนึ่งพันเอ็ด');
      expect(th.gateNumberWords(2025), 'สองพันยี่สิบห้า');
      expect(th.gateNumberWords(9999), 'เก้าพันเก้าร้อยเก้าสิบเก้า');
      expect(() => th.gateNumberWords(0), throwsRangeError);
    });

    test('1〜9999 のすべてで、典型的な誤り（หนึ่งสิบ・สองสิบ・สิบหนึ่ง・…สิบหนึ่ง・空白）が出ない', () {
      const th = ThStrings();
      for (var n = 1; n <= 9999; n++) {
        final w = th.gateNumberWords(n);
        expect(w, isNotEmpty, reason: '$n');
        expect(w.contains(' '), isFalse, reason: '$n に空白: "$w"');
        expect(w.contains('หนึ่งสิบ'), isFalse, reason: '$n: "$w"');
        expect(w.contains('สองสิบ'), isFalse, reason: '$n: 20 台は ยี่สิบ: "$w"');
        expect(w.contains('สิบหนึ่ง'), isFalse, reason: '$n: 一の位の 1 は เอ็ด: "$w"');
        // 「หนึ่ง」で終わるのは 1 だけ（それ以外の末尾の 1 は เอ็ด）
        expect(w.endsWith('หนึ่ง'), n == 1, reason: '$n: "$w"');
      }
    });

    test('保護者ゲート: 読み上げ・ドットの桁区切り・タイ数字の入力', () {
      expect(const GateChallenge(482).promptFor(const ThStrings()), 'สี่ร้อยแปดสิบสอง');
      expect(const GateChallenge(1200).verify('1.200'), isTrue);
      expect(const GateChallenge(482).verify('๔๘๒'), isTrue);
      expect(const GateChallenge(1200).verify('๑,๒๐๐'), isTrue);
      expect(const GateChallenge(482).verify('๔๘๓'), isFalse);
    });

    test('小数点はドット。成長カード・レポート・年（仏暦に西暦を添える）', () {
      const th = ThStrings();
      expect(th.decimalSeparator, '.');
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'ภาษาอังกฤษ',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: th,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, '+2.5 จากครั้งก่อน');
      expect(d(-4).headline, 'มาไปต่อจากตรงนี้กัน');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 7.5).nextLine, 'อีก 7.5 คะแนนถึงระดับถัดไป');
      expect(d(1, toNext: null).nextLine, 'ถึงระดับสูงสุดแล้ว!');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', 'คำกริยา', 0.4, 0.7)],
      );
      expect(r.toText(strings: th),
          'สัปดาห์นี้: 3 วัน / 12 ข้อ\nสิ่งที่ดีขึ้นในสัปดาห์นี้:\n- คำกริยา (40% -> 70%)');
      expect(th.formatYear(1945), 'พ.ศ. 2488 (ค.ศ. 1945)');
      expect(th.formatYear(2026), 'พ.ศ. 2569 (ค.ศ. 2026)');
      expect(th.formatYear(-500), 'ก่อน ค.ศ. 500');
      expect(th.solvableValue(1), '1 ข้อ'); // 複数形は無い
    });

    test('数値入力: 1,200.5（カンマが桁区切り、ドットが小数点）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const ThStrings().decimalSeparator;
      expect(checkAnswer(q, '1,200.5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200.5', decimalSeparator: sep).correct, isTrue);
    });

    test('持ち物の既定の項目・偏差値の名称', () {
      const th = ThStrings();
      expect(th.checklistDefaults.first, ('pencil', 'เครื่องเขียน'));
      expect(th.checklistDefaults.length, 6);
      expect(th.deviationLabel, 'ดัชนีคะแนนในแอป');
      expect(th.deviationNote, contains('50'));
      expect(formatDeviationRange(const DeviationEstimate(55), th), '50–60');
    });
  });
}

void formatNumberTests() {
  test('点数の表示: 小数1桁に丸めて、整数なら小数点なし（3.0・0.0・-0.0 にしない）', () {
    for (final s in ChukoreStrings.supported) {
      expect(s.formatNumber(3), '3', reason: s.tag);
      expect(s.formatNumber(2.96), '3', reason: s.tag);
      expect(s.formatNumber(99.96), '100', reason: s.tag);
      expect(s.formatNumber(0.04), '0', reason: s.tag);
      expect(s.formatNumber(-0.04), '0', reason: s.tag);
      expect(s.formatNumber(0), '0', reason: s.tag);
      expect(s.formatNumber(2.5), '2${s.decimalSeparator}5', reason: s.tag);
      expect(s.formatNumber(7.45), '7${s.decimalSeparator}5', reason: s.tag);
      expect(s.formatNumber(-2.5), '-2${s.decimalSeparator}5', reason: s.tag);
      expect(s.formatNumber(0.06), '0${s.decimalSeparator}1', reason: s.tag);
    }
  });
}

void hiTests() {
  group('ヒンディー語', () {
    test('forLocale: hi・hi-IN', () {
      expect(ChukoreStrings.forLocale('hi'), isA<HiStrings>());
      expect(ChukoreStrings.forLocale('hi-IN'), isA<HiStrings>());
      expect(ChukoreStrings.forLocale('hi_IN'), isA<HiStrings>());
      expect(const HiStrings().tag, 'hi');
    });

    test('0〜99 の表: 100 語・重複なし・空白なし（写し間違いの検出）', () {
      expect(HiStrings.numbers.length, 100);
      expect(HiStrings.numbers.toSet().length, 100);
      for (final w in HiStrings.numbers) {
        expect(w.trim(), w);
        expect(w.contains(' '), isFalse, reason: w);
      }
    });

    test('数の読み上げ（不規則な 1〜99 は表から。〜सौ・〜हज़ार は空白で区切る）', () {
      const hi = HiStrings();
      expect(hi.gateNumberWords(1), 'एक');
      expect(hi.gateNumberWords(11), 'ग्यारह');
      expect(hi.gateNumberWords(25), 'पच्चीस');
      expect(hi.gateNumberWords(99), 'निन्यानवे');
      expect(hi.gateNumberWords(100), 'एक सौ');
      expect(hi.gateNumberWords(101), 'एक सौ एक');
      expect(hi.gateNumberWords(200), 'दो सौ');
      expect(hi.gateNumberWords(482), 'चार सौ बयासी');
      expect(hi.gateNumberWords(999), 'नौ सौ निन्यानवे');
      expect(hi.gateNumberWords(1000), 'एक हज़ार');
      expect(hi.gateNumberWords(1001), 'एक हज़ार एक');
      expect(hi.gateNumberWords(2025), 'दो हज़ार पच्चीस');
      expect(hi.gateNumberWords(9999), 'नौ हज़ार नौ सौ निन्यानवे');
      expect(() => hi.gateNumberWords(0), throwsRangeError);
    });

    test('1〜9999 のすべてで、空白の乱れや重複した位取りが出ない', () {
      const hi = HiStrings();
      for (var n = 1; n <= 9999; n++) {
        final w = hi.gateNumberWords(n);
        expect(w, isNotEmpty, reason: '$n');
        expect(w, equals(w.trim()), reason: '$n: "$w"');
        expect(w.contains('  '), isFalse, reason: '$n: "$w"');
        expect(RegExp('सौ').allMatches(w).length, lessThanOrEqualTo(1), reason: '$n: "$w"');
        expect(RegExp('हज़ार').allMatches(w).length, lessThanOrEqualTo(1), reason: '$n: "$w"');
        // 位の読みは、その位の数が 1 以上のときだけ出る
        expect(w.contains('सौ'), (n % 1000) >= 100, reason: '$n: "$w"');
        expect(w.contains('हज़ार'), n >= 1000, reason: '$n: "$w"');
      }
    });

    test('保護者ゲート: 読み上げ・ドットの桁区切り・デーヴァナーガリー数字の入力', () {
      expect(const GateChallenge(482).promptFor(const HiStrings()), 'चार सौ बयासी');
      expect(const GateChallenge(1200).verify('1,200'), isTrue);
      expect(const GateChallenge(482).verify('४८२'), isTrue);
      expect(const GateChallenge(1200).verify('१,२००'), isTrue);
      expect(const GateChallenge(482).verify('४८३'), isFalse);
    });

    test('小数点はドット。成長カード・レポート・年', () {
      const hi = HiStrings();
      expect(hi.decimalSeparator, '.');
      GrowthCardData d(double? delta, {double? toNext = 5}) => GrowthCardData(
            subjectLabel: 'अंग्रेज़ी',
            level: Level.b,
            pointsToNext: toNext,
            scoreDelta: delta,
            strings: hi,
            radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
          );
      expect(d(2.5).headline, 'पिछली बार से +2.5');
      expect(d(-4).headline, 'यहाँ से फिर आगे बढ़ें');
      expect(d(-4).headline.contains('-'), isFalse);
      expect(d(null, toNext: 7.5).nextLine, 'अगले स्तर के लिए 7.5 अंक बाकी');
      expect(d(1, toNext: null).nextLine, 'सबसे ऊँचे स्तर पर पहुँच गए!');
      final r = WeeklyReport(
        weekStart: DateTime.utc(2026, 10, 13),
        attemptCount: 12,
        activeDays: 3,
        improvements: const [Improvement('u', 'क्रिया', 0.4, 0.7)],
      );
      expect(r.toText(strings: hi), 'इस सप्ताह: 3 दिन / 12 प्रश्न\nइस सप्ताह जो बेहतर हुआ:\n- क्रिया (40% -> 70%)');
      expect(hi.formatYear(-500), '500 ई.पू.');
      expect(hi.formatYear(1945), '1945 ई.');
      expect(hi.solvableValue(1), '1 प्रश्न'); // 複数形の区別は付けない
    });

    test('数値入力: 1,200.5（カンマが桁区切り、ドットが小数点）', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '1200.5', explanationId: 'x',
      );
      final sep = const HiStrings().decimalSeparator;
      expect(checkAnswer(q, '1,200.5', decimalSeparator: sep).correct, isTrue);
      expect(checkAnswer(q, '1200.5', decimalSeparator: sep).correct, isTrue);
    });

    test('持ち物の既定の項目・偏差値の名称・年輪の読み上げ', () {
      const hi = HiStrings();
      expect(hi.checklistDefaults.first, ('pencil', 'पेन-पेंसिल'));
      expect(hi.checklistDefaults.length, 6);
      expect(hi.deviationLabel, 'ऐप के भीतर का अंक सूचकांक');
      expect(hi.deviationNote, contains('50'));
      expect(formatDeviationRange(const DeviationEstimate(55), hi), '50–60');
      expect(hi.ringsLatestMonth('2026-10', 12), contains('2026-10'));
    });
  });
}
