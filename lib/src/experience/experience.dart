import 'dart:convert';

import '../bank/question_bank.dart';
import '../scope/unit_tree.dart';

/// 教科をまたぐ体験の教材（`sort`・`link`・`dial`・`balance`）。仕様と判定だけを持ち、画面・音・アニメはアプリ側。
/// 文言は ID だけ（本文はコンテンツ側）。体験は習熟度に直接加点しない（体験後の確認問題で測る）。
/// 数学の式を動かす体験は `Exploration`（`lib/src/math`）。設計は docs/learning_model.md §4.1。
sealed class Experience {
  const Experience({
    required this.id,
    required this.version,
    required this.unitId,
    required this.promptId,
    required this.explanationId,
  });

  final String id;
  final int version;
  final String unitId;
  final String promptId;
  final String explanationId;

  /// JSON の `kind`。
  String get kind;

  static const knownKinds = {'sort', 'link', 'dial', 'balance', 'timeline'};
  static const _common = {'id', 'version', 'unitId', 'kind', 'promptId', 'explanationId'};

  /// 読めなければ [FormatException]。
  factory Experience.fromJson(Map<String, dynamic> j) {
    final id = _str(j, 'id', '体験');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('id は英数字と _ だけ: $id');
    final kind = _str(j, 'kind', id);
    if (!knownKinds.contains(kind)) throw FormatException('$id: 未対応の kind: $kind');
    final extra = switch (kind) {
      'sort' => const {'bins', 'items'},
      'link' => const {'nodes', 'edges', 'directed'},
      'dial' => const {'min', 'max', 'step', 'initial', 'target', 'tolerance'},
      'timeline' => const {'events'},
      _ => const {'items', 'leftFixed', 'rightFixed'},
    };
    final unknown = j.keys.where((k) => !_common.contains(k) && !extra.contains(k));
    if (unknown.isNotEmpty) throw FormatException('$id: 未知のキー: ${unknown.join(', ')}');
    final version = j['version'];
    if (version is! int || version < 1) throw FormatException('$id: version は 1 以上の整数');
    final c = (
      id: id,
      version: version,
      unitId: _str(j, 'unitId', id),
      promptId: _str(j, 'promptId', id),
      explanationId: _str(j, 'explanationId', id),
    );
    return switch (kind) {
      'sort' => SortExperience._parse(j, c),
      'link' => LinkExperience._parse(j, c),
      'dial' => DialExperience._parse(j, c),
      'timeline' => TimelineExperience._parse(j, c),
      _ => BalanceExperience._parse(j, c),
    };
  }
}

typedef _Common = ({String id, int version, String unitId, String promptId, String explanationId});

String _str(Map m, String k, String where) {
  final v = m[k];
  if (v is! String || v.isEmpty) throw FormatException('$where: $k は空でない文字列');
  return v;
}

List<Map> _maps(Object? v, String id, String key, {int min = 1, int max = 100}) {
  if (v is! List || v.length < min || v.length > max || v.any((e) => e is! Map)) {
    throw FormatException('$id: $key は $min〜$max 個のオブジェクト');
  }
  return [for (final e in v) e as Map];
}

double _num(Map m, String k, String id) {
  final v = m[k];
  if (v is! num || v.isNaN || v.isInfinite) throw FormatException('$id: $k は数');
  return v.toDouble();
}

void _onlyKeys(Map m, Set<String> keys, String id, String where) {
  if (m.keys.any((k) => !keys.contains(k))) throw FormatException('$id: $where は ${keys.join('・')} だけ');
}

// ───────────────────────── sort（仕分け）─────────────────────────

/// 仕分けの結果。
class SortResult {
  const SortResult({required this.correct, required this.wrong, required this.unplaced});

  /// 正しい入れ物に入っているもの。
  final List<String> correct;

  /// 違う入れ物に入っているもの。
  final List<String> wrong;

  /// まだどこにも入れていないもの。
  final List<String> unplaced;

