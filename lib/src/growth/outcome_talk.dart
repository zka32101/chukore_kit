import '../guardian/age_policy.dart';
import '../l10n/strings.dart';
import 'outcome_summary.dart';

/// 本番の点の変化に対する、保護者への声かけ。**点数や差の数字を含めず、結果より取り組みを話題にする**。
/// 他の子や前回との比較を煽らず、下がったときも責めない。
class OutcomeTalk {
  const OutcomeTalk(this.change);

  /// どの変化についての声かけか。
  final OutcomeChange change;

  String text(ChukoreStrings strings) => switch (change) {
    OutcomeChange.first => strings.talkOutcomeFirst,
    OutcomeChange.up => strings.talkOutcomeUp,
    OutcomeChange.same => strings.talkOutcomeSame,
    OutcomeChange.down => strings.talkOutcomeDown,
  };
}

/// いちばん新しい本番の記録の変化から、保護者への声かけを選ぶ。記録が無ければ null。
OutcomeTalk? suggestOutcomeTalk(OutcomeSummary summary) =>
    summary.entries.isEmpty ? null : OutcomeTalk(summary.entries.last.change);

/// [suggestOutcomeTalk] に、年齢の方針の確認を足したもの。保護者向けレポートと同じ扱い（[ChildFeature.weeklyReport]）。
///
/// - 子どもでない（[isChild] が偽）なら、そのまま声かけを選ぶ
/// - 子どもで、方針が [Access.allowed] なら選ぶ
/// - 子どもで、方針が [Access.needsGuardianGate] なら、[guardianApproved]（保護者ゲートを通した）が真のときだけ
/// - 方針が [Access.hidden]・書かれていない場合は、常に null
OutcomeTalk? suggestOutcomeTalkFor(
  AgePolicy policy,
  OutcomeSummary summary, {
  required bool isChild,
  bool guardianApproved = false,
}) {
  final access = policy.accessForChild(ChildFeature.weeklyReport, isChild: isChild);
  final ok = access == Access.allowed || (access == Access.needsGuardianGate && guardianApproved);
  return ok ? suggestOutcomeTalk(summary) : null;
}
