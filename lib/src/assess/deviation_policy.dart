import '../l10n/strings.dart';
import 'assess.dart';

/// アプリ内偏差値を出さない理由。
enum DeviationHiddenReason { under13, notOptedIn, notAvailable }

class DeviationDisplay {
  const DeviationDisplay.shown(this.estimate) : hiddenReason = null;
  const DeviationDisplay.hidden(this.hiddenReason) : estimate = null;

  final DeviationEstimate? estimate;
  final DeviationHiddenReason? hiddenReason;

  bool get visible => estimate != null;
}

/// G9 アプリ内偏差値の表示ポリシー。
/// 13歳未満は出さない（到達レベルのみ）。本人が表示を選ぶまで出さない（初期は非表示）。
/// 換算できないとき（[estimate] が null）も出さない。順位・人数は元から返さない。
DeviationDisplay deviationDisplay({
  required bool isUnder13,
  required bool optedIn,
  required DeviationEstimate? estimate,
}) {
  if (isUnder13) return const DeviationDisplay.hidden(DeviationHiddenReason.under13);
  if (!optedIn) return const DeviationDisplay.hidden(DeviationHiddenReason.notOptedIn);
  if (estimate == null) return const DeviationDisplay.hidden(DeviationHiddenReason.notAvailable);
  return DeviationDisplay.shown(estimate);
}

/// 幅で表示する（例: 52〜58）。数字より幅を見せ、断定しない。
String formatDeviationRange(DeviationEstimate e, ChukoreStrings strings) =>
    strings.deviationRange('${e.low.round()}', '${e.high.round()}');
