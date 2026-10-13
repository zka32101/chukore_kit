import '../models/models.dart';
import '../weak/weak_notes.dart';

/// G2: 単元グループ（3〜6軸）ごとの習熟度スナップショット。
class RadarSnapshot {
  const RadarSnapshot(this.takenAt, this.axes);

  final DateTime takenAt;

  /// グループID → 平均習熟度(0〜1)。
  final Map<String, double> axes;
}

/// [groups]（グループID → 葉の単元ID）ごとに習熟度の平均を取る。未学習の単元は0として数える。
RadarSnapshot takeRadarSnapshot(
  DateTime now,
  Map<String, List<String>> groups,
  Map<String, Mastery> mastery,
) {
  if (groups.length < 3 || groups.length > 6) {
    throw ArgumentError('レーダーの軸は3〜6本: ${groups.length}');
  }
  return RadarSnapshot(dateOnly(now), {
    for (final g in groups.entries)
      g.key: g.value.isEmpty
          ? 0.0
          : g.value.fold<double>(0, (s, id) => s + (mastery[id]?.score ?? 0)) /
              g.value.length,
  });
}

/// 重ね描き用: 今月 − 先月 の軸ごとの差（共通の軸のみ）。
Map<String, double> radarDiff(RadarSnapshot previous, RadarSnapshot current) => {
      for (final e in current.axes.entries)
        if (previous.axes.containsKey(e.key)) e.key: e.value - previous.axes[e.key]!,
    };

/// G3: 得点推移。自己ベスト更新の判定（初回は更新扱いにしない）。
bool isPersonalBest(List<double> pastScores, double newScore) =>
    pastScores.isNotEmpty && newScore > pastScores.reduce((a, b) => a > b ? a : b);

/// G4: 克服スタンプの累計。
int overcomeStampCount(List<WeakEntry> notes) => notes.where((n) => n.overcome).length;

/// G5: 以前間違えたが、今は（最後の回答が正解）解ける問題の数。
int nowSolvableCount(Iterable<Attempt> attempts) {
  final byQ = <String, List<Attempt>>{};
  for (final a in attempts) {
    (byQ[a.questionId] ??= []).add(a);
  }
  var n = 0;
  for (final l in byQ.values) {
    l.sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
    final firstWrong = l.indexWhere((a) => !a.correct);
    if (firstWrong >= 0 && l.last.correct && firstWrong < l.length - 1) n++;
  }
  return n;
}

/// G6: キャラの進化段階（0〜4 = 5パターン）。学年と克服スタンプ数の節目で上がる。
/// 学年が上がるだけでも段階が進み、スタンプで更に進む。休んでも下がらない。
class EvolutionRule {
  const EvolutionRule({this.stampThresholds = const [10, 30, 60, 100]});

  /// 段階1〜4に上がるのに必要な累計スタンプ数。
  final List<int> stampThresholds;

  int stage({required int grade, required int stamps}) {
    final byStamps = stampThresholds.where((t) => stamps >= t).length;
    final byGrade = (grade - 1).clamp(0, 2);
    return (byStamps + byGrade).clamp(0, stampThresholds.length);
  }
}
