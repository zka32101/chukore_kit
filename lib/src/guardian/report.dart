import '../assess/mastery.dart';
import '../models/models.dart';
import '../scope/unit_tree.dart';

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
  });

  final DateTime weekStart;
  final int attemptCount;
  final int activeDays;

  /// 伸びた単元（伸びが大きい順）。
  final List<Improvement> improvements;

  /// 共有リンクや OS の共有機能に渡す文面。「伸びた所」中心で、責める表現は使わない。
  String toText({int maxItems = 3}) {
    final b = StringBuffer('今週の学習: $activeDays日 / $attemptCount問\n');
    if (improvements.isEmpty) {
      b.write('今週は新しく伸びた単元はありませんでした。来週もゆっくり続けましょう。');
    } else {
      b.writeln('今週伸びた所:');
      for (final i in improvements.take(maxItems)) {
        b.writeln('・${i.title}（${(i.before * 100).round()}% → ${(i.after * 100).round()}%）');
      }
    }
    return b.toString().trimRight();
  }
}

/// [weekStart] から7日間のレポートを作る。伸び = 週末時点と週初時点の習熟度の差。
WeeklyReport buildWeeklyReport(
  Iterable<Attempt> attempts,
  UnitTree tree,
  DateTime weekStart,
) {
  final start = dateOnly(weekStart);
  final end = start.add(const Duration(days: 7));
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

  return WeeklyReport(
    weekStart: start,
    attemptCount: inWeek.length,
    activeDays: inWeek.map((a) => dateOnly(a.answeredAt)).toSet().length,
    improvements: improvements,
  );
}
