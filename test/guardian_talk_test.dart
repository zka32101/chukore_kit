import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

WeeklyReport report({int days = 0, int attempts = 0, int overcome = 0, List<Improvement> improved = const [], int prevDays = 0, int prevAttempts = 0}) =>
    WeeklyReport(
      weekStart: DateTime(2026, 10, 12),
      attemptCount: attempts,
      activeDays: days,
      improvements: improved,
      previousAttemptCount: prevAttempts,
      previousActiveDays: prevDays,
      newlyOvercome: overcome,
    );

const up = Improvement('u1', '分数', 0.4, 0.7);

void main() {
  group('声かけの選び方', () {
    test('伸びた > 克服 > 継続 > はじめの一歩 > おやすみ の優先', () {
      expect(suggestGuardianTalk(report(days: 5, attempts: 50, overcome: 2, improved: [up])).kind, MyWeekKind.grew);
      expect(suggestGuardianTalk(report(days: 5, attempts: 50, overcome: 2)).kind, MyWeekKind.overcame);
      expect(suggestGuardianTalk(report(days: 3, attempts: 30)).kind, MyWeekKind.kept);
      expect(suggestGuardianTalk(report(days: 2, attempts: 10)).kind, MyWeekKind.started);
      expect(suggestGuardianTalk(report(days: 1, attempts: 3)).kind, MyWeekKind.started);
      expect(suggestGuardianTalk(report()).kind, MyWeekKind.rest);
    });

    test('先週より少なくても、先週と比べた言い方にはならない（種類は今週の中身だけで決まる）', () {
      final less = suggestGuardianTalk(report(days: 3, attempts: 20, prevDays: 7, prevAttempts: 100));
      final more = suggestGuardianTalk(report(days: 3, attempts: 20));
      expect(less.kind, more.kind);
      expect(less.text(const JaStrings()), more.text(const JaStrings()));
    });

    test('子ども本人向けのふりかえり（buildMyWeek）と同じ種類になる', () {
      for (final r in [
        report(),
        report(days: 1),
        report(days: 4),
        report(days: 4, overcome: 1),
        report(days: 4, improved: [up]),
      ]) {
        expect(suggestGuardianTalk(r).kind, buildMyWeek(r).kind);
      }
    });
  });

  group('文面', () {
    test('種類ごとに文言が違い、文言は ChukoreStrings から引く', () {
      const s = EnStrings();
      final texts = {for (final k in MyWeekKind.values) k: GuardianTalk(k).text(s)};
      expect(texts[MyWeekKind.grew], s.talkGrew);
      expect(texts[MyWeekKind.overcame], s.talkOvercame);
      expect(texts[MyWeekKind.kept], s.talkSteady);
      expect(texts[MyWeekKind.started], s.talkStarted);
      expect(texts[MyWeekKind.rest], s.talkRest);
      expect(texts.values.toSet().length, 5);
    });

    test('全言語に5種類の文言があり、数字を含まない', () {
      for (final s in ChukoreStrings.supported) {
        for (final k in MyWeekKind.values) {
          final t = GuardianTalk(k).text(s);
          expect(t.trim(), isNotEmpty, reason: '${s.tag} $k');
          expect(RegExp(r'[0-9０-９]').hasMatch(t), isFalse, reason: '${s.tag} $k');
          expect(t.contains('­'), isFalse, reason: '${s.tag} $k に混入した制御文字');
        }
      }
    });

    test('おやすみの文言は、責めずに、いつでも始められると伝える（日本語・英語で内容を確認）', () {
      expect(const JaStrings().talkRest, contains('責めず'));
      expect(const JaStrings().talkRest, contains('いつでも'));
      expect(const EnStrings().talkRest, contains('No blame'));
      expect(const EnStrings().talkRest, contains('any time'));
    });
  });
}
