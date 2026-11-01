import 'dart:convert';
import 'dart:math';

import '../bank/question_bank.dart';
import '../scope/unit_tree.dart';

/// 証明の問題（合同・相似など）。証明を「主張（だから…）と根拠（なぜなら…）の並び」として持ち、
/// 2 つの遊び方で採点する: ①手順を並べる（[gradeProofOrder]）②各行の根拠を語群から選ぶ（[gradeProofReasons]）。
/// 文言はすべて文言の ID（`texts.json`）。国・言語ごとに書き方が違っても同じ仕組みで使える。
/// 責めない設計: 採点は「どこがちがうか」を返すだけで、点や順位は付けない。
class ProofReason {
  const ProofReason({required this.id, required this.textId});

  final String id;
  final String textId;
}

class ProofStep {
  const ProofStep({
    required this.id,
    required this.claimId,
    required this.reasonId,
    required this.after,
  });

  final String id;

  /// この行の主張（文言の ID）。
  final String claimId;

  /// この行の根拠（[ProofSpec.reasons] の ID）。
  final String reasonId;

  /// この行より前に書かれていなければならない行（前の行だけを指せる）。
  final List<String> after;
}

/// 手順を並べる問題の「まぎらわしい行」（証明に要らない・誤った主張）。
class ProofDecoy {
  const ProofDecoy({
    required this.id,
    required this.claimId,
    required this.tag,
  });

  final String id;
  final String claimId;

  /// つまずきの型（例: `used_alternate_angle`）。
  final String tag;
}

class ProofSpec {
  const ProofSpec({
    required this.id,
    required this.unitId,
    required this.titleId,
    required this.givenId,
    required this.goalId,
    required this.reasons,
    required this.steps,
    required this.decoys,
  });

  final String id;
  final String unitId;
  final String titleId;

  /// 仮定・結論（文言の ID）。
  final String givenId, goalId;

  /// 根拠の語群。どの行にも使われないものは、選択肢の「まぎらわしい根拠」になる。
  final List<ProofReason> reasons;

  /// 正しい証明（書く順）。
  final List<ProofStep> steps;
  final List<ProofDecoy> decoys;

  ProofStep stepById(String id) => steps.firstWhere((s) => s.id == id);

  Set<String> get usedReasonIds => {for (final s in steps) s.reasonId};

  /// 選択肢にだけ出る根拠。
  List<ProofReason> get decoyReasons => [
    for (final r in reasons)
      if (!usedReasonIds.contains(r.id)) r,
  ];

  /// 画面に出す文言の ID（検証・文言の突き合わせ用）。
  Iterable<String> get textIds => [
    titleId,
    givenId,
    goalId,
    for (final r in reasons) r.textId,
    for (final s in steps) s.claimId,
    for (final d in decoys) d.claimId,
  ];

  /// 並べ替えの出題: 正しい行とまぎらわしい行を [seed] でシャッフルした行 ID。
  /// 正しい順（書いた順）と同じ並びにはならない。
  List<String> shuffledStepIds(int seed, {bool withDecoys = true}) {
    final ids = [
      for (final s in steps) s.id,
      if (withDecoys)
        for (final d in decoys) d.id,
    ];
    final correct = [for (final s in steps) s.id];
    var out = [...ids]..shuffle(Random(seed));
    // 正しい順と同じ並びのままにならないよう、ずらす
    if (_same(out, correct) && out.length > 1) {
      out = [...out.skip(1), out.first];
    }
    return out;
  }

  /// 根拠の選択肢（その行の正解 + 語群のまぎらわしい根拠）を [seed] でシャッフルした根拠 ID。
  List<String> reasonChoices(int seed) =>
      [for (final r in reasons) r.id]..shuffle(Random(seed));

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const _keys = {
    'id',
    'unitId',
    'titleId',
    'givenId',
    'goalId',
    'reasons',
    'steps',
    'decoys',
  };

