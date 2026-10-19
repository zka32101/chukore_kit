import '../models/models.dart';
import '../prereq/prerequisites.dart';

/// 弱い単元をいくつも説明する「土台」の単元 1 つ。
class RootCause {
  const RootCause({
    required this.unitId,
    required this.mastery,
    required this.explains,
    required this.selfWeak,
    required this.externalReferrals,
  });

  final String unitId;

  /// 習熟度（学習の記録が無ければ null）。
  final double? mastery;

  /// この単元を固めると解ける見込みのある弱い単元（単元ID順。自分自身が弱いなら自分も含む）。
  final List<String> explains;

  /// この単元自身が弱い（記録が無い場合は偽）。
  final bool selfWeak;

  /// 他アプリへの誘導先（この単元の前提が他アプリにあるとき）。
  final List<ExternalRef> externalReferrals;
}

/// 弱い単元ごとに前提をさかのぼり（[diagnoseBacktrace]）、**同じ土台に行き着く単元をまとめて**、
/// 多くの弱点を説明する土台の順に並べる。「この数単元を固めれば、弱点の多くがほどける」を示す。
///
/// - 弱い単元: [unitIds]（省略時は [mastery] に記録のある単元）のうち、習熟度が [weakBelow] 未満のもの。
///   記録の無い単元は、[includeUnknown] が真のときだけ弱い単元として数える
/// - 前提がすべて固まっている弱い単元は、その単元自身が土台
/// - 並び: 説明する単元が多い順 → 習熟度の低い順（記録なしが先）→ 単元ID順
/// - 弱い単元が無ければ空。同じ入力なら同じ結果
List<RootCause> rankRootCauses(
  PrerequisiteGraph graph,
  Map<String, Mastery> mastery, {
  Iterable<String>? unitIds,
  double weakBelow = 0.6,
  bool includeUnknown = false,
}) {
  final scope = {...(unitIds ?? mastery.keys)};
  final weak = [
    for (final u in scope)
      if (mastery[u] != null ? mastery[u]!.score < weakBelow : includeUnknown) u,
  ]..sort();

  final explains = <String, Set<String>>{};
  final external = <String, Map<String, ExternalRef>>{};
  for (final u in weak) {
    final bt = diagnoseBacktrace(graph, u, mastery, threshold: weakBelow);
    final roots = bt.prerequisitesSolid ? [u] : [for (final r in bt.rootCauses) r.unitId];
    for (final r in roots) {
      (explains[r] ??= {}).add(u);
      for (final e in graph.externalOf(r)) {
        (external[r] ??= {})[e.id] = e;
      }
    }
  }

  final out = [
    for (final e in explains.entries)
      RootCause(
        unitId: e.key,
        mastery: mastery[e.key]?.score,
        explains: e.value.toList(), // 弱い単元を単元ID順に処理しているので、すでに単元ID順
        selfWeak: mastery[e.key] != null, // 土台になるのは「弱い」か「記録なし」のどちらか
        externalReferrals: (external[e.key]?.values.toList() ?? [])..sort((a, b) => a.id.compareTo(b.id)),
      ),
  ]..sort((a, b) {
      final c = b.explains.length.compareTo(a.explains.length);
      if (c != 0) return c;
      final ma = a.mastery ?? -1, mb = b.mastery ?? -1;
      final d = ma.compareTo(mb);
      return d != 0 ? d : a.unitId.compareTo(b.unitId);
    });
  return out;
}
