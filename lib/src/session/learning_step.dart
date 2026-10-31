import '../insight/next_units.dart';
import '../lesson/lesson.dart';
import '../lesson/lesson_progress.dart';
import '../models/models.dart';
import '../prereq/prerequisites.dart';

/// 次にやることの種類。
enum LearningStepKind {
  /// レッスンを読む（事前の確認 → 説明 → 確認クイズ）。
  lesson,

  /// 体験・実験をする。
  explore,

  /// 練習する（出題器の出題）。
  practice,

  /// 復習する（期限が来た問題）。
  review,

  /// 単元テスト・模試を受ける。
  test,

  /// すべて仕上がっている。混ぜ練習で保つ。
  maintain,
}

/// 次にやることを選んだ理由。画面は理由を短い責めない文にする（文言は教科アプリ側）。
enum LearningStepReason {
  /// テストが近い。
  testSoon,

  /// 土台の単元（前提）が弱い。
  prerequisiteWeak,

  /// 同じ誤解の型を繰り返している。
  repeatedMistake,

  /// まだ始めていない単元。
  newUnit,

  /// レッスンを読み終えていない。
  lessonNotFinished,

  /// レッスンのあとで、体験で確かめる。
  afterLesson,

  /// 復習の期限が来ている。
  reviewDue,

  /// 練習を続ける。
  keepPracticing,

  /// どの単元も仕上がっている。
  allDone,
}

/// 次にやること 1 つ。
class LearningStep {
  const LearningStep({
    required this.kind,
    required this.reason,
    this.unitId,
    this.lessonId,
    this.blockIndex,
    this.explorationId,
    this.tag,
    this.daysToTest,
  });

  final LearningStepKind kind;
  final LearningStepReason reason;

  /// 対象の単元（`test` で範囲全体のときは最も弱い単元）。
  final String? unitId;

  /// レッスンの ID（`lesson` のとき）。
  final String? lessonId;

  /// レッスンの中の開始位置（つまずきの型の解説から始めるときのブロックの番号）。
  final int? blockIndex;

  /// 体験の ID（`explore` のとき）。
  final String? explorationId;

  /// 繰り返している誤解の型（`repeatedMistake` のとき）。
  final String? tag;

  /// テストまでの日数（`testSoon` のとき）。
  final int? daysToTest;
}

/// `nextLearningStep` のしきい値（仮決定。ソフトローンチで検証する）。
class LearningStepConfig {
  const LearningStepConfig({
    this.testSoonDays = 7,
    this.testGapDays = 3,
    this.doneAt = 0.8,
    this.readyAt = 0.6,
    this.skipLessonAt = 0.7,
    this.exploreBelow = 0.6,
    this.repeatedMistakeCount = 3,
    this.lookbackDays = 30,
    this.reviewDueMin = 3,
  });

  /// テストまでこの日数以内なら、新しいことより「テスト → 弱いところの練習」を先にする。
  final int testSoonDays;

  /// 直近にこの日数以内でテスト・模試を受けていれば、また勧めない。
  final int testGapDays;

  /// 習熟度がこれ以上なら、仕上がり済み。
  final double doneAt;

  /// 前提の習熟度がこれ未満なら、前提が弱い。
  final double readyAt;

  /// 習熟度がこれ以上なら、レッスンは飛ばして練習から（得意）。
  final double skipLessonAt;

  /// 習熟度がこれ未満で、体験があれば体験を勧める。
  final double exploreBelow;

  /// 同じ誤解の型の誤答がこの数以上で「繰り返している」。
  final int repeatedMistakeCount;

  /// 誤解の型の繰り返しを見る期間（日）。
  final int lookbackDays;

  /// 復習の期限が来た問題がこの数以上で、復習を勧める。
  final int reviewDueMin;
}

/// `nextLearningStep` が参照する、学びの材料。どれも省略できる（省けば、その段階は勧めない）。
class LearningContext {
  const LearningContext({
    this.graph,
    this.lessons,
    this.progress = const {},
    this.explorations = const {},
    this.doneExplorations = const {},
    this.reviewDue = const {},
    this.config = const LearningStepConfig(),
  });

  /// 単元の前提（なければ前提は見ない）。
  final PrerequisiteGraph? graph;

  /// レッスン。
  final LessonSet? lessons;

  /// レッスンの進み具合（レッスン ID → 進み具合）。
  final Map<String, LessonProgress> progress;

