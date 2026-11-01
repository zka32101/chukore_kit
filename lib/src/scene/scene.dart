import 'dart:convert';

import '../bank/question_bank.dart';
import '../scope/unit_tree.dart';

/// 場面（現実の具体例）。授業やレッスンの導入、問題の題材に使う「身近な場面」の目録 `scenes.json`。
/// 例: ボールを投げたときの軌道（関数 y=ax²）、影の長さで木の高さを測る（相似）、海外の試合の中継時刻（時差）。
/// 場面の本文は ID だけを持ち、文言はコンテンツ側（国・言語ごと。その国の暮らしに合う場面を選べる）。
/// 場面は型（`MathTemplate.scene`）とレッスンの導入（`HookBlock.scene`）から ID で参照する。
class Scene {
  const Scene({required this.id, required this.titleId, required this.textId, required this.unitIds});

  final String id;

  /// 場面の名前（文言の ID）。
  final String titleId;

  /// 場面の説明（文言の ID）。
  final String textId;

  /// この場面を使える単元。
  final List<String> unitIds;

  static const _keys = {'id', 'titleId', 'textId', 'unitIds'};

  /// 読めなければ [FormatException]。
  factory Scene.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('場面の未知のキー: ${unknown.join(', ')}');
    String str(String k) {
      final v = j[k];
      if (v is! String || v.isEmpty) throw FormatException('場面: $k は空でない文字列');
      return v;
    }

    final id = str('id');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('場面の id は英数字と _ だけ: $id');
    final u = j['unitIds'];
    if (u is! List || u.isEmpty || u.length > 20 || u.any((e) => e is! String || e.isEmpty) || u.toSet().length != u.length) {
      throw FormatException('$id: unitIds は 1〜20 個の単元 ID（重複なし）');
    }
    return Scene(id: id, titleId: str('titleId'), textId: str('textId'), unitIds: [for (final e in u) e as String]);
  }
}

/// 場面の集まり（`scenes.json`）。
class SceneSet {
  const SceneSet(this.scenes);

  final List<Scene> scenes;

  Set<String> get ids => {for (final s in scenes) s.id};

  /// `{"version":1,"scenes":[…]}`。読めなければ [FormatException]。
  factory SceneSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('場面の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('場面の JSON はオブジェクトです');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['scenes'];
    if (raw is! List) throw const FormatException('scenes が必要です');
    final out = [for (final s in raw) Scene.fromJson(Map<String, dynamic>.from(s as Map))];
    final ids = <String>{};
    for (final s in out) {
      if (!ids.add(s.id)) throw FormatException('id が重複しています: ${s.id}');
    }
    return SceneSet(out);
  }
}

/// 場面の検証。エラー: `scene_unit_missing`（単元がない）。
List<ValidationIssue> validateScenes(SceneSet set, {required UnitTree tree}) {
  final issues = <ValidationIssue>[];
  for (final s in set.scenes) {
    for (final u in s.unitIds) {
      if (tree[u] == null) {
        issues.add(ValidationIssue(IssueSeverity.error, 'scene_unit_missing', s.id, '単元 $u がありません'));
      }
    }
  }
  return issues;
}
