import 'dart:convert';

import '../bank/question_bank.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';

/// レッスンのブロック 1 つ。種類ごとのクラスで、文言は ID だけを持つ（本文はコンテンツ側）。
sealed class LessonBlock {
  const LessonBlock();

  /// JSON の `type`。
  String get type;
}

/// 導入。なぜ学ぶか・身近な例。
class HookBlock extends LessonBlock {
  const HookBlock(this.textId, {this.scene});

  /// 導入の場面（現実の具体例。`scenes.json` の ID）。無ければ null。
  final String? scene;
  final String textId;
  @override
  String get type => 'hook';
}

/// 説明。
class TextBlock extends LessonBlock {
  const TextBlock(this.textId);
  final String textId;
  @override
  String get type => 'text';
}

/// 図。型 ID＋種（`template`・`seed`）か、コンテンツ側の図の ID（`figureId`）のどちらか。説明文の ID（`altId`）は必須。
class FigureBlock extends LessonBlock {
  const FigureBlock({required this.altId, this.template, this.seed, this.figureId});
  final String altId;
  final String? template;
  final int? seed;
  final String? figureId;
  @override
  String get type => 'figure';
}

/// 式の表示（`expr` は式か方程式）。
class FormulaBlock extends LessonBlock {
  const FormulaBlock(this.expr, {this.textId});
  final String expr;
  final String? textId;
  @override
  String get type => 'formula';
}

/// 例題。型 ID と種で問題を決め、途中式 [lines]（型の値を `{…}` で差し込む書き方）を 1 行ずつ見せる。
/// [target] は着く先（解の形など）、[form] は最後の行の形。[textIds] は行ごとの説明（行と同じ数か空）。
class ExampleBlock extends LessonBlock {
  const ExampleBlock({
    required this.template,
    required this.seed,
    required this.lines,
    this.target,
    this.form,
    this.textIds = const [],
  });
  final String template;
  final int seed;
  final List<String> lines;
  final String? target;
  final String? form;
  final List<String> textIds;
  @override
  String get type => 'example';
}

/// 体験への入口（体験型 `Exploration` か作図 `Construction` の ID）。
class ExploreBlock extends LessonBlock {
  const ExploreBlock({this.exploration, this.construction});
  final String? exploration;
  final String? construction;
  @override
  String get type => 'explore';
}

/// 確認クイズ（1〜3 問。問題 ID か変種 ID）。答えを見る前に解く。
class CheckBlock extends LessonBlock {
  const CheckBlock(this.questions);
  final List<String> questions;
  @override
  String get type => 'check';
}

/// つまずきの型の解説（「ここで間違えやすい」）。
class PitfallBlock extends LessonBlock {
  const PitfallBlock(this.tag, this.textId);
  final String tag;
  final String textId;
  @override
  String get type => 'pitfall';
}

/// 要点（2〜3 行）。
class SummaryBlock extends LessonBlock {
  const SummaryBlock(this.textIds);
  final List<String> textIds;
  @override
  String get type => 'summary';
}

/// レッスン 1 つ（教科書の 1 見開き。3〜5 分）。設計は docs/learning_model.md §3。
class Lesson {
  const Lesson({
    required this.id,
    required this.version,
    required this.unitId,
    required this.minutes,
    required this.titleId,
    required this.blocks,
    this.pre = const [],
  });

  final String id;
  final int version;
  final String unitId;
  final int minutes;
  final String titleId;

  /// 事前の確認（レッスンの前に解く 1〜2 問）。「知っていたか」を測る。
  final List<String> pre;
  final List<LessonBlock> blocks;

  /// このレッスンが使う文言の ID（題名と、各ブロックの説明）。出てくる順・重複なし。
  List<String> get textIds {
    final out = <String>[titleId];
    for (final b in blocks) {
      switch (b) {
        case HookBlock():
          out.add(b.textId);
        case TextBlock():
          out.add(b.textId);
        case FormulaBlock():
          if (b.textId != null) out.add(b.textId!);
        case ExampleBlock():
          out.addAll(b.textIds);
        case PitfallBlock():
          out.add(b.textId);
        case SummaryBlock():
          out.addAll(b.textIds);
        case FigureBlock():
          out.add(b.altId);
        case ExploreBlock() || CheckBlock():
          break;
      }
    }
    return out.toSet().toList();
  }

