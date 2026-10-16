import '../models/models.dart';

/// 正誤と自信の組み合わせ。
enum ConfidenceKind {
  /// 自信ありで正解（定着している）。
  solid,

  /// 自信なしで正解（まぐれかもしれない）。
  lucky,

  /// 自信ありで誤答（思い込み・誤解の可能性が高い。最優先で直したい）。
  misconception,

  /// 自信なしで誤答（分からないと自覚している）。
  gap,
}

/// 回答1回の見立て。自信を聞いていない回答は null。
ConfidenceKind? confidenceKindOf(Attempt a) {
  final c = a.confident;
  if (c == null) return null;
  return a.correct
      ? (c ? ConfidenceKind.solid : ConfidenceKind.lucky)
      : (c ? ConfidenceKind.misconception : ConfidenceKind.gap);
}

/// 単元ごとの自信度の集計。
class ConfidenceSummary {
  const ConfidenceSummary(this.unitId, this.counts);

  final String unitId;
  final Map<ConfidenceKind, int> counts;

  int count(ConfidenceKind k) => counts[k] ?? 0;

  /// 自信を聞いた回答の数。
  int get answered => counts.values.fold(0, (s, c) => s + c);

  /// 誤答のうち「自信ありで間違えた」割合（誤答が無ければ null）。高いほど思い込みが多い。
  double? get misconceptionShare {
    final wrong = count(ConfidenceKind.misconception) + count(ConfidenceKind.gap);
    return wrong == 0 ? null : count(ConfidenceKind.misconception) / wrong;
  }

  /// 正解のうち「自信なし」だった割合（正解が無ければ null）。高いほどまぐれ・不安定。
  double? get luckyShare {
    final right = count(ConfidenceKind.solid) + count(ConfidenceKind.lucky);
    return right == 0 ? null : count(ConfidenceKind.lucky) / right;
  }
}

/// 単元別に集計する（自信を聞いていない回答は数えない）。単元ID順。
List<ConfidenceSummary> summarizeConfidence(Iterable<Attempt> attempts) {
  final byUnit = <String, Map<ConfidenceKind, int>>{};
  for (final a in attempts) {
    final k = confidenceKindOf(a);
    if (k == null) continue;
    final m = byUnit.putIfAbsent(a.unitId, () => {});
    m[k] = (m[k] ?? 0) + 1;
  }
  final ids = byUnit.keys.toList()..sort();
  return [for (final id in ids) ConfidenceSummary(id, byUnit[id]!)];
}
