import '../l10n/strings.dart';
import 'my_week.dart';
import 'report.dart';

/// 保護者への「声かけ」の提案。週のレポートから、**結果よりも取り組みをほめる**一言を選ぶ。
/// 他の子や先週と比べない・責めない・点数や順位に触れない（数字を含まない）。
/// 種類の優先は 子ども本人向けの週のふりかえり（[MyWeekKind]）と同じで、伸びた > 克服 > 継続 > はじめの一歩 > おやすみ。
class GuardianTalk {
  const GuardianTalk(this.kind);

  final MyWeekKind kind;

  /// 保護者に見せる文面（文言は [ChukoreStrings]。18 言語）。
  String text(ChukoreStrings strings) => switch (kind) {
        MyWeekKind.grew => strings.talkGrew,
        MyWeekKind.overcame => strings.talkOvercame,
        MyWeekKind.kept => strings.talkSteady,
        MyWeekKind.started => strings.talkStarted,
        MyWeekKind.rest => strings.talkRest,
      };
}

/// 週のレポート [report] から、保護者への声かけを選ぶ。同じ入力なら同じ結果。
/// 見せてよいかは `AgePolicy`（`ChildFeature.weeklyReport`）で決める（この関数は判断しない）。
GuardianTalk suggestGuardianTalk(WeeklyReport report) => GuardianTalk(buildMyWeek(report).kind);
