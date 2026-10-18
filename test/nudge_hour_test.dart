import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-20 は火曜日
final now = DateTime(2026, 10, 20, 12);

Attempt at(int daysAgo, int hour, {int minute = 0, String q = 'q'}) => Attempt(
      questionId: q,
      unitId: 'u',
      correct: true,
      answeredAt: DateTime(2026, 10, 20 - daysAgo, hour, minute),
    );

/// 毎日 [hour] 時に、[perDay] 問解いた履歴（[days] 日分、昨日から）。
List<Attempt> daily(int hour, {int days = 10, int perDay = 1}) => [
      for (var d = 1; d <= days; d++)
        for (var i = 0; i < perDay; i++) at(d, hour, minute: i),
    ];

NudgeHour? suggest(Iterable<Attempt> a, {DateTime? forDate, int minDays = 5}) =>
    suggestNudgeHour(a, now: now, forDate: forDate, minDays: minDays);

void main() {
  test('いつも同じ時間帯に学習していれば、その時を提案する', () {
    final r = suggest(daily(17))!;
    expect((r.hour, r.share, r.days, r.clamped), (17, 1.0, 10, false));
  });

  test('1 日の問題数に偏らない（1 日に何問解いても 1 日）', () {
    // 夕方は毎日 1 問、深夜は 3 日だけ 40 問
    final a = [
      ...daily(17, days: 8),
      for (var d = 1; d <= 3; d++)
        for (var i = 0; i < 40; i++) at(d, 12, minute: i % 60, q: 'x$i'),
    ];
    expect(suggest(a)!.hour, 17, reason: '問題数ではなく学習した日の数で数える');
  });

  test('時間帯のゆれ（前後 1 時間）はならして、よく学習する時間に寄る', () {
    final a = [
      for (var d = 1; d <= 9; d++) at(d, d.isEven ? 17 : 18),
      at(10, 17),
    ];
    final r = suggest(a)!;
    expect([17, 18], contains(r.hour));
    expect(r.share, 1.0);
  });

  test('1 つの時刻だけ多くても、隣り合う時刻に学習が集まっていればそちらを選ぶ', () {
    // 10 時は 4 日（単独）、17 時と 18 時は各 3 日（隣り合う）
    final a = [
      for (var d = 1; d <= 4; d++) at(d, 10),
      for (var d = 5; d <= 7; d++) at(d, 17),
      for (var d = 8; d <= 10; d++) at(d, 18),
    ];
    expect([17, 18], contains(suggest(a)!.hour));
  });

  test('学習日が少なければ null（提案しない）', () {
    expect(suggest(daily(17, days: 4)), isNull);
    expect(suggest(daily(17, days: 5)), isNotNull);
    expect(suggest(daily(17, days: 4), minDays: 4), isNotNull);
    expect(suggest(const []), isNull);
  });

  test('偏りが無ければ null（時間帯がばらばら）', () {
    final a = [for (var d = 1; d <= 12; d++) at(d, (d * 5) % 24)];
    expect(suggest(a), isNull);
  });

  test('夜遅く・早朝は通知に向かないので、許す範囲に寄せる（clamped）', () {
    final late = suggest(daily(23))!;
    expect((late.hour, late.clamped), (20, true));
    final early = suggest(daily(5))!;
    expect((early.hour, early.clamped), (7, true));
    final edge = suggest(daily(20))!;
    expect((edge.hour, edge.clamped), (20, false));
    expect(suggestNudgeHour(daily(23), now: now, latestHour: 22)!.hour, 22);
  });

  test('直近 28 日だけを見る（それより前の習慣は無視）', () {
    final a = [
      for (var d = 30; d <= 50; d++) at(d, 9), // 古い習慣（朝）
      ...daily(19, days: 6),
    ];
    expect(suggest(a)!.hour, 19);
    expect(suggest(a)!.days, 6);
  });

  test('今日の記録も数える。未来の記録は数えない', () {
    final a = [...daily(17, days: 4), at(0, 17), at(-1, 8), at(-2, 8)];
    final r = suggest(a)!;
    expect(r.days, 5);
    expect(r.hour, 17);
  });

  group('平日と土日', () {
    // 平日は夕方 17 時、土日は朝 9 時に学習する子（直近 4 週間）
    final a = <Attempt>[];
    for (var d = 1; d <= 28; d++) {
      final date = DateTime(2026, 10, 20 - d);
      final weekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      a.add(at(d, weekend ? 9 : 17));
    }
    test('平日の日を指定すると平日の時間帯、土日を指定すると土日の時間帯', () {
      expect(suggest(a, forDate: DateTime(2026, 10, 21))!.hour, 17, reason: '水曜');
      expect(suggest(a, forDate: DateTime(2026, 10, 24))!.hour, 9, reason: '土曜');
    });
    test('指定しなければ全体（平日が多いので夕方）', () {
      expect(suggest(a)!.hour, 17);
    });
    test('同じ種類の学習日が少なければ、全体で求める', () {
      final onlyWeekdays = [for (final x in a) if (DateTime(x.answeredAt.year, x.answeredAt.month, x.answeredAt.day).weekday <= 5) x];
      expect(suggest(onlyWeekdays, forDate: DateTime(2026, 10, 24))!.hour, 17);
    });
  });

  test('同じ入力なら同じ結果。入力の順は関係ない', () {
    final a = daily(18, days: 7);
    final r1 = suggest(a)!, r2 = suggest(a.reversed)!;
    expect((r1.hour, r1.share, r1.days), (r2.hour, r2.share, r2.days));
  });

  test('既定の時刻は夕方', () => expect(defaultNudgeHour, 18));
}