  /// すべて正しく入っている。
  bool get complete => wrong.isEmpty && unplaced.isEmpty;
}

/// 言葉・物・出来事を入れ物に分ける（言葉の分類、地形の分類、物質の分類など）。
class SortExperience extends Experience {
  const SortExperience._({
    required super.id,
    required super.version,
    required super.unitId,
    required super.promptId,
    required super.explanationId,
    required this.bins,
    required this.items,
  });

  /// 入れ物の ID。
  final List<String> bins;

  /// 入れるもの（ID → 正しい入れ物）。順序は JSON のまま。
  final Map<String, String> items;

  @override
  String get kind => 'sort';

  factory SortExperience._parse(Map<String, dynamic> j, _Common c) {
    final bins = [for (final b in _maps(j['bins'], c.id, 'bins', min: 2, max: 10)) _binId(b, c.id)];
    if (bins.toSet().length != bins.length) throw FormatException('${c.id}: bins の id が重複');
    final items = <String, String>{};
    for (final m in _maps(j['items'], c.id, 'items', min: 2, max: 30)) {
      _onlyKeys(m, const {'id', 'bin'}, c.id, 'items');
      final id = _str(m, 'id', '${c.id}.items');
      final bin = _str(m, 'bin', '${c.id}.items');
      if (!bins.contains(bin)) throw FormatException('${c.id}: $id の bin $bin が bins にありません');
      if (items.containsKey(id)) throw FormatException('${c.id}: items の id が重複: $id');
      items[id] = bin;
    }
    return SortExperience._(
      id: c.id, version: c.version, unitId: c.unitId, promptId: c.promptId, explanationId: c.explanationId,
      bins: bins,
      items: items,
    );
  }

  static String _binId(Map m, String id) {
    _onlyKeys(m, const {'id'}, id, 'bins');
    return _str(m, 'id', '$id.bins');
  }

  /// 入れ方 [placement]（もの ID → 入れ物 ID）の判定。知らない ID は無視する。
  SortResult check(Map<String, String> placement) {
    final correct = <String>[], wrong = <String>[], unplaced = <String>[];
    for (final e in items.entries) {
      final p = placement[e.key];
      if (p == null) {
        unplaced.add(e.key);
      } else if (p == e.value) {
        correct.add(e.key);
      } else {
        wrong.add(e.key);
      }
    }
    return SortResult(correct: correct, wrong: wrong, unplaced: unplaced);
  }
}

// ───────────────────────── link（つなぎ）─────────────────────────

/// つなぎの結果。辺は `from>to`（向きなしのときは ID の小さい方を先にそろえる）。
class LinkResult {
  const LinkResult({required this.correct, required this.missing, required this.extra, this.reversed = const []});

  final List<String> correct, missing, extra;

  /// 余分な辺のうち、向きだけが逆のもの（原因と結果の取り違え。向きありのときだけ。誤解の型 `cause_effect_reversed`）。
  /// `extra` にも含まれる。
  final List<String> reversed;

  /// 過不足なくつながっている。
  bool get complete => missing.isEmpty && extra.isEmpty;
}

/// 点を線（矢印）でつなぐ（因果の矢印、地層の順、語と意味など）。
class LinkExperience extends Experience {
  const LinkExperience._({
    required super.id,
    required super.version,
    required super.unitId,
    required super.promptId,
    required super.explanationId,
    required this.nodes,
    required this.edges,
    required this.directed,
  });

  final List<String> nodes;

  /// 正しい辺（`from>to`）。
  final List<String> edges;
  final bool directed;

  @override
  String get kind => 'link';

