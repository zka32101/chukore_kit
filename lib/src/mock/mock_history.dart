import '../growth/growth.dart';
import 'mock_exam.dart';

/// 模試1回の記録（日付と採点結果）。
class MockHistoryEntry {
  const MockHistoryEntry(this.date, this.result);

  final DateTime date;
  final MockExamResult result;
}

/// 1回ぶんの推移。前回との差は初回は null。
class MockStep {
  const MockStep({
    required this.date,
    required this.score,
    required this.deviation,
    required this.unanswered,
    required this.timedOut,
    required this.secondsPerQuestion,
    required this.scoreDelta,
    required this.deviationDelta,
    required this.isPersonalBest,
  });

  final DateTime date;

  /// 100点満点換算。
  final double score;

  /// アプリ内偏差値（段階1）。全国の偏差値ではない。
  final double deviation;
  final int unanswered;
  final bool timedOut;

  /// 1問あたりにかけた時間（秒）。問題が無いときは 0。
  final double secondsPerQuestion;
  final double? scoreDelta, deviationDelta;
  final bool isPersonalBest;
}

/// 単元の正答率の変化。
class UnitChange {
  const UnitChange({
    required this.unitId,
    required this.previousRate,
    required this.latestRate,
    required this.previousTotal,
    required this.latestTotal,
  });

  final String unitId;
  final double previousRate, latestRate;
  final int previousTotal, latestTotal;

  /// 正答率の差（プラスなら伸びた）。
  double get delta => latestRate - previousRate;
}

/// 模試の履歴の比較。
class MockComparison {
  const MockComparison({
    required this.steps,
    required this.sincePrevious,
    required this.sinceFirst,
    required this.bestScore,
    required this.slopePerExam,
  });

  /// 日付順の推移。
  final List<MockStep> steps;

  /// 直近の回と、その前の回での単元別の変化（伸びた順）。2 回に満たなければ空。
  final List<UnitChange> sincePrevious;

  /// 直近の回と、最初の回での単元別の変化（伸びた順）。
  final List<UnitChange> sinceFirst;
  final double bestScore;

  /// 得点の傾き（1 回ごとに平均で何点動くか。最小二乗法）。2 回に満たなければ 0。
  final double slopePerExam;

  /// 最も伸びた単元（伸びが 0 を超えるもの）。
  UnitChange? get mostImproved {
    final up = [for (final c in sincePrevious) if (c.delta > 0) c];
    return up.isEmpty ? null : up.first;
  }

  /// 最も下がった単元（下がりが 0 未満のもの）。
  UnitChange? get mostDeclined {
    final down = [for (final c in sincePrevious) if (c.delta < 0) c];
    return down.isEmpty ? null : down.last;
  }
}

List<UnitChange> _unitChanges(MockExamResult from, MockExamResult to, int minQuestions) {
  final before = {for (final u in from.byUnit) u.unitId: u};
  final out = <UnitChange>[];
  for (final u in to.byUnit) {
    final b = before[u.unitId];
    if (b == null || b.total < minQuestions || u.total < minQuestions) continue;
    out.add(UnitChange(
      unitId: u.unitId,
      previousRate: b.rate,
      latestRate: u.rate,
      previousTotal: b.total,
      latestTotal: u.total,
    ));
  }
  // 伸びた順（同じなら単元ID順）
  out.sort((a, b) {
    final c = b.delta.compareTo(a.delta);
    return c != 0 ? c : a.unitId.compareTo(b.unitId);
  });
  return out;
}

/// 模試の履歴を比べる。得点・アプリ内偏差値・時間のかけ方の推移と、単元別の伸びを出す。
///
/// 単元別の変化は、両方の回で [minQuestions] 問以上出た単元だけ（少ない問題数での増減は
/// ぶれが大きいため）。日付順に並べて扱い、同じ日は渡された順。
MockComparison compareMockExams(
  Iterable<MockHistoryEntry> entries, {
  int minQuestions = 2,
}) {
  final sorted = [...entries];
  // 安定に並べる（同じ日は元の順）
  final indexed = [for (var i = 0; i < sorted.length; i++) (i, sorted[i])]
    ..sort((a, b) {
      final c = a.$2.date.compareTo(b.$2.date);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final list = [for (final e in indexed) e.$2];

  final steps = <MockStep>[];
  final past = <double>[];
  for (final e in list) {
    final r = e.result;
    steps.add(MockStep(
      date: e.date,
      score: r.score100,
      deviation: r.deviation.value,
      unanswered: r.unanswered,
      timedOut: r.timedOut,
      secondsPerQuestion: r.total == 0 ? 0 : r.elapsed.inMilliseconds / 1000 / r.total,
      scoreDelta: steps.isEmpty ? null : r.score100 - steps.last.score,
      deviationDelta: steps.isEmpty ? null : r.deviation.value - steps.last.deviation,
      isPersonalBest: isPersonalBest(past, r.score100),
    ));
    past.add(r.score100);
  }

  var slope = 0.0;
  final n = steps.length;
  if (n >= 2) {
    final meanX = (n - 1) / 2;
    final meanY = steps.fold<double>(0, (s, e) => s + e.score) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (i - meanX) * (steps[i].score - meanY);
      den += (i - meanX) * (i - meanX);
    }
    slope = num / den;
  }

  return MockComparison(
    steps: steps,
    sincePrevious: n >= 2 ? _unitChanges(list[n - 2].result, list[n - 1].result, minQuestions) : const [],
    sinceFirst: n >= 2 ? _unitChanges(list.first.result, list.last.result, minQuestions) : const [],
    bestScore: past.isEmpty ? 0 : past.reduce((a, b) => a > b ? a : b),
    slopePerExam: slope,
  );
}
