import 'dart:math' as math;

/// 到達レベル。
enum Level { s, a, b, c, d }

/// 各レベルの下限点（100点満点換算）。教科ごとに設定ファイルから作る想定。
class LevelThresholds {
  const LevelThresholds({this.s = 90, this.a = 75, this.b = 60, this.c = 40});

  final double s, a, b, c;

  double minOf(Level l) => switch (l) {
        Level.s => s,
        Level.a => a,
        Level.b => b,
        Level.c => c,
        Level.d => 0,
      };
}

class LevelResult {
  const LevelResult(this.level, this.weightedScore, this.pointsToNext);

  final Level level;
  final double weightedScore;

  /// 次のレベルまでの残り点。最上位は null。
  final double? pointsToNext;
}

/// 直近3回（古い→新しい順で渡す）の加重平均で判定。重みは古い順に 1,2,3。
LevelResult judgeLevel(
  List<double> recentScores, {
  LevelThresholds thresholds = const LevelThresholds(),
}) {
  if (recentScores.isEmpty) {
    throw ArgumentError('recentScores must not be empty');
  }
  final used = recentScores.length > 3
      ? recentScores.sublist(recentScores.length - 3)
      : recentScores;
  final firstWeight = 3 - used.length + 1;
  var sw = 0.0, s = 0.0;
  for (var i = 0; i < used.length; i++) {
    final w = (firstWeight + i).toDouble();
    sw += w;
    s += w * used[i];
  }
  final score = s / sw;
  final level = Level.values.firstWhere(
    (l) => score >= thresholds.minOf(l),
    orElse: () => Level.d,
  );
  final next = level == Level.s ? null : Level.values[level.index - 1];
  return LevelResult(
    level,
    score,
    next == null ? null : math.max(0, thresholds.minOf(next) - score),
  );
}

class DeviationEstimate {
  const DeviationEstimate(this.value, {this.margin = 5});

  final double value;
  final double margin;
  double get low => value - margin;
  double get high => value + margin;
}

/// アプリ内偏差値（段階1）。[baseRates] は各問の基準正答率 p_i、[score] は正解数 X。
/// 偏差値 = 50 + 10 × (X − E) / (k × √V)。50 は想定集団の平均で、アプリ内だけの目安（全国の偏差値ではない）。
DeviationEstimate estimateDeviation(
  List<double> baseRates,
  int score, {
  double k = 2.3,
}) {
  if (baseRates.isEmpty) throw ArgumentError('baseRates must not be empty');
  var e = 0.0, v = 0.0;
  for (final p in baseRates) {
    e += p;
    v += p * (1 - p);
  }
  final sd = k * math.sqrt(v);
  if (sd == 0) return const DeviationEstimate(50);
  return DeviationEstimate(50 + 10 * (score - e) / sd);
}
