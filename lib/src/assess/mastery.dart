import 'dart:math' as math;

import '../models/models.dart';

/// 14日で半減する加重正答率から単元ごとの習熟度を作る。
Map<String, Mastery> computeMastery(
  Iterable<Attempt> attempts,
  DateTime now, {
  double halfLifeDays = 14,
}) {
  final today = dateOnly(now);
  final sumW = <String, double>{};
  final sumC = <String, double>{};
  final last = <String, DateTime>{};
  for (final a in attempts) {
    final age = math.max(
        0, today.difference(dateOnly(a.answeredAt)).inDays);
    final w = math.pow(0.5, age / halfLifeDays).toDouble();
    sumW[a.unitId] = (sumW[a.unitId] ?? 0) + w;
    sumC[a.unitId] = (sumC[a.unitId] ?? 0) + (a.correct ? w : 0);
    final prev = last[a.unitId];
    if (prev == null || a.answeredAt.isAfter(prev)) last[a.unitId] = a.answeredAt;
  }
  return {
    for (final id in sumW.keys)
      id: Mastery(
        unitId: id,
        score: sumC[id]! / sumW[id]!,
        lastPracticedAt: last[id],
      ),
  };
}