  factory LinkExperience._parse(Map<String, dynamic> j, _Common c) {
    final rn = j['nodes'];
    if (rn is! List || rn.length < 2 || rn.length > 30 || rn.any((e) => e is! String || e.isEmpty)) {
      throw FormatException('${c.id}: nodes は 2〜30 個の ID');
    }
    final nodes = [for (final n in rn) n as String];
    if (nodes.toSet().length != nodes.length) throw FormatException('${c.id}: nodes が重複');
    final directed = j['directed'] ?? true;
    if (directed is! bool) throw FormatException('${c.id}: directed は真偽');
    final edges = <String>[];
    for (final m in _maps(j['edges'], c.id, 'edges', max: 100)) {
      _onlyKeys(m, const {'from', 'to'}, c.id, 'edges');
      final f = _str(m, 'from', '${c.id}.edges'), t = _str(m, 'to', '${c.id}.edges');
      if (!nodes.contains(f) || !nodes.contains(t)) throw FormatException('${c.id}: 辺 $f>$t の点が nodes にありません');
      if (f == t) throw FormatException('${c.id}: 自分への辺: $f');
      final key = edgeKey(f, t, directed: directed);
      if (edges.contains(key)) throw FormatException('${c.id}: 辺が重複: $key');
      edges.add(key);
    }
    return LinkExperience._(
      id: c.id, version: c.version, unitId: c.unitId, promptId: c.promptId, explanationId: c.explanationId,
      nodes: nodes,
      edges: edges,
      directed: directed,
    );
  }

  /// 辺の表し方。向きなしは ID の小さい方を先にする。
  static String edgeKey(String from, String to, {bool directed = true}) =>
      directed || from.compareTo(to) <= 0 ? '$from>$to' : '$to>$from';

  static String _flip(String key) {
    final i = key.indexOf('>');
    return '${key.substring(i + 1)}>${key.substring(0, i)}';
  }

  /// つないだ辺 [made]（`(from, to)`）の判定。点にない辺や自分への辺は余分として数える。重複は 1 本。
  LinkResult check(Iterable<(String, String)> made) {
    final keys = <String>{for (final (f, t) in made) edgeKey(f, t, directed: directed)};
    return LinkResult(
      correct: [for (final e in edges) if (keys.contains(e)) e],
      missing: [for (final e in edges) if (!keys.contains(e)) e],
      extra: [for (final k in keys.toList()..sort()) if (!edges.contains(k)) k],
      // 向きなしの辺は ID の小さい方を先にそろえてあるので、逆向きの辺は正解の中に現れない（向きありのときだけ出る）
      reversed: [for (final k in keys.toList()..sort()) if (!edges.contains(k) && edges.contains(_flip(k))) k],
    );
  }
}

// ───────────────────────── dial（ダイヤル）─────────────────────────

/// ダイヤルの結果。
class DialResult {
  const DialResult({required this.value, required this.distance, required this.reached});

  /// 目盛に合わせた値。
  final double value;

  /// 目標との差（絶対値）。
  final double distance;
  final bool reached;
}

/// ダイヤル（目盛）を回して目標に合わせる（時差、角度、縮尺、温度など）。
class DialExperience extends Experience {
  const DialExperience._({
    required super.id,
    required super.version,
    required super.unitId,
    required super.promptId,
    required super.explanationId,
    required this.min,
    required this.max,
    required this.step,
    required this.initial,
    required this.target,
    required this.tolerance,
  });

  final double min, max, step, initial, target;

  /// 目標との差がこれ以下なら合っている（0 なら一致）。
  final double tolerance;

  @override
  String get kind => 'dial';

  factory DialExperience._parse(Map<String, dynamic> j, _Common c) {
    final min = _num(j, 'min', c.id), max = _num(j, 'max', c.id), step = _num(j, 'step', c.id);
    if (!(step > 0) || step > max - min) throw FormatException('${c.id}: step は 0 より大きく、範囲以下');
    final tol = j.containsKey('tolerance') ? _num(j, 'tolerance', c.id) : 0.0;
    if (tol < 0) throw FormatException('${c.id}: tolerance は 0 以上');
    final d = DialExperience._(
      id: c.id, version: c.version, unitId: c.unitId, promptId: c.promptId, explanationId: c.explanationId,
      min: min, max: max, step: step,
      initial: _num(j, 'initial', c.id),
      target: _num(j, 'target', c.id),
      tolerance: tol,
    );
    if (d.count > 10000) throw FormatException('${c.id}: 目盛が多すぎます');
    if (!d.onGrid(d.initial)) throw FormatException('${c.id}: initial は目盛の上の値');
    if (!d.onGrid(d.target)) throw FormatException('${c.id}: target は目盛の上の値');
    return d;
  }

