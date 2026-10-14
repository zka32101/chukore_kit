import '../assess/assess.dart';

/// レーダーの1軸。[previous] は先月のスナップショット（無ければ null）。
class RadarAxis {
  const RadarAxis(this.label, this.current, [this.previous])
      : assert(current >= 0 && current <= 1),
        assert(previous == null || (previous >= 0 && previous <= 1));

  final String label;
  final double current;
  final double? previous;
}

/// 成長カードの中身。名前・ID・メールの欄は持たない（個人情報を載せられない形）。
class GrowthCardData {
  GrowthCardData({
    required this.subjectLabel,
    required this.level,
    required this.radar,
    this.pointsToNext,
    this.scoreDelta,
    this.isPersonalBest = false,
    this.overcomeStamps = 0,
    this.nowSolvable = 0,
    this.streakDays = 0,
    this.stage = 0,
  }) : assert(radar.length >= 3 && radar.length <= 6);

  /// 例: 「英語」。教科名のみ。
  final String subjectLabel;
  final Level level;
  final List<RadarAxis> radar;

  /// 次のレベルまでの残り点（最上位は null）。
  final double? pointsToNext;

  /// 前回の模擬テストとの得点差。初回は null。
  final double? scoreDelta;
  final bool isPersonalBest;
  final int overcomeStamps;
  final int nowSolvable;
  final int streakDays;

  /// キャラの進化段階（0〜4）。
  final int stage;

  String get levelLabel => switch (level) {
        Level.s => 'S',
        Level.a => 'A',
        Level.b => 'B',
        Level.c => 'C',
        Level.d => 'D',
      };

  /// カードの見出し。数字より「前回からの変化」を主役にし、下がった時も落ち込ませない。
  String get headline {
    if (isPersonalBest) return '自己ベスト更新！';
    final d = scoreDelta;
    if (d == null) return 'はじめの一歩';
    if (d > 0) return '前回より +${_fmt(d)}点';
    if (d == 0) return '前回と同じ。安定してきた';
    return 'ここからまた伸ばそう';
  }

  /// 次のレベルへの案内。最上位は祝う文言。
  String get nextLine {
    final p = pointsToNext;
    return p == null ? '最高レベルに到達！' : 'あと${_fmt(p)}点で次のレベル';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// 共有できるか。13歳未満は保護者ゲートを通した後のみ。共有は毎回ユーザーが押す前提。
bool canShareGrowthCard({required bool isUnder13, required bool gatePassed}) =>
    !isUnder13 || gatePassed;
