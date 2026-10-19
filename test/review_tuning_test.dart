import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final d0 = DateTime(2026, 9, 1, 10);

Attempt at(String q, int day, bool ok, {String mode = 'practice', int hints = 0}) => Attempt(
      questionId: q,
      unitId: 'u',
      correct: ok,
      answeredAt: d0.add(Duration(days: day)),
      mode: mode,
      hintsUsed: hints,
    );

/// 問題 [id] を、箱 1 に入れてから [gap] 日後に解いた結果 [ok]（箱 1 の間隔は 3 日）。
List<Attempt> box1(String id, bool ok, {int gap = 3, String mode = 'practice', int hints = 0}) => [
      at(id, 0, true),
      at(id, 1, true), // 2 回目の正解で箱 1 へ
      at(id, 1 + gap, ok, mode: mode, hints: hints),
    ];

/// [n] 問のうち [right] 問が正解。
List<Attempt> batch(int n, int right, {int gap = 3, String mode = 'practice', int hints = 0, String prefix = 'q'}) => [
      for (var i = 0; i < n; i++) ...box1('$prefix$i', i < right, gap: gap, mode: mode, hints: hints),
    ];

BoxRetention b(ReviewTuning t, int box) => t.boxes.firstWhere((x) => x.box == box);

void main() {
  group('判断', () {
    test('思い出せない割合が高ければ短く、ほぼ確実なら長く、そのあたりなら変えない', () {
      final shorter = tuneReviewIntervals(batch(40, 10));
      expect(b(shorter, 1).action, IntervalAction.shorten);
      expect([b(shorter, 1).oldDays, b(shorter, 1).newDays], [3, 2]);
      expect(shorter.config.intervalDays.sublist(0, 2), [1, 2]);

      final longer = tuneReviewIntervals(batch(40, 40));
      expect(b(longer, 1).action, IntervalAction.lengthen);
      expect(b(longer, 1).newDays, 4);

      final keep = tuneReviewIntervals(batch(40, 34));
      expect(b(keep, 1).action, IntervalAction.keep);
      expect(b(keep, 1).newDays, 3);
      expect(b(keep, 1).retention, closeTo(0.85, 1e-9));
    });

    test('回答が minAttempts に満たない箱は判断しない（境目は含める）', () {
      expect(b(tuneReviewIntervals(batch(29, 5)), 1).action, IntervalAction.insufficient);
      expect(b(tuneReviewIntervals(batch(30, 5)), 1).action, IntervalAction.shorten);
      expect(tuneReviewIntervals(batch(29, 5)).changed, isFalse);
      expect(b(tuneReviewIntervals(batch(29, 5), minAttempts: 29), 1).action, IntervalAction.shorten);
    });

    test('データが無ければ全部「判断しない」で、間隔は元のまま', () {
      final t = tuneReviewIntervals(const []);
      expect(t.boxes.every((x) => x.action == IntervalAction.insufficient), isTrue);
      expect(t.config.intervalDays, [1, 3, 7, 14, 30]);
      expect(t.changed, isFalse);
    });
  });

  group('数える回答', () {
    test('期日の前・遅れすぎの復習、ヒント付き、別モードは数えない', () {
      final early = tuneReviewIntervals(batch(40, 10, gap: 2));
      expect(b(early, 1).attempts, 0, reason: '期日（3日）より前');
      expect(b(tuneReviewIntervals(batch(40, 10, gap: 4)), 1).attempts, 40, reason: '3×1.5=4.5 日までは数える');
      expect(b(tuneReviewIntervals(batch(40, 10, gap: 5)), 1).attempts, 0, reason: '遅れすぎ');
      expect(b(tuneReviewIntervals(batch(40, 10, hints: 1)), 1).attempts, 0);
      expect(b(tuneReviewIntervals(batch(40, 10, mode: 'mock')), 1).attempts, 0);
      expect(b(tuneReviewIntervals(batch(40, 10, mode: 'mock'), mode: 'mock'), 1).attempts, 40);
    });

    test('遅れすぎの境目は maxLateRatio 倍（含める）', () {
      expect(b(tuneReviewIntervals(batch(40, 10, gap: 6), maxLateRatio: 2), 1).attempts, 40);
      expect(b(tuneReviewIntervals(batch(40, 10, gap: 7), maxLateRatio: 2), 1).attempts, 0);
    });

    test('自信なしの正解は箱を上げず、箱のまま次も数える。間違えると箱 0 に戻る', () {
      // 箱 1 で自信なしの正解 → 箱 1 のまま。3 日後の復習も箱 1 として数える
      final unsure = [
        for (var i = 0; i < 40; i++) ...[
          at('q$i', 0, true),
          at('q$i', 1, true),
          Attempt(questionId: 'q$i', unitId: 'u', correct: true, answeredAt: d0.add(const Duration(days: 4)), confident: false),
          at('q$i', 7, true),
        ],
      ];
      expect(b(tuneReviewIntervals(unsure), 1).attempts, 80);
      // 箱 1 で間違えると箱 0 に戻る。次の復習は箱 0 なので、箱 1 には数えない
      final wrong = [for (var i = 0; i < 40; i++) ...[at('q$i', 0, true), at('q$i', 1, true), at('q$i', 4, false), at('q$i', 7, true)]];
      expect(b(tuneReviewIntervals(wrong), 1).attempts, 40);
    });

    test('初回・箱 0 の回答は数えない（間違えた翌日の復習は箱 0）', () {
      final a = [for (var i = 0; i < 40; i++) ...[at('q$i', 0, false), at('q$i', 1, true)]];
      final t = tuneReviewIntervals(a);
      expect(t.boxes.every((x) => x.attempts == 0), isTrue);
    });

    test('順不同の履歴でも、時刻順に数える', () {
      final a = batch(40, 10).reversed.toList();
      expect(b(tuneReviewIntervals(a), 1).attempts, 40);
    });
  });

  group('間隔の整合', () {
    test('前の箱より必ず長くなる（箱 1 を伸ばしたら、変えない箱 2 も押し上げる）', () {
      const cfg = ReviewConfig(intervalDays: [1, 2, 3]);
      // 箱 1 の間隔は 2 日。2 日後に全問正解
      final a = [for (var i = 0; i < 40; i++) ...[at('q$i', 0, true), at('q$i', 1, true), at('q$i', 3, true)]];
      final t = tuneReviewIntervals(a, config: cfg);
      expect(b(t, 1).action, IntervalAction.lengthen);
      expect(t.config.intervalDays, [1, 3, 4]);
      expect(b(t, 2).action, IntervalAction.insufficient);
      expect(b(t, 2).newDays, 4);
      expect(t.changed, isTrue);
    });

    test('短くしても 1 つ前の箱より 1 日は長い', () {
      const cfg = ReviewConfig(intervalDays: [1, 2, 3]);
      final a = [for (var i = 0; i < 40; i++) ...[at('q$i', 0, true), at('q$i', 1, true), at('q$i', 3, false)]];
      final t = tuneReviewIntervals(a, config: cfg);
      expect(b(t, 1).action, IntervalAction.shorten);
      expect(t.config.intervalDays[1], 2, reason: '2×0.75=1.5→2 で、箱 0（1 日）より長い');
    });

    test('短くする幅は 25%（8 日 → 6 日）', () {
      const cfg = ReviewConfig(intervalDays: [1, 8, 20]);
      final a = [for (var i = 0; i < 40; i++) ...[at('q$i', 0, true), at('q$i', 1, true), at('q$i', 9, false)]];
      expect(tuneReviewIntervals(a, config: cfg).config.intervalDays.sublist(0, 2), [1, 6]);
    });

    test('入力が不正ならエラー', () {
      expect(() => tuneReviewIntervals(const [], config: const ReviewConfig(intervalDays: [])), throwsArgumentError);
      expect(() => tuneReviewIntervals(const [], minAttempts: 0), throwsArgumentError);
    });
  });
}