  /// 読めなければ [FormatException]。
  factory ProofSpec.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) {
      throw FormatException('証明の未知のキー: ${unknown.join(', ')}');
    }
    String str(Map<String, dynamic> m, String k, String where) {
      final v = m[k];
      if (v is! String || v.isEmpty) {
        throw FormatException('$where: $k は空でない文字列');
      }
      return v;
    }

    final id = str(j, 'id', '証明');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) {
      throw FormatException('証明の id は英数字と _ だけ: $id');
    }
    List<Map<String, dynamic>> list(String k, {bool required = true}) {
      final v = j[k];
      if (v == null && !required) return const [];
      if (v is! List || (required && v.isEmpty)) {
        throw FormatException('$id: $k が必要です');
      }
      return [for (final e in v) Map<String, dynamic>.from(e as Map)];
    }

    final reasons = [
      for (final r in list('reasons'))
        ProofReason(
          id: str(r, 'id', '$id の根拠'),
          textId: str(r, 'textId', '$id の根拠'),
        ),
    ];
    final steps = <ProofStep>[];
    for (final s in list('steps')) {
      final a = s['after'];
      if (a != null && (a is! List || a.any((e) => e is! String))) {
        throw FormatException('$id: after は行 ID の配列');
      }
      steps.add(
        ProofStep(
          id: str(s, 'id', '$id の行'),
          claimId: str(s, 'claimId', '$id の行'),
          reasonId: str(s, 'reasonId', '$id の行'),
          after: [for (final e in (a as List? ?? const [])) e as String],
        ),
      );
    }
    final decoys = [
      for (final d in list('decoys', required: false))
        ProofDecoy(
          id: str(d, 'id', '$id のまぎらわしい行'),
          claimId: str(d, 'claimId', '$id のまぎらわしい行'),
          tag: str(d, 'tag', '$id のまぎらわしい行'),
        ),
    ];
    return ProofSpec(
      id: id,
      unitId: str(j, 'unitId', id),
      titleId: str(j, 'titleId', id),
      givenId: str(j, 'givenId', id),
      goalId: str(j, 'goalId', id),
      reasons: reasons,
      steps: steps,
      decoys: decoys,
    );
  }
}

/// 証明の集まり（`proofs.json`）。
class ProofSet {
  const ProofSet(this.proofs);

  final List<ProofSpec> proofs;

  /// `{"version":1,"proofs":[…]}`。読めなければ [FormatException]。
  factory ProofSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('証明の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) {
      throw const FormatException('証明の JSON はオブジェクトです');
    }
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['proofs'];
    if (raw is! List) throw const FormatException('proofs が必要です');
    final out = [
      for (final p in raw)
        ProofSpec.fromJson(Map<String, dynamic>.from(p as Map)),
    ];
    final ids = <String>{};
    for (final p in out) {
      if (!ids.add(p.id)) throw FormatException('id が重複しています: ${p.id}');
    }
    return ProofSet(out);
  }
}

/// 証明の検証。
/// エラー: `proof_unit_missing`・`proof_too_short`（行が 3 つ未満）・`proof_id_duplicate`（行・根拠・まぎらわしい行の ID の重複）・
/// `proof_reason_missing`（行の根拠が語群にない）・`proof_after_invalid`（after が前の行を指していない）・
/// `proof_not_connected`（最後の行に結びつかない行がある。証明は最後の行が結論）。
/// 警告: `proof_no_decoy_reason`（まぎらわしい根拠がない）・`proof_no_decoy_step`。
List<ValidationIssue> validateProofs(ProofSet set, {required UnitTree tree}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  void warn(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.warning, code, id, msg));
  for (final p in set.proofs) {
    if (tree[p.unitId] == null) {
      err('proof_unit_missing', p.id, '単元 ${p.unitId} がありません');
    }
    if (p.steps.length < 3) {
      err('proof_too_short', p.id, '行は 3 つ以上（${p.steps.length}）');
    }
    final ids = <String>{};
    for (final id in [
      for (final s in p.steps) s.id,
      for (final d in p.decoys) d.id,
      for (final r in p.reasons) r.id,
    ]) {
      if (!ids.add(id)) err('proof_id_duplicate', p.id, '$id が重複しています');
    }
    final reasonIds = {for (final r in p.reasons) r.id};
    final seen = <String>{};
    for (final s in p.steps) {
      if (!reasonIds.contains(s.reasonId)) {
          err(
            'proof_reason_missing',
            p.id,
            '${s.id} の根拠 ${s.reasonId} が語群にありません',
          );
      }
      for (final a in s.after) {
        if (!seen.contains(a)) {
            err(
              'proof_after_invalid',
              p.id,
              '${s.id} の after $a は、前に書かれた行ではありません',
            );
        }
      }
      seen.add(s.id);
    }
    if (p.steps.isNotEmpty) {
      // 最後の行から after をたどって、すべての行に着くこと
      final byId = {for (final s in p.steps) s.id: s};
      final reach = <String>{};
      void walk(String id) {
        if (!reach.add(id)) return;
        for (final a in byId[id]?.after ?? const <String>[]) {
          walk(a);
        }
      }

      walk(p.steps.last.id);
      for (final s in p.steps) {
        if (!reach.contains(s.id)) {
          err('proof_not_connected', p.id, '${s.id} は結論に結びついていません');
        }
      }
    }
    if (p.decoyReasons.isEmpty) {
      warn('proof_no_decoy_reason', p.id, 'まぎらわしい根拠がありません');
    }
    if (p.decoys.isEmpty) warn('proof_no_decoy_step', p.id, 'まぎらわしい行がありません');
  }
  return issues;
}