  int get count => ((max - min) / step + 1e-9).floor() + 1;

  bool onGrid(double v) {
    if (v < min - 1e-9 || v > max + 1e-9) return false;
    final k = (v - min) / step;
    return (k - k.roundToDouble()).abs() < 1e-9;
  }

  /// 最も近い目盛の値にする（範囲外は端）。
  double snap(double v) {
    final k = ((v - min) / step).round().clamp(0, count - 1);
    return ((min + k * step) * 1e9).roundToDouble() / 1e9;
  }

  /// ダイヤルの値 [v] の判定（目盛に合わせてから比べる）。
  DialResult check(double v) {
    final s = snap(v);
    final dist = (s - target).abs();
    return DialResult(value: s, distance: dist, reached: dist <= tolerance + 1e-9);
  }
}

// ───────────────────────── balance（天秤）─────────────────────────

/// 天秤の傾き。重い方に傾く。
enum Tilt { left, right, even }

/// 天秤の結果。
class BalanceResult {
  const BalanceResult({required this.left, required this.right, required this.tilt, required this.solved});

  /// 左右の重さの合計（最初から載っているものを含む）。
  final double left, right;
  final Tilt tilt;

  /// つりあい、かつ 1 つ以上載せている。
  final bool solved;
}

/// 天秤に載せてつりあわせる（方程式、てこ、密度、化学反応式の係数など）。
class BalanceExperience extends Experience {
  const BalanceExperience._({
    required super.id,
    required super.version,
    required super.unitId,
    required super.promptId,
    required super.explanationId,
    required this.items,
    required this.leftFixed,
    required this.rightFixed,
  });

  /// 載せるもの（ID → 重さ）。順序は JSON のまま。
  final Map<String, double> items;

  /// 最初から載っている重さ。
  final List<double> leftFixed, rightFixed;

  @override
  String get kind => 'balance';

  /// 全探索できる最大の個数（3^n 通り）。
  static const maxItems = 12;

  factory BalanceExperience._parse(Map<String, dynamic> j, _Common c) {
    final items = <String, double>{};
    for (final m in _maps(j['items'], c.id, 'items', min: 1, max: maxItems)) {
      _onlyKeys(m, const {'id', 'weight'}, c.id, 'items');
      final id = _str(m, 'id', '${c.id}.items');
      final w = _num(m, 'weight', '${c.id}.$id');
      if (!(w > 0)) throw FormatException('${c.id}: $id の weight は 0 より大きい');
      if (items.containsKey(id)) throw FormatException('${c.id}: items の id が重複: $id');
      items[id] = w;
    }
    List<double> fixed(String k) {
      final v = j[k];
      if (v == null) return const [];
      if (v is! List || v.length > 30 || v.any((e) => e is! num || e.isNaN || e.isInfinite || e < 0)) {
        throw FormatException('${c.id}: $k は 0 以上の数の並び');
      }
      return [for (final e in v) (e as num).toDouble()];
    }

    return BalanceExperience._(
      id: c.id, version: c.version, unitId: c.unitId, promptId: c.promptId, explanationId: c.explanationId,
      items: items,
      leftFixed: fixed('leftFixed'),
      rightFixed: fixed('rightFixed'),
    );
  }

