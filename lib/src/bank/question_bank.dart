import '../models/models.dart';
import '../question/text_match.dart';
import '../scope/unit_tree.dart';
import '../teacher/teacher_mode.dart';

enum IssueSeverity { error, warning }

/// 検証で見つかった問題。[code] は機械で扱える識別子、[subjectId] は問題・単元などのID。
class ValidationIssue {
  const ValidationIssue(this.severity, this.code, this.subjectId, this.message);

  final IssueSeverity severity;
  final String code;
  final String subjectId;
  final String message;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '${isError ? 'ERROR' : 'WARN '} $code [$subjectId] $message';
}

bool hasErrors(Iterable<ValidationIssue> issues) => issues.any((i) => i.isError);

/// `checkAnswer` が扱う問題タイプ。
const knownQuestionTypes = {'choice', 'map', 'numeric', 'order', 'timeline', 'text', 'multi'};

final _thousands = RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$');
final _tagPattern = RegExp(r'^[a-z][a-z0-9_]*$');

const _questionKeys = ['id', 'unitId', 'type', 'difficulty', 'answer', 'explanationId'];
const _mistakeKeys = [
  'id', 'tag', 'questionId', 'sourceChoiceId', 'statement', 'fixChoices', 'correctChoice', 'explanation',
];

/// 読み込んだ問題集。壊れた項目は [issues] に報告して読み飛ばす。
class QuestionBankData {
  const QuestionBankData(this.questions, this.mistakeLines, this.issues);

  final List<Question> questions;
  final List<MistakeLine> mistakeLines;
  final List<ValidationIssue> issues;
}

/// JSON から問題集を読む。形式: `{"version": 1, "questions": [...], "mistakeLines": [...]}`。
/// 必須項目の欠け・型の違い・基準正答率の範囲外は、その項目だけ `malformed` として報告して飛ばす。
QuestionBankData parseQuestionBank(Map<String, dynamic> json) {
  final issues = <ValidationIssue>[];
  T? tryParse<T>(Object? raw, String kind, List<String> required, T Function(Map<String, dynamic>) build) {
    String id = '?';
    void bad(String why) =>
        issues.add(ValidationIssue(IssueSeverity.error, 'malformed', id, '$kind を読めません: $why'));
    if (raw is! Map) {
      bad('オブジェクトではありません');
      return null;
    }
    final m = Map<String, dynamic>.from(raw);
    id = (m['id'] as Object?)?.toString() ?? '?';
    final missing = [for (final k in required) if (m[k] == null) k];
    if (missing.isNotEmpty) {
      bad('必須項目がありません: ${missing.join(', ')}');
      return null;
    }
    try {
      return build(m);
    } catch (e) {
      bad(e is AssertionError || (e is FormatException && e.message == Question.difficultyRangeError)
          ? '基準正答率は 0〜1 にしてください' : '項目の型が違います（${_short(e)}）');
      return null;
    }
  }

  final questions = <Question>[
    for (final r in (json['questions'] as List? ?? const []))
      ?tryParse(r, 'question', _questionKeys, Question.fromJson),
  ];
  final lines = <MistakeLine>[
    for (final r in (json['mistakeLines'] as List? ?? const []))
      ?tryParse(r, 'mistakeLine', _mistakeKeys, MistakeLine.fromJson),
  ];
  return QuestionBankData(questions, lines, issues);
}

String _short(Object e) {
  final t = e.toString().replaceAll('\n', ' ');
  return t.length > 120 ? '${t.substring(0, 120)}…' : t;
}

/// 単元の一覧を検証する（ID の重複・親の欠け・循環・件数）。
List<ValidationIssue> validateUnitList(List<Unit> units) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  void warn(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.warning, code, id, msg));

  final byId = <String, Unit>{};
  for (final u in units) {
    if (byId.containsKey(u.id)) {
      err('duplicate_unit_id', u.id, '単元IDが重複しています');
    }
    byId[u.id] = u;
  }
  final parents = {for (final u in units) if (u.parentId != null) u.parentId!};
  for (final u in byId.values) {
    final p = u.parentId;
    if (p != null && !byId.containsKey(p)) {
      err('unit_parent_missing', u.id, '親の単元 $p がありません');
      continue;
    }
    // 循環: 親をたどって自分に戻る
    final seen = <String>{u.id};
    var cur = p;
    while (cur != null && byId.containsKey(cur)) {
      if (!seen.add(cur)) {
        err('unit_cycle', u.id, '親子関係が循環しています');
        break;
      }
      cur = byId[cur]!.parentId;
    }
    if (u.estimatedQuestions < 0) err('unit_negative_count', u.id, 'estimatedQuestions が負です');
    if (!parents.contains(u.id) && u.estimatedQuestions == 0) {
      warn('unit_no_estimate', u.id, '葉の単元で estimatedQuestions が 0（逆算の重みが付きません）');
    }
  }
  return _sorted(issues);
}

