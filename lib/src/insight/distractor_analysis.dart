import '../models/models.dart';

/// 選択肢 1 つの選ばれ方。
class OptionStat {
  const OptionStat({required this.id, required this.chosen, required this.isAnswer, this.tag});

  final String id;

  /// 選ばれた回数。
  final int chosen;

  /// 正解の選択肢か。
  final bool isAnswer;

  /// 誤解の型（付いていれば）。
  final String? tag;
}

/// 選択肢の分析で見つかる気になる点。
enum DistractorFlag {
  /// 型の付いていない誤答が、誤答の中でよく選ばれている。**新しい誤解の型の候補**（先生役のセリフの材料にもなる）。
  popularUntagged,

  /// 誰にも選ばれない誤答がある。選択肢として役に立っていない（差し替え候補）。
  neverChosen,

  /// 誤答のどれかが、正解より多く選ばれている。問題文や正解が紛らわしい（誤り・曖昧さ）かもしれない。
  beatsAnswer,
}

/// 問題 1 つの選択肢の分析。
class QuestionDistractors {
  const QuestionDistractors({
    required this.questionId,
    required this.unitId,
    required this.attempts,
    required this.options,
    required this.flags,
    this.popularUntaggedIds = const {},
  });

  final String questionId;

  /// 型の付いていない誤答のうち、特によく選ばれている選択肢のID。
  final Set<String> popularUntaggedIds;
  final String unitId;

  /// 選択肢が分かる回答の数（選んだ選択肢のIDが残っている回答）。
  final int attempts;

  /// 選択肢ごとの選ばれ方（問題の選択肢の順）。
  final List<OptionStat> options;

  final Set<DistractorFlag> flags;

  OptionStat? get answer => options.where((o) => o.isAnswer).firstOrNull;

  /// 正答率（選んだ選択肢が分かる回答のうち、正解を選んだ割合）。
  double get correctRate => attempts == 0 ? 0 : (answer?.chosen ?? 0) / attempts;

  /// 誤答の中での、選択肢 [id] の割合（誤答が無ければ 0）。
  double shareOfWrong(String id) {
    final wrong = attempts - (answer?.chosen ?? 0);
    if (wrong <= 0) return 0;
    final o = options.where((x) => x.id == id).firstOrNull;
    return o == null || o.isAnswer ? 0 : o.chosen / wrong;
  }

  /// 型の付いていない誤答で、特によく選ばれているもの（多い順）。
  List<OptionStat> get popularUntagged => [
        for (final o in options)
          if (!o.isAnswer && o.tag == null && popularUntaggedIds.contains(o.id)) o,
      ]..sort((a, b) {
          final c = b.chosen.compareTo(a.chosen);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
}

/// 回答履歴から、選択式（`choice`・`map`）の問題の選択肢の選ばれ方を調べる。
///
/// **端末 1 台の履歴では 1 問あたりの回答が少ない**ので、アプリが（個人を特定しない形で）集めた回答の束を
/// 渡す想定（`calibrateDifficulty` と同じ。基盤は集めない・送らない）。
///
/// - 数えるのは [mode] の回答（既定は練習）で、ヒントを使った回答は数えない（選び方が変わるため）。
///   選んだ選択肢のIDが無い回答、問題の選択肢に無いIDは数えない
/// - 回答が [minAttempts] 件に満たない問題は調べない
/// - [DistractorFlag.popularUntagged]: 型の付いていない誤答が、誤答の [popularShare] 以上を占め、
///   かつ [minChosen] 回以上選ばれた
/// - [DistractorFlag.neverChosen]: 誤答の選択肢に、1 回も選ばれないものがある
/// - [DistractorFlag.beatsAnswer]: 誤答の選択肢が、正解より多く選ばれている
///
/// 気になる点のある問題だけを返す。並びは 旗の数が多い順 → 回答の多い順 → 問題ID順。
List<QuestionDistractors> analyzeDistractors(
  Iterable<Attempt> attempts,
  Iterable<Question> questions, {
  int minAttempts = 30,
  double popularShare = 0.25,
  int minChosen = 5,
  String mode = 'practice',
}) {
  if (minAttempts < 1) throw ArgumentError('minAttempts must be positive');
  final byId = {
    for (final q in questions)
      if (q.type == 'choice' || q.type == 'map') q.id: q,
  };
  final counts = <String, Map<String, int>>{};
  for (final a in attempts) {
    final q = byId[a.questionId];
    final chosen = a.chosenId;
    if (q == null || chosen == null || a.mode != mode || a.hintsUsed > 0) continue;
    if (!q.choices.contains(chosen)) continue;
    final m = counts.putIfAbsent(q.id, () => {});
    m[chosen] = (m[chosen] ?? 0) + 1;
  }

  final out = <QuestionDistractors>[];
  for (final e in counts.entries) {
    final q = byId[e.key]!;
    final total = e.value.values.fold<int>(0, (s, n) => s + n);
    if (total < minAttempts) continue;
    final options = [
      for (final c in q.choices)
        OptionStat(id: c, chosen: e.value[c] ?? 0, isAnswer: c == q.answer, tag: q.misconceptionTags[c]),
    ];
    final answerCount = e.value[q.answer] ?? 0;
    final wrong = total - answerCount;
    final flags = <DistractorFlag>{};
    final popular = <String>{};
    for (final o in options) {
      if (o.isAnswer) continue;
      if (o.chosen == 0) flags.add(DistractorFlag.neverChosen);
      if (o.chosen > answerCount) flags.add(DistractorFlag.beatsAnswer);
      if (o.tag == null && wrong > 0 && o.chosen >= minChosen && o.chosen / wrong >= popularShare) {
        flags.add(DistractorFlag.popularUntagged);
        popular.add(o.id);
      }
    }
    if (flags.isEmpty) continue;
    out.add(QuestionDistractors(
      questionId: q.id,
      unitId: q.unitId,
      attempts: total,
      options: options,
      flags: flags,
      popularUntaggedIds: popular,
    ));
  }
  out.sort((a, b) {
    final c = b.flags.length.compareTo(a.flags.length);
    if (c != 0) return c;
    final d = b.attempts.compareTo(a.attempts);
    return d != 0 ? d : a.questionId.compareTo(b.questionId);
  });
  return out;
}

/// 型の付いていない誤答の選択肢を、単元ごとに集める（新しい誤解の型を洗い出す入口）。
/// 各単元で、[DistractorFlag.popularUntagged] の選択肢を持つ問題の数が多い順。
Map<String, List<QuestionDistractors>> untaggedCandidatesByUnit(Iterable<QuestionDistractors> results) {
  final byUnit = <String, List<QuestionDistractors>>{};
  for (final r in results) {
    if (r.flags.contains(DistractorFlag.popularUntagged)) (byUnit[r.unitId] ??= []).add(r);
  }
  final units = byUnit.keys.toList()
    ..sort((a, b) {
      final c = byUnit[b]!.length.compareTo(byUnit[a]!.length);
      return c != 0 ? c : a.compareTo(b);
    });
  return {for (final u in units) u: byUnit[u]!};
}