/// 並べ替えの採点結果。
class ProofOrderResult {
  const ProofOrderResult({
    required this.correct,
    required this.decoyPicked,
    required this.missing,
    required this.misplaced,
  });

  /// 過不足なく、前提の順を守っている。
  final bool correct;

  /// 入れてしまったまぎらわしい行（ID）。
  final List<String> decoyPicked;

  /// 入れ忘れた正しい行（ID）。
  final List<String> missing;

  /// その行が前提とする行より前に置かれた、または前提が欠けている行（ID）。
  final List<String> misplaced;
}

/// 手順の並べ替えの採点。同じ前提で、順番が入れ替わってもよい行（例: 仮定 2 つ）は、どちらを先に置いても正解。
ProofOrderResult gradeProofOrder(ProofSpec spec, List<String> chosen) {
  final stepIds = {for (final s in spec.steps) s.id};
  final decoyIds = {for (final d in spec.decoys) d.id};
  final picked = [
    for (final c in chosen)
      if (decoyIds.contains(c)) c,
  ];
  final position = <String, int>{};
  for (var i = 0; i < chosen.length; i++) {
    position.putIfAbsent(chosen[i], () => i);
  }
  final missing = [
    for (final s in spec.steps)
      if (!position.containsKey(s.id)) s.id,
  ];
  final misplaced = <String>[];
  for (final s in spec.steps) {
    final at = position[s.id];
    if (at == null) continue;
    for (final a in s.after) {
      final pa = position[a];
      if (pa == null || pa > at) {
        misplaced.add(s.id);
        break;
      }
    }
  }
  final unknown = chosen.any(
    (c) => !stepIds.contains(c) && !decoyIds.contains(c),
  );
  final dup = chosen.toSet().length != chosen.length;
  return ProofOrderResult(
    correct:
        picked.isEmpty &&
        missing.isEmpty &&
        misplaced.isEmpty &&
        !unknown &&
        !dup,
    decoyPicked: picked,
    missing: missing,
    misplaced: misplaced,
  );
}

/// 根拠選びの採点結果。
class ProofReasonResult {
  const ProofReasonResult({
    required this.rightStepIds,
    required this.wrongStepIds,
    required this.blankStepIds,
  });

  final List<String> rightStepIds, wrongStepIds, blankStepIds;

  bool get correct => wrongStepIds.isEmpty && blankStepIds.isEmpty;
}

/// 各行の根拠選びの採点。[answers] は 行 ID → 選んだ根拠 ID。
ProofReasonResult gradeProofReasons(
  ProofSpec spec,
  Map<String, String> answers,
) {
  final right = <String>[], wrong = <String>[], blank = <String>[];
  for (final s in spec.steps) {
    final a = answers[s.id];
    if (a == null) {
      blank.add(s.id);
    } else if (a == s.reasonId) {
      right.add(s.id);
    } else {
      wrong.add(s.id);
    }
  }
  return ProofReasonResult(
    rightStepIds: right,
    wrongStepIds: wrong,
    blankStepIds: blank,
  );
}
