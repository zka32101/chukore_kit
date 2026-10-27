import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int m, int day) => DateTime(2026, m, day);
RealTestRecord rec(DateTime when, double score) => RealTestRecord(when, score);

void main() {
  group('parseScoreInput', () {
    test('普通の入力・全角・前後の空白・桁区切りを読む', () {
      expect(parseScoreInput('85', maxScore: 100).value, 85);
      expect(parseScoreInput(' ８５ ', maxScore: 100).value, 85);
      expect(parseScoreInput('72.5', maxScore: 100).value, 72.5);
      expect(parseScoreInput('1,250', maxScore: 1500).value, 1250);
      expect(parseScoreInput('0', maxScore: 100).value, 0);
      expect(parseScoreInput('100', maxScore: 100).value, 100);
    });

    test('小数点がカンマの国: 7,5 は 7.5（満点 10）。ドットは桁区切りとして落とす', () {
      expect(parseScoreInput('7,5', maxScore: 10, decimalSeparator: ',').value, 7.5);
      expect(parseScoreInput('１,２', maxScore: 10, decimalSeparator: ',').value, 1.2);
    });

    test('空・数でない・マイナス・満点超過は理由つきで拒否', () {
      expect(parseScoreInput('', maxScore: 100).error, ScoreInputError.empty);
      expect(parseScoreInput('   ', maxScore: 100).error, ScoreInputError.empty);
      for (final bad in ['abc', 'NaN', 'Infinity', '1e3', '8 5x', '12..5', '--5']) {
        expect(parseScoreInput(bad, maxScore: 100).error, ScoreInputError.notNumber, reason: bad);
      }
      expect(parseScoreInput('-3', maxScore: 100).error, ScoreInputError.negative);
      expect(parseScoreInput('−3', maxScore: 100).error, ScoreInputError.negative, reason: '全角のマイナス記号');
      expect(parseScoreInput('100.5', maxScore: 100).error, ScoreInputError.overMax);
      expect(parseScoreInput('11', maxScore: 10).error, ScoreInputError.overMax);
      expect(parseScoreInput('85', maxScore: 100).isOk, true);
      expect(parseScoreInput('x', maxScore: 100).isOk, false);
    });

    test('maxScore が 0 以下ならエラー', () {
      expect(() => parseScoreInput('5', maxScore: 0), throwsArgumentError);
      expect(() => parseScoreInput('5', maxScore: -1), throwsArgumentError);
    });
  });

  group('decideScorePrompt: テスト後', () {
    final tests = [d(6, 10)];

    test('テスト当日は聞かない。翌日から14日以内だけ聞く（15日目は聞かない）', () {
      expect(
        decideScorePrompt(today: d(6, 10), testDates: tests, records: const [], baseline: rec(d(1, 1), 50)),
        isNull,
      );
      final next = decideScorePrompt(today: d(6, 11), testDates: tests, records: const [], baseline: rec(d(1, 1), 50));
      expect(next?.kind, ScorePromptKind.afterTest);
      expect(next?.testDate, dateOnly(d(6, 10)));
      expect(
        decideScorePrompt(today: d(6, 24), testDates: tests, records: const [], baseline: rec(d(1, 1), 50)),
        isNotNull,
      );
      expect(
        decideScorePrompt(today: d(6, 25), testDates: tests, records: const [], baseline: rec(d(1, 1), 50)),
        isNull,
      );
    });

    test('テストの前日までは聞かない', () {
      expect(
        decideScorePrompt(today: d(6, 9), testDates: tests, records: const [], baseline: rec(d(1, 1), 50)),
        isNull,
      );
    });

    test('そのテストの前後3日以内に記録があれば聞かない（4日離れていれば聞く）', () {
      final p = rec(d(1, 1), 50);
      expect(decideScorePrompt(today: d(6, 12), testDates: tests, records: [rec(d(6, 13), 80)], baseline: p), isNull);
      expect(decideScorePrompt(today: d(6, 12), testDates: tests, records: [rec(d(6, 7), 80)], baseline: p), isNull);
      expect(
        decideScorePrompt(today: d(6, 16), testDates: tests, records: [rec(d(6, 14), 80)], baseline: p)?.kind,
        ScorePromptKind.afterTest,
      );
    });

    test('聞いたテストは二度と聞かない（入れても入れなくても）。次のテストは聞く', () {
      final p = rec(d(1, 1), 50);
      final first = decideScorePrompt(today: d(6, 11), testDates: tests, records: const [], baseline: p)!;
      final state = const ScorePromptState().markPrompted(first, d(6, 11));
      expect(
        decideScorePrompt(today: d(6, 12), testDates: tests, records: const [], state: state, baseline: p),
        isNull,
      );
      final two = [d(6, 10), d(6, 12)];
      final second = decideScorePrompt(today: d(6, 14), testDates: two, records: const [], state: state, baseline: p);
      expect(second?.testDate, dateOnly(d(6, 12)));
    });

    test('複数のテストが候補なら新しいほうを聞く', () {
      final p = decideScorePrompt(
        today: d(6, 20),
        testDates: [d(6, 8), d(6, 15)],
        records: const [],
        baseline: rec(d(1, 1), 50),
      );
      expect(p?.testDate, dateOnly(d(6, 15)));
    });

    test('1日に1回まで', () {
      final state = ScorePromptState(lastPromptedOn: d(6, 11));
      expect(
        decideScorePrompt(
          today: d(6, 11),
          testDates: tests,
          records: const [],
          state: state,
          baseline: rec(d(1, 1), 50),
        ),
        isNull,
      );
      expect(
        decideScorePrompt(
          today: d(6, 12),
          testDates: tests,
          records: const [],
          state: state,
          baseline: rec(d(1, 1), 50),
        ),
        isNotNull,
      );
    });
  });

  group('decideScorePrompt: 使う前の点', () {
    test('記録も使う前の点も無く、一度も聞いていなければ聞く。聞いたら二度と聞かない', () {
      final p = decideScorePrompt(today: d(5, 1), testDates: const [], records: const []);
      expect(p?.kind, ScorePromptKind.baseline);
      final state = const ScorePromptState().markPrompted(p!, d(5, 1));
      expect(state.baselineAsked, true);
      expect(decideScorePrompt(today: d(5, 2), testDates: const [], records: const [], state: state), isNull);
    });

    test('使う前の点がある・本番の記録がすでにある場合は聞かない', () {
      expect(
        decideScorePrompt(today: d(5, 1), testDates: const [], records: const [], baseline: rec(d(1, 1), 50)),
        isNull,
      );
      expect(decideScorePrompt(today: d(5, 1), testDates: const [], records: [rec(d(4, 1), 60)]), isNull);
    });

    test('テスト後の質問が先（同じ日に両方は聞かない）', () {
      final p = decideScorePrompt(today: d(6, 11), testDates: [d(6, 10)], records: const []);
      expect(p?.kind, ScorePromptKind.afterTest);
    });
  });

  test('markPrompted は元の状態を変えない。日付は日のみで持つ', () {
    const s0 = ScorePromptState();
    final s1 = s0.markPrompted(
      ScorePrompt(ScorePromptKind.afterTest, DateTime(2026, 6, 10, 15)),
      DateTime(2026, 6, 11, 9),
    );
    expect(s0.askedTests, isEmpty);
    expect(s1.askedTests, {dateOnly(DateTime(2026, 6, 10))});
    expect(s1.lastPromptedOn, dateOnly(DateTime(2026, 6, 11)));
  });

  test('windowDays・matchDays の不正はエラー', () {
    expect(
      () => decideScorePrompt(today: d(6, 1), testDates: const [], records: const [], windowDays: 0),
      throwsArgumentError,
    );
    expect(
      () => decideScorePrompt(today: d(6, 1), testDates: const [], records: const [], matchDays: -1),
      throwsArgumentError,
    );
  });
}
