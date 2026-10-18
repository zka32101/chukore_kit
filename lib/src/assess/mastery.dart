import 'dart:math' as math;

import '../models/models.dart';

/// ヒントを使った正解の加点（使ったヒントの数 0, 1, 2, … に対応。最後の値はそれ以上の数にも使う）。
/// 0 個なら満点、1 個で 0.7、2 個で 0.45、3 個以上で 0.25。誤答は 0 のまま。値は仮決定。
const defaultHintCredits = [1.0, 0.7, 0.45, 0.25];

/// 使ったヒントの数 [hintsUsed] に対する正解の加点（0〜1）。
double hintCredit(int hintsUsed, {List<double> credits = defaultHintCredits}) {
  if (credits.isEmpty) return 1.0;
  final i = hintsUsed < 0 ? 0 : hintsUsed;
  return credits[i < credits.length ? i : credits.length - 1];
}

/// 14日で半減する加重正答率から単元ごとの習熟度を作る。
/// ヒントを使った正解は満点ではなく [hintCredits] の加点で数える（自力で解けた正解と区別する）。
Map<String, Mastery> computeMastery(
  Iterable<Attempt> attempts,
  DateTime now, {
  double halfLifeDays = 14,
  List<double> hintCredits = defaultHintCredits,
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
    sumC[a.unitId] = (sumC[a.unitId] ?? 0) + (a.correct ? w * hintCredit(a.hintsUsed, credits: hintCredits) : 0);
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
