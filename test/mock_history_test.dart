import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question _q(String id, String unit, {double p = .5}) => Question(
      id: id, unitId: unit, type: 'choice', difficulty: p,
      choices: const ['x', 'y'], answer: 'x', explanationId: 'e',
    );

/// 単元 a・b に各 [perUnit] 問。a は [aRight] 問、b は [bRight] 問正解。
MockExamResult _result(int aRight, int bRight, {int perUnit = 5, Duration elapsed = const Duration(minutes: 10), Duration? limit}) {
  final qs = [for (var i = 0; i < perUnit; i++) _q('a$i', 'a'), for (var i = 0; i < perUnit; i++) _q('b$i', 'b')];
  final answers = <String, String>{
    for (var i = 0; i < perUnit; i++) 'a$i': i < aRight ? 'x' : 'y',
    for (var i = 0; i < perUnit; i++) 'b$i': i < bRight ? 'x' : 'y',
  };
  return scoreMockExam(
    MockExam(questions: qs, requestedCount: qs.length, timeLimit: limit),
    answers,
    answeredAt: DateTime(2026, 10, 1),
    elapsed: elapsed,
  );
}

MockHistoryEntry _e(int day, MockExamResult r) => MockHistoryEntry(DateTime(2026, 10, day), r);

void main() {
  test('日付順に並べ、前回との差・自己ベストを出す', () {
    final c = compareMockExams([
      _e(20, _result(5, 4)), // 90 点
      _e(1, _result(2, 2)), // 40 点（入力が前後しても日付順）
      _e(10, _result(3, 3)), // 60 点
    ]);
    expect(c.steps.map((s) => s.score), [40, 60, 90]);
    expect(c.steps.map((s) => s.scoreDelta), [null, 20, 30]);
    expect(c.steps.map((s) => s.isPersonalBest), [false, true, true]);
    expect(c.bestScore, 90);
    expect(c.steps[1].deviationDelta, closeTo(c.steps[1].deviation - c.steps[0].deviation, 1e-9));
    expect(c.steps[2].deviation, greaterThan(c.steps[0].deviation));
  });

  test('得点の傾き（最小二乗法）', () {
    // 40, 60, 90 → 傾き (90-40)/2 = 25
    final up = compareMockExams([_e(1, _result(2, 2)), _e(10, _result(3, 3)), _e(20, _result(5, 4))]);
    expect(up.slopePerExam, closeTo(25, 1e-9));
    final flat = compareMockExams([_e(1, _result(3, 3)), _e(2, _result(3, 3)), _e(3, _result(3, 3))]);
    expect(flat.slopePerExam, closeTo(0, 1e-9));
    final down = compareMockExams([_e(1, _result(5, 5)), _e(2, _result(3, 3))]);
    expect(down.slopePerExam, closeTo(-40, 1e-9));
    expect(compareMockExams([_e(1, _result(3, 3))]).slopePerExam, 0);
  });

  test('単元別の変化: 伸びた順。最も伸びた・最も下がった単元', () {
    final c = compareMockExams([
      _e(1, _result(2, 4)), // a 40%・b 80%
      _e(10, _result(5, 2)), // a 100%・b 40%
    ]);
    expect(c.sincePrevious.map((u) => u.unitId), ['a', 'b']);
    expect(c.sincePrevious.first.unitId, 'a');
    expect(c.sincePrevious.first.delta, closeTo(0.6, 1e-9));
    expect(c.sincePrevious.last.unitId, 'b');
    expect(c.sincePrevious.last.delta, closeTo(-0.4, 1e-9));
    expect(c.mostImproved!.unitId, 'a');
    expect(c.mostDeclined!.unitId, 'b');
  });

  test('前回と最初の回を分けて比べる', () {
    final c = compareMockExams([
      _e(1, _result(1, 1)), // 20%
      _e(10, _result(4, 4)), // 80%
      _e(20, _result(5, 4)), // a 100%・b 80%
    ]);
    expect(c.sincePrevious.firstWhere((u) => u.unitId == 'a').delta, closeTo(0.2, 1e-9));
    expect(c.sinceFirst.firstWhere((u) => u.unitId == 'a').delta, closeTo(0.8, 1e-9));
    expect(c.sinceFirst.firstWhere((u) => u.unitId == 'b').delta, closeTo(0.6, 1e-9));
  });

  test('問題が少ない単元はぶれが大きいので比べない（minQuestions）。伸びも下がりもなければ null', () {
    final c = compareMockExams([_e(1, _result(0, 1, perUnit: 1)), _e(2, _result(1, 0, perUnit: 1))]);
    expect(c.sincePrevious, isEmpty);
    final c1 = compareMockExams([_e(1, _result(0, 1, perUnit: 1)), _e(2, _result(1, 0, perUnit: 1))], minQuestions: 1);
    expect(c1.sincePrevious.length, 2);
    final same = compareMockExams([_e(1, _result(3, 3)), _e(2, _result(3, 3))]);
    expect(same.mostImproved, isNull);
    expect(same.mostDeclined, isNull);
  });

  test('時間のかけ方: 1問あたりの秒・未回答・時間切れ', () {
    final c = compareMockExams([
      _e(1, _result(3, 3, elapsed: const Duration(minutes: 10), limit: const Duration(minutes: 20))),
      _e(2, _result(3, 3, elapsed: const Duration(minutes: 25), limit: const Duration(minutes: 20))),
    ]);
    expect(c.steps[0].secondsPerQuestion, closeTo(60, 1e-9)); // 600 秒 / 10 問
    expect(c.steps[0].timedOut, isFalse);
    expect(c.steps[1].secondsPerQuestion, closeTo(150, 1e-9));
    expect(c.steps[1].timedOut, isTrue);
    expect(c.steps[1].unanswered, 0);
  });

  test('履歴が 0 件・1 件', () {
    final none = compareMockExams(const []);
    expect(none.steps, isEmpty);
    expect(none.bestScore, 0);
    final one = compareMockExams([_e(1, _result(3, 3))]);
    expect(one.steps.single.scoreDelta, isNull);
    expect(one.sincePrevious, isEmpty);
    expect(one.sinceFirst, isEmpty);
  });
}
