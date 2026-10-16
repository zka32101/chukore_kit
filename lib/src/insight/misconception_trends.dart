import '../models/models.dart';
import '../weak/weak_notes.dart';

/// 誤解の型の直近の増減。
enum MisconceptionTrend {
  /// 直近の期間で初めて出た。
  newlyAppeared,

  /// 直近の期間のほうが多い。
  rising,

  /// 同じくらい。
  steady,

  /// 直近の期間のほうが少ない。
  falling,

  /// 直近の期間には出ていない（それ以前だけ）。
  quiet,
}

/// 誤解の型1つの集計。単元をまたいで数える。
class MisconceptionInsight {
  const MisconceptionInsight({
    required this.tag,
    required this.wrongCount,
    required this.confidentWrongCount,
    required this.byUnit,
    required this.questionIds,
    required this.lastWrongAt,
    required this.recentCount,
    required this.previousCount,
    required this.trend,
    required this.overcome,
  });

  final String tag;
  final int wrongCount;

  /// そのうち自信ありで誤答した回数（思い込みの疑い）。
  final int confidentWrongCount;

  /// 単元ID → 回数（回数の多い順、同数はID順）。
  final Map<String, int> byUnit;
  final Set<String> questionIds;
  final DateTime lastWrongAt;

  /// 直近の期間・その前の同じ長さの期間での回数。
  final int recentCount, previousCount;
  final MisconceptionTrend trend;

  /// 克服判定（弱点ノートと同じ基準）。
  final bool overcome;

  /// 複数の単元にまたがって出ている＝単元をこえた共通のつまずき。
  bool get crossUnit => byUnit.length >= 2;
}

/// 回答履歴から、誤解の型を単元をまたいで集計する。誤答した選択肢に型が付いている回答だけが対象。
///
/// 直近 [windowDays] 日と、その前の同じ長さの期間を比べて増減を出す（日付はローカルの暦日）。
/// 結果は 克服していないものを先 → 単元をまたぐもの → 回数の多い順 → 型の名前順。
/// 「同じ型が別の単元でも出ている」ものは、さかのぼり診断や学び直しの入口になる。
List<MisconceptionInsight> analyzeMisconceptions(
  Iterable<Attempt> attempts,
  Map<String, Question> questions,
  DateTime now, {
  int windowDays = 14,
}) {
  final today = dateOnly(now);
  final recentFrom = today.subtract(Duration(days: windowDays - 1));
  final previousFrom = recentFrom.subtract(Duration(days: windowDays));

  final wrongs = <String, List<Attempt>>{};
  for (final a in attempts) {
    if (a.correct || a.chosenId == null) continue;
    final q = questions[a.questionId];
    final tag = q?.misconceptionTags[a.chosenId];
    if (tag == null) continue;
    (wrongs[tag] ??= []).add(a);
  }

  final overcome = {
    for (final w in buildWeakNotes(attempts, questions))
      if (w.tag != null) w.tag!: w.overcome,
  };

  final out = <MisconceptionInsight>[];
  for (final e in wrongs.entries) {
    final list = e.value..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
    final units = <String, int>{};
    var recent = 0, previous = 0;
    for (final a in list) {
      units[a.unitId] = (units[a.unitId] ?? 0) + 1;
      final d = dateOnly(a.answeredAt);
      if (!d.isBefore(recentFrom) && !d.isAfter(today)) {
        recent++;
      } else if (!d.isBefore(previousFrom) && d.isBefore(recentFrom)) {
        previous++;
      }
    }
    final sortedUnits = units.keys.toList()
      ..sort((a, b) {
        final c = units[b]!.compareTo(units[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    out.add(MisconceptionInsight(
      tag: e.key,
      wrongCount: list.length,
      confidentWrongCount: list.where((a) => a.confident == true).length,
      byUnit: {for (final u in sortedUnits) u: units[u]!},
      questionIds: {for (final a in list) a.questionId},
      lastWrongAt: list.last.answeredAt,
      recentCount: recent,
      previousCount: previous,
      trend: recent == 0
          ? MisconceptionTrend.quiet
          : previous == 0
              ? (list.length == recent ? MisconceptionTrend.newlyAppeared : MisconceptionTrend.rising)
              : recent > previous
                  ? MisconceptionTrend.rising
                  : recent < previous
                      ? MisconceptionTrend.falling
                      : MisconceptionTrend.steady,
      overcome: overcome[e.key] ?? false,
    ));
  }
  out.sort((a, b) {
    if (a.overcome != b.overcome) return a.overcome ? 1 : -1;
    if (a.crossUnit != b.crossUnit) return a.crossUnit ? -1 : 1;
    final c = b.wrongCount.compareTo(a.wrongCount);
    return c != 0 ? c : a.tag.compareTo(b.tag);
  });
  return out;
}
