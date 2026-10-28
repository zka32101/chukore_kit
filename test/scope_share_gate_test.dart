import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree tree() => UnitTree(1, [
  const Unit(id: 'g1', subject: 'en', grade: 1, title: 'G1', order: 1),
  const Unit(id: 'e1', subject: 'en', grade: 1, title: 'e1', parentId: 'g1', order: 1),
  const Unit(id: 'e2', subject: 'en', grade: 1, title: 'e2', parentId: 'g1', order: 2),
]);

String? make(AgePolicy policy, {required bool isChild, bool approved = false, DateTime? testDate}) => encodeScopeFor(
  policy,
  tree(),
  isChild: isChild,
  guardianApproved: approved,
  unitIds: const ['e1'],
  testDate: testDate,
);

void main() {
  final plain = encodeScope(tree(), unitIds: const ['e1']);

  test('既定の方針: 子どもには範囲カードの符号を作らない（承認があっても）。子どもでなければ作る', () {
    const policy = AgePolicy();
    expect(policy.accessForChild(ChildFeature.scopeShare, isChild: true), Access.hidden);
    expect(make(policy, isChild: true), isNull);
    expect(make(policy, isChild: true, approved: true), isNull, reason: '方針が非表示なら、承認があっても作らない');
    expect(make(policy, isChild: false), plain);
  });

  test('方針が保護者ゲートのあとなら、承認があるときだけ作る。許可なら承認なしで作る', () {
    const gate = AgePolicy(childAccess: {ChildFeature.scopeShare: Access.needsGuardianGate});
    expect(make(gate, isChild: true), isNull);
    expect(make(gate, isChild: true, approved: true), plain);
    const open = AgePolicy(childAccess: {ChildFeature.scopeShare: Access.allowed});
    expect(make(open, isChild: true), plain);
  });

  test('書かれていない方針は子どもには作らない（安全側）', () {
    const unset = AgePolicy(childAccess: {ChildFeature.deviation: Access.allowed});
    expect(make(unset, isChild: true, approved: true), isNull);
  });

  test('作るときは encodeScope と同じ符号。テスト日も入る', () {
    const open = AgePolicy(childAccess: {ChildFeature.scopeShare: Access.allowed});
    final d = DateTime(2026, 11, 5);
    expect(make(open, isChild: true, testDate: d), encodeScope(tree(), unitIds: const ['e1'], testDate: d));
  });

  test('許可されていても、範囲が不正なら encodeScope と同じエラー（作れないものは黙って null にしない）', () {
    const open = AgePolicy(childAccess: {ChildFeature.scopeShare: Access.allowed});
    expect(() => encodeScopeFor(open, tree(), isChild: true, unitIds: const []), throwsArgumentError);
    expect(
      encodeScopeFor(const AgePolicy(), tree(), isChild: true, unitIds: const []),
      isNull,
      reason: '許可されていない子どもには、範囲の検査より先に null',
    );
  });

  test('JSON の方針で scopeShare を許可すると、子どもにも作れる', () {
    final p = AgePolicyTable.parse('{"regions":{"JP":{"access":{"scopeShare":"allowed"}}}}').forRegion('JP');
    expect(make(p, isChild: true), plain);
  });
}
