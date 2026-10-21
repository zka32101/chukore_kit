import '../models/models.dart';
import '../prereq/prerequisites.dart';

/// 次に取り組める単元の状態。
enum NextUnitStatus {
  /// 学習の記録があり、まだ仕上がっていない（続きから）。
  inProgress,

  /// まだ学習の記録が無い（新しく始める）。
  notStarted,
}

/// 次に取り組める単元 1 つ。
class NextUnit {
  const NextUnit({required this.unitId, required this.status, required this.mastery, required this.unlocks});

  final String unitId;
  final NextUnitStatus status;

  /// 習熟度（記録が無ければ null）。
  final double? mastery;

  /// この単元を前提にしている単元の数（直接）。多いほど、先が開ける土台。
  final int unlocks;
}

/// 前提が固まっていて、いま取り組める単元を、取り組む順に返す。「根っこ」を直す提案（`rankRootCauses`）が
/// 弱い土台に戻るのに対し、こちらは**先へ進む**提案。
///
/// - 候補: [unitIds]（省略時は前提グラフの全単元）。習熟度が [doneAt] 以上の単元は仕上がり済みとして外す
/// - 取り組める条件: 直接の前提がすべて [readyAt] 以上（学習の記録が無い前提は固まっていない扱い）。
///   前提を持たない単元はいつでも取り組める。他アプリの前提（`ExternalRef`）は止めない
/// - 並び: 続きから（記録あり）を先 → 習熟度の低い順。新しく始めるものは、先が開ける数（`unlocks`）が多い順 → 単元ID順
/// - 最大 [maxUnits] 件。同じ入力なら同じ結果
List<NextUnit> suggestNextUnits(
  PrerequisiteGraph graph,
  Map<String, Mastery> mastery, {
  Iterable<String>? unitIds,
  double doneAt = 0.8,
  double readyAt = 0.6,
  int maxUnits = 3,
}) {
  if (maxUnits < 1) throw ArgumentError('maxUnits must be positive');
  final unlocks = <String, int>{};
  for (final n in graph.nodes) {
    for (final r in n.requires) {
      unlocks[r] = (unlocks[r] ?? 0) + 1;
    }
  }
  final candidates = {...(unitIds ?? graph.nodes.map((n) => n.unitId))};

  bool prereqsReady(String u) =>
      graph.requiresOf(u).every((r) => mastery[r] != null && mastery[r]!.score >= readyAt);

  final out = <NextUnit>[];
  for (final u in candidates) {
    final m = mastery[u]?.score;
    if (m != null && m >= doneAt) continue;
    if (!prereqsReady(u)) continue;
    out.add(NextUnit(
      unitId: u,
      status: m == null ? NextUnitStatus.notStarted : NextUnitStatus.inProgress,
      mastery: m,
      unlocks: unlocks[u] ?? 0,
    ));
  }
  out.sort((a, b) {
    if (a.status != b.status) return a.status == NextUnitStatus.inProgress ? -1 : 1;
    if (a.status == NextUnitStatus.inProgress) {
      final c = a.mastery!.compareTo(b.mastery!);
      if (c != 0) return c;
    } else {
      final c = b.unlocks.compareTo(a.unlocks);
      if (c != 0) return c;
    }
    return a.unitId.compareTo(b.unitId);
  });
  return out.take(maxUnits).toList();
}
