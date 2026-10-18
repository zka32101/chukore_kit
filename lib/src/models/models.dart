/// 日付だけを比較するため UTC の 0 時に揃える。
/// 日付は渡された DateTime の年月日フィールド（端末のローカル暦日を想定）を使うので、
/// 保存先から読む回答時刻はローカル時刻にしてから渡すこと（時差のある国で日付がずれないように）。
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
    this.hintIds = const [],
  }) : assert(difficulty >= 0 && difficulty <= 1);

  /// 基準正答率の範囲外（assert はリリースビルドで無効なので、読み込み時にも明示的に確かめる）。
  static const difficultyRangeError = 'difficulty_out_of_range';

  factory Question.fromJson(Map<String, dynamic> j) {
    final d = (j['difficulty'] as num).toDouble();
    if (!(d >= 0 && d <= 1)) throw const FormatException(difficultyRangeError);
    return Question._fromJson(j);
  }

  factory Question._fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        unitId: j['unitId'] as String,
        type: j['type'] as String,
        difficulty: (j['difficulty'] as num).toDouble(),
        choices: [for (final c in (j['choices'] as List? ?? const [])) c as String],
        answer: j['answer'] as String,
        explanationId: j['explanationId'] as String,
        misconceptionTags: {
          for (final e in ((j['misconceptionTags'] as Map?) ?? const {}).entries)
            e.key as String: e.value as String,
        },
        version: (j['version'] as int?) ?? 1,
        hintIds: [for (final h in (j['hintIds'] as List? ?? const [])) h as String],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'type': type,
        'difficulty': difficulty,
        'choices': choices,
        'answer': answer,
        'explanationId': explanationId,
        if (misconceptionTags.isNotEmpty) 'misconceptionTags': misconceptionTags,
        'version': version,
        if (hintIds.isNotEmpty) 'hintIds': hintIds,
      };

  /// 内容の一部を変えた写しを作る（基準正答率の見直しなど）。内容を変えたら [version] を上げること。
  Question copyWith({double? difficulty, int? version, List<String>? hintIds, Map<String, String>? misconceptionTags}) => Question(
        id: id,
        unitId: unitId,
        type: type,
        difficulty: difficulty ?? this.difficulty,
        choices: choices,
        answer: answer,
        explanationId: explanationId,
        misconceptionTags: misconceptionTags ?? this.misconceptionTags,
        version: version ?? this.version,
        hintIds: hintIds ?? this.hintIds,
      );

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

  /// 段階ヒントの ID（浅いものから順に。本文は問題データ側。`explanationId` と同じ扱い）。無ければ空。
  /// 1 つ目は考え方、2 つ目は途中の式、のように少しずつ答えに近づける。
  final List<String> hintIds;
}

/// 誤答・失点の理由（本人が選ぶ）。回答（[Attempt.reason]）にも、テスト後の振り返りにも使う。
enum LossReason {
  /// 習っていない・分からなかった（理解不足）。
  dontKnow,

  /// 一度覚えたが忘れていた。
  forgot,

  /// 分かっていたのに取り違えた（ケアレス）。
  careless,

  /// 時間が足りなかった。
  timeShort,
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
    this.confident,
    this.reason,
    this.hintsUsed = 0,
  });

  final String questionId;
  final String unitId;
  final bool correct;
  final String? chosenId;
  final DateTime answeredAt;
  final int elapsedMs;
  final String mode;

  /// 回答時の自信（true = 自信あり、false = 自信なし、null = 聞いていない）。
  final bool? confident;

  /// 間違えた理由の自己申告（誤答のときだけ。答えなくてもよいので null のことが多い）。
  /// 申告があれば、ケアレスミスの推定（`classifyMistakes`）より優先する。
  final LossReason? reason;

  /// 答える前に見たヒントの数（0 = 使わなかった）。ヒントを使った正解は、習熟度への加点を小さくする
  /// （`defaultHintCredits`）。模試ではヒントを出さない。
  final int hintsUsed;
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
