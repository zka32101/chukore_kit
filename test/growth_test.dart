import 'package:chukore_kit/chukore_kit.dart';
import 'package:test/test.dart';

Attempt _at(String q, int day, bool ok) => Attempt(
      questionId: q,
      unitId: 'u',
      correct: ok,
      answeredAt: DateTime.utc(2026, 10, day),
    );

void main() {
  test('レーダー: 軸数の制約と平均', () {
    final m = {
      'a': const Mastery(unitId: 'a', score: 0.8),
      'b': const Mastery(unitId: 'b', score: 0.4),
    };
    final groups = {
      'g1': ['a', 'b'],
      'g2': ['c'],
      'g3': ['a'],
    };
    final s = takeRadarSnapshot(DateTime.utc(2026, 10, 13), groups, m);
    expect(s.axes['g1'], closeTo(0.6, 1e-9));
    expect(s.axes['g2'], 0);
    expect(() => takeRadarSnapshot(DateTime.utc(2026, 10, 13), {'g': ['a']}, m),
        throwsArgumentError);
    final later = RadarSnapshot(DateTime.utc(2026, 11, 1), {'g1': 0.7, 'g2': 0.2, 'g3': 0.9});
    expect(radarDiff(s, later)['g1'], closeTo(0.1, 1e-9));
  });

  test('自己ベスト: 初回は祝わず、更新時のみ', () {
    expect(isPersonalBest([], 80), isFalse);
    expect(isPersonalBest([60, 70], 75), isTrue);
    expect(isPersonalBest([60, 70], 70), isFalse);
  });

  test('できるようになった数', () {
    final n = nowSolvableCount([
      _at('q1', 1, false), _at('q1', 3, true), // 解ける
      _at('q2', 1, false), _at('q2', 3, false), // まだ
      _at('q3', 1, true), // 元から正解
    ]);
    expect(n, 1);
  });

  test('キャラ進化: 学年とスタンプで段階が上がり、上限は4', () {
    const r = EvolutionRule();
    expect(r.stage(grade: 1, stamps: 0), 0);
    expect(r.stage(grade: 2, stamps: 0), 1);
    expect(r.stage(grade: 1, stamps: 30), 2);
    expect(r.stage(grade: 3, stamps: 100), 4);
  });
}
