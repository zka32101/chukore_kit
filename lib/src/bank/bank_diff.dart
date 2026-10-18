import 'dart:convert';

import '../models/models.dart';
import 'question_bank.dart';

/// 内容が変わった問題。[fromVersion] は変更前の版、[after] は変更後の問題（版は [fromVersion] より大きい）。
class QuestionChange {
  const QuestionChange({required this.fromVersion, required this.after});

  final int fromVersion;
  final Question after;

  String get id => after.id;
}

/// 2 つの問題集の差分。月ごとの差分配信（全体を送り直さない更新）に使う。
/// 配信と保存は各アプリ側で、ここは「差分を作る・検査する・適用する」だけを持つ。
///
/// 回答履歴は問題ID（と版）に結びつくので、内容を変えた問題は `version` を上げる決まりにしている
/// （[check] が上げ忘れを見つける）。適用後の問題集は、通常どおり `validateQuestionBank` で検証する。
class BankDiff {
  const BankDiff({this.added = const [], this.removed = const [], this.changed = const []});

  static const formatName = 'chukore_kit.bank_diff';
  static const formatVersion = 1;

  final List<Question> added;

  /// 削除された問題のID。
  final List<String> removed;
  final List<QuestionChange> changed;

  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;

  /// [from]（今の版）から [to]（新しい版）への差分。並びは [to] の順（削除は [from] の順）。
  factory BankDiff.between(List<Question> from, List<Question> to) {
    final before = {for (final q in from) q.id: q};
    final after = {for (final q in to) q.id: q};
    return BankDiff(
      added: [for (final q in to) if (!before.containsKey(q.id)) q],
      removed: [for (final q in from) if (!after.containsKey(q.id)) q.id],
      changed: [
        for (final q in to)
          if (before[q.id] case final old? when !_sameContent(old, q) || old.version != q.version)
            QuestionChange(fromVersion: old.version, after: q),
      ],
    );
  }

  /// 差分の検査。[from] は差分の元になった問題集。
  /// - 内容が変わったのに版が上がっていない／版が下がった: エラー
  /// - 内容は同じなのに版だけ上がった: 警告
  List<ValidationIssue> check(List<Question> from) {
    final before = {for (final q in from) q.id: q};
    final issues = <ValidationIssue>[];
    for (final c in changed) {
      final old = before[c.id];
      if (old == null) continue;
      final sameContent = _sameContent(old, c.after);
      if (c.after.version < old.version) {
        issues.add(ValidationIssue(IssueSeverity.error, 'version_decreased', c.id,
            '版が下がっています（${old.version} → ${c.after.version}）'));
      } else if (!sameContent && c.after.version == old.version) {
        issues.add(ValidationIssue(IssueSeverity.error, 'changed_without_version_bump', c.id,
            '内容が変わりましたが version が ${old.version} のままです（回答履歴の集計が古い内容と混ざります）。version を上げてください'));
      } else if (sameContent && c.after.version > old.version) {
        issues.add(ValidationIssue(IssueSeverity.warning, 'version_bumped_without_change', c.id,
            '内容は同じですが version が上がっています（${old.version} → ${c.after.version}）'));
      }
    }
    return [...issues.where((i) => i.isError), ...issues.where((i) => !i.isError)];
  }

  /// [base] に差分を当てた問題集を返す。並びは、削除を除き、変更は元の位置のまま、追加は最後。
  /// 差分の元と違う問題集（削除・変更する問題が無い、変更前の版が合わない、追加する問題がすでにある）に
  /// 当てようとしたら [StateError]。途中まで当たった状態は返さない。
  List<Question> apply(List<Question> base) {
    final byId = {for (final q in base) q.id: q};
    for (final id in removed) {
      if (!byId.containsKey(id)) throw StateError('削除する問題 $id が手元にありません（差分の元の版と違います）');
    }
    for (final c in changed) {
      final cur = byId[c.id];
      if (cur == null) throw StateError('変更する問題 ${c.id} が手元にありません（差分の元の版と違います）');
      if (cur.version != c.fromVersion) {
        throw StateError('問題 ${c.id} の版が合いません（手元 ${cur.version}、差分の元 ${c.fromVersion}）。順番に適用してください');
      }
    }
    for (final q in added) {
      if (byId.containsKey(q.id)) throw StateError('追加する問題 ${q.id} がすでにあります（差分を二重に当てていませんか）');
    }
    final drop = removed.toSet();
    final replace = {for (final c in changed) c.id: c.after};
    return [
      for (final q in base)
        if (!drop.contains(q.id)) replace[q.id] ?? q,
      ...added,
    ];
  }

  String toJsonString() => jsonEncode({
        'format': formatName,
        'version': formatVersion,
        'added': [for (final q in added) q.toJson()],
        'removed': removed,
        'changed': [for (final c in changed) {'fromVersion': c.fromVersion, 'question': c.after.toJson()}],
      });

  /// JSON 文字列から読む。形が不正なら [FormatException]。
  factory BankDiff.parse(String source) {
    try {
      final root = jsonDecode(source);
      if (root is! Map || root['format'] != formatName) {
        throw const FormatException('問題集の差分ファイルではありません');
      }
      final v = root['version'];
      if (v is! int || v < 1) throw const FormatException('差分の版が不正です');
      if (v > formatVersion) throw FormatException('新しい版の差分です（$v > $formatVersion）。アプリを更新してください');
      Question q(Object? j) => Question.fromJson(Map<String, dynamic>.from(j as Map));
      return BankDiff(
        added: [for (final j in root['added'] as List) q(j)],
        removed: [for (final id in root['removed'] as List) id as String],
        changed: [
          for (final j in root['changed'] as List)
            QuestionChange(fromVersion: (j as Map)['fromVersion'] as int, after: q(j['question'])),
        ],
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('問題集の差分ファイルを読めません（形が違います）');
    }
  }
}

bool _sameContent(Question a, Question b) =>
    a.unitId == b.unitId &&
    a.type == b.type &&
    a.difficulty == b.difficulty &&
    a.answer == b.answer &&
    a.explanationId == b.explanationId &&
    _listEq(a.choices, b.choices) &&
    _mapEq(a.misconceptionTags, b.misconceptionTags);

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
