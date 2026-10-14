import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    for (final s in const [JaStrings(), EnStrings()]) {
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