  /// 単元の体験（単元 ID → 体験の ID）。
  final Map<String, List<String>> explorations;

  /// すでにやった体験の ID。
  final Set<String> doneExplorations;

  /// 単元ごとの、復習の期限が来た問題の数。
  final Map<String, int> reviewDue;
  final LearningStepConfig config;
}

/// 「今日の次の 1 手」を決める（設計は docs/learning_model.md §5）。範囲 [unitIds]（葉の単元）の習熟度・回答・レッスンの進み具合・
/// 前提・テスト日から、レッスン・体験・練習・復習・テストのどれを、どの単元でやるかを返す。範囲が空なら null。
///
/// 優先順（上から）:
/// 1. テストが [LearningStepConfig.testSoonDays] 日以内 → 直近に受けていなければ `test`（最も弱い単元）。受けていれば、新しいことを足さず、弱い単元の練習へ
/// 2. 取り組む単元を選ぶ: 仕上がっていない単元のうち、記録があるものの習熟度の低い順。無ければ、前提が固まっていて取り組める新しい単元
/// 3. その単元の前提が弱ければ、前提をさかのぼって、土台の単元を対象にする（`prerequisiteWeak`）
/// 4. 同じ誤解の型を繰り返し、その型の解説（`pitfall`）があるレッスンがあれば、解説から（`repeatedMistake`）
/// 5. レッスンがあり、読み終えておらず、得意でなければ `lesson`（`newUnit`・`lessonNotFinished`）
/// 6. 体験があり、習熟度が低く、まだやっていなければ `explore`（`afterLesson`）
/// 7. 復習の期限が来た問題が多ければ `review`、そうでなければ `practice`
/// どの単元も仕上がっていれば `maintain`。同じ入力なら同じ結果。
LearningStep? nextLearningStep({
  required DateTime now,
  required Iterable<String> unitIds,
  required Map<String, Mastery> mastery,
  required List<Attempt> attempts,
  List<Question> questions = const [],
  LearningContext context = const LearningContext(),
  DateTime? testDate,
}) {
  final cfg = context.config;
  final candidates = (unitIds.toSet().toList()..sort());
  if (candidates.isEmpty) return null;
  final today = dateOnly(now);
  double m(String u) => mastery[u]?.score ?? 0;
  bool done(String u) => mastery[u] != null && mastery[u]!.score >= cfg.doneAt;
  final pending = [
    for (final u in candidates)
      if (!done(u)) u,
  ];
  final weakest =
      ([...candidates]..sort((a, b) {
            final c = m(a).compareTo(m(b));
            return c != 0 ? c : a.compareTo(b);
          }))
          .first;

  // 1. テストが近い
  var closeToTest = false;
  int? daysToTest;
  if (testDate != null) {
    final d = dateOnly(testDate).difference(today).inDays;
    if (d >= 0 && d <= cfg.testSoonDays) {
      closeToTest = true;
      daysToTest = d;
      final recentTest = attempts.any((a) {
        if (a.mode != 'mock' && a.mode != 'unit_test') return false;
        final age = today.difference(dateOnly(a.answeredAt)).inDays;
        return age >= 0 && age < cfg.testGapDays;
      });
      if (!recentTest && d > 0) {
        return LearningStep(
          kind: LearningStepKind.test,
          reason: LearningStepReason.testSoon,
          unitId: weakest,
          daysToTest: d,
        );
      }
    }
  }
  if (pending.isEmpty) {
    return LearningStep(
      kind: LearningStepKind.maintain,
      reason: LearningStepReason.allDone,
      unitId: weakest,
      daysToTest: daysToTest,
    );
  }

  // 2. 取り組む単元
  final graph = context.graph ?? PrerequisiteGraph(const []);
  final started =
      [
        for (final u in pending)
          if (mastery[u] != null) u,
      ]..sort((a, b) {
        final c = m(a).compareTo(m(b));
        return c != 0 ? c : a.compareTo(b);
      });
  String focus;
  if (started.isNotEmpty) {
    focus = started.first;
  } else {
    final next = suggestNextUnits(
      graph,
      mastery,
      unitIds: pending,
      maxUnits: 1,
      doneAt: cfg.doneAt,
      readyAt: cfg.readyAt,
    );
    focus = next.isNotEmpty ? next.first.unitId : pending.first;
  }

  // 3. 前提が弱ければ、土台の単元へ
  var target = focus;
  var reason = LearningStepReason.keepPracticing;
  final visited = <String>{focus};
  while (true) {
    final weak = [
      for (final r in graph.requiresOf(target))
        if (mastery[r] == null || mastery[r]!.score < cfg.readyAt) r,
    ]..sort();
    final candidate = weak.where((r) => !visited.contains(r)).firstOrNull;
    if (candidate == null) break;
    visited.add(candidate);
    target = candidate;
    reason = LearningStepReason.prerequisiteWeak;
  }
  final prereqRoot = target != focus;

  final lessons = [
    for (final l in context.lessons?.lessons ?? const <Lesson>[])
      if (l.unitId == target) l,
  ];
  bool finished(Lesson l) => context.progress[l.id]?.isComplete(l) ?? false;
  final m0 = mastery[target]?.score;

  // 4. 同じ誤解の型の繰り返し（レッスンに解説があるとき）
  final tag = _repeatedTag(target, attempts, questions, today, cfg);
  if (tag != null) {
    for (final l in lessons) {
      final i = l.blocks.indexWhere((b) => b is PitfallBlock && b.tag == tag);
      if (i >= 0) {
        return LearningStep(
          kind: LearningStepKind.lesson,
          reason: LearningStepReason.repeatedMistake,
          unitId: target,
          lessonId: l.id,
          blockIndex: i,
          tag: tag,
          daysToTest: daysToTest,
        );
      }
    }
  }

  // 5. レッスン（テストが近いときは新しいレッスンを足さない）
  final unfinished = lessons.where((l) => !finished(l)).toList();
  final lessonDone = lessons.isEmpty || unfinished.isEmpty;
  if (!closeToTest && unfinished.isNotEmpty && (m0 == null || m0 < cfg.skipLessonAt)) {
    return LearningStep(
      kind: LearningStepKind.lesson,
      reason: prereqRoot
          ? LearningStepReason.prerequisiteWeak
          : (mastery[target] == null && !_hasAttempts(target, attempts)
                ? LearningStepReason.newUnit
                : LearningStepReason.lessonNotFinished),
      unitId: target,
      lessonId: unfinished.first.id,
    );
  }

  // 6. 体験
  if (!closeToTest && lessonDone && (m0 ?? 0) < cfg.exploreBelow) {
    final ex = (context.explorations[target] ?? const <String>[])
        .where((e) => !context.doneExplorations.contains(e))
        .firstOrNull;
    if (ex != null) {
      return LearningStep(
        kind: LearningStepKind.explore,
        reason: LearningStepReason.afterLesson,
        unitId: target,
        explorationId: ex,
      );
    }
  }

  // 7. 復習か練習
  if ((context.reviewDue[target] ?? 0) >= cfg.reviewDueMin) {
    return LearningStep(
      kind: LearningStepKind.review,
      reason: LearningStepReason.reviewDue,
      unitId: target,
      daysToTest: daysToTest,
    );
  }
  return LearningStep(
    kind: LearningStepKind.practice,
    reason: closeToTest ? LearningStepReason.testSoon : (prereqRoot ? reason : LearningStepReason.keepPracticing),
    unitId: target,
    daysToTest: daysToTest,
  );
}

bool _hasAttempts(String unitId, List<Attempt> attempts) => attempts.any((a) => a.unitId == unitId);

/// 単元 [unitId] の直近 [LearningStepConfig.lookbackDays] 日の誤答で、同じ誤解の型が [LearningStepConfig.repeatedMistakeCount] 回以上あれば、その型。
/// 複数あれば回数の多いもの（同数は型の名前順）。
String? _repeatedTag(
  String unitId,
  List<Attempt> attempts,
  List<Question> questions,
  DateTime today,
  LearningStepConfig cfg,
) {
  final byId = {for (final q in questions) q.id: q};
  final counts = <String, int>{};
  for (final a in attempts) {
    if (a.correct || a.unitId != unitId || a.chosenId == null) continue;
    final age = today.difference(dateOnly(a.answeredAt)).inDays;
    if (age < 0 || age > cfg.lookbackDays) continue;
    final tag = byId[a.questionId]?.misconceptionTags[a.chosenId];
    if (tag != null) counts[tag] = (counts[tag] ?? 0) + 1;
  }
  final hits = counts.entries.where((e) => e.value >= cfg.repeatedMistakeCount).toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return hits.isEmpty ? null : hits.first.key;
}
