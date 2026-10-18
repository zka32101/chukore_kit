import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

WeeklyReport report({
  int attempts = 0,
  int days = 0,
  int prevAttempts = 0,
  int prevDays = 0,
  int overcome = 0,
  List<Improvement> improved = const [],
  List<String> eased = const [],
}) =>
    WeeklyReport(
      weekStart: DateTime(2026, 10, 12),
      attemptCount: attempts,
      activeDays: days,
      improvements: improved,
      previousAttemptCount: prevAttempts,
      previousActiveDays: prevDays,
      newlyOvercome: overcome,
      easedMisconceptions: eased,
    );

Improvement imp(String title, double before, double after) => Improvement(title, title, before, after);

void main() {
  const ja = JaStrings();
  const en = EnStrings();

  group('見出しの種類（優先は 伸びた > 克服 > 続けた > はじめの一歩 > ひとやすみ）', () {
    test('伸びた単元があれば grew', () {
      expect(buildMyWeek(report(days: 1, attempts: 5, improved: [imp('一次方程式', 0.3, 0.5)])).kind, MyWeekKind.grew);
    });
    test('伸びは無くても、克服できたつまずきがあれば overcame', () {
      expect(buildMyWeek(report(days: 5, attempts: 30, overcome: 2)).kind, MyWeekKind.overcame);
    });
    test('3 日以上続けたら kept。1〜2 日なら started', () {
      expect(buildMyWeek(report(days: 3, attempts: 9)).kind, MyWeekKind.kept);
      expect(buildMyWeek(report(days: 2, attempts: 9)).kind, MyWeekKind.started);
      expect(buildMyWeek(report(days: 1, attempts: 1)).kind, MyWeekKind.started);
    });
    test('学習していない週は rest（責めない）', () {
      final w = buildMyWeek(report());
      expect(w.kind, MyWeekKind.rest);
      expect(w.toText(ja), ja.myWeekRest, reason: '見出しだけ。「0日」「0問」などの数字は出さない');
    });
  });

  group('「できたこと」だけを前に出す', () {
    test('先週より少なくても、少ないことは伝えない（moreThanLastWeek が偽になるだけ）', () {
      final w = buildMyWeek(report(days: 2, attempts: 5, prevDays: 6, prevAttempts: 40));
      expect(w.moreThanLastWeek, isFalse);
      final text = w.toText(ja);
      expect(text.contains('先週'), isFalse);
      expect(text.contains('6'), isFalse);
    });
    test('先週より日数か問題数が多ければ moreThanLastWeek', () {
      expect(buildMyWeek(report(days: 4, attempts: 5, prevDays: 3, prevAttempts: 50)).moreThanLastWeek, isTrue);
      expect(buildMyWeek(report(days: 3, attempts: 20, prevDays: 3, prevAttempts: 10)).moreThanLastWeek, isTrue);
      expect(buildMyWeek(report(days: 3, attempts: 10, prevDays: 3, prevAttempts: 10)).moreThanLastWeek, isFalse);
    });
    test('減った誤解の型の材料は子ども向けには使わない（名前を出さない）', () {
      final w = buildMyWeek(report(days: 3, attempts: 9, eased: ['sign_error']));
      expect(w.toText(en).contains('sign_error'), isFalse);
    });
  });

  group('文面', () {
    final w = buildMyWeek(report(
      days: 4,
      attempts: 38,
      overcome: 2,
      improved: [imp('一次方程式', 0.3, 0.6), imp('文字式', 0.4, 0.5), imp('正負の数', 0.2, 0.3), imp('比例', 0.1, 0.15)],
    ));

    test('見出し → 日数と問題数 → 克服した数 → 伸びた単元（最大 3 つ）。パーセントは出さない', () {
      expect(
        w.toText(ja),
        '${ja.myWeekGrew}\n${ja.reportHeader(4, 38)}\n${ja.statStamps}: 2\n${ja.reportImprovedTitle}\n- 一次方程式\n- 文字式\n- 正負の数',
      );
      expect(w.toText(ja).contains('%'), isFalse);
      expect(w.improvedTitles.length, MyWeek.maxImproved);
    });

    test('克服が 0 なら克服の行は無い。伸びた単元が無ければその行も無い', () {
      final plain = buildMyWeek(report(days: 3, attempts: 9));
      expect(plain.toText(en), '${en.myWeekKept}\n${en.reportHeader(3, 9)}');
    });

    test('全言語で 5 種類の見出しが空でなく、互いに違う', () {
      for (final l in ChukoreStrings.supported) {
        final t = [
          l.myWeekGrew,
          l.myWeekOvercame,
          l.myWeekKept,
          l.myWeekStarted,
          l.myWeekRest,
        ];
        expect(t.every((x) => x.trim().isNotEmpty), isTrue, reason: l.tag);
        expect(t.toSet().length, 5, reason: l.tag);
        for (final k in MyWeekKind.values) {
          expect(buildMyWeek(report(days: k == MyWeekKind.rest ? 0 : 1)).headline(l).isNotEmpty, isTrue);
        }
      }
    });

    test('見出しに数字を含まない', () {
      for (final l in ChukoreStrings.supported) {
        for (final t in [l.myWeekGrew, l.myWeekOvercame, l.myWeekKept, l.myWeekStarted, l.myWeekRest]) {
          expect(RegExp(r'[0-9０-９٠-٩०-९๐-๙]').hasMatch(t), isFalse, reason: '${l.tag}: $t');
        }
      }
    });
  });

  group('AgePolicy', () {
    test('子ども本人の振り返りは、既定で使える（自分の記録を自分で見るだけ）', () {
      const p = AgePolicy();
      expect(p.accessFor(ChildFeature.selfReview, age: 10), Access.allowed);
      expect(p.accessFor(ChildFeature.weeklyReport, age: 10), Access.needsGuardianGate, reason: '保護者向けレポートは従来どおり');
    });
    test('JSON の access に書かないと出さない（安全側）。書けば使える', () {
      final hidden = AgePolicyTable.parse('{"regions":{"DE":{"access":{"weeklyReport":"allowed"}}}}').forRegion('DE');
      expect(hidden.accessForChild(ChildFeature.selfReview, isChild: true), Access.hidden);
      final shown = AgePolicyTable.parse('{"regions":{"DE":{"access":{"selfReview":"allowed"}}}}').forRegion('DE');
      expect(shown.accessForChild(ChildFeature.selfReview, isChild: true), Access.allowed);
    });
  });

  test('同じ入力なら同じ結果', () {
    final r = report(days: 4, attempts: 38, overcome: 1, improved: [imp('a', 0.1, 0.2)]);
    expect(buildMyWeek(r).toText(ja), buildMyWeek(r).toText(ja));
  });
}