/// 問題集を単元ツリーと突き合わせて検証する。
/// エラーは出題・判定・克服判定が壊れるもの、警告は品質上の注意。
List<ValidationIssue> validateQuestionBank({
  required List<Question> questions,
  UnitTree? tree,
  List<MistakeLine> mistakeLines = const [],
}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  void warn(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.warning, code, id, msg));

  final byId = <String, Question>{};
  for (final q in questions) {
    if (byId.containsKey(q.id)) err('duplicate_question_id', q.id, '問題IDが重複しています');
    byId[q.id] = q;

    if (!knownQuestionTypes.contains(q.type)) {
      err('unknown_type', q.id, '未対応の問題タイプ: ${q.type}');
    }
    if (q.explanationId.trim().isEmpty) err('explanation_missing', q.id, 'explanationId が空です');
    if (q.version < 1) err('bad_version', q.id, 'version は 1 以上');
    if (!(q.difficulty >= 0 && q.difficulty <= 1)) {
      err('difficulty_out_of_range', q.id, '基準正答率は 0〜1 にしてください: ${q.difficulty}');
    } else if (q.difficulty == 0 || q.difficulty == 1) {
      warn('difficulty_extreme', q.id, '基準正答率が ${q.difficulty}（アプリ内偏差値の換算で分散が 0 になります）');
    }

    final uniqueChoices = q.choices.toSet();
    if (uniqueChoices.length != q.choices.length) err('choices_duplicate', q.id, '選択肢が重複しています');

    switch (q.type) {
      case 'choice' || 'map':
        if (q.choices.length < 2) err('choices_too_few', q.id, '選択肢は2つ以上');
        if (!uniqueChoices.contains(q.answer)) err('answer_not_in_choices', q.id, '正解 ${q.answer} が選択肢にありません');
      case 'numeric':
        final v = double.tryParse(q.answer.replaceAll(',', ''));
        if (v == null) {
          err('numeric_answer_invalid', q.id, '数値として読めない正解: ${q.answer}');
        } else if (q.answer.contains(',') && !_thousands.hasMatch(q.answer.trim())) {
          warn('numeric_answer_comma', q.id, '正解はピリオド区切りで書いてください（桁区切り以外のカンマは無視されます）: ${q.answer}');
        }
      case 'text':
        final alts = textAlternatives(q.answer);
        if (alts.any((a) => normalizeText(a).isEmpty)) {
          err('text_answer_empty', q.id, '正解（別解）が空です: "${q.answer}"（別解は | で区切ります）');
        } else if (alts.map(normalizeText).toSet().length != alts.length) {
          warn('text_alt_duplicate', q.id, '表記ゆれをそろえると同じになる別解があります: ${q.answer}');
        }
        if (q.choices.isNotEmpty) warn('choices_ignored', q.id, 'text では選択肢は使われません');
      case 'multi':
        final items = multiItems(q.answer);
        if (items.length < 2) err('multi_too_few', q.id, 'multi は 2 項目以上（項目は ; で区切ります）。1 項目なら text にしてください');
        final seen = <String, int>{};
        for (var i = 0; i < items.length; i++) {
          if (items[i].any((a) => normalizeText(a).isEmpty)) {
            err('multi_item_empty', q.id, '${i + 1} 番目の項目（別解）が空です: "${q.answer}"');
            continue;
          }
          for (final a in items[i]) {
            if (RegExp(r'[;；、,，\n\r]').hasMatch(a)) {
              err('multi_item_separator', q.id, '項目 "$a" に区切り文字（; 、 , 改行）が入っています。入力の区切りと区別できません');
            }
            final n = normalizeText(a);
            final other = seen[n];
            if (other != null && other != i) {
              err('multi_ambiguous', q.id, '"$a" が ${other + 1} 番目と ${i + 1} 番目の項目の両方に当たります');
            }
            seen[n] = i;
          }
        }
        if (q.choices.isNotEmpty) warn('choices_ignored', q.id, 'multi では選択肢は使われません');
      case 'order' || 'timeline':
        final ids = q.answer.split(',').map((e) => e.trim()).toList();
        if (ids.length < 2) err('order_too_few', q.id, '並べ替えは2つ以上');
        if (ids.toSet().length != ids.length) err('order_duplicate', q.id, '正解の順序にIDの重複があります');
        if (!(uniqueChoices.length == ids.length && uniqueChoices.containsAll(ids))) {
          err('order_choices_mismatch', q.id, '選択肢と正解の順序のIDが一致しません');
        }
    }

    if (q.misconceptionTags.isNotEmpty) {
      if (q.type != 'choice' && q.type != 'map') {
        warn('tags_ignored', q.id, '${q.type} では誤解の型は使われません');
      }
      for (final e in q.misconceptionTags.entries) {
        if (!uniqueChoices.contains(e.key)) {
          err('tag_choice_missing', q.id, '誤解の型の付いた選択肢 ${e.key} が選択肢にありません');
        } else if (e.key == q.answer) {
          err('tag_on_answer', q.id, '正解の選択肢に誤解の型 ${e.value} が付いています');
        }
        if (!_tagPattern.hasMatch(e.value)) {
          err('tag_format', q.id, '誤解の型は小文字・数字・アンダースコア: ${e.value}');
        }
      }
    }

    if (tree != null) {
      final u = tree[q.unitId];
      if (u == null) {
        err('unit_missing', q.id, '単元 ${q.unitId} が単元ツリーにありません');
      } else if (!tree.isLeaf(u.id)) {
        warn('unit_not_leaf', q.id, '単元 ${u.id} は葉ではありません（葉の単元に付けると範囲選択・習熟度が正しく働きます）');
      }
    }
  }

  if (tree != null) {
    final used = {for (final q in questions) q.unitId};
    void walk(Iterable<Unit> us) {
      for (final u in us) {
        if (tree.isLeaf(u.id)) {
          if (!used.contains(u.id)) warn('unit_empty', u.id, '問題がありません');
        } else {
          walk(tree.childrenOf(u.id));
        }
      }
    }

    walk(tree.roots);
  }

  final lineIds = <String>{};
  for (final l in mistakeLines) {
    if (!lineIds.add(l.id)) err('duplicate_mistake_line_id', l.id, 'まちがいキャラのIDが重複しています');
    if (l.statement.trim().isEmpty) err('mistake_statement_empty', l.id, 'セリフが空です');
    if (l.explanation.trim().isEmpty) err('mistake_explanation_empty', l.id, '説明が空です');
    if (l.fixChoices.length < 2) err('mistake_choices_too_few', l.id, '直す選択肢は2つ以上');
    if (l.fixChoices.toSet().length != l.fixChoices.length) {
      err('mistake_choices_duplicate', l.id, '直す選択肢が重複しています');
    }
    if (!l.fixChoices.contains(l.correctChoice)) {
      err('mistake_correct_not_in_choices', l.id, '正解 ${l.correctChoice} が直す選択肢にありません');
    }
    final q = byId[l.questionId];
    if (q == null) {
      err('mistake_question_missing', l.id, '元の問題 ${l.questionId} がありません');
      continue;
    }
    if (!q.misconceptionTags.values.contains(l.tag)) {
      err('mistake_tag_mismatch', l.id, '元の問題 ${q.id} に誤解の型 ${l.tag} が付いていません');
    }
    if (q.misconceptionTags[l.sourceChoiceId] != l.tag) {
      err('mistake_source_mismatch', l.id,
          '元の問題 ${q.id} の選択肢 ${l.sourceChoiceId} に、誤解の型 ${l.tag} が付いていません');
    }
  }
  return _sorted(issues);
}

List<ValidationIssue> _sorted(List<ValidationIssue> issues) => [
      ...issues.where((i) => i.isError),
      ...issues.where((i) => !i.isError),
    ];
