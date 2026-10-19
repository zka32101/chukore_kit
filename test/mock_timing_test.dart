import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final at = DateTime(2026, 10, 18, 10);

Question q(String id, String unit) => Question(
      id: id,
      unitId: unit,
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
    );

/// 10 問（u1: q0〜q4、u2: q5〜q9）。制限時間 [limit] 分（null = なし）。
MockExam exam({int? limit = 20}) => MockExam(
      questions: [for (var i = 0; i < 10; i++) q('q$i', i < 5 ? 'u1' : 'u2')],
      requestedCount: 10,
      timeLimit: limit == null ? null : Duration(minutes: limit),
    );

/// [ms]（問題番号 → 所要ミリ秒）で採点。[wrong] の問題は間違い、[skip] は未回答。
MockTiming run(
  Map<int, int> ms, {
  int elapsedMin = 15,
  Set<int> wrong = const {},
  Set<int> skip = const {},
  int? limit = 20,
  MockTimingConfig config = const MockTimingConfig(),
}) {
  final e = exam(limit: limit);
  final answers = {
    for (var i = 0; i < 10; i++)
      if (!skip.contains(i)) 'q$i': wrong.contains(i) ? 'b' : 'a',
  };
  final r = scoreMockExam(e, answers, answeredAt: at, elapsed: Duration(minutes: elapsedMin), perQuestionMs: {for (final x in ms.entries) 'q${x.key}': x.value});
  return analyzeMockTiming(e, r, config: config);
}

Map<int, int> even(int ms) => {for (var i = 0; i < 10; i++) i: ms};

void main() {
  group('傾向', () {
    test('時間切れ・未回答があれば ranOutOfTime（制限時間があるとき）', () {
      expect(run(even(100000), elapsedMin: 21).pattern, TimingPattern.ranOutOfTime);
      expect(run(even(100000), elapsedMin: 21).spareMs, 0, reason: '超えたときの余りは 0（負にしない）');
      expect(run(even(100000), elapsedMin: 10, skip: {9}).pattern, TimingPattern.ranOutOfTime);
      expect(run(even(100000), elapsedMin: 21, limit: null).pattern, isNot(TimingPattern.ranOutOfTime), reason: '制限時間が無ければ時間切れは無い');
    });

    test('制限時間の 20% 以上を残して終えたら spareTime。境目は含める', () {
      final s = run(even(60000), elapsedMin: 10);
      expect(s.pattern, TimingPattern.spareTime);
      expect(s.spareMs, 10 * 60000);
      expect(run(even(60000), elapsedMin: 16).pattern, TimingPattern.spareTime, reason: '残り 4 分 = ちょうど 20%');
      expect(run(even(60000), elapsedMin: 17).pattern, TimingPattern.balanced);
    });

    test('時間をかけたのに間違えた問題があれば slowOnFew。正解なら balanced', () {
      final ms = {...even(100000), 3: 300000};
      final bad = run(ms, elapsedMin: 18, wrong: {3});
      expect(bad.pattern, TimingPattern.slowOnFew);
      expect(bad.skipCandidates.map((s) => s.questionId), ['q3']);
      final good = run(ms, elapsedMin: 18);
      expect(good.pattern, TimingPattern.balanced);
      expect(good.slowQuestions.map((s) => s.questionId), ['q3']);
      expect(good.skipCandidates, isEmpty);
    });

    test('所要時間の記録が minTimed 件に満たなければ unknown（時間切れだけは分かる）', () {
      expect(run({0: 1000, 1: 1000, 2: 1000, 3: 1000}, elapsedMin: 10).pattern, TimingPattern.unknown);
      expect(run({0: 1000, 1: 1000, 2: 1000, 3: 1000, 4: 1000}, elapsedMin: 18).pattern, isNot(TimingPattern.unknown));
      expect(run(const {}, elapsedMin: 21).pattern, TimingPattern.ranOutOfTime);
      expect(run({0: 1000, 1: 1000}, limit: null).pattern, TimingPattern.unknown);
    });
  });

  group('かけすぎた問題', () {
    test('目安（制限時間 ÷ 問題数 = 120 秒）の 2 倍を超えたものだけ。ちょうど 2 倍は含めない', () {
      final s = run({...even(100000), 0: 240000, 1: 240001, 2: 500000}, elapsedMin: 18);
      expect(s.fairShareMs, 120000);
      expect(s.slowQuestions.map((x) => x.questionId), ['q2', 'q1'], reason: 'かかった時間の長い順。q0 はちょうど 2 倍で含めない');
      expect(s.slowQuestions.first.multiple, closeTo(500000 / 120000, 1e-9));
    });

    test('同じ時間なら問題ID順。skipCandidates は間違えたものだけ', () {
      final s = run({...even(100000), 4: 300000, 2: 300000, 8: 300000}, elapsedMin: 18, wrong: {4, 8});
      expect(s.slowQuestions.map((x) => x.questionId), ['q2', 'q4', 'q8']);
      expect(s.skipCandidates.map((x) => x.questionId), ['q4', 'q8']);
    });

    test('制限時間が無いときの目安は、所要時間の中央値', () {
      final s = run({0: 10000, 1: 20000, 2: 30000, 3: 40000, 4: 50000, 5: 200000}, limit: null);
      expect(s.fairShareMs, 35000, reason: '中央値（30000 と 40000 の平均）');
      expect(s.slowQuestions.map((x) => x.questionId), ['q5']);
      expect(run({0: 1000, 1: 2000, 2: 3000, 3: 4000, 4: 5000}, limit: null).fairShareMs, 3000, reason: '奇数件の中央値');
    });

    test('かけすぎた問題が全体の所要時間に占める割合', () {
      final s = run({...even(100000), 3: 400000}, elapsedMin: 18);
      expect(s.slowShare, closeTo(400000 / (9 * 100000 + 400000), 1e-9));
    });
  });

  group('単元ごと', () {
    test('1 問あたりが長い単元が先。正答率つき', () {
      final ms = {for (var i = 0; i < 10; i++) i: i < 5 ? 50000 : 90000};
      final s = run(ms, elapsedMin: 18, wrong: {5, 6});
      expect(s.units.map((u) => u.unitId), ['u2', 'u1']);
      expect(s.units.first.avgMs, 90000);
      expect(s.units.first.correctRate, closeTo(3 / 5, 1e-9));
      expect(s.units.last.totalMs, 250000);
      expect(s.units.last.questions, 5);
    });

    test('同じ平均なら単元ID順。記録の無い問題は数えない', () {
      final s = run({0: 60000, 1: 60000, 5: 60000, 6: 60000, 7: 60000, 8: 0}, elapsedMin: 18);
      expect(s.units.map((u) => u.unitId), ['u1', 'u2']);
      expect(s.units.last.questions, 3);
    });
  });
}
