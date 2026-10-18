import 'dart:math' as math;

import '../bank/question_bank.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';

/// 他のアプリ（小学コレ！など）にある前提の単元。コードは共有せず、誘導（リンク）だけを持つ。
class ExternalRef {
  const ExternalRef({required this.id, required this.title, this.link});

  factory ExternalRef.fromJson(Map<String, dynamic> j) => ExternalRef(
        id: j['id'] as String,
        title: j['title'] as String,
        link: j['link'] as String?,
      );

  final String id;
  final String title;

  /// ストアのリンクやアプリ間リンク。開くのはアプリ側。
  final String? link;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, if (link != null) 'link': link};
}

/// 1つの単元の前提。[requires] は同じ単元ツリー内の単元、[external] は他アプリの単元。
class PrereqNode {
  const PrereqNode(this.unitId, {this.requires = const [], this.external = const []});

  factory PrereqNode.fromJson(Map<String, dynamic> j) => PrereqNode(
        j['unitId'] as String,
        requires: [for (final r in (j['requires'] as List? ?? const [])) r as String],
        external: [
          for (final e in (j['external'] as List? ?? const [])) ExternalRef.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );

  final String unitId;
  final List<String> requires;
  final List<ExternalRef> external;
}

/// 単元の依存関係（前提の整理）。形式: `{"version": 1, "prerequisites": [{"unitId": ..., "requires": [...], "external": [...]}]}`
class PrerequisiteGraph {
  PrerequisiteGraph(Iterable<PrereqNode> nodes) : _nodes = {for (final n in nodes) n.unitId: n};

  factory PrerequisiteGraph.fromJson(Map<String, dynamic> j) => PrerequisiteGraph([
        for (final n in (j['prerequisites'] as List? ?? const [])) PrereqNode.fromJson(Map<String, dynamic>.from(n as Map)),
      ]);

  final Map<String, PrereqNode> _nodes;

  Iterable<PrereqNode> get nodes => _nodes.values;

  List<String> requiresOf(String unitId) => _nodes[unitId]?.requires ?? const [];

  List<ExternalRef> externalOf(String unitId) => _nodes[unitId]?.external ?? const [];

  /// [from] から前提をたどって [target] に着くか（[from] 自身は含まない）。循環があっても止まる。
  bool _reaches(String from, String target) {
    final seen = <String>{};
    final stack = [...requiresOf(from)];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      if (cur == target) return true;
      if (seen.add(cur)) stack.addAll(requiresOf(cur));
    }
    return false;
  }

  /// [id] から前提をたどって [id] に戻る道筋（[id] から始まり、最後の手前まで）。循環が無ければ null。
  List<String>? _cyclePath(String id) {
    final prev = <String, String>{};
    final queue = <String>[];
    for (final r in requiresOf(id)) {
      if (r == id) return [id];
      if (!prev.containsKey(r)) {
        prev[r] = id;
        queue.add(r);
      }
    }
    for (var i = 0; i < queue.length; i++) {
      for (final r in requiresOf(queue[i])) {
        if (r == id) {
          final path = <String>[];
          for (String? c = queue[i]; c != null && c != id; c = prev[c]) {
            path.add(c);
          }
          return [id, ...path.reversed];
        }
        if (!prev.containsKey(r)) {
          prev[r] = queue[i];
          queue.add(r);
        }
      }
    }
    return null;
  }

  /// 前提の定義がまだ無い末端の単元（作成の進み具合の確認用）。単元ツリーの順。
  List<Unit> uncoveredLeaves(UnitTree tree) =>
      [for (final u in tree.allLeaves()) if (!_nodes.containsKey(u.id)) u];

  /// 単元ツリーと突き合わせて検証する（単元が無い・自分自身が前提・循環・IDの重複）。
  List<ValidationIssue> validate(UnitTree tree, {Iterable<PrereqNode>? rawNodes}) {
    final issues = <ValidationIssue>[];
    void err(String code, String id, String msg) => issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
    if (rawNodes != null) {
      final seen = <String>{};
      for (final n in rawNodes) {
        if (!seen.add(n.unitId)) err('prereq_duplicate', n.unitId, '前提の定義が重複しています');
      }
    }
    for (final n in nodes) {
      if (tree[n.unitId] == null) err('prereq_unit_missing', n.unitId, '単元 ${n.unitId} が単元ツリーにありません');
      for (final r in n.requires) {
        if (r == n.unitId) {
          err('prereq_self', n.unitId, '自分自身が前提になっています');
        } else if (tree[r] == null) {
          err('prereq_requires_missing', n.unitId, '前提の単元 $r が単元ツリーにありません');
        }
      }
      for (final e in n.external) {
        if (e.id.trim().isEmpty || e.title.trim().isEmpty) err('prereq_external_empty', n.unitId, '他アプリの前提の id と title は必須です');
      }
    }
    // 循環: 前提をたどって自分に戻る。同じ循環は、IDが最小の単元でだけ 1 回報告し、道筋を示す。
    for (final id in _nodes.keys) {
      final path = _cyclePath(id);
      if (path == null) continue;
      if (path.reduce((a, b) => a.compareTo(b) <= 0 ? a : b) != id) continue;
      err('prereq_cycle', id, '前提が循環しています: ${[...path, id].join(' → ')}');
    }

    // 警告（直すと分かりやすくなるが、動作には影響しない）
    void warn(String code, String id, String msg) =>
        issues.add(ValidationIssue(IssueSeverity.warning, code, id, msg));
    for (final n in nodes) {
      final seenReq = <String>{};
      for (final r in n.requires) {
        if (!seenReq.add(r)) warn('prereq_requires_duplicate', n.unitId, '前提 $r が重複しています');
      }
      final unit = tree[n.unitId];
      for (final r in seenReq) {
        final pre = tree[r];
        if (unit == null || pre == null || r == n.unitId) continue;
        if (pre.subject != unit.subject) {
          warn('prereq_cross_subject', n.unitId, '前提 $r は別の教科です（${pre.subject} → ${unit.subject}）。意図したものか確認してください');
        } else if (pre.grade > unit.grade) {
          warn('prereq_grade_inversion', n.unitId, '前提 $r は上の学年です（${pre.grade}年 → ${unit.grade}年）。向きが逆かもしれません');
        }
        // 別の前提の先でも辿れるなら、直接書かなくてよい
        final via = [for (final o in seenReq) if (o != r && _reaches(o, r)) o];
        if (via.isNotEmpty) {
          warn('prereq_redundant', n.unitId, '前提 $r は ${via.first} の前提でもあるため、直接書かなくても同じ結果になります');
        }
      }
    }
    return [...issues.where((i) => i.isError), ...issues.where((i) => !i.isError)];
  }
}

