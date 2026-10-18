import '../assess/assess.dart';
import '../models/models.dart';
import '../question/answer.dart';
import '../scope/unit_tree.dart';

/// 模試。範囲（単元）と問題数・制限時間を決めて、問題集から出題する。
class MockExam {
  const MockExam({
    required this.questions,
    required this.requestedCount,
    this.timeLimit,
    this.seed = 0,
  });

  /// 出題順に並んだ問題。
  final List<Question> questions;
  final int requestedCount;

  /// 制限時間。null なら時間制限なし。
  final Duration? timeLimit;
  final int seed;

  /// 問題が足りず、希望の数に届かなかった。
  bool get shortfall => questions.length < requestedCount;
}

/// 単元ごとの成績。
class UnitScore {
  const UnitScore(this.unitId, this.total, this.correct);

  final String unitId;
  final int total, correct;

  double get rate => total == 0 ? 0 : correct / total;
}

/// 模試の結果。
class MockExamResult {
  const MockExamResult({
    required this.total,
    required this.correct,
    required this.unanswered,
    required this.timedOut,
    required this.elapsed,
    required this.byUnit,
    required this.deviation,
    required this.attempts,
  });

  final int total, correct;

  /// 未回答（不正解として数える）。
  final int unanswered;
  final bool timedOut;
  final Duration elapsed;

  /// 単元別（単元ID順）。
  final List<UnitScore> byUnit;

  /// アプリ内偏差値（段階1）。全国の偏差値ではない。
  final DeviationEstimate deviation;

  /// 回答履歴に残す分（未回答は含めない）。mode は `mock`。
  final List<Attempt> attempts;

  double get rate => total == 0 ? 0 : correct / total;

  /// 100点満点換算。
  double get score100 => rate * 100;

  /// 正答率の低い単元（[below] 未満）。低い順→単元ID順。弱点ノートや復習の入口に使う。
  List<UnitScore> weakUnits({double below = 0.6}) => [
        for (final u in byUnit)
          if (u.rate < below) u,
      ]..sort((a, b) {
          final c = a.rate.compareTo(b.rate);
          return c != 0 ? c : a.unitId.compareTo(b.unitId);
        });
}

/// 実行環境に依らない文字列ハッシュ（String.hashCode は版・環境で変わるので使わない）。
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return h;
}

