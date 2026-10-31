import '../models/models.dart';
import 'lesson.dart';
import 'lesson_progress.dart';

/// 学びの流れの段階。
enum FunnelStage {
  /// ①学ぶ（レッスンを終えた）。
  learn,

  /// ②体験（体験をやった）。
  explore,

  /// ③練習（問題を解いた）。
  practice,

  /// ④テスト（模試・単元テストなどを受けた）。
  test,
}

/// テストとして数える回答の mode。
const _testModes = {'mock', 'unit_test', 'real_test', 'teacher'};

/// 単元 1 つの、学びの流れの到達。
class UnitFunnel {
  const UnitFunnel({required this.unitId, required this.applicable, required this.reached});

  final String unitId;

  /// この単元にある段階（レッスンや体験が無ければ、その段階は含めない）。練習とテストは常にある。
  final Set<FunnelStage> applicable;

  /// 到達した段階。
  final Set<FunnelStage> reached;

  /// 止まっている段階（段階の順で、あるのにまだ届いていない最初のもの。全部届いていれば null）。
  FunnelStage? get stuckAt {
    for (final s in FunnelStage.values) {
      if (applicable.contains(s) && !reached.contains(s)) return s;
    }
    return null;
  }
}

/// 単元ごとに「学ぶ → 体験 → 練習 → テスト」のどこまで進んだかを出す（端末内の記録から）。
/// - 学ぶ: その単元のレッスンのどれかを終えた
/// - 体験: その単元の体験のどれかをやった（[explorations]: 単元 ID → 体験 ID、[doneExplorations]）
/// - 練習: レッスンの確認・テスト以外の回答がある
/// - テスト: mode が mock / unit_test / real_test / teacher の回答がある
/// 並びは [unitIds] の順。
List<UnitFunnel> buildLearningFunnel({
  required Iterable<String> unitIds,
  required List<Attempt> attempts,
  LessonSet? lessons,
  Map<String, LessonProgress> progress = const {},
  Map<String, List<String>> explorations = const {},
  Set<String> doneExplorations = const {},
}) {
  final practiced = <String>{}, tested = <String>{};
  for (final a in attempts) {
    if (_testModes.contains(a.mode)) {
      tested.add(a.unitId);
    } else if (a.mode != lessonCheckMode) {
      practiced.add(a.unitId);
    }
  }
  return [
    for (final u in unitIds)
      () {
        final ls = [
          for (final l in lessons?.lessons ?? const <Lesson>[])
            if (l.unitId == u) l,
        ];
        final ex = explorations[u] ?? const <String>[];
        return UnitFunnel(
          unitId: u,
          applicable: {
            if (ls.isNotEmpty) FunnelStage.learn,
            if (ex.isNotEmpty) FunnelStage.explore,
            FunnelStage.practice,
            FunnelStage.test,
          },
          reached: {
            if (ls.any((l) => progress[l.id]?.completedAt != null)) FunnelStage.learn,
            if (ex.any(doneExplorations.contains)) FunnelStage.explore,
            if (practiced.contains(u)) FunnelStage.practice,
            if (tested.contains(u)) FunnelStage.test,
          },
        );
      }(),
  ];
}

/// 段階ごとの「ある単元の数」と「届いた単元の数」。複数の単元・複数の人の流れを足し合わせる。
class StageCount {
  const StageCount(this.applicable, this.reached);
  final int applicable, reached;

  /// 届いた割合（ある単元が 0 なら 0）。
  double get rate => applicable == 0 ? 0 : reached / applicable;
}

Map<FunnelStage, StageCount> summarizeFunnel(Iterable<UnitFunnel> funnels) {
  final app = {for (final s in FunnelStage.values) s: 0};
  final rea = {for (final s in FunnelStage.values) s: 0};
  for (final f in funnels) {
    for (final s in f.applicable) {
      app[s] = app[s]! + 1;
      if (f.reached.contains(s)) rea[s] = rea[s]! + 1;
    }
  }
  return {for (final s in FunnelStage.values) s: StageCount(app[s]!, rea[s]!)};
}

/// ブロック 1 つの読まれ方。
class BlockRead {
  const BlockRead({required this.index, required this.type, required this.learners, required this.viewed});

  final int index;
  final String type;
  final int learners, viewed;

  /// 読まれた割合（記録が 0 件なら 0）。低いブロックは飛ばされている。
  double get viewRate => learners == 0 ? 0 : viewed / learners;
}

/// レッスン [lesson] のブロックごとの読まれ方。[progress] はそのレッスンの記録（他のレッスンの記録は数えない）。
List<BlockRead> summarizeBlockReads(Lesson lesson, Iterable<LessonProgress> progress) {
  final mine = [
    for (final p in progress)
      if (p.lessonId == lesson.id) p,
  ];
  return [
    for (var i = 0; i < lesson.blocks.length; i++)
      BlockRead(
        index: i,
        type: lesson.blocks[i].type,
        learners: mine.length,
        viewed: mine.where((p) => p.viewed.contains(i)).length,
      ),
  ];
}

/// 読まれる割合が [below] 未満のブロック（記録が [minLearners] 件以上あるときだけ）。説明の直し先の候補。
List<BlockRead> skippedBlocks(Lesson lesson, Iterable<LessonProgress> progress, {double below = 0.5, int minLearners = 5}) => [
  for (final b in summarizeBlockReads(lesson, progress))
    if (b.learners >= minLearners && b.viewRate < below) b,
];

/// 確認クイズの誤答から分かった誤解の型の集計。
class CheckMistakes {
  const CheckMistakes({required this.tags, required this.uncovered});

  /// 誤解の型 → 回数（回数の多い順→型の名前順）。
  final Map<String, int> tags;

  /// 多く出ているのに、このレッスンに解説（`pitfall`）が無い型（回数の多い順）。レッスンへの追加の候補。
  final List<String> uncovered;
}

/// レッスン [lesson] の確認クイズ（事前の確認は除く）の誤答を [attempts] から拾い、問題の `misconceptionTags`
/// （[questions]）で誤解の型にして数える。レッスンの確認の回答（mode が `lesson_check`）だけを見る。
/// 回数が [minCount] 以上で、解説の無い型を [CheckMistakes.uncovered] に入れる。
CheckMistakes lessonCheckMistakes(
  Lesson lesson,
  List<Attempt> attempts,
  List<Question> questions, {
  int minCount = 3,
}) {
  final byId = {for (final q in questions) q.id: q};
  final checks = lesson.checkQuestions.toSet();
  final counts = <String, int>{};
  for (final a in attempts) {
    if (a.mode != lessonCheckMode || a.correct || !checks.contains(a.questionId)) continue;
    final tag = byId[a.questionId]?.misconceptionTags[a.chosenId];
    if (tag != null) counts[tag] = (counts[tag] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  final covered = {
    for (final b in lesson.blocks)
      if (b is PitfallBlock) b.tag,
  };
  return CheckMistakes(
    tags: {for (final k in keys) k: counts[k]!},
    uncovered: [
      for (final k in keys)
        if (counts[k]! >= minCount && !covered.contains(k)) k,
    ],
  );
}

/// 効き目の伸びが [maxGain] 以下のレッスン（記録が [minLearners] 件以上のものだけ）。コンテンツの直し先の候補。
/// 事前と事後が両方そろった記録が無い（`avgGain` が null）レッスンは判断できないので出さない。
List<LessonEffect> ineffectiveLessons(Iterable<LessonEffect> effects, {double maxGain = 0.05, int minLearners = 5}) => [
  for (final e in effects)
    if (e.learners >= minLearners && e.avgGain != null && e.avgGain! <= maxGain) e,
];
