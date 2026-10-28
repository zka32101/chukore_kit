import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 20);

NudgeDecision? decide(AgePolicy policy, {required bool isChild, bool guardianApproved = false}) => decideNudgeFor(
  policy,
  isChild: isChild,
  guardianApproved: guardianApproved,
  today: today,
  lastPracticedOn: today.subtract(const Duration(days: 1)),
  testDate: today.add(const Duration(days: 3)), // テストが近い: 通知の条件はそろっている
);

void main() {
  test('前提: 条件がそろっていれば、年齢を見ない decideNudge は通知を返す', () {
    final d = decideNudge(
      today: today,
      lastPracticedOn: today.subtract(const Duration(days: 1)),
      testDate: today.add(const Duration(days: 3)),
    );
    expect(d?.kind, NudgeKind.testSoon);
  });

  test('既定の方針: 子どもには通知を出さない（常に null）。子どもでなければ出す', () {
    const policy = AgePolicy();
    expect(policy.accessForChild(ChildFeature.nudge, isChild: true), Access.hidden);
    expect(decide(policy, isChild: true), isNull);
    expect(decide(policy, isChild: true, guardianApproved: true), isNull, reason: '保護者の承認があっても、方針が許さなければ出さない');
    expect(decide(policy, isChild: false)?.kind, NudgeKind.testSoon);
  });

  test('方針が保護者ゲートのあとなら、承認があるときだけ出す', () {
    const policy = AgePolicy(childAccess: {ChildFeature.nudge: Access.needsGuardianGate});
    expect(decide(policy, isChild: true), isNull);
    expect(decide(policy, isChild: true, guardianApproved: true)?.kind, NudgeKind.testSoon);
  });

  test('方針が許可なら、子どもにも出す', () {
    const policy = AgePolicy(childAccess: {ChildFeature.nudge: Access.allowed});
    expect(decide(policy, isChild: true)?.kind, NudgeKind.testSoon);
  });

  test('書かれていない方針（access を書いたが nudge を書き忘れた）は、子どもには出さない（安全側）', () {
    const policy = AgePolicy(childAccess: {ChildFeature.weeklyReport: Access.allowed});
    expect(decide(policy, isChild: true, guardianApproved: true), isNull);
  });

  test('通知の条件を満たさないときは、許可されていても null（decideNudge の判定は変わらない）', () {
    const policy = AgePolicy(childAccess: {ChildFeature.nudge: Access.allowed});
    final d = decideNudgeFor(policy, isChild: true, today: today, lastPracticedOn: today); // 今日すでに学習した
    expect(d, isNull);
  });

  test('JSON の access に nudge を書ける。書き間違いは拒否。書かなければ子どもには出さない', () {
    final allowed = AgePolicyTable.parse('{"regions":{"JP":{"access":{"nudge":"needsGuardianGate"}}}}').forRegion('JP');
    expect(allowed.accessForChild(ChildFeature.nudge, isChild: true), Access.needsGuardianGate);
    final without = AgePolicyTable.parse('{"regions":{"JP":{"access":{"weeklyReport":"allowed"}}}}').forRegion('JP');
    expect(without.accessForChild(ChildFeature.nudge, isChild: true), Access.hidden);
    expect(() => AgePolicyTable.parse('{"regions":{"JP":{"access":{"nudges":"allowed"}}}}'), throwsFormatException);
  });
}
