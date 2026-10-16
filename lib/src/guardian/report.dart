import '../assess/mastery.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';
import '../weak/weak_notes.dart';

class Improvement {
  const Improvement(this.unitId, this.title, this.before, this.after);

  final String unitId;
  final String title;
  final double before, after;
  double get delta => after - before;
}

/// 週次の保護者レポート。個人情報（名前・メール）は含めない。
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.attemptCount,
    required this.activeDays,
    required this.improvements,
    this.previousAttemptCount = 0,
    this.previousActiveDays = 0,
    this.newlyOvercome = 0,
    this.easedMisconceptions = const [],
  });

  final DateTime weekStart;
  final int attemptCount;
  final int activeDays;

  /// 前の週の回答数・学習した日数（先週との比較用）。
  final int previousAttemptCount, previousActiveDays;

  /// この週に新しく克服できた弱点の数（弱点ノートの克服。誤解の型と問題単位の両方）。
  /// 問題集（`questions`）を渡したときだけ数える。
  final int newlyOvercome;

  /// 前の週には間違えていたが、この週は間違えなかった誤解の型（型の名前順）。
  /// 責めずに「減ったところ」を伝えるための材料。問題集を渡したときだけ。
  final List<String> easedMisconceptions;

  /// 回答数の先週との差（プラスなら増えた）。
  int get attemptDelta => attemptCount - previousAttemptCount;

  /// 伸びた単元（伸びが大きい順）。
  final List<Improvement> improvements;

  /// 共有リンクや OS の共有機能に渡す文面。「伸びた所」中心で、責める表現は使わない。
  String toText({int maxItems = 3, ChukoreStrings strings = const JaStrings()}) {
    final b = StringBuffer('${strings.reportHeader(activeDays, attemptCount)}\n');
    if (improvements.isEmpty) {
      b.write(strings.reportEmpty);
    } else {
      b.writeln(strings.reportImprovedTitle);
      for (final i in improvements.take(maxItems)) {
        b.writeln(strings.reportItem(i.title, (i.before * 100).round(), (i.after * 100).round()));
      }
    }
    return b.toString().trimRight();
  }
}

/// [weekStart] から7日間のレポートを作る。伸び = 週末時点と週初時点の習熟度の差。
/// [questions]（問題ID → 問題）を渡すと、新しく克服した弱点の数と、減った誤解の型も出す。
/// 個人情報は入らない。13歳未満に見せてよい内容・範囲は、見せる側（アプリ）が決める。
WeeklyReport buildWeeklyReport(
  Iterable<Attempt> attempts,
  UnitTree tree,
  DateTime weekStart, {
  Map<String, Question>? questions,
}) {
  final start = dateOnly(weekStart);
  final end = start.add(const Duration(days: 7));
  final prevStart = start.subtract(const Duration(days: 7));
  final prevWeek = attempts.where((a) {
    final d = dateOnly(a.answeredAt);
    return !d.isBefore(prevStart) && d.isBefore(start);
  }).toList();
  final before = attempts.where((a) => dateOnly(a.answeredAt).isBefore(start));
  final inWeek = attempts
      .where((a) {
        final d = dateOnly(a.answeredAt);
        return !d.isBefore(start) && d.isBefore(end);
      })
      .toList();

  final mBefore = computeMastery(before, start);
  final mAfter = computeMastery([...before, ...inWeek], end.subtract(const Duration(days: 1)));

  final improvements = [
    for (final e in mAfter.entries)
      if (inWeek.any((a) => a.unitId == e.key) &&
          e.value.score > (mBefore[e.key]?.score ?? 0))
        Improvement(
          e.key,
          tree[e.key]?.title ?? e.key,
          mBefore[e.key]?.score ?? 0,
          e.value.score,
        ),
  ]..sort((a, b) {
      final c = b.delta.compareTo(a.delta);
      return c != 0 ? c : a.unitId.compareTo(b.unitId);
    });

  var newlyOvercome = 0;
  var eased = <String>[];
  if (questions != null) {
    final upToEnd = attempts.where((a) => dateOnly(a.answeredAt).isBefore(end)).toList();
    final overcomeAtStart = {
      for (final w in buildWeakNotes(before, questions)) if (w.overcome) w.key,
    };
    newlyOvercome = buildWeakNotes(upToEnd, questions)
        .where((w) => w.overcome && !overcomeAtStart.contains(w.key))
        .length;

    Set<String> wrongTags(Iterable<Attempt> xs) => {
          for (final a in xs)
            if (!a.correct && a.chosenId != null)
              ?questions[a.questionId]?.misconceptionTags[a.chosenId],
        };
    eased = (wrongTags(prevWeek)..removeAll(wrongTags(inWeek))).toList()..sort();
  }

  return WeeklyReport(
    weekStart: start,
    attemptCount: inWeek.length,
    activeDays: inWeek.map((a) => dateOnly(a.answeredAt)).toSet().length,
    improvements: improvements,
    previousAttemptCount: prevWeek.length,
    previousActiveDays: prevWeek.map((a) => dateOnly(a.answeredAt)).toSet().length,
    newlyOvercome: newlyOvercome,
    easedMisconceptions: eased,
  );
}
