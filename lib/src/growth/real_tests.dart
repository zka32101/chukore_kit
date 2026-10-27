import '../assess/assess.dart';
import 'growth.dart';

/// 模擬テストの得点（100点満点換算）。
class MockScore {
  const MockScore(this.date, this.score);

  final DateTime date;
  final double score;
}

/// 本番のテストの種類。種類をまたいで点を比べない（難しさが違う）。
enum RealTestKind {
  /// 学校の定期テスト。
  regular,

  /// 模試。
  mock,

  /// その他。
  other,
}

/// 実際のテストの点数（本人が入力する）。
///
/// [score] は [maxScore] 満点での点（既定は 100 点満点）。満点が違うテスト（0〜10 点制、500 点満点など）は、
/// [ratio]（点 ÷ 満点）や [normalizedScore]（100 点満点換算）で比べる。
class RealTestRecord {
  const RealTestRecord(this.date, this.score, {this.maxScore = 100, this.kind = RealTestKind.regular});

  final DateTime date;
  final double score;
  final double maxScore;
  final RealTestKind kind;

  /// 点が正しい範囲か（満点が正で、点が 0 以上満点以下）。
  bool get isValid => maxScore > 0 && score >= 0 && score <= maxScore;

  /// 点 ÷ 満点（0〜1）。範囲外の入力でも 0〜1 に収める。
  double get ratio => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;

  /// 100 点満点換算。
  double get normalizedScore => ratio * 100;
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
    final before = [
      for (final m in mocks)
        if (m.date.isBefore(r.date)) m.score,
    ];
    out.add(
      RealTestComparison(
        record: r,
        realLevel: judgeLevel([r.normalizedScore], thresholds: thresholds).level,
        mockLevel: before.isEmpty ? null : judgeLevel(before, thresholds: thresholds).level,
        deltaFromPrevious: past.isEmpty ? null : r.normalizedScore - past.last,
        isPersonalBest: isPersonalBest(past, r.normalizedScore),
      ),
    );
    past.add(r.normalizedScore);
  }
  return out;
}
