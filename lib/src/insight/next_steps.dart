import '../mock/mock_exam.dart';
import '../models/models.dart';
import '../prereq/prerequisites.dart';
import '../weak/retry_set.dart';

/// 模試で落とした単元 1 つについての「次の一手」。
class NextStep {
  const NextStep({
    required this.unitId,
    required this.rate,
    required this.studyOrder,
    required this.rootCauseUnitIds,
    required this.externalReferrals,
    required this.retrySets,
  });

  /// 模試で正答率が低かった単元。
  final String unitId;
  final double rate;

  /// 取り組む順。つまずきの出発点（土台に近い順）→ この単元。前提が固まっていれば、この単元だけ。
  final List<String> studyOrder;

  /// 前提のうち、つまずきの出発点の候補（空なら前提は固まっている＝この単元そのものを復習）。
  final List<String> rootCauseUnitIds;

  /// 他アプリへの誘導先（前提が他アプリの単元にあるとき）。
  final List<ExternalRef> externalReferrals;

  /// [studyOrder] の単元の問題で作った解き直しセット（弱点の優先順）。
  final List<RetrySet> retrySets;

  bool get prerequisitesSolid => rootCauseUnitIds.isEmpty;
}

/// 模試の結果から、来週の優先順位の材料を作る。
///
/// 正答率が [below] 未満の単元（低い順）を最大 [maxUnits] 件取り上げ、各単元について
/// 前提をさかのぼって（[diagnoseBacktrace]）つまずきの出発点を探し、出発点 → その単元の順に取り組むよう並べる。
/// 解き直しセットは、取り組む単元の問題から [buildRetrySets] で作る（[perSet] 問まで）。
///
/// 前提の習熟度 [mastery] が無い単元は「記録なし」として出発点の候補になりうる（[diagnoseBacktrace] と同じ）。
/// 取り上げる単元が無ければ空（落とした単元なし）。同じ入力なら同じ結果。
List<NextStep> planNextSteps({
  required MockExamResult result,
  required PrerequisiteGraph graph,
  required Map<String, Mastery> mastery,
  Iterable<Attempt> attempts = const [],
  Iterable<Question> questions = const [],
  double below = 0.6,
  int maxUnits = 3,
  int perSet = 5,
}) {
  if (maxUnits < 1) throw ArgumentError('maxUnits must be positive');
  final qs = questions.toList();
  final hist = attempts.toList();
  final out = <NextStep>[];
  for (final u in result.weakUnits(below: below).take(maxUnits)) {
    final bt = diagnoseBacktrace(graph, u.unitId, mastery);
    final roots = [for (final r in bt.rootCauses) r.unitId];
    final order = [...roots, u.unitId];
    final inScope = {...order};
    final scoped = [for (final q in qs) if (inScope.contains(q.unitId)) q];
    final sets = scoped.isEmpty
        ? <RetrySet>[]
        : [
            for (final s in buildRetrySets(attempts: hist, questions: scoped, perSet: perSet))
              if (s.questions.isNotEmpty) s,
          ];
    out.add(NextStep(
      unitId: u.unitId,
      rate: u.rate,
      studyOrder: order,
      rootCauseUnitIds: roots,
      externalReferrals: bt.externalReferrals,
      retrySets: sets,
    ));
  }
  return out;
}
