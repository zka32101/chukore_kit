import 'lesson.dart';

/// レッスンの進み具合（端末内）。読んだブロック・事前の確認・確認クイズの結果・終えた日時。不変で、更新は新しい値を返す。
/// 読んだだけでは習熟度に加点しない。確認クイズの結果は [lessonCheckAttempt] で回答にする。
class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    this.viewed = const {},
    this.pre = const {},
    this.post = const {},
    this.completedAt,
  });

  final String lessonId;

  /// 読んだブロックの番号（0 始まり）。
  final Set<int> viewed;

  /// 事前の確認の結果（問題 ID → 正解か）。
  final Map<String, bool> pre;

  /// 確認クイズ（事後）の結果（問題 ID → 正解か）。
  final Map<String, bool> post;
  final DateTime? completedAt;

  LessonProgress _copy({Set<int>? viewed, Map<String, bool>? pre, Map<String, bool>? post, DateTime? completedAt}) =>
      LessonProgress(
        lessonId: lessonId,
        viewed: viewed ?? this.viewed,
        pre: pre ?? this.pre,
        post: post ?? this.post,
        completedAt: completedAt ?? this.completedAt,
      );

  /// ブロック [index] を読んだ。
  LessonProgress viewBlock(int index) {
    if (index < 0) throw ArgumentError('index は 0 以上');
    return _copy(viewed: {...viewed, index});
  }

  /// 事前の確認の結果。同じ問題はあとの結果で置き換える。
  LessonProgress recordPre(String questionId, bool correct) => _copy(pre: {...pre, questionId: correct});

  /// 確認クイズ（事後）の結果。同じ問題はあとの結果で置き換える。
  LessonProgress recordCheck(String questionId, bool correct) => _copy(post: {...post, questionId: correct});

  /// 終えた。
  LessonProgress complete(DateTime at) => _copy(completedAt: at);

  /// [lesson] のブロックをすべて読んだか。
  bool viewedAll(Lesson lesson) => List.generate(lesson.blocks.length, (i) => i).every(viewed.contains);

  /// [lesson] の確認クイズにすべて答えたか。
  bool checkedAll(Lesson lesson) => lesson.checkQuestions.every(post.containsKey);

  /// ブロックをすべて読み、確認クイズにすべて答えたか。
  bool isComplete(Lesson lesson) => viewedAll(lesson) && checkedAll(lesson);

  static double? _rate(Map<String, bool> m) => m.isEmpty ? null : m.values.where((v) => v).length / m.length;

  /// 事前の確認の正答率（答えていなければ null）。
  double? get preRate => _rate(pre);

  /// 確認クイズの正答率（答えていなければ null）。
  double? get postRate => _rate(post);

  /// 事前 → 事後の伸び（正答率の差。どちらかが無ければ null）。
  double? get gain {
    final a = preRate, b = postRate;
    return a == null || b == null ? null : b - a;
  }

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'viewed': (viewed.toList()..sort()),
    'pre': pre,
    'post': post,
    if (completedAt != null) 'completedAt': completedAt!.toUtc().toIso8601String(),
  };

  /// 読めなければ [FormatException]。
  factory LessonProgress.fromJson(Map<String, dynamic> j) {
    try {
      Map<String, bool> results(Object? v) => {
        for (final e in ((v as Map?) ?? const {}).entries) e.key as String: e.value as bool,
      };
      final viewed = {for (final v in (j['viewed'] as List? ?? const [])) v as int};
      if (viewed.any((i) => i < 0)) throw const FormatException('viewed は 0 以上');
      final id = j['lessonId'];
      if (id is! String || id.isEmpty) throw const FormatException('lessonId');
      final at = j['completedAt'];
      return LessonProgress(
        lessonId: id,
        viewed: viewed,
        pre: results(j['pre']),
        post: results(j['post']),
        completedAt: at == null ? null : DateTime.parse(at as String),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('レッスンの進み具合を読めません（形が違います）');
    }
  }
}

/// 1 つのレッスンの効き目の集計（端末内の記録を束ねたもの）。
class LessonEffect {
  const LessonEffect({
    required this.lessonId,
    required this.learners,
    required this.completed,
    required this.avgPre,
    required this.avgPost,
    required this.avgGain,
  });

  final String lessonId;

  /// 記録の数。
  final int learners;

  /// 終えた記録の数（`completedAt` がある）。
  final int completed;

  /// 事前の確認の平均正答率（事前に答えた記録だけ。無ければ null）。
  final double? avgPre;

  /// 確認クイズの平均正答率（無ければ null）。
  final double? avgPost;

  /// 事前も事後もある記録の、伸びの平均（無ければ null）。
  final double? avgGain;

  /// 終えた割合。
  double get completionRate => learners == 0 ? 0 : completed / learners;
}

/// レッスンごとの効き目を集計する（`minLearners` 件に満たないレッスンは出さない）。並びはレッスン ID。
/// 端末内の自分の記録、またはアプリが個人を特定しない形で集めた記録の束を渡す想定（基盤は集めない・送らない）。
List<LessonEffect> summarizeLessonEffects(Iterable<LessonProgress> progress, {int minLearners = 1}) {
  final byLesson = <String, List<LessonProgress>>{};
  for (final p in progress) {
    (byLesson[p.lessonId] ??= []).add(p);
  }
  double? avg(Iterable<double?> xs) {
    final v = [for (final x in xs) ?x];
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  return [
    for (final id in byLesson.keys.toList()..sort())
      if (byLesson[id]!.length >= minLearners)
        LessonEffect(
          lessonId: id,
          learners: byLesson[id]!.length,
          completed: byLesson[id]!.where((p) => p.completedAt != null).length,
          avgPre: avg(byLesson[id]!.map((p) => p.preRate)),
          avgPost: avg(byLesson[id]!.map((p) => p.postRate)),
          avgGain: avg(byLesson[id]!.map((p) => p.gain)),
        ),
  ];
}