/// 前提1つの診断状態。
enum StepStatus {
  /// 習熟度が基準以上。
  ok,

  /// 習熟度が基準未満。
  weak,

  /// まだ学習の記録が無い（原因かどうか分からない）。
  unknown,
}

class BacktraceStep {
  const BacktraceStep({
    required this.unitId,
    required this.depth,
    required this.mastery,
    required this.status,
    required this.isRootCause,
  });

  final String unitId;

  /// つまずいた単元から数えた段数（直接の前提 = 1）。複数の道があるときは最短。
  final int depth;
  final double? mastery;
  final StepStatus status;

  /// 前提がすべて ok なのに、この単元が weak／unknown ＝ つまずきの出発点の候補。
  final bool isRootCause;
}

class BacktraceResult {
  const BacktraceResult({
    required this.startUnitId,
    required this.steps,
    required this.rootCauses,
    required this.externalReferrals,
  });

  final String startUnitId;

  /// 前提すべて。土台に近い（段数が大きい）ものから順に。
  final List<BacktraceStep> steps;

  /// つまずきの出発点の候補（土台に近い順）。空なら、前提は固まっている（その単元そのものを復習）。
  final List<BacktraceStep> rootCauses;

  /// 他アプリへの誘導先。出発点の候補が持つもの（前提の整理に他アプリの単元がある場合）。
  final List<ExternalRef> externalReferrals;

  bool get prerequisitesSolid => rootCauses.isEmpty;
}

/// B さかのぼり診断。つまずいた単元 [startUnitId] の前提をたどり、どこでつまずき始めたかを特定する。
/// [threshold] 未満を weak、学習の記録が無いものを unknown とする。決まった入力なら同じ結果。
BacktraceResult diagnoseBacktrace(
  PrerequisiteGraph graph,
  String startUnitId,
  Map<String, Mastery> mastery, {
  double threshold = 0.6,
}) {
  // 前提を幅優先でたどる（最短の段数を記録）。start に戻る循環は無視する。
  final depth = <String, int>{};
  var frontier = [startUnitId];
  var d = 0;
  while (frontier.isNotEmpty) {
    d++;
    final next = <String>[];
    for (final u in frontier) {
      for (final r in graph.requiresOf(u)) {
        if (r == startUnitId || depth.containsKey(r)) continue;
        depth[r] = d;
        next.add(r);
      }
    }
    frontier = next;
  }

  StepStatus statusOf(String id) {
    final m = mastery[id]?.score;
    if (m == null) return StepStatus.unknown;
    return m < threshold ? StepStatus.weak : StepStatus.ok;
  }

  final status = {for (final id in depth.keys) id: statusOf(id)};
  bool isRoot(String id) =>
      status[id] != StepStatus.ok &&
      graph.requiresOf(id).where(depth.containsKey).every((r) => status[r] == StepStatus.ok);

  // 循環した前提（検証を通さず読み込んだ場合）では isRoot が誰も true にならないので、
  // 習熟が足りない前提のうち最も土台に近い（段数が大きい）ものを出発点の候補にする。
  final rootIds = <String>{for (final id in depth.keys) if (isRoot(id)) id};
  if (rootIds.isEmpty) {
    final notOk = [for (final id in depth.keys) if (status[id] != StepStatus.ok) id];
    if (notOk.isNotEmpty) {
      final deepest = notOk.map((id) => depth[id]!).reduce(math.max);
      rootIds.addAll(notOk.where((id) => depth[id] == deepest));
    }
  }

  final steps = [
    for (final e in depth.entries)
      BacktraceStep(
        unitId: e.key,
        depth: e.value,
        mastery: mastery[e.key]?.score,
        status: status[e.key]!,
        isRootCause: rootIds.contains(e.key),
      ),
  ]..sort((a, b) {
      final c = b.depth.compareTo(a.depth); // 土台に近い順
      return c != 0 ? c : a.unitId.compareTo(b.unitId);
    });
  final roots = [for (final s in steps) if (s.isRootCause) s];

  final external = <String, ExternalRef>{};
  for (final r in roots) {
    for (final e in graph.externalOf(r.unitId)) {
      external[e.id] = e;
    }
  }
  // 出発点の候補が他アプリの単元に行き着くとき（内側の前提が無い単元の外部前提）も拾う
  if (roots.isEmpty && depth.isEmpty) {
    for (final e in graph.externalOf(startUnitId)) {
      external[e.id] = e;
    }
  }
  return BacktraceResult(
    startUnitId: startUnitId,
    steps: steps,
    rootCauses: roots,
    externalReferrals: external.values.toList(),
  );
}
