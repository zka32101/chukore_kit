import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

/// 今日から順に、問題数 [totals] の計画（先頭が今日）。
List<DayPlan> days(List<int> totals, {Set<int> last = const {}}) => [
      for (var i = 0; i < totals.length; i++)
        DayPlan(
          date: today.add(Duration(days: i)),
          daysLeft: totals.length - 1 - i,
          total: totals[i],
          focus: totals[i],
          weak: 0,
          review: 0,
          focusByUnit: const {},
          lastMinute: last.contains(i),
        ),
    ];

void main() {
  test('近い日の山場を、日数つきで返す。中央値のおよそ 1.5 倍かつ 5 問以上多い日', () {
    final p = findPeakAhead(days([10, 10, 10, 20, 10, 10, 10]), today: today)!;
    expect(p.daysAhead, 3);
    expect(p.total, 20);
    expect(p.typical, 10);
    expect(p.date, today.add(const Duration(days: 3)));
  });

  test('今日は予告しない。lookahead より先も予告しない', () {
    expect(findPeakAhead(days([30, 10, 10, 10, 10]), today: today), isNull, reason: '今日の山場は予告ではない');
    expect(findPeakAhead(days([10, 10, 10, 10, 10, 10, 30, 10]), today: today), isNull);
    expect(findPeakAhead(days([10, 10, 10, 10, 10, 10, 30, 10]), today: today, lookahead: 6)!.daysAhead, 6);
  });

  test('倍率・差の両方が要る（少ない問題数の日の小さな差は山場ではない）', () {
    expect(findPeakAhead(days([2, 2, 2, 4, 2]), today: today), isNull, reason: '2倍でも差が 2 問');
    expect(findPeakAhead(days([20, 20, 20, 28, 20]), today: today), isNull, reason: '差は 8 問でも 1.4 倍');
    expect(findPeakAhead(days([20, 20, 20, 30, 20]), today: today)!.total, 30, reason: 'ちょうど 1.5 倍');
    expect(findPeakAhead(days([10, 10, 10, 15, 10]), today: today)!.total, 15, reason: 'ちょうど 5 問差');
  });

  test('最初の山場を返す。追い込み（lastMinute）の日は予告しない・基準にも入れない', () {
    expect(findPeakAhead(days([10, 10, 25, 10, 30]), today: today)!.daysAhead, 2);
    // 問題の無い日（休み）は基準に入れない。入れると中央値が 0 になり、ふつうの日が山場になる
    expect(findPeakAhead(days([0, 0, 0, 10, 10, 12]), today: today), isNull);
    expect(findPeakAhead(days([10, 10, 10, 40], last: {3}), today: today), isNull);
    // 追い込みの日を基準に入れると中央値が上がって山場が消える
    expect(findPeakAhead(days([10, 10, 20, 50, 50, 50], last: {3, 4, 5}), today: today)!.daysAhead, 2);
  });

  test('偶数件の中央値は平均（丸め）。問題のある日が無ければ null', () {
    expect(findPeakAhead(days([8, 10, 10, 20]), today: today)!.typical, 10);
    expect(findPeakAhead(days([8, 9, 20, 30]), today: today, ratio: 1)!.typical, 15, reason: '14.5 は四捨五入');
    expect(findPeakAhead(days([0, 0, 0]), today: today), isNull);
    expect(findPeakAhead(const [], today: today), isNull);
    expect(() => findPeakAhead(days([1]), today: today, lookahead: 0), throwsArgumentError);
  });

  test('時刻が付いた today でも日付で数える', () {
    expect(findPeakAhead(days([10, 10, 20, 10]), today: DateTime(2026, 10, 1, 23, 59))!.daysAhead, 2);
  });

  test('全言語に予告の文言があり、数字を含まない', () {
    for (final s in ChukoreStrings.supported) {
      final l = s.languageCode;
      expect(s.peakAhead.trim(), isNotEmpty, reason: '$l');
      expect(RegExp(r'[0-9０-９]').hasMatch(s.peakAhead), isFalse, reason: '$l');
    }
  });
}
