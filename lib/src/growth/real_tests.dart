import '../assess/assess.dart';
import 'growth.dart';

/// 模擬テストの得点（100点満点換算）。
class MockScore {
  const MockScore(this.date, this.score);

  final DateTime date;
  final double score;
}

/// 実際の定期テストの点数（本人が入力する）。
class RealTestRecord {
  const RealTestRecord(this.date, this.score);

  final DateTime date;
  final double score;
}

/// 1回分の比較結果。
class RealTestComparison {
  const RealTestComparison({
    required this.record,
    required this.realLevel,
    required this.mockLevel,
    required this.deltaFromPrevious,
    required this.isPersonalBest,
  });

  final RealTestRecord record;

  /// 本番の点数のレベル。
  final Level realLevel;

  /// その時点の模擬テスト（直近3回の加重平均）のレベル。模擬テストがまだ無ければ null。
  final Level? mockLevel;

  /// 前回の本番との得点差。初回は null。
  final double? deltaFromPrevious;
  final bool isPersonalBest;
}

/// G8 本番の点数の記録。実際の定期テストの点を、到達レベルの変化と並べる。
/// 日付順に並べて返す。同じ日は、その日より前の模擬テストだけを使う。
List<RealTestComparison> compareRealTests(
  List<RealTestRecord> real,
  List<MockScore> mock, {
  LevelThresholds thresholds = const LevelThresholds(),
}) {
  final reals = [...real]..sort((a, b) => a.date.compareTo(b.date));
  final mocks = [...mock]..sort((a, b) => a.date.compareTo(b.date));
  final out = <RealTestComparison>[];
  final past = <double>[];
  for (final r in reals) {
    final before = [for (final m in mocks) if (m.date.isBefore(r.date)) m.score];
    out.add(RealTestComparison(
      record: r,
      realLevel: judgeLevel([r.score], thresholds: thresholds).level,
      mockLevel: before.isEmpty ? null : judgeLevel(before, thresholds: thresholds).level,
      deltaFromPrevious: past.isEmpty ? null : r.score - past.last,
      isPersonalBest: isPersonalBest(past, r.score),
    ));
    past.add(r.score);
  }
  return out;
}
