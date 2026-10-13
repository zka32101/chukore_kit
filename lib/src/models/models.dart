/// 日付だけを比較するため UTC の 0 時に揃える。
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// 単元。教科書別の差は範囲選択で吸収する。
class Unit {
  const Unit({
    required this.id,
    required this.subject,
    required this.grade,
    required this.title,
    this.parentId,
    this.order = 0,
    this.estimatedQuestions = 0,
  });

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id'] as String,
        subject: j['subject'] as String,
        grade: j['grade'] as int,
        parentId: j['parentId'] as String?,
        title: j['title'] as String,
        order: (j['order'] as int?) ?? 0,
        estimatedQuestions: (j['estimatedQuestions'] as int?) ?? 0,
      );

  final String id;
  final String subject;
  final int grade;
  final String? parentId;
  final String title;
  final int order;
  final int estimatedQuestions;
}

class Question {
  const Question({
    required this.id,
    required this.unitId,
    required this.type,
    required this.difficulty,
    required this.choices,
    required this.answer,
    required this.explanationId,
    this.misconceptionTags = const {},
    this.version = 1,
  }) : assert(difficulty >= 0 && difficulty <= 1);

  final String id;
  final String unitId;
  final String type;

  /// 基準正答率 0〜1。
  final double difficulty;
  final List<String> choices;
  final String answer;
  final String explanationId;

  /// 誤答選択肢ID → 誤解の型（例: sign_error）。
  final Map<String, String> misconceptionTags;
  final int version;
}

class Attempt {
  const Attempt({
    required this.questionId,
    required this.unitId,
    required this.correct,
    required this.answeredAt,
    this.chosenId,
    this.elapsedMs = 0,
    this.mode = 'practice',
  });

  final String questionId;
  final String unitId;
  final bool correct;
  final String? chosenId;
  final DateTime answeredAt;
  final int elapsedMs;
  final String mode;
}

class Mastery {
  const Mastery({required this.unitId, required this.score, this.lastPracticedAt});

  final String unitId;

  /// 0〜1。未学習は 0。
  final double score;
  final DateTime? lastPracticedAt;
}

class TestPlan {
  const TestPlan({
    required this.id,
    required this.subject,
    required this.testDate,
    required this.unitIds,
  });

  final String id;
  final String subject;
  final DateTime testDate;

  /// 出題範囲の単元ID（葉）。
  final List<String> unitIds;
}

enum BusyKind { busy, off }

/// 忙しい日（量×0.3）／お休み（量×0）。
class BusyDay {
  const BusyDay(this.date, [this.kind = BusyKind.busy]);

  final DateTime date;
  final BusyKind kind;

  double get factor => kind == BusyKind.off ? 0.0 : 0.3;
}
