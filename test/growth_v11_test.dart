import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G7 成長の年輪', () {
    test('月ごとの学習日数と合計。同じ日は1日', () {
      final r = buildGrowthRings([
        DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 3, 20), DateTime.utc(2026, 8, 10),
        DateTime.utc(2026, 9, 1),
      ]);
      expect(r.totalDays, 3);
      expect(r.months.map((m) => (m.year, m.month, m.days)), [(2026, 8, 2), (2026, 9, 1)]);
    });

    test('休んだ月も細い輪として残り、合計は減らない（今月まで伸びる）', () {
      final days = [DateTime.utc(2026, 1, 5), DateTime.utc(2026, 1, 6)];
      final base = buildGrowthRings(days);
      final later = buildGrowthRings(days, now: DateTime.utc(2026, 4, 20));
      expect(later.totalDays, base.totalDays);
      expect(later.months.map((m) => m.month), [1, 2, 3, 4]);
      expect(later.months[1].days, 0);
      expect(later.months[1].ratio, 0);
    });

    test('年をまたぐ。太さは月の日数に対する割合', () {
      final r = buildGrowthRings([
        DateTime.utc(2026, 12, 31),
        for (var d = 1; d <= 14; d++) DateTime.utc(2027, 2, d), // 2月は28日
      ]);
      expect(r.months.map((m) => (m.year, m.month)), [(2026, 12), (2027, 1), (2027, 2)]);
      expect(r.months.last.daysInMonth, 28);
      expect(r.months.last.ratio, 0.5);
    });

    test('学習が無ければ空', () {
      final r = buildGrowthRings(const []);
      expect(r.months, isEmpty);
      expect(r.totalDays, 0);
    });

    testWidgets('描画でき、読み上げに合計日数が入る（言語別）', (tester) async {
      final handle = tester.ensureSemantics();
      final rings = buildGrowthRings([for (var d = 1; d <= 5; d++) DateTime.utc(2026, 9, d)],
          now: DateTime.utc(2026, 11, 1));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 200, height: 200, child: GrowthRingsView(rings: rings, strings: const EnStrings()))),
      ));
      // 最新の月は 11 月（学習 0 日）。休んだ月も読み上げに出る
      expect(find.bySemanticsLabel('Growth rings. 5 days of practice in total. Latest month, 2026-11: 0 days of practice'),
          findsOneWidget);
      handle.dispose();
    });

    test('読み上げの文言: 最新の月の学習日数（月は 2026-10 の形）', () {
      final rings = buildGrowthRings([DateTime.utc(2026, 9, 3), DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 2)]);
      expect(rings.months.last.label, '2026-10');
      expect(GrowthRingsView(rings: rings, strings: const EnStrings()).semanticsLabel,
          'Growth rings. 3 days of practice in total. Latest month, 2026-10: 2 days of practice');
      expect(GrowthRingsView(rings: rings, strings: const JaStrings()).semanticsLabel,
          contains('直近の月（2026-10）は2日'));
      expect(GrowthRingsView(rings: rings, strings: const ThStrings()).semanticsLabel, contains('2026-10'));
      // 年輪が空なら合計の文言だけ
      expect(GrowthRingsView(rings: buildGrowthRings(const []), strings: const EnStrings()).semanticsLabel,
          'Growth rings. 0 days of practice in total');
    });

    test('最新の月の文言の単複・形式（全言語で月と日数が入る）', () {
      expect(const EnStrings().ringsLatestMonth('2026-10', 1), 'Latest month, 2026-10: 1 day of practice');
      expect(const FrStrings().ringsLatestMonth('2026-10', 1), contains('1 jour d'));
      expect(const FrStrings().ringsLatestMonth('2026-10', 5), contains('5 jours'));
      expect(const DeStrings().ringsLatestMonth('2026-10', 1), 'Letzter Monat, 2026-10: 1 Lerntag');
      expect(const DeStrings().ringsLatestMonth('2026-10', 3), 'Letzter Monat, 2026-10: 3 Lerntage');
      expect(const PtStrings().ringsLatestMonth('2026-10', 1), contains('1 dia'));
      expect(const EsStrings().ringsLatestMonth('2026-10', 2), contains('2 días'));
      for (final l in ChukoreStrings.supported) {
        final t = l.ringsLatestMonth('2026-10', 12);
        expect(t, contains('2026-10'), reason: l.tag);
        expect(t, contains('12'), reason: l.tag);
      }
    });

    test('読み上げの単複', () {
      expect(const EnStrings().ringsSemantics(1), contains('1 day of'));
      expect(const FrStrings().ringsSemantics(1), contains('1 jour d'));
      expect(const PtStrings().ringsSemantics(2), contains('2 dias'));
    });
  });

  group('G8 本番の点数の記録', () {
    final mock = [
      MockScore(DateTime.utc(2026, 4, 1), 50),
      MockScore(DateTime.utc(2026, 4, 15), 60),
      MockScore(DateTime.utc(2026, 5, 1), 70),
      MockScore(DateTime.utc(2026, 5, 20), 90),
    ];

    test('レベル・前回との差・自己ベスト（日付順に返る）', () {
      final r = compareRealTests([
        RealTestRecord(DateTime.utc(2026, 7, 1), 80),
        RealTestRecord(DateTime.utc(2026, 5, 10), 62), // 順不同で渡す
      ], mock);
      expect(r.map((c) => c.record.score), [62, 80]);
      expect(r[0].deltaFromPrevious, isNull);
      expect(r[0].isPersonalBest, isFalse); // 初回は祝わない
      expect(r[1].deltaFromPrevious, 18);
      expect(r[1].isPersonalBest, isTrue);
      expect(r[0].realLevel, Level.b); // 62 → B（既定 60 以上）
      expect(r[1].realLevel, Level.a); // 80 → A
    });

    test('模擬テストは、その日より前の直近3回の加重平均で判定', () {
      final r = compareRealTests([RealTestRecord(DateTime.utc(2026, 5, 10), 62)], mock);
      // 5/10 より前: 50, 60, 70 → (50*1 + 60*2 + 70*3)/6 = 63.3 → B
      expect(r.single.mockLevel, Level.b);
      final later = compareRealTests([RealTestRecord(DateTime.utc(2026, 6, 1), 62)], mock);
      // 60, 70, 90 → (60 + 140 + 270)/6 = 78.3 → A
      expect(later.single.mockLevel, Level.a);
    });

    test('模擬テストがまだ無ければ mockLevel は null。同日の模擬は使わない', () {
      final none = compareRealTests([RealTestRecord(DateTime.utc(2026, 3, 1), 70)], mock);
      expect(none.single.mockLevel, isNull);
      final same = compareRealTests([RealTestRecord(DateTime.utc(2026, 4, 1), 70)], mock);
      expect(same.single.mockLevel, isNull);
    });

    test('レベルの境界値は設定で変えられる', () {
      final r = compareRealTests([RealTestRecord(DateTime.utc(2026, 7, 1), 80)], const [],
          thresholds: const LevelThresholds(s: 80));
      expect(r.single.realLevel, Level.s);
    });

    test('点が下がっても記録できる（差は負、自己ベストではない）', () {
      final r = compareRealTests([
        RealTestRecord(DateTime.utc(2026, 5, 1), 80),
        RealTestRecord(DateTime.utc(2026, 7, 1), 70),
      ], const []);
      expect(r[1].deltaFromPrevious, -10);
      expect(r[1].isPersonalBest, isFalse);
    });
  });

  group('G9 アプリ内偏差値の表示ポリシー', () {
    const est = DeviationEstimate(55);

    test('13歳未満は出さない（本人が希望しても）', () {
      final d = deviationDisplay(isUnder13: true, optedIn: true, estimate: est);
      expect(d.visible, isFalse);
      expect(d.hiddenReason, DeviationHiddenReason.under13);
    });

    test('本人が表示を選ぶまで出さない（初期は非表示）', () {
      final d = deviationDisplay(isUnder13: false, optedIn: false, estimate: est);
      expect(d.visible, isFalse);
      expect(d.hiddenReason, DeviationHiddenReason.notOptedIn);
    });

    test('換算できないときは出さない', () {
      final d = deviationDisplay(isUnder13: false, optedIn: true, estimate: null);
      expect(d.hiddenReason, DeviationHiddenReason.notAvailable);
    });

    test('条件がそろえば出す', () {
      final d = deviationDisplay(isUnder13: false, optedIn: true, estimate: est);
      expect(d.visible, isTrue);
      expect(d.estimate!.value, 55);
    });

    test('幅で表示する（言語別の区切り）', () {
      expect(formatDeviationRange(est, const JaStrings()), '50〜60');
      expect(formatDeviationRange(est, const EnStrings()), '50–60');
      expect(formatDeviationRange(est, const KoStrings()), '50~60');
      expect(formatDeviationRange(const DeviationEstimate(52.6), const JaStrings()), '48〜58');
    });

    test('名称は「アプリ内偏差値」。日本語では全国の偏差値と区別する注記つき', () {
      const ja = JaStrings();
      expect(ja.deviationLabel, 'アプリ内偏差値');
      expect(ja.deviationNote, contains('アプリ内'));
      expect(ja.deviationNote, contains('全国の偏差値ではありません'));
      // 旧名称の「目安偏差値」は、利用者に見える文言に残さない
      for (final s in ChukoreStrings.supported) {
        expect(s.deviationLabel, isNot(contains('目安')));
        expect(s.deviationNote, isNot(contains('目安偏差値')));
      }
    });

    test('全言語で、アプリ内だけの目安であることを明示する文言がある', () {
      for (final s in ChukoreStrings.supported) {
        expect(s.deviationLabel, isNotEmpty);
        expect(s.deviationNote, contains('50'));
      }
    });
  });

  test('年輪は中身が同じなら等しい（作り直されても描き直さない）。違えば等しくない', () {
    final days = [DateTime.utc(2026, 9, 3), DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 2)];
    final a = buildGrowthRings(days);
    final b = buildGrowthRings(days);
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.months.first, b.months.first);
    expect(buildGrowthRings([...days, DateTime.utc(2026, 10, 3)]), isNot(a));
    expect(buildGrowthRings(days.sublist(1)), isNot(a));
    // 合計日数も月の数も同じで、月ごとの日数だけが違う
    final x = buildGrowthRings([DateTime.utc(2026, 9, 3), DateTime.utc(2026, 9, 4), DateTime.utc(2026, 10, 1)]);
    final y = buildGrowthRings([DateTime.utc(2026, 9, 3), DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 2)]);
    expect((x.totalDays, x.months.length), (y.totalDays, y.months.length));
    expect(x, isNot(y));
    expect(const GrowthRings([], 0), const GrowthRings([], 0));
  });
}
