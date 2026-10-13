import '../models/models.dart';

/// 学年×単元の木構造。アプリ同梱JSON（バージョン付き）から作る。
class UnitTree {
  UnitTree(this.version, Iterable<Unit> units)
      : _byId = {for (final u in units) u.id: u} {
    for (final u in _byId.values) {
      (_children[u.parentId] ??= []).add(u);
    }
    for (final l in _children.values) {
      l.sort((a, b) {
        final c = a.order.compareTo(b.order);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    }
  }

  /// `{"version": 1, "units": [ {...Unit...} ]}`
  factory UnitTree.fromJson(Map<String, dynamic> j) => UnitTree(
        j['version'] as int,
        (j['units'] as List)
            .map((e) => Unit.fromJson(e as Map<String, dynamic>)),
      );

  final int version;
  final Map<String, Unit> _byId;
  final Map<String?, List<Unit>> _children = {};

  Unit? operator [](String id) => _byId[id];

  List<Unit> get roots => List.unmodifiable(_children[null] ?? const []);

  List<Unit> childrenOf(String id) =>
      List.unmodifiable(_children[id] ?? const []);

  bool isLeaf(String id) => (_children[id] ?? const []).isEmpty;

  /// 選択した単元（親を選べば配下すべて）を葉に展開する。重複なし・木の順。
  List<Unit> resolveLeaves(Iterable<String> selectedIds) {
    final out = <String, Unit>{};
    void walk(String id) {
      final u = _byId[id];
      if (u == null) return;
      if (isLeaf(id)) {
        out[id] = u;
      } else {
        for (final c in childrenOf(id)) {
          walk(c.id);
        }
      }
    }

    selectedIds.forEach(walk);
    return out.values.toList();
  }
}