  /// 確認クイズの問題 ID（出てくる順）。
  List<String> get checkQuestions => [
    for (final b in blocks)
      if (b is CheckBlock) ...b.questions,
  ];

  static const _keys = {'id', 'version', 'unitId', 'minutes', 'titleId', 'pre', 'blocks'};

  /// 読めなければ [FormatException]（未知のキー・種類・型違い・範囲外）。
  factory Lesson.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('未知のキー: ${unknown.join(', ')}');
    String str(Map m, String k, String where) {
      final v = m[k];
      if (v is! String || v.isEmpty) throw FormatException('$where: $k は空でない文字列');
      return v;
    }

    final id = str(j, 'id', 'レッスン');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('id は英数字と _ だけ: $id');
    final version = j['version'];
    if (version is! int || version < 1) throw FormatException('$id: version は 1 以上の整数');
    final minutes = j['minutes'];
    if (minutes is! int || minutes < 1 || minutes > 30) throw FormatException('$id: minutes は 1〜30 の整数');
    List<String> ids(Object? v, String where, {int min = 0, int max = 99}) {
      if (v == null) {
        if (min > 0) throw FormatException('$id: $where が必要です');
        return const [];
      }
      if (v is! List || v.any((e) => e is! String || e.isEmpty) || v.length < min || v.length > max) {
        throw FormatException('$id: $where は ID が $min〜$max 個');
      }
      return [for (final e in v) e as String];
    }

    final pre = ids(j['pre'], 'pre', max: 2);
    final rawBlocks = j['blocks'];
    if (rawBlocks is! List || rawBlocks.isEmpty) throw FormatException('$id: blocks が必要です');
    final blocks = <LessonBlock>[];
    for (final raw in rawBlocks) {
      if (raw is! Map) throw FormatException('$id: blocks の要素はオブジェクト');
      final b = Map<String, dynamic>.from(raw);
      final type = b['type'];
      void only(Set<String> keys) {
        final extra = b.keys.where((k) => k != 'type' && !keys.contains(k));
        if (extra.isNotEmpty) throw FormatException('$id: $type に未知のキー: ${extra.join(', ')}');
      }

      switch (type) {
        case 'hook':
          only({'textId', 'scene'});
          blocks.add(HookBlock(str(b, 'textId', '$id.hook'), scene: b.containsKey('scene') ? str(b, 'scene', '$id.hook') : null));
        case 'text':
          only({'textId'});
          blocks.add(TextBlock(str(b, 'textId', '$id.text')));
        case 'figure':
          only({'altId', 'template', 'seed', 'figureId'});
          final hasT = b.containsKey('template') || b.containsKey('seed');
          if (hasT == b.containsKey('figureId')) {
            throw FormatException('$id: figure は template＋seed か figureId のどちらか 1 つ');
          }
          if (hasT && (b['template'] is! String || b['seed'] is! int || (b['seed'] as int) < 1)) {
            throw FormatException('$id: figure の template は文字列、seed は 1 以上の整数');
          }
          blocks.add(
            FigureBlock(
              altId: str(b, 'altId', '$id.figure'),
              template: b['template'] as String?,
              seed: b['seed'] as int?,
              figureId: b.containsKey('figureId') ? str(b, 'figureId', '$id.figure') : null,
            ),
          );
        case 'formula':
          only({'expr', 'textId'});
          blocks.add(
            FormulaBlock(
              str(b, 'expr', '$id.formula'),
              textId: b.containsKey('textId') ? str(b, 'textId', '$id.formula') : null,
            ),
          );
        case 'example':
          only({'template', 'seed', 'lines', 'target', 'form', 'textIds'});
          final seed = b['seed'];
          if (seed is! int || seed < 1) throw FormatException('$id: example の seed は 1 以上の整数');
          final lines = ids(b['lines'], 'example.lines', min: 2, max: 12);
          final textIds = ids(b['textIds'], 'example.textIds', max: 12);
          if (textIds.isNotEmpty && textIds.length != lines.length) {
            throw FormatException('$id: example の textIds は lines と同じ数（行ごとの説明）');
          }
          blocks.add(
            ExampleBlock(
              template: str(b, 'template', '$id.example'),
              seed: seed,
              lines: lines,
              target: b.containsKey('target') ? str(b, 'target', '$id.example') : null,
              form: b.containsKey('form') ? str(b, 'form', '$id.example') : null,
              textIds: textIds,
            ),
          );
        case 'explore':
          only({'exploration', 'construction'});
          if (b.containsKey('exploration') == b.containsKey('construction')) {
            throw FormatException('$id: explore は exploration か construction のどちらか 1 つ');
          }
          blocks.add(
            ExploreBlock(
              exploration: b.containsKey('exploration') ? str(b, 'exploration', '$id.explore') : null,
              construction: b.containsKey('construction') ? str(b, 'construction', '$id.explore') : null,
            ),
          );
        case 'check':
          only({'questions'});
          blocks.add(CheckBlock(ids(b['questions'], 'check.questions', min: 1, max: 3)));
        case 'pitfall':
          only({'tag', 'textId'});
          final tag = str(b, 'tag', '$id.pitfall');
          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(tag)) throw FormatException('$id: pitfall の tag は小文字・数字・アンダースコア: $tag');
          blocks.add(PitfallBlock(tag, str(b, 'textId', '$id.pitfall')));
        case 'summary':
          only({'textIds'});
          blocks.add(SummaryBlock(ids(b['textIds'], 'summary.textIds', min: 1, max: 4)));
        default:
          throw FormatException('$id: 未対応のブロック: $type');
      }
    }
    return Lesson(
      id: id,
      version: version,
      unitId: str(j, 'unitId', id),
      minutes: minutes,
      titleId: str(j, 'titleId', id),
      pre: pre,
      blocks: blocks,
    );
  }
}

