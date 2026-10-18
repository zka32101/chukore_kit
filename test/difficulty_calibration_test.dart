import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 1, 10);

Question q(String id, double difficulty, {String unit = 'u1', String type = 'choice', int version = 1}) => Question(
      id: id,
      unitId: unit,
      type: type,
      difficulty: difficulty,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
      version: version,
    );

/// 問題 [qid] を [n] 回解いて [correct] 回正解した履歴。
List<Attempt> solved(String qid, int n, int correct, {String mode = 'practice', int hints = 0, String unit = 'u1'}) => [
      for (var i = 0; i < n; i++)
        Attempt(
          questionId: qid,
          unitId: unit,
          correct: i < correct,
          answeredAt: t0.add(Duration(minutes: i)),
          mode: mode,
          hintsUsed: hints,
        ),
    ];

void main() {
  group('ずれの検出', () {
    test('見積もりより大きく易しい／難しい問題を見つける。ずれの大きい順', () {
      final qs = [q('z_easy', 0.5), q('a_hard', 0.8), q('ok', 0.6)];
      final a = [
        ...solved('a_hard', 100, 55), // 実測 0.55（見積もり 0.8 → −0.25）。履歴の順では先でも、ずれが小さいので後ろに並ぶ
        ...solved('ok', 100, 62), // 実測 0.62（見積もり 0.6）
        ...solved('z_easy', 100, 85), // 実測 0.85（見積もり 0.5 → +0.35）
      ];
      final r = calibrateDifficulty(a, qs);
      expect(r.drifts.map((d) => d.questionId), ['z_easy', 'a_hard']);
      expect(r.drifts.first.easierThanAssumed, isTrue);
      expect(r.drifts.last.easierThanAssumed, isFalse);
      expect(r.drifts.first.gap, closeTo(0.35, 1e-9));
      expect(r.measured, 3);
    });

    test('提案値は実測を 0.05 刻みに丸め、0.05〜0.95 に収める', () {
      final r = calibrateDifficulty([...solved('a', 100, 87), ...solved('b', 100, 100), ...solved('c', 100, 0)],
          [q('a', 0.5), q('b', 0.5), q('c', 0.5)]);
      final s = {for (final d in r.drifts) d.questionId: d.suggested};
      expect(s['a'], 0.85);
      expect(s['b'], 0.95, reason: '1.0 にしない（偏差値の換算で分散が 0 になる）');
      expect(s['c'], 0.05);
    });

    test('回答が少ない問題は判定しない（minAttempts）', () {
      final a = solved('x', 19, 19);
      expect(calibrateDifficulty(a, [q('x', 0.3)]).drifts, isEmpty);
      expect(calibrateDifficulty(a, [q('x', 0.3)]).measured, 0);
      expect(calibrateDifficulty(solved('x', 20, 20), [q('x', 0.3)]).drifts.length, 1);
      expect(calibrateDifficulty(solved('x', 5, 5), [q('x', 0.3)], minAttempts: 5).drifts.length, 1);
    });

    test('差が小さければ、回答が多くてもずれとは言わない（minGap）', () {
      final r = calibrateDifficulty(solved('x', 10000, 6800), [q('x', 0.6)]);
      expect(r.drifts, isEmpty, reason: '差は 0.08。統計的には有意でも、見直すほどではない');
      expect(calibrateDifficulty(solved('x', 10000, 6800), [q('x', 0.6)], minGap: 0.05).drifts.length, 1);
    });

    test('偶然のばらつきの範囲なら、差が大きくてもずれとは言わない（信頼区間）', () {
      // 20 回で 14 回正解（0.7）。見積もり 0.5 は信頼区間（約 0.48〜0.86）に入る
      final r = calibrateDifficulty(solved('x', 20, 14), [q('x', 0.5)], minGap: 0.15);
      expect(r.drifts, isEmpty);
      // 同じ割合でも 200 回なら有意
      expect(calibrateDifficulty(solved('x', 200, 140), [q('x', 0.5)]).drifts.length, 1);
    });

    test('信頼区間は実測を含む。回答が多いほど狭い', () {
      final small = calibrateDifficulty(solved('x', 20, 20), [q('x', 0.3)]).drifts.single;
      final large = calibrateDifficulty(solved('x', 400, 400), [q('x', 0.3)]).drifts.single;
      expect(small.low <= small.observed && small.observed <= small.high, isTrue);
      expect(large.high - large.low, lessThan(small.high - small.low));
    });
  });

  group('数える回答', () {
    final qs = [q('x', 0.3)];
    test('模試の回答は別（既定は練習のみ）。mode で変えられる', () {
      final a = [...solved('x', 30, 30, mode: 'mock')];
      expect(calibrateDifficulty(a, qs).measured, 0);
      expect(calibrateDifficulty(a, qs, mode: 'mock').measured, 1);
    });
    test('ヒントを使った回答は数えない（正解が増えて易しい側にかたよる）', () {
      final a = [...solved('x', 30, 30, hints: 1), ...solved('x', 20, 6)];
      final r = calibrateDifficulty(a, qs);
      expect(r.measured, 1);
      expect(r.drifts, isEmpty, reason: 'ヒント無しの 20 回は 0.3 → ずれなし');
    });
    test('暗記カード・問題集に無い問題は対象外', () {
      final a = [...solved('card1', 30, 30), ...solved('ghost', 30, 30)];
      expect(calibrateDifficulty(a, [q('card1', 0.3, type: 'card')]).measured, 0);
    });
  });

  group('単元ごとの偏り', () {
    test('単元の問題の「実測 − 基準」の平均。偏りの大きい順。回答が足りた問題だけ数える', () {
      final qs = [q('a', 0.5), q('b', 0.5), q('c', 0.5, unit: 'u2'), q('d', 0.5, unit: 'u3')];
      final a = [
        ...solved('a', 40, 32), // +0.3
        ...solved('b', 40, 28, unit: 'u1'), // +0.2
        ...solved('c', 40, 22, unit: 'u2'), // −? 0.55-0.5=+0.05
        ...solved('d', 5, 5, unit: 'u3'), // 回答が足りない
      ];
      final r = calibrateDifficulty(a, qs);
      expect(r.units.map((u) => u.unitId), ['u1', 'u2']);
      expect(r.units.first.meanGap, closeTo(0.25, 1e-9));
      expect(r.units.first.questions, 2);
    });
  });

  group('反映（recalibrate）', () {
    test('ずれた問題だけ提案値に変え、version を 1 上げる。差分更新で検査を通る', () {
      final qs = [q('easy', 0.5, version: 3), q('ok', 0.6)];
      final a = [...solved('easy', 100, 85), ...solved('ok', 100, 61)];
      final next = recalibrate(qs, calibrateDifficulty(a, qs));
      expect(next.map((x) => (x.id, x.difficulty, x.version)), [('easy', 0.85, 4), ('ok', 0.6, 1)]);
      final diff = BankDiff.between(qs, next);
      expect(diff.check(qs), isEmpty, reason: '内容を変えて version を上げている');
      expect(diff.changed.map((c) => c.id), ['easy']);
    });
    test('提案値が今の値と同じなら変えない（version も上げない）', () {
      // 基準 0.85、実測 0.86 → 提案値は 0.85。回答が非常に多く、ずれの下限を小さくすれば「ずれ」として出る
      final qs = [q('x', 0.85, version: 2)];
      final report = calibrateDifficulty(solved('x', 100000, 86000), qs, minGap: 0.005);
      expect(report.drifts.single.suggested, 0.85);
      final next = recalibrate(qs, report).single;
      expect((next.difficulty, next.version), (0.85, 2));
    });
  });

  test('minAttempts は 1 以上。同じ入力なら同じ結果', () {
    expect(() => calibrateDifficulty(const [], const [], minAttempts: 0), throwsArgumentError);
    final qs = [q('a', 0.5), q('b', 0.5)];
    final a = [...solved('a', 50, 45), ...solved('b', 50, 45)];
    expect(calibrateDifficulty(a, qs).drifts.map((d) => d.questionId), calibrateDifficulty(a.reversed, qs.reversed).drifts.map((d) => d.questionId));
  });
}