  /// 載せ方 [sides]（もの ID → `left` / `right`。載せていないものは書かない）の判定。
  /// 知らない ID・`left` `right` 以外は無視する。
  BalanceResult check(Map<String, String> sides) {
    var l = leftFixed.fold<double>(0, (s, w) => s + w);
    var r = rightFixed.fold<double>(0, (s, w) => s + w);
    var placed = 0;
    for (final e in items.entries) {
      final side = sides[e.key];
      if (side == 'left') {
        l += e.value;
        placed++;
      } else if (side == 'right') {
        r += e.value;
        placed++;
      }
    }
    final tilt = (l - r).abs() < 1e-9 ? Tilt.even : (l > r ? Tilt.left : Tilt.right);
    return BalanceResult(left: l, right: r, tilt: tilt, solved: tilt == Tilt.even && placed > 0);
  }

  /// つりあう載せ方（1 つ以上載せる）を最大 [limit] 通り。ヒントや、解があるかの検証に使う。
  List<Map<String, String>> solutions({int limit = 5}) {
    final ids = items.keys.toList();
    final out = <Map<String, String>>[];
    final sides = List.filled(ids.length, 0); // 0 載せない / 1 左 / 2 右
    void walk(int i) {
      if (out.length >= limit) return;
      if (i == ids.length) {
        final m = {
          for (var k = 0; k < ids.length; k++)
            if (sides[k] != 0) ids[k]: sides[k] == 1 ? 'left' : 'right',
        };
        if (check(m).solved) out.add(m);
        return;
      }
      for (var s = 0; s < 3; s++) {
        sides[i] = s;
        walk(i + 1);
      }
    }

    walk(0);
    return out;
  }
}

// ───────────────────────── timeline（年表づくり）─────────────────────────

/// 年表づくりの結果。
class TimelineResult {
  const TimelineResult({required this.reversedPairs, required this.unplaced});

  /// 置いた順が逆になっている組（`(先のはずの出来事, 後のはずの出来事)`。置いた順で、組の並びは (先に置いた方, 後に置いた方) の順）。
  /// 「A は B より前」のような前後の言葉でフィードバックする。
  final List<(String, String)> reversedPairs;

  /// まだ置いていない出来事。
  final List<String> unplaced;

  /// 全部置いて、前後がすべて正しい。
  bool get complete => reversedPairs.isEmpty && unplaced.isEmpty;

  /// 前後が逆になっている出来事の ID（置いた順・重複なし）。
  List<String> get misplaced {
    final seen = <String>{};
    return [
      for (final (a, b) in reversedPairs) ...[
        if (seen.add(a)) a,
        if (seen.add(b)) b,
      ],
    ];
  }
}

/// 出来事のカードを年表に並べる（年表づくり）。置き方の誤りを「前後」で返す。
class TimelineExperience extends Experience {
  const TimelineExperience._({
    required super.id,
    required super.version,
    required super.unitId,
    required super.promptId,
    required super.explanationId,
    required this.events,
  });

  /// 出来事（古い順。同じ年は `order` の小さい方が先）。ID → 西暦（紀元前は負）。
  final List<({String id, int year, int order})> events;

  @override
  String get kind => 'timeline';

  /// 出来事の最大数。
  static const maxEvents = 30;

  factory TimelineExperience._parse(Map<String, dynamic> j, _Common c) {
    final list = <({String id, int year, int order})>[];
    for (final m in _maps(j['events'], c.id, 'events', min: 2, max: maxEvents)) {
      _onlyKeys(m, const {'id', 'year', 'order'}, c.id, 'events');
      final id = _str(m, 'id', '${c.id}.events');
      final y = m['year'], o = m['order'] ?? 0;
      if (y is! int || y == 0) throw FormatException('${c.id}: $id の year は 0 でない整数の年（紀元前は負）');
      if (o is! int) throw FormatException('${c.id}: $id の order は整数');
      if (list.any((e) => e.id == id)) throw FormatException('${c.id}: events の id が重複: $id');
      if (list.any((e) => e.year == y && e.order == o)) {
        throw FormatException('${c.id}: $id は同じ年・同じ order の出来事があり、前後が決まりません');
      }
      list.add((id: id, year: y, order: o));
    }
    list.sort((a, b) {
      final d = a.year.compareTo(b.year);
      return d != 0 ? d : a.order.compareTo(b.order);
    });
    return TimelineExperience._(
      id: c.id, version: c.version, unitId: c.unitId, promptId: c.promptId, explanationId: c.explanationId,
      events: list,
    );
  }

