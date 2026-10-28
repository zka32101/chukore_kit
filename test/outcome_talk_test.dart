import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

RealTestRecord t(int month, double score) => RealTestRecord(DateTime(2026, month, 10), score);

OutcomeSummary summary(List<RealTestRecord> r, {RealTestRecord? baseline}) =>
    buildOutcomeSummary(r, const [], baseline: baseline);

void main() {
  group('suggestOutcomeTalk', () {
    test('いちばん新しい記録の変化に対応する。記録が無ければ null', () {
      expect(suggestOutcomeTalk(summary(const [])), isNull);
      expect(suggestOutcomeTalk(summary([t(4, 60)]))?.change, OutcomeChange.first);
      expect(suggestOutcomeTalk(summary([t(4, 60), t(6, 75)]))?.change, OutcomeChange.up);
      expect(suggestOutcomeTalk(summary([t(4, 60), t(6, 61)]))?.change, OutcomeChange.same);
      expect(suggestOutcomeTalk(summary([t(4, 75), t(6, 60)]))?.change, OutcomeChange.down);
      expect(suggestOutcomeTalk(summary([t(4, 60), t(5, 80), t(6, 55)]))?.change, OutcomeChange.down, reason: '最後の記録');
    });

    test('使う前の点があれば、最初の記録も変化として声かけする', () {
      final s = summary([t(4, 70)], baseline: RealTestRecord(DateTime(2026, 1, 1), 50));
      expect(suggestOutcomeTalk(s)?.change, OutcomeChange.up);
    });
  });

  group('文言（全言語）', () {
    test('4つの変化すべてに、空でない声かけがあり、数字を含まない', () {
      for (final s in ChukoreStrings.supported) {
        for (final c in OutcomeChange.values) {
          final m = OutcomeTalk(c).text(s);
          expect(m.trim(), isNotEmpty, reason: '${s.tag} $c');
          expect(RegExp(r'[0-9０-９]').hasMatch(m), false, reason: '${s.tag} $c: 点数や日数の数字を含めない');
        }
      }
    });

    test('4つの文言は言語内で互いに違う', () {
      for (final s in ChukoreStrings.supported) {
        final all = [for (final c in OutcomeChange.values) OutcomeTalk(c).text(s)];
        expect(all.toSet().length, 4, reason: s.tag);
      }
    });

    test('下がったときも責めない形（日本語・英語で固定）。上がったときも結果を保証しない', () {
      expect(OutcomeTalk(OutcomeChange.down).text(const JaStrings()), contains('責めず'));
      expect(OutcomeTalk(OutcomeChange.down).text(const EnStrings()), contains('No blame'));
      expect(OutcomeTalk(OutcomeChange.up).text(const JaStrings()), contains('ほめて'));
      expect(OutcomeTalk(OutcomeChange.up).text(const JaStrings()), isNot(contains('保証')));
    });
  });

  group('suggestOutcomeTalkFor: 年齢の方針', () {
    final s = summary([t(4, 60), t(6, 75)]);

    test('既定の方針: 子どもには保護者ゲートのあとだけ。子どもでなければそのまま', () {
      const policy = AgePolicy();
      expect(policy.accessForChild(ChildFeature.weeklyReport, isChild: true), Access.needsGuardianGate);
      expect(suggestOutcomeTalkFor(policy, s, isChild: true), isNull);
      expect(suggestOutcomeTalkFor(policy, s, isChild: true, guardianApproved: true)?.change, OutcomeChange.up);
      expect(suggestOutcomeTalkFor(policy, s, isChild: false)?.change, OutcomeChange.up);
    });

    test('方針が非表示なら、承認があっても出さない。許可なら承認なしで出す', () {
      const hidden = AgePolicy(childAccess: {ChildFeature.weeklyReport: Access.hidden});
      expect(suggestOutcomeTalkFor(hidden, s, isChild: true, guardianApproved: true), isNull);
      const open = AgePolicy(childAccess: {ChildFeature.weeklyReport: Access.allowed});
      expect(suggestOutcomeTalkFor(open, s, isChild: true)?.change, OutcomeChange.up);
    });

    test('書かれていない方針は、子どもには出さない（安全側）。記録が無ければ許可でも null', () {
      const unset = AgePolicy(childAccess: {ChildFeature.deviation: Access.allowed});
      expect(suggestOutcomeTalkFor(unset, s, isChild: true, guardianApproved: true), isNull);
      const open = AgePolicy(childAccess: {ChildFeature.weeklyReport: Access.allowed});
      expect(suggestOutcomeTalkFor(open, summary(const []), isChild: true), isNull);
    });
  });
}