/// レッスンの集まり（`lessons.json`）。
class LessonSet {
  const LessonSet(this.lessons);

  final List<Lesson> lessons;

  /// `{"version":1,"lessons":[…]}`。読めなければ [FormatException]。
  factory LessonSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('レッスンの JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('レッスンの JSON はオブジェクトです');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['lessons'];
    if (raw is! List) throw const FormatException('lessons が必要です');
    final out = [for (final l in raw) Lesson.fromJson(Map<String, dynamic>.from(l as Map))];
    final ids = <String>{};
    for (final l in out) {
      if (!ids.add(l.id)) throw FormatException('id が重複しています: ${l.id}');
    }
    return LessonSet(out);
  }
}

/// レッスンの参照先の一覧（教科側が作る）。
class LessonRefs {
  const LessonRefs({
    this.questionIds = const {},
    this.templateIds = const {},
    this.explorationIds = const {},
    this.constructionIds = const {},
    this.sceneIds = const {},
    this.tags = const {},
  });

  final Set<String> questionIds;
  final Set<String> templateIds;
  final Set<String> explorationIds;
  final Set<String> constructionIds;

  /// 場面（現実の具体例）の ID。
  final Set<String> sceneIds;

  /// 誤解の型（問題の `misconceptionTags`・型の `wrong` のタグ）。
  final Set<String> tags;
}

/// 教科ごとの検査（例題の途中式・式の読み取り）。数学は `MathLessonChecker`。
abstract class LessonChecker {
  const LessonChecker();

  /// 例題の途中式を検査する。問題があれば理由、なければ null。
  String? checkExample(ExampleBlock block);

  /// `formula` の式が読めるか。
  bool formulaReadable(String expr);
}

/// 変種 ID（`型~種`）の型 ID を返す。変種でなければ null。
String? _variantTemplate(String id) {
  final m = RegExp(r'^([A-Za-z0-9_]+)~(\d+)$').firstMatch(id);
  return m?.group(1);
}

