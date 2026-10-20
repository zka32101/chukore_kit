import '../models/models.dart';
import 'mock_exam.dart';
import '../util/median.dart';

/// 時間配分の全体の傾向。優先は ranOutOfTime > spareTime > slowOnFew > balanced。
enum TimingPattern {
  /// 時間切れ、または未回答がある（制限時間があるとき）。
  ranOutOfTime,

  /// 制限時間の [MockTimingConfig.spareShare] 以上を残して終わった（見直しに回せる）。
  spareTime,

  /// 少数の問題に時間をかけすぎ、しかも間違えた問題がある（飛ばして戻る練習の候補）。
  slowOnFew,

  /// 目立った偏りは無い。
  balanced,

  /// 所要時間の記録が足りず、判断しない。
  unknown,
}

/// 時間をかけすぎた問題。
class SlowQuestion {
  const SlowQuestion({required this.questionId, required this.unitId, required this.elapsedMs, required this.correct, required this.multiple});

  final String questionId;
  final String unitId;
  final int elapsedMs;
  final bool correct;

  /// 1 問あたりの目安時間の何倍かかったか。
  final double multiple;
}

/// 単元ごとの時間。
class UnitTime {
  const UnitTime({required this.unitId, required this.questions, required this.totalMs, required this.avgMs, required this.correctRate});

  final String unitId;

  /// 所要時間が記録された問題の数。
  final int questions;
  final int totalMs;
  final int avgMs;
  final double correctRate;
}

class MockTimingConfig {
  const MockTimingConfig({this.slowFactor = 2.0, this.minTimed = 5, this.spareShare = 0.2});

  /// 目安時間（制限時間 ÷ 問題数）の何倍を超えたら「かけすぎ」か。
  final double slowFactor;

  /// 所要時間が記録された回答がこれ未満なら判断しない。
  final int minTimed;

  /// 制限時間のこの割合以上を残して終えたら「余裕あり」。
  final double spareShare;
}

class MockTiming {
  const MockTiming({
    required this.pattern,
    required this.fairShareMs,
    required this.slowQuestions,
    required this.skipCandidates,
    required this.units,
    required this.spareMs,
    required this.slowShare,
  });

  final TimingPattern pattern;

  /// 1 問あたりの目安時間（制限時間 ÷ 問題数。制限時間が無いときは所要時間の中央値）。判断しないとき 0。
  final int fairShareMs;

  /// 時間をかけすぎた問題（かかった時間が長い順）。
  final List<SlowQuestion> slowQuestions;

  /// そのうち、時間をかけたのに間違えた問題（本番では飛ばして、あとで戻る練習の候補）。
  final List<SlowQuestion> skipCandidates;

  /// 単元ごとの時間（1 問あたりが長い順）。
  final List<UnitTime> units;

  /// 余った時間（制限時間 − かかった時間。無い・超えたときは 0）。
  final int spareMs;

  /// 全体の所要時間のうち、かけすぎた問題が占めた割合（0〜1）。
  final double slowShare;
}

/// 模試の時間配分を調べる。**責めない**: 時間がかかった問題を「飛ばして戻る」練習の材料と、
/// 余った時間を見直しに回す材料にする。
///
/// 所要時間は `scoreMockExam` の `perQuestionMs`（記録された回答の `elapsedMs` が 1 以上のもの）を使う。
/// [config.minTimed] 件に満たなければ [TimingPattern.unknown]。
MockTiming analyzeMockTiming(MockExam exam, MockExamResult result, {MockTimingConfig config = const MockTimingConfig()}) {
  final timed = [for (final a in result.attempts) if (a.elapsedMs > 0) a];
  final limitMs = exam.timeLimit?.inMilliseconds;
  final spare = limitMs == null ? 0 : (limitMs - result.elapsed.inMilliseconds).clamp(0, limitMs);

  if (timed.length < config.minTimed) {
    return MockTiming(
      pattern: limitMs != null && (result.timedOut || result.unanswered > 0) ? TimingPattern.ranOutOfTime : TimingPattern.unknown,
      fairShareMs: 0,
      slowQuestions: const [],
      skipCandidates: const [],
      units: const [],
      spareMs: spare,
      slowShare: 0,
    );
  }

  final int fair;
  if (limitMs != null && exam.questions.isNotEmpty) {
    fair = (limitMs / exam.questions.length).round();
  } else {
    fair = median([for (final a in timed) a.elapsedMs]).round();
  }

  final slow = [
    for (final a in timed)
      if (a.elapsedMs > fair * config.slowFactor)
        SlowQuestion(questionId: a.questionId, unitId: a.unitId, elapsedMs: a.elapsedMs, correct: a.correct, multiple: a.elapsedMs / fair),
  ]..sort((a, b) {
      final c = b.elapsedMs.compareTo(a.elapsedMs);
      return c != 0 ? c : a.questionId.compareTo(b.questionId);
    });
  final skip = [for (final s in slow) if (!s.correct) s];

  final byUnit = <String, List<Attempt>>{};
  for (final a in timed) {
    (byUnit[a.unitId] ??= []).add(a);
  }
  final units = [
    for (final e in byUnit.entries)
      () {
        final total = e.value.fold<int>(0, (s, a) => s + a.elapsedMs);
        return UnitTime(
          unitId: e.key,
          questions: e.value.length,
          totalMs: total,
          avgMs: (total / e.value.length).round(),
          correctRate: e.value.where((a) => a.correct).length / e.value.length,
        );
      }(),
  ]..sort((a, b) {
      final c = b.avgMs.compareTo(a.avgMs);
      return c != 0 ? c : a.unitId.compareTo(b.unitId);
    });

  final totalMs = timed.fold<int>(0, (s, a) => s + a.elapsedMs);
  final slowMs = slow.fold<int>(0, (s, q) => s + q.elapsedMs);

  final TimingPattern pattern;
  if (limitMs != null && (result.timedOut || result.unanswered > 0)) {
    pattern = TimingPattern.ranOutOfTime;
  } else if (limitMs != null && spare >= limitMs * config.spareShare) {
    pattern = TimingPattern.spareTime;
  } else if (skip.isNotEmpty) {
    pattern = TimingPattern.slowOnFew;
  } else {
    pattern = TimingPattern.balanced;
  }
  return MockTiming(
    pattern: pattern,
    fairShareMs: fair,
    slowQuestions: slow,
    skipCandidates: skip,
    units: units,
    spareMs: spare,
    slowShare: totalMs == 0 ? 0 : slowMs / totalMs,
  );
}