  /// 正しい順（古い順）の出来事 ID。
  List<String> get order => [for (final e in events) e.id];

  /// 置いた順 [placed]（出来事 ID。知らない ID と重複は無視）の判定。
  TimelineResult check(List<String> placed) {
    final rank = {for (var i = 0; i < events.length; i++) events[i].id: i};
    final seq = <String>[];
    for (final p in placed) {
      if (rank.containsKey(p) && !seq.contains(p)) seq.add(p);
    }
    final pairs = <(String, String)>[];
    for (var i = 0; i < seq.length; i++) {
      for (var k = i + 1; k < seq.length; k++) {
        if (rank[seq[i]]! > rank[seq[k]]!) pairs.add((seq[i], seq[k]));
      }
    }
    return TimelineResult(
      reversedPairs: pairs,
      unplaced: [for (final e in events) if (!seq.contains(e.id)) e.id],
    );
  }
}

// ───────────────────────── 集まりと検証 ─────────────────────────

/// 体験の集まり（`experiences.json`）。
class ExperienceSet {
  const ExperienceSet(this.experiences);

  final List<Experience> experiences;

  /// `{"version":1,"experiences":[…]}`。読めなければ [FormatException]。
  factory ExperienceSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('体験の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('体験の JSON はオブジェクトです');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['experiences'];
    if (raw is! List) throw const FormatException('experiences が必要です');
    final out = [for (final e in raw) Experience.fromJson(Map<String, dynamic>.from(e as Map))];
    final ids = <String>{};
    for (final e in out) {
      if (!ids.add(e.id)) throw FormatException('id が重複しています: ${e.id}');
    }
    return ExperienceSet(out);
  }
}

/// 体験の検証。エラー: `experience_unit_missing`（単元がない）・`experience_goal_unreachable`
/// （つりあう載せ方がない）・`experience_initial_is_goal`（最初から目標を満たしている: 天秤が最初からつりあう・
/// ダイヤルが最初から目標）。警告: `experience_bin_empty`（正解のものが 1 つも無い入れ物）。
List<ValidationIssue> validateExperiences(ExperienceSet set, {required UnitTree tree}) {
  final issues = <ValidationIssue>[];
  void add(IssueSeverity s, String code, String id, String msg) => issues.add(ValidationIssue(s, code, id, msg));
  for (final e in set.experiences) {
    if (tree[e.unitId] == null) add(IssueSeverity.error, 'experience_unit_missing', e.id, '単元 ${e.unitId} がありません');
    switch (e) {
      case SortExperience():
        for (final b in e.bins) {
          if (!e.items.values.contains(b)) add(IssueSeverity.warning, 'experience_bin_empty', e.id, '入れ物 $b に入るものがありません');
        }
      case LinkExperience():
        break;
      case DialExperience():
        if (e.check(e.initial).reached) {
          add(IssueSeverity.error, 'experience_initial_is_goal', e.id, '最初の値がすでに目標に合っています');
        }
      case TimelineExperience():
        break;
      case BalanceExperience():
        if ((e.leftFixed.fold<double>(0, (s, w) => s + w) - e.rightFixed.fold<double>(0, (s, w) => s + w)).abs() < 1e-9) {
          add(IssueSeverity.error, 'experience_initial_is_goal', e.id, '最初からつりあっています');
        }
        if (e.solutions(limit: 1).isEmpty) {
          add(IssueSeverity.error, 'experience_goal_unreachable', e.id, 'つりあう載せ方がありません');
        }
    }
  }
  return issues;
}
