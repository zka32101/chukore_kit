import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree _tree() => UnitTree(1, [
      Unit(id: 'g', subject: 'math', grade: 1, title: 'G'),
      Unit(id: 'a', subject: 'math', grade: 1, title: 'A', parentId: 'g', estimatedQuestions: 40),
      Unit(id: 'b', subject: 'math', grade: 1, title: 'B', parentId: 'g', estimatedQuestions: 40),
      Unit(id: 'c', subject: 'math', grade: 1, title: 'C', estimatedQuestions: 20),
    ]);

Map<String, Mastery> _m(Map<String, double> s) =>
    {for (final e in s.entries) e.key: Mastery(unitId: e.key, score: e.value)};

void main() {
  test('見込み点は、問題数の重みで習熟度を平均して 100 点満点にしたもの', () {
    final p = buildGoalPlan(
      tree: _tree(), unitIds: ['g', 'c'],
      mastery: _m({'a': 0.5, 'b': 1.0, 'c': 0.0}), targetScore: 60,
    );
    // (40×0.5 + 40×1.0 + 20×0) / 100 = 0.6 → 60 点
    expect(p.currentScore, closeTo(60, 1e-9));
    expect(p.achieved, isTrue);
    expect(p.steps, isEmpty);
    expect(p.gap, 0);
  });

  test('記録のない単元は 0（未学習）として数える', () {
    final p = buildGoalPlan(tree: _tree(), unitIds: ['g', 'c'], mastery: const {}, targetScore: 50);
    expect(p.currentScore, 0);
    expect(p.maxPossible, closeTo(90, 1e-9)); // 全単元を 0.9 まで
  });

  test('効果（重み × 伸びしろ）の大きい単元から選び、届くところで止める。最後は必要な分だけ', () {
    final p = buildGoalPlan(
      tree: _tree(), unitIds: ['g', 'c'],
      mastery: _m({'a': 0.5, 'b': 0.5, 'c': 0.5}), targetScore: 60,
    );
    // 現在 50 点。a と b の伸びしろは各 40×0.4/100×100 = 16 点、c は 8 点。必要なのは 10 点
    expect(p.currentScore, closeTo(50, 1e-9));
    expect(p.steps.length, 1);
    final s = p.steps.single;
    expect(s.unitId, 'a'); // 同点は単元ID順
    expect(s.gainPoints, closeTo(10, 1e-9));
    // 16 点ぶんの伸びしろ（0.5→0.9）のうち 10/16 だけ伸ばす → 0.5 + 0.4×10/16 = 0.75
    expect(s.targetMastery, closeTo(0.75, 1e-9));
    expect(s.currentMastery, 0.5);
    expect(p.unitIds, ['a']);
    expect(p.unreachable, isFalse);
  });

  test('1 つでは足りなければ、次の単元へ。合計の増分がちょうど差になる', () {
    final p = buildGoalPlan(
      tree: _tree(), unitIds: ['g', 'c'],
      mastery: _m({'a': 0.5, 'b': 0.5, 'c': 0.5}), targetScore: 80,
    );
    // 差 30 点: a 16 + b 14（b は 16 点のうち 14）
    expect(p.steps.map((s) => s.unitId), ['a', 'b']);
    expect(p.steps[0].targetMastery, closeTo(0.9, 1e-9));
    expect(p.steps[1].targetMastery, closeTo(0.5 + 0.4 * 14 / 16, 1e-9));
    expect(p.steps.fold<double>(0, (s, e) => s + e.gainPoints), closeTo(p.gap, 1e-9));
  });

  test('上限まで伸ばしても届かない目標は unreachable。全単元を上限まで伸ばす案を返す', () {
    final p = buildGoalPlan(
      tree: _tree(), unitIds: ['g', 'c'],
      mastery: _m({'a': 0.5, 'b': 0.5, 'c': 0.5}), targetScore: 95,
    );
    expect(p.unreachable, isTrue);
    expect(p.maxPossible, closeTo(90, 1e-9));
    expect(p.steps.map((s) => s.unitId).toSet(), {'a', 'b', 'c'});
    expect(p.steps.every((s) => (s.targetMastery - 0.9).abs() < 1e-9), isTrue);
  });

  test('すでに上限を超えている単元は伸ばさない。上限は変えられる', () {
    final p = buildGoalPlan(
      tree: _tree(), unitIds: ['g'],
      mastery: _m({'a': 0.95, 'b': 0.2}), targetScore: 70,
    );
    expect(p.steps.map((s) => s.unitId), ['b']);
    // 上限を超えている a は、そのまま数える（a 0.95・b 0.9 の平均 = 92.5 点）
    expect(p.maxPossible, closeTo(92.5, 1e-9));
    final high = buildGoalPlan(
      tree: _tree(), unitIds: ['g'], mastery: _m({'a': 0.95, 'b': 0.2}), targetScore: 95, masteryCap: 1.0,
    );
    expect(high.maxPossible, closeTo(100, 1e-9));
    expect(high.unreachable, isFalse);
  });

  test('範囲の外の単元は数えない。範囲が空なら 0 点・ステップなし', () {
    final p = buildGoalPlan(tree: _tree(), unitIds: ['c'], mastery: _m({'a': 1.0, 'c': 0.4}), targetScore: 60);
    expect(p.currentScore, closeTo(40, 1e-9));
    expect(p.steps.single.unitId, 'c');
    final empty = buildGoalPlan(tree: _tree(), unitIds: const [], mastery: const {}, targetScore: 60);
    expect(empty.currentScore, 0);
    expect(empty.steps, isEmpty);
  });

  test('目標点・上限が範囲外なら ArgumentError', () {
    expect(() => buildGoalPlan(tree: _tree(), unitIds: ['g'], mastery: const {}, targetScore: 0), throwsArgumentError);
    expect(() => buildGoalPlan(tree: _tree(), unitIds: ['g'], mastery: const {}, targetScore: 101), throwsArgumentError);
    expect(() => buildGoalPlan(tree: _tree(), unitIds: ['g'], mastery: const {}, targetScore: 80, masteryCap: 0), throwsArgumentError);
  });

  test('到達レベルの下限点を目標にできる', () {
    const th = LevelThresholds();
    final p = buildGoalPlan(
      tree: _tree(), unitIds: ['g', 'c'], mastery: _m({'a': 0.5, 'b': 0.5, 'c': 0.5}),
      targetScore: th.minOf(Level.b),
    );
    expect(p.targetScore, 60);
    expect(p.achieved, isFalse);
  });
}
