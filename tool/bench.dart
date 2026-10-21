// 大量の回答履歴での処理時間を測る。使い方: `dart run tool/bench.dart [回答の件数=100000]`
// 長く使った子の端末で固まらないかの確認用（絶対値は環境で変わる。遅い関数が無いかを見る）。
// 目安: どの関数も 1 秒未満（JIT 実行の目安。アプリの実機はもう少し速い）。超えたら終了コード 1。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';

const limitMs = 1000;

void main(List<String> args) async {
  final n = args.isNotEmpty ? int.parse(args.first) : 100000;
  final data = BenchData.generate(n);
  stdout.writeln('回答 ${data.attempts.length} 件 / 問題 ${data.questions.length} 問 / 単元 ${data.units} 個');
  final today = data.today;
  var slow = 0;
  void bench(String name, Object? Function() f) {
    final sw = Stopwatch()..start();
    f();
    sw.stop();
    final ms = sw.elapsedMilliseconds;
    final mark = ms >= limitMs ? ' ← 遅い' : '';
    if (ms >= limitMs) slow++;
    stdout.writeln('${ms.toString().padLeft(6)} ms  $name$mark');
  }

  final a = data.attempts, qs = data.questions;
  final byId = {for (final q in qs) q.id: q};
  bench('computeMastery', () => computeMastery(a, today));
  bench('buildReviewStates + dueForReview', () => dueForReview(buildReviewStates(a), today));
  bench('buildWeakNotes', () => buildWeakNotes(a, byId));
  bench('buildRetrySets', () => buildRetrySets(attempts: a, questions: qs));
  bench('classifyMistakes', () => classifyMistakes(a));
  bench('summarizeMistakeReasons', () => summarizeMistakeReasons(a));
  bench('calibrateDifficulty', () => calibrateDifficulty(a, qs));
  bench('analyzeDistractors', () => analyzeDistractors(a, qs));
  bench('tuneReviewIntervals', () => tuneReviewIntervals(a));
  bench('suggestCapacity', () => suggestCapacity(a, today: today));
  bench('suggestBreak', () => suggestBreak(a, now: today));
  bench('buildQualityReport', () => buildQualityReport(a, qs));
  bench('buildTodayCard', () => buildTodayCard(now: today, attempts: a, plan: data.plan));
  bench('pickPractice', () {
    final m = computeMastery(a, today);
    return pickPractice(plan: data.plan.first, questions: qs, mastery: m, attempts: a, today: today);
  });
  bench('buildWeeklyReport', () => buildWeeklyReport(a, data.tree, today.subtract(const Duration(days: 6)), questions: byId));
  bench('AttemptBackup.export', () => AttemptBackup.export(a));
  final json = AttemptBackup.export(a);
  bench('AttemptBackup.parse', () => AttemptBackup.parse(json));
  final db = sqlite3.openInMemory();
  final store = SqliteAttemptStore(db);
  final sw = Stopwatch()..start();
  db.execute('BEGIN');
  for (final x in a) {
    await store.add(x);
  }
  db.execute('COMMIT');
  stdout.writeln('${sw.elapsedMilliseconds.toString().padLeft(6)} ms  SqliteAttemptStore.add × ${a.length}（1 つの取引）');
  final sw2 = Stopwatch()..start();
  final back = await store.query();
  stdout.writeln('${sw2.elapsedMilliseconds.toString().padLeft(6)} ms  SqliteAttemptStore.query（全件 ${back.length}）');
  final sw3 = Stopwatch()..start();
  await store.query(from: today.subtract(const Duration(days: 7)), unitId: 'u1');
  stdout.writeln('${sw3.elapsedMilliseconds.toString().padLeft(6)} ms  SqliteAttemptStore.query（直近 7 日・1 単元）');
  if (slow > 0) {
    stdout.writeln('遅い関数が $slow 個あります（目安 $limitMs ms 未満）');
    exit(1);
  }
}

/// 長く使った子の履歴を模した、決まった（乱数に依存しない）データ。
class BenchData {
  BenchData._(this.attempts, this.questions, this.units, this.today, this.plan, this.tree);

  final List<Attempt> attempts;
  final List<Question> questions;
  final int units;
  final DateTime today;
  final List<DayPlan> plan;
  final UnitTree tree;

  static BenchData generate(int n) {
    const unitCount = 30, perUnit = 20;
    final today = DateTime(2026, 10, 20, 18);
    final questions = [
      for (var u = 0; u < unitCount; u++)
        for (var i = 0; i < perUnit; i++)
          Question(
            id: 'u${u}_q$i',
            unitId: 'u$u',
            type: 'choice',
            difficulty: 0.3 + 0.5 * ((u * 7 + i * 3) % 10) / 10,
            choices: const ['a', 'b', 'c', 'd'],
            answer: 'a',
            explanationId: 'e',
            misconceptionTags: {'b': 't${u}_b', 'c': 't${u}_c'},
          ),
    ];
    var seed = 12345;
    int next(int m) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % m;
    }

    final attempts = <Attempt>[];
    for (var i = 0; i < n; i++) {
      final q = questions[next(questions.length)];
      final day = next(365);
      final correct = next(100) < 70;
      attempts.add(Attempt(
        questionId: q.id,
        unitId: q.unitId,
        correct: correct,
        chosenId: correct ? 'a' : ['b', 'c', 'd'][next(3)],
        answeredAt: today.subtract(Duration(days: day, minutes: next(600))),
        elapsedMs: 3000 + next(15000),
        mode: next(20) == 0 ? 'mock' : 'practice',
        confident: next(3) == 0 ? next(2) == 0 : null,
        hintsUsed: next(10) == 0 ? 1 : 0,
      ));
    }
    final tree = UnitTree(1, [
      for (var u = 0; u < unitCount; u++)
        Unit(id: 'u$u', subject: 'en', grade: 1, title: 'u$u', order: u, estimatedQuestions: perUnit),
    ]);
    final planResult = buildPlan(
      today: today,
      plan: TestPlan(id: 't', subject: 'en', testDate: today.add(const Duration(days: 30)), unitIds: [for (var u = 0; u < unitCount; u++) 'u$u']),
      tree: tree,
    );
    return BenchData._(attempts, questions, unitCount, today, planResult.days, tree);
  }
}
