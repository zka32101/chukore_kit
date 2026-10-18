import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 20, 17, 0);

/// 「いま」の [minutesAgo] 分前に答えた回答。
Attempt at(double minutesAgo, {bool ok = true, int ms = 15000, String mode = 'practice', String q = 'q'}) => Attempt(
      questionId: q,
      unitId: 'u1',
      correct: ok,
      answeredAt: now.subtract(Duration(milliseconds: (minutesAgo * 60000).round())),
      elapsedMs: ms,
      mode: mode,
    );

/// [count] 問を [everyMin] 分おきに（最後の 1 問が [lastAgo] 分前）。
List<Attempt> run(int count, {double everyMin = 1, double lastAgo = 0.5, bool Function(int i)? ok, int Function(int i)? ms}) => [
      for (var i = 0; i < count; i++)
        at(lastAgo + (count - 1 - i) * everyMin, ok: ok?.call(i) ?? true, ms: ms?.call(i) ?? 15000),
    ];

BreakSuggestion? suggest(Iterable<Attempt> a, {DateTime? last, BreakConfig config = const BreakConfig()}) =>
    suggestBreak(a, now: now, lastSuggestedAt: last, config: config);

void main() {
  group('勧めない', () {
    test('履歴が無い・短い学習・順調なら null', () {
      expect(suggest(const []), isNull);
      expect(suggest(run(5)), isNull);
      expect(suggest(run(12)), isNull);
    });

    test('最後の回答から 30 分以上たっていれば、すでに休んでいる', () {
      expect(suggest(run(20, lastAgo: 29)), isNotNull, reason: '29 分前はまだ続いている（長く続けている）');
      expect(suggest(run(20, lastAgo: 30)), isNull);
      expect(suggest(run(4, ok: (_) => false, lastAgo: 31)), isNull);
    });

    test('前に提案してから 15 分以内は、繰り返し提案しない', () {
      final a = run(16, everyMin: 3, lastAgo: 1); // 約 46 分続けている
      expect(suggest(a), isNotNull);
      expect(suggest(a, last: now.subtract(const Duration(minutes: 10))), isNull);
      expect(suggest(a, last: now.subtract(const Duration(minutes: 15))), isNotNull);
      expect(suggest(a, last: now.subtract(const Duration(hours: 3))), isNotNull);
    });

    test('模試・本番の記録は見ない（途中で止めない）。未来の記録も見ない', () {
      final mockMisses = [for (var i = 0; i < 4; i++) at(i.toDouble(), ok: false, mode: 'mock')];
      expect(suggest(mockMisses), isNull, reason: '練習なら続けて間違えたで勧める形でも、模試の記録は見ない');
      expect(suggest([...mockMisses, at(9)]), isNull);
      final future = [at(-5, ok: false), at(-4, ok: false), at(-3, ok: false), at(-2, ok: false)];
      expect(suggest(future), isNull);
      const cfg = BreakConfig(modes: {'practice', 'mock'});
      expect(suggest([for (var i = 0; i < 4; i++) at(i.toDouble(), ok: false, mode: 'mock')], config: cfg)?.reason, BreakReason.mistakeStreak);
    });
  });

  group('続けて間違えた', () {
    test('直近 4 問がすべて誤答なら mistakeStreak。3 問なら勧めない', () {
      final four = [at(5), at(4, ok: false), at(3, ok: false), at(2, ok: false), at(1, ok: false)];
      expect(suggest(four)!.reason, BreakReason.mistakeStreak);
      final three = [at(5), at(4), at(3, ok: false), at(2, ok: false), at(1, ok: false)];
      expect(suggest(three), isNull);
    });

    test('間に正解が入れば連続ではない', () {
      expect(suggest([at(5, ok: false), at(4, ok: false), at(3), at(2, ok: false), at(1, ok: false)]), isNull);
    });

    test('前の学習（30 分以上あいた）の誤答は数えない', () {
      final a = [at(120, ok: false), at(119, ok: false), at(118, ok: false), at(2, ok: false), at(1, ok: false)];
      expect(suggest(a), isNull);
    });
  });

  group('あてずっぽう', () {
    test('直近 5 問がすべて 2 秒未満の誤答なら rushing（続けて間違えたより優先）', () {
      final a = [for (var i = 0; i < 5; i++) at(5.0 - i, ok: false, ms: 1500)];
      expect(suggest(a)!.reason, BreakReason.rushing);
    });
    test('1 問でも正解か 2 秒以上なら rushing ではない（続けて間違えた、にはなる）', () {
      final slow = [for (var i = 0; i < 5; i++) at(5.0 - i, ok: false, ms: i == 2 ? 2000 : 1500)];
      expect(suggest(slow)!.reason, BreakReason.mistakeStreak);
      final right = [for (var i = 0; i < 5; i++) at(5.0 - i, ok: i == 2, ms: 1500)];
      expect(suggest(right), isNull);
    });
    test('所要時間が計れていない（0）回答は、速いとは見なさない', () {
      final a = [for (var i = 0; i < 5; i++) at(5.0 - i, ok: false, ms: 0)];
      expect(suggest(a)!.reason, BreakReason.mistakeStreak);
    });
  });

  group('途中から遅くなった', () {
    // 12 問: 最初の 5 問は 10 秒、最後の 5 問は [lastMs] 秒、間は 12 秒
    List<Attempt> slowing(int lastMs, {int count = 12}) => run(count, ms: (i) => i < 5 ? 10000 : (i >= count - 5 ? lastMs : 12000));

    test('直近 5 問の中央値が最初の 5 問の 2 倍以上なら slowingDown', () {
      expect(suggest(slowing(25000))!.reason, BreakReason.slowingDown);
      expect(suggest(slowing(20000))!.reason, BreakReason.slowingDown, reason: 'ちょうど 2 倍');
      expect(suggest(slowing(19000)), isNull);
    });
    test('回答が 10 問に満たなければ見ない', () {
      expect(suggest(slowing(25000, count: 9)), isNull);
    });
    test('5 分を超える回答（席を離れた）は、遅くなったとは数えない', () {
      final a = run(12, ms: (i) => i < 5 ? 10000 : 6 * 60 * 1000);
      expect(suggest(a), isNull);
    });
  });

  group('長く続けている', () {
    test('休まずに 40 分以上で longSession。それ未満なら勧めない', () {
      final long = run(16, everyMin: 3, lastAgo: 1); // 約 46 分
      final r = suggest(long)!;
      expect(r.reason, BreakReason.longSession);
      expect(r.minutesIntoSession, inInclusiveRange(45, 47));
      expect(r.breakMinutes, 5);
      expect(suggest(run(13, everyMin: 3, lastAgo: 1)), isNull, reason: '約 37 分');
    });
    test('途中で休んで（30 分以上あけて）再開したなら、再開からの時間で見る', () {
      final a = [...run(15, everyMin: 3, lastAgo: 120), ...run(5, everyMin: 1, lastAgo: 0.5)];
      expect(suggest(a), isNull);
    });
    test('最初の回答の所要時間も、始めた時刻にふくめる', () {
      final a = [at(39.5, ms: 60000), ...run(5, everyMin: 5, lastAgo: 0.5).skip(1)]; // 0.5 + 15 = 15.5 分前から、最初は 39.5 分前
      expect(suggest(a)!.minutesIntoSession, 40);
      expect(suggest(a)!.reason, BreakReason.longSession);
    });
  });

  group('理由の優先', () {
    test('あてずっぽう > 続けて間違えた > 遅くなった > 長く続けている', () {
      // 長く続けていて、最後が 4 問の誤答
      final longThenMisses = [...run(14, everyMin: 3, lastAgo: 5), ...run(4, everyMin: 1, lastAgo: 0.5, ok: (_) => false)];
      expect(suggest(longThenMisses)!.reason, BreakReason.mistakeStreak);
      // 長く続けていて、遅くなっている
      final longAndSlow = run(16, everyMin: 3, lastAgo: 1, ms: (i) => i < 5 ? 10000 : (i >= 11 ? 30000 : 12000));
      expect(suggest(longAndSlow)!.reason, BreakReason.slowingDown);
    });
  });

  group('設定と再現性', () {
    test('設定で変えられる', () {
      const cfg = BreakConfig(mistakeStreak: 3, maxSessionMinutes: 10);
      expect(suggest([at(3, ok: false), at(2, ok: false), at(1, ok: false)], config: cfg)!.reason, BreakReason.mistakeStreak);
      expect(suggest(run(6, everyMin: 3, lastAgo: 1), config: cfg)!.reason, BreakReason.longSession);
    });
    test('同じ入力なら同じ結果。履歴の順は関係ない', () {
      final a = run(16, everyMin: 3, lastAgo: 1);
      expect(suggest(a)!.reason, suggest(a.reversed)!.reason);
      expect(suggest(a)!.minutesIntoSession, suggest(a.reversed)!.minutesIntoSession);
    });
  });

  group('文言', () {
    test('全言語で 4 つの文言が空でなく、互いに違い、数字を含まない', () {
      for (final l in ChukoreStrings.supported) {
        final t = [for (final r in BreakReason.values) BreakSuggestion(reason: r, minutesIntoSession: 45, breakMinutes: 5).text(l)];
        expect(t.every((x) => x.trim().isNotEmpty), isTrue, reason: l.tag);
        expect(t.toSet().length, 4, reason: l.tag);
        for (final x in t) {
          expect(RegExp(r'[0-9０-９٠-٩०-९๐-๙]').hasMatch(x), isFalse, reason: '${l.tag}: $x');
        }
      }
    });
    test('理由に対応する文言を返す', () {
      const en = EnStrings();
      BreakSuggestion s(BreakReason r) => BreakSuggestion(reason: r, minutesIntoSession: 1, breakMinutes: 5);
      expect(s(BreakReason.rushing).text(en), en.breakRushing);
      expect(s(BreakReason.mistakeStreak).text(en), en.breakMistakes);
      expect(s(BreakReason.slowingDown).text(en), en.breakSlowing);
      expect(s(BreakReason.longSession).text(en), en.breakLong);
    });
  });
}