/// 乱数に依らない決まった混ぜ方（同じ seed なら同じ順）。
List<T> _shuffled<T>(List<T> xs, int seed) {
  final out = [...xs];
  var s = (seed ^ 0x9E3779B9) & 0x7FFFFFFF;
  int next() {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF;
    return s;
  }

  for (var i = out.length - 1; i > 0; i--) {
    final j = next() % (i + 1);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// 範囲 [unitIds] の葉の単元から [count] 問を選ぶ。単元ごとの本数は estimatedQuestions に比例
/// （最大剰余法）、各単元の中は [seed] で決まる順。[excludeQuestionIds] は出さない。
/// 暗記カード（`card`）は自己採点で点数にできないので、出さない。
/// 問題が足りなければ全部出して [MockExam.shortfall] を true にする。同じ入力なら同じ結果。
MockExam buildMockExam({
  required List<Question> questions,
  required UnitTree tree,
  required Iterable<String> unitIds,
  int count = 20,
  Duration? timeLimit = const Duration(minutes: 30),
  int seed = 0,
  Set<String> excludeQuestionIds = const {},
}) {
  if (count <= 0) throw ArgumentError('count must be positive');
  final leaves = tree.resolveLeaves(unitIds);
  final pools = <String, List<Question>>{};
  for (final u in leaves) {
    final pool = [
      for (final q in questions)
        if (q.unitId == u.id && q.type != 'card' && !excludeQuestionIds.contains(q.id)) q,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (pool.isNotEmpty) pools[u.id] = _shuffled(pool, seed ^ _stableHash(u.id));
  }
  final weight = {
    for (final u in leaves)
      if (pools.containsKey(u.id)) u.id: (u.estimatedQuestions <= 0 ? 1 : u.estimatedQuestions).toDouble(),
  };
  final ids = pools.keys.toList()..sort();
  final capacity = {for (final id in ids) id: pools[id]!.length};
  final available = capacity.values.fold<int>(0, (s, c) => s + c);
  final target = count < available ? count : available;

  // 比例配分 → 上限を超えた分は、余裕のある単元へ重みの大きい順に回す
  final take = {for (final id in ids) id: 0};
  var remaining = target;
  while (remaining > 0) {
    final open = [for (final id in ids) if (take[id]! < capacity[id]!) id];
    final sum = open.fold<double>(0, (s, id) => s + weight[id]!);
    final exact = {for (final id in open) id: remaining * weight[id]! / sum};
    var given = 0;
    for (final id in open) {
      final n = exact[id]!.floor();
      final add = n < capacity[id]! - take[id]! ? n : capacity[id]! - take[id]!;
      take[id] = take[id]! + add;
      given += add;
    }
    var left = remaining - given;
    final order = [...open]..sort((a, b) {
        final c = (exact[b]! - exact[b]!.floor()).compareTo(exact[a]! - exact[a]!.floor());
        return c != 0 ? c : a.compareTo(b);
      });
    for (final id in order) {
      if (left == 0) break;
      if (take[id]! < capacity[id]!) {
        take[id] = take[id]! + 1;
        left--;
        given++;
      }
    }
    remaining -= given;
  }

  final chosen = [
    for (final id in ids) ...pools[id]!.take(take[id]!),
  ];
  return MockExam(
    questions: _shuffled(chosen, seed),
    requestedCount: count,
    timeLimit: timeLimit,
    seed: seed,
  );
}

/// 採点。[answers] は 問題ID → 入力（選択肢ID・数値・並べ順など。checkAnswer と同じ）。
/// [elapsed] が制限時間を超えたら [MockExamResult.timedOut]（時間内に答えた分だけを [answers] に入れて渡す）。
/// [perQuestionMs] は問題ごとの所要時間（任意。履歴の elapsedMs になる）。
MockExamResult scoreMockExam(
  MockExam exam,
  Map<String, String> answers, {
  required DateTime answeredAt,
  Duration elapsed = Duration.zero,
  Map<String, int> perQuestionMs = const {},

  /// 問題ID → 自信（true = 自信あり）。任意。履歴の confident になる。
  Map<String, bool> confident = const {},
  String decimalSeparator = '.',
}) {
  var correct = 0, unanswered = 0;
  final totals = <String, int>{}, rights = <String, int>{};
  final attempts = <Attempt>[];
  for (final q in exam.questions) {
    totals[q.unitId] = (totals[q.unitId] ?? 0) + 1;
    final input = answers[q.id];
    if (input == null || input.trim().isEmpty) {
      unanswered++;
      continue;
    }
    final r = checkAnswer(q, input, decimalSeparator: decimalSeparator);
    if (r.correct) {
      correct++;
      rights[q.unitId] = (rights[q.unitId] ?? 0) + 1;
    }
    attempts.add(Attempt(
      questionId: q.id,
      unitId: q.unitId,
      correct: r.correct,
      chosenId: input,
      answeredAt: answeredAt,
      elapsedMs: perQuestionMs[q.id] ?? 0,
      mode: 'mock',
      confident: confident[q.id],
    ));
  }
  final unitIds = totals.keys.toList()..sort();
  return MockExamResult(
    total: exam.questions.length,
    correct: correct,
    unanswered: unanswered,
    timedOut: exam.timeLimit != null && elapsed > exam.timeLimit!,
    elapsed: elapsed,
    byUnit: [for (final id in unitIds) UnitScore(id, totals[id]!, rights[id] ?? 0)],
    deviation: exam.questions.isEmpty
        ? const DeviationEstimate(50)
        : estimateDeviation([for (final q in exam.questions) q.difficulty], correct),
    attempts: attempts,
  );
}
