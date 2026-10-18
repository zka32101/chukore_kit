import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int month, int day) => DateTime(2026, month, day);

void main() {
  final today = d(10, 20);
  final yesterday = d(10, 19);

  NudgeDecision? decide({
    DateTime? last,
    int streak = 0,
    DateTime? test,
    int due = 0,
    DateTime? nudged,
    List<BusyDay> busy = const [],
    NudgeSettings settings = const NudgeSettings(),
  }) =>
      decideNudge(
        today: today,
        lastPracticedOn: last,
        streakDays: streak,
        testDate: test,
        dueReviews: due,
        lastNudgedOn: nudged,
        busyDays: busy,
        settings: settings,
      );

  group('何を出すか', () {
    test('テストが 7 日以内 → testSoon（日数つき）', () {
      final r = decide(last: yesterday, test: d(10, 27))!;
      expect((r.kind, r.daysToTest), (NudgeKind.testSoon, 7));
      expect(decide(last: yesterday, test: d(10, 28)), isNull, reason: '8 日先はまだ');
    });

    test('復習が 3 問以上たまっている → review', () {
      final r = decide(last: d(10, 18), due: 3)!;
      expect((r.kind, r.dueReviews), (NudgeKind.review, 3));
      expect(decide(last: d(10, 18), due: 2), isNull);
    });

    test('昨日学習して、連続 3 日以上 → streak', () {
      final r = decide(last: yesterday, streak: 3)!;
      expect((r.kind, r.streakDays), (NudgeKind.streak, 3));
      expect(decide(last: yesterday, streak: 2), isNull);
    });

    test('優先は testSoon > review > streak', () {
      expect(decide(last: yesterday, streak: 5, due: 9, test: d(10, 25))!.kind, NudgeKind.testSoon);
      expect(decide(last: yesterday, streak: 5, due: 9)!.kind, NudgeKind.review);
      expect(decide(last: yesterday, streak: 5, due: 1)!.kind, NudgeKind.streak);
    });

    test('連続記録がすでに途切れている（2 日以上あいた）なら streak は出さない', () {
      expect(decide(last: d(10, 18), streak: 9), isNull);
    });
  });

  group('出さない', () {
    test('今日すでに学習した', () {
      expect(decide(last: today, test: d(10, 22), due: 9), isNull);
      expect(decide(last: DateTime(2026, 10, 20, 23, 59), due: 9), isNull, reason: '時刻は見ない');
    });

    test('忙しい日・お休みの日', () {
      expect(decide(last: yesterday, test: d(10, 22), busy: [BusyDay(today)]), isNull);
      expect(decide(last: yesterday, test: d(10, 22), busy: [BusyDay(today, BusyKind.off)]), isNull);
      expect(decide(last: yesterday, test: d(10, 22), busy: [BusyDay(d(10, 21))])?.kind, NudgeKind.testSoon, reason: '別の日は関係ない');
    });

    test('テスト当日・テストが過ぎたあと', () {
      expect(decide(last: yesterday, test: today, due: 9), isNull);
      expect(decide(last: yesterday, test: d(10, 10), due: 9)!.kind, NudgeKind.review, reason: '過ぎたテストは無視して他の判定へ');
    });

    test('前回の通知から 2 日空ける。テスト 3 日前からは毎日', () {
      expect(decide(last: d(10, 18), due: 5, nudged: yesterday), isNull);
      expect(decide(last: d(10, 18), due: 5, nudged: d(10, 18))!.kind, NudgeKind.review);
      expect(decide(last: yesterday, test: d(10, 24), nudged: yesterday), isNull, reason: '4 日前はまだ空ける');
      expect(decide(last: yesterday, test: d(10, 23), nudged: yesterday)!.kind, NudgeKind.testSoon);
    });

    test('2 週間以上離れていたら、しつこく促さない（テストが近い場合を除く）', () {
      expect(decide(last: d(10, 6), due: 9)!.kind, NudgeKind.review, reason: '14 日はまだ');
      expect(decide(last: d(10, 5), due: 9), isNull);
      expect(decide(last: d(10, 5), due: 9, test: d(10, 25))!.kind, NudgeKind.testSoon);
    });

    test('一度も学習していない人は、テストが近いときだけ', () {
      expect(decide(due: 9), isNull);
      expect(decide(test: d(10, 25))!.kind, NudgeKind.testSoon);
    });
  });

  test('日付は時刻に関係なく暦日で比べる', () {
    final r = decideNudge(
      today: DateTime(2026, 10, 20, 7, 30),
      lastPracticedOn: DateTime(2026, 10, 19, 23, 50),
      streakDays: 4,
    );
    expect(r?.kind, NudgeKind.streak);
  });

  test('設定を変えられる', () {
    const s = NudgeSettings(minDueReviews: 1, testSoonDays: 2);
    expect(decide(last: yesterday, due: 1, settings: s)?.kind, NudgeKind.review);
    expect(decide(last: yesterday, test: d(10, 23), settings: s), isNull);
  });

  group('文言', () {
    test('全言語で 3 種類とも空でなく、互いに違う', () {
      for (final l in ChukoreStrings.supported) {
        final t = [for (final k in NudgeKind.values) nudgeText(k, l)];
        expect(t.every((x) => x.trim().isNotEmpty), isTrue, reason: l.tag);
        expect(t.toSet().length, 3, reason: l.tag);
      }
    });

    test('数字を含まない（回数・日数は呼び出し側が添える）', () {
      for (final l in ChukoreStrings.supported) {
        for (final k in NudgeKind.values) {
          expect(RegExp(r'[0-9０-９٠-٩०-९๐-๙]').hasMatch(nudgeText(k, l)), isFalse, reason: '${l.tag} $k');
        }
      }
    });

    test('種類ごとに対応する文言を返す', () {
      const en = EnStrings();
      expect(nudgeText(NudgeKind.testSoon, en), en.nudgeTestSoon);
      expect(nudgeText(NudgeKind.review, en), en.nudgeReview);
      expect(nudgeText(NudgeKind.streak, en), en.nudgeStreak);
    });
  });
}
