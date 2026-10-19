import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 28);

/// 今日から [daysAgo] 日前に [n] 問。
List<Attempt> day(int daysAgo, int n, {String mode = 'practice'}) => [
      for (var i = 0; i < n; i++)
        Attempt(
          questionId: 'q$i',
          unitId: 'u',
          correct: true,
          answeredAt: DateTime(2026, 10, 28, 10, i % 50).subtract(Duration(days: daysAgo)),
          mode: mode,
        ),
    ];

List<Attempt> days(List<int> counts, {int start = 1}) => [for (var i = 0; i < counts.length; i++) ...day(start + i, counts[i])];

void main() {
  group('判断', () {
    test('ふだんの量が少なければ減らし（1 回に 20%）、多ければ少し増やし、近ければ変えない', () {
      final low = suggestCapacity(days([4, 4, 4, 4, 4, 4]), today: today);
      expect(low.action, CapacityAction.lower);
      expect([low.typical, low.suggested], [4, 8], reason: '10→4 でなく 1 回に 2 まで');

      final high = suggestCapacity(days([20, 20, 20, 20, 20]), today: today);
      expect(high.action, CapacityAction.raise);
      expect(high.suggested, 12);

      for (final n in [9, 10, 11]) {
        final keep = suggestCapacity(days([n, n, n, n, n]), today: today);
        expect(keep.action, CapacityAction.keep, reason: '$n');
        expect(keep.suggested, 10);
      }
      expect(suggestCapacity(days([12, 12, 12, 12, 12]), today: today).action, CapacityAction.raise, reason: '差 2 は不感帯（1）の外');
      expect(suggestCapacity(days([8, 8, 8, 8, 8]), today: today).suggested, 8);
    });

    test('学習した日が minActiveDays 未満なら判断しない（境目は含める）', () {
      expect(suggestCapacity(days([4, 4, 4, 4]), today: today).action, CapacityAction.insufficient);
      expect(suggestCapacity(days([4, 4, 4, 4]), today: today).suggested, 10);
      expect(suggestCapacity(days([4, 4, 4, 4, 4]), today: today).action, CapacityAction.lower);
      expect(suggestCapacity(days([4, 4, 4, 4]), today: today, minActiveDays: 4).action, CapacityAction.lower);
    });

    test('学習しなかった日（おやすみ）は数えない。中央値なので外れ値に引きずられない', () {
      // 学習した日は 5 日で、間は空き。詰め込みの 60 問の日があっても中央値は 4
      final a = [...day(1, 4), ...day(5, 4), ...day(9, 4), ...day(13, 60), ...day(20, 4)];
      final s = suggestCapacity(a, today: today);
      expect(s.activeDays, 5);
      expect(s.typical, 4);
    });

    test('奇数日の中央値は真ん中の値', () {
      expect(suggestCapacity(days([8, 1, 7, 2, 6]), today: today).typical, 6);
    });

    test('偶数日の中央値は平均（丸め）', () {
      expect(suggestCapacity(days([3, 4, 4, 5, 6, 7]), today: today).typical, 5, reason: '(4+5)/2=4.5→5');
    });
  });

  group('数える範囲', () {
    test('窓の外（古い・未来）、別モードは数えない。窓の端の日は数える', () {
      final a = [...days([4, 4, 4, 4]), ...day(28, 4), ...day(29, 4), ...day(-1, 4), ...day(2, 4, mode: 'mock')];
      // 窓は 28 日（今日から 27 日前まで）。28 日前・未来・模試は数えない → 4 日のまま
      expect(suggestCapacity(a, today: today).activeDays, 4);
      expect(suggestCapacity([...days([4, 4, 4, 4]), ...day(27, 4)], today: today).activeDays, 5, reason: '27 日前は窓の中');
      expect(suggestCapacity([...days([4, 4, 4, 4]), ...day(5, 4, mode: 'mock')], today: today, mode: 'mock').activeDays, 1);
    });

    test('同じ日の回答は、時刻が違っても 1 日にまとめる', () {
      final a = [...day(1, 3), ...day(2, 3), ...day(3, 3), ...day(4, 3), ...day(5, 3)];
      expect(suggestCapacity(a, today: today).typical, 3);
    });
  });

  group('量の範囲', () {
    test('minBase・maxBase に収める。増減は今の量の 20%', () {
      final floor = suggestCapacity(days([1, 1, 1, 1, 1]), today: today, current: 6);
      expect(floor.suggested, 5, reason: '6 の 20% は 1。5 が下限');
      final ceil = suggestCapacity(days([90, 90, 90, 90, 90]), today: today, current: 39);
      expect(ceil.suggested, 40);
      final atMax = suggestCapacity(days([90, 90, 90, 90, 90]), today: today, current: 40);
      expect(atMax.action, CapacityAction.keep);
      expect(atMax.suggested, 40);
      final big = suggestCapacity(days([90, 90, 90, 90, 90]), today: today, current: 30);
      expect(big.suggested, 36, reason: '30 の 20% = 6');
    });

    test('applyTo は 1 日の量だけを替える', () {
      const base = PlannerConfig(baseQuantity: 10, carryOverRate: 0.3, dailyCapFactor: 1.5, lastMinuteDays: 5);
      final c = suggestCapacity(days([4, 4, 4, 4, 4]), today: today).applyTo(base);
      expect(c.baseQuantity, 8);
      expect([c.carryOverRate, c.dailyCapFactor, c.lastMinuteDays], [0.3, 1.5, 5]);
      expect(identical(c.ratios, base.ratios), isTrue);
    });

    test('入力が不正ならエラー', () {
      expect(() => suggestCapacity(const [], today: today, windowDays: 0), throwsArgumentError);
      expect(() => suggestCapacity(const [], today: today, minActiveDays: 0), throwsArgumentError);
      expect(() => suggestCapacity(const [], today: today, minBase: 10, maxBase: 5), throwsArgumentError);
    });
  });
}