/// レッスンの検証。エラー: `lesson_unit_missing`・`lesson_unit_not_leaf`・`lesson_ref_missing`（問題・型・体験・作図の参照先がない）・
/// `lesson_example_mismatch`（例題の途中式が途中で変わる・目標に着かない・型の答えと違う）・`lesson_formula_unreadable`・
/// `lesson_tag_unknown`・`lesson_no_check`。警告: `lesson_too_long`（`minutes` 5 超かブロック 12 超）・`lesson_no_summary`・`lesson_first_not_hook`。
List<ValidationIssue> validateLessons(
  LessonSet set, {
  required UnitTree tree,
  required LessonRefs refs,
  LessonChecker? checker,
}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) => issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  void warn(String code, String id, String msg) => issues.add(ValidationIssue(IssueSeverity.warning, code, id, msg));
  for (final l in set.lessons) {
    final unit = tree[l.unitId];
    if (unit == null) {
      err('lesson_unit_missing', l.id, '単元 ${l.unitId} がありません');
    } else if (!tree.isLeaf(l.unitId)) {
      err('lesson_unit_not_leaf', l.id, '単元 ${l.unitId} は葉ではありません（レッスンは葉の単元に付けます）');
    }
    bool questionOk(String q) {
      final t = _variantTemplate(q);
      return t != null ? refs.templateIds.contains(t) : refs.questionIds.contains(q);
    }

    for (final q in l.pre) {
      if (!questionOk(q)) err('lesson_ref_missing', l.id, '事前の確認の問題 $q がありません');
    }
    for (final b in l.blocks) {
      switch (b) {
        case CheckBlock():
          for (final q in b.questions) {
            if (!questionOk(q)) err('lesson_ref_missing', l.id, '確認クイズの問題 $q がありません');
          }
        case FigureBlock():
          if (b.template != null && !refs.templateIds.contains(b.template)) {
            err('lesson_ref_missing', l.id, '図の型 ${b.template} がありません');
          }
        case ExampleBlock():
          if (!refs.templateIds.contains(b.template)) {
            err('lesson_ref_missing', l.id, '例題の型 ${b.template} がありません');
          } else if (checker != null) {
            final why = checker.checkExample(b);
            if (why != null) err('lesson_example_mismatch', l.id, '例題（${b.template}~${b.seed}）: $why');
          }
        case ExploreBlock():
          if (b.exploration != null && !refs.explorationIds.contains(b.exploration)) {
            err('lesson_ref_missing', l.id, '体験 ${b.exploration} がありません');
          }
          if (b.construction != null && !refs.constructionIds.contains(b.construction)) {
            err('lesson_ref_missing', l.id, '作図 ${b.construction} がありません');
          }
        case PitfallBlock():
          if (!refs.tags.contains(b.tag)) err('lesson_tag_unknown', l.id, '誤解の型 ${b.tag} が問題・型にありません');
        case FormulaBlock():
          if (checker != null && !checker.formulaReadable(b.expr)) {
            err('lesson_formula_unreadable', l.id, '式を読めません: ${b.expr}');
          }
        case HookBlock():
          if (b.scene != null && !refs.sceneIds.contains(b.scene)) {
            err('lesson_ref_missing', l.id, '場面 ${b.scene} がありません');
          }
        case TextBlock() || SummaryBlock():
          break;
      }
    }
    if (!l.blocks.any((b) => b is CheckBlock)) err('lesson_no_check', l.id, '確認クイズ（check）がありません');
    if (!l.blocks.any((b) => b is SummaryBlock)) warn('lesson_no_summary', l.id, '要点（summary）がありません');
    if (l.minutes > 5 || l.blocks.length > 12) {
      warn('lesson_too_long', l.id, '長すぎます（minutes ${l.minutes}・ブロック ${l.blocks.length}。5 分・12 ブロックまでを目安に）');
    }
    if (l.blocks.first is! HookBlock) warn('lesson_first_not_hook', l.id, '最初のブロックは導入（hook）にします');
  }
  return issues;
}

/// 確認クイズ・事前の確認の回答の `Attempt.mode`。習熟度の計算には、ふつうの回答として数える。
const lessonCheckMode = 'lesson_check';

/// レッスンの確認クイズの結果を、回答の履歴にする。
Attempt lessonCheckAttempt({
  required String questionId,
  required String unitId,
  required bool correct,
  required DateTime answeredAt,
  String? chosenId,
  int elapsedMs = 0,
  bool? confident,
}) => Attempt(
  questionId: questionId,
  unitId: unitId,
  correct: correct,
  answeredAt: answeredAt,
  chosenId: chosenId,
  elapsedMs: elapsedMs,
  mode: lessonCheckMode,
  confident: confident,
);
