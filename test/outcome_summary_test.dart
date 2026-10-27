import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

RealTestRecord t(int month, double score, {double max = 100, RealTestKind kind = RealTestKind.regular, int day = 10}) =>
    RealTestRecord(DateTime(2026, month, day), score, maxScore: max, kind: kind);

Attempt a(DateTime when) => Attempt(questionId: 'q', unitId: 'u', correct: true, answeredAt: when);

void main() {
  group('RealTestRecord', () {
    test('満点が違っても、比と100点換算で比べられる', () {
      expect(t(5, 7.5, max: 10).ratio, 0.75);
      expect(t(5, 375, max: 500).normalizedScore, closeTo(75, 1e-9));
      expect(t(5, 60).normalizedScore, 60);
    });

    test('範囲外は isValid が偽で、ratio は 0〜1 に収まる', () {
      expect(t(5, 11, max: 10).isValid, false);
      expect(t(5, 11, max: 10).ratio, 1);
      expect(t(5, -1).isValid, false);
      expect(t(5, 50, max: 0).isValid, false);
      expect(t(5, 50, max: 0).ratio, 0);
      expect(t(5, 100).isValid, true);
      expect(t(5, 0).isValid, true);
    });

    test('compareRealTests は満点が違っても100点換算で前回と比べる（満点100なら従来どおり）', () {
      final r = compareRealTests([t(4, 6, max: 10), t(6, 80)], const []);
      expect(r[1].deltaFromPrevious, closeTo(20, 1e-9));
      final old = compareRealTests([
        RealTestRecord(DateTime.utc(2026, 5, 1), 80),
        RealTestRecord(DateTime.utc(2026, 7, 1), 70),
      ], const []);
      expect(old[1].deltaFromPrevious, -10);
    });
  });

  group('buildOutcomeSummary: 変化', () {
    test('前回との差がノイズ幅を超えたときだけ up / down、幅以内は same。境界はちょうど3点を same', () {
      final s = buildOutcomeSummary([t(4, 60), t(5, 63), t(6, 70), t(7, 66.9), t(8, 66.9)], const []);
      expect(s.entries.map((e) => e.change), [
        OutcomeChange.first,
        OutcomeChange.same,
        OutcomeChange.up,
        OutcomeChange.down,
        OutcomeChange.same,
      ]);
      expect(s.entries[2].deltaRatio, closeTo(0.07, 1e-9));
      expect(s.ups, 1);
      expect(s.compared, 4);
    });

    test('満点が違うテストも比で比べる（10点満点の6 → 100点満点の80 は +0.2）', () {
      final s = buildOutcomeSummary([t(4, 6, max: 10), t(6, 80)], const []);
      expect(s.entries[1].change, OutcomeChange.up);
      expect(s.entries[1].deltaRatio, closeTo(0.2, 1e-9));
    });

    test('使う前の点があれば、最初の記録はそれと比べる。以降の deltaFromBaseline も出る', () {
      final base = RealTestRecord(DateTime(2026, 2, 1), 50);
      final s = buildOutcomeSummary([t(4, 58), t(6, 70)], const [], baseline: base);
      expect(s.entries[0].change, OutcomeChange.up);
      expect(s.entries[0].deltaFromBaseline, closeTo(0.08, 1e-9));
      expect(s.entries[1].deltaRatio, closeTo(0.12, 1e-9));
      expect(s.entries[1].deltaFromBaseline, closeTo(0.20, 1e-9));
      final none = buildOutcomeSummary([t(4, 58)], const []);
      expect(none.entries.single.change, OutcomeChange.first);
      expect(none.entries.single.deltaFromBaseline, isNull);
      expect(none.entries.single.deltaRatio, isNull);
    });

    test('範囲外の点は数えず skipped に数える。種類が違う記録は比べない。順不同でも日付順', () {
      final s = buildOutcomeSummary([
        t(6, 70),
        t(4, 60),
        t(5, 120), // 範囲外
        t(5, 90, kind: RealTestKind.mock),
      ], const []);
      expect(s.skipped, 1);
      expect(s.entries.map((e) => e.record.score), [60, 70]);
      final mock = buildOutcomeSummary([t(5, 90, kind: RealTestKind.mock)], const [], kind: RealTestKind.mock);
      expect(mock.entries, hasLength(1));
    });

    test('同じ日の記録は入力順を保つ。自己ベスト', () {
      final s = buildOutcomeSummary([t(5, 50), t(5, 80), t(6, 70)], const []);
      expect(s.entries.map((e) => e.record.score), [50, 80, 70]);
      expect(s.bestNormalized, 80);
      expect(buildOutcomeSummary(const [], const []).bestNormalized, isNull);
    });

    test('noise と lookbackDays の不正はエラー', () {
      expect(() => buildOutcomeSummary(const [], const [], noise: -0.1), throwsArgumentError);
      expect(() => buildOutcomeSummary(const [], const [], lookbackDays: 0), throwsArgumentError);
    });
  });

  group('buildOutcomeSummary: 使った量', () {
    final test0 = t(6, 70, day: 15); // 6/15
    test('テストの前日までの28日間の学習日数と問題数。当日と範囲外は数えない', () {
      final attempts = [
        a(DateTime(2026, 6, 14, 20)), // 前日: 数える
        a(DateTime(2026, 6, 14, 21)), // 同じ日
        a(DateTime(2026, 5, 18, 9)), // ちょうど28日前: 数える
        a(DateTime(2026, 5, 17, 9)), // 29日前: 数えない
        a(DateTime(2026, 6, 15, 8)), // 当日: 数えない
      ];
      final e = buildOutcomeSummary([test0], attempts).entries.single;
      expect(e.activeDays, 2);
      expect(e.questions, 3);
      final short = buildOutcomeSummary([test0], attempts, lookbackDays: 7).entries.single;
      expect(short.activeDays, 1);
      expect(short.questions, 2);
    });

    test('学習日の境界（午前4時）を使うと、深夜の学習は前日に数える', () {
      final attempts = [a(DateTime(2026, 6, 15, 1, 30))]; // 当日の午前1:30 → 学習日は6/14
      expect(buildOutcomeSummary([test0], attempts).entries.single.activeDays, 0);
      expect(
        buildOutcomeSummary([test0], attempts, studyDay: const StudyDay(startHour: 4)).entries.single.activeDays,
        1,
      );
    });
  });
}
