import '../models/models.dart';
import 'weak_notes.dart';

/// 弱点の優先順: 未克服だけ、自信ありで誤答が多い（思い込みの疑い）順 → 最近間違えた順 → キー順。
/// [includeOvercome] が真なら克服済みも後ろに付ける。
List<WeakEntry> prioritizeWeak(Iterable<WeakEntry> entries, {bool includeOvercome = false}) {
  final list = [
    for (final e in entries)
      if (includeOvercome || !e.overcome) e,
  ]..sort((a, b) {
      if (a.overcome != b.overcome) return a.overcome ? 1 : -1;
      final c = b.confidentWrongCount.compareTo(a.confidentWrongCount);
      if (c != 0) return c;
      final d = b.lastWrongAt.compareTo(a.lastWrongAt);
      return d != 0 ? d : a.key.compareTo(b.key);
    });
  return list;
}

/// 弱点の項目 [entry] に当たる問題。誤解の型（tag）なら、その型が選択肢に付いている問題すべて。
/// 問題単位（questionId）なら、その問題だけ。[pool] の順を保つ。
List<Question> questionsForWeakEntry(WeakEntry entry, Iterable<Question> pool) => [
      for (final q in pool)
        if (entry.questionId != null ? q.id == entry.questionId : q.misconceptionTags.values.contains(entry.tag)) q,
    ];

/// 誤解の型・間違えた問題ごとの解き直しセット。
class RetrySet {
  const RetrySet({required this.entry, required this.questions});

  final WeakEntry entry;

  /// 解き直す順。同じ型の未出題の問題 → 間違えた問題（最近間違えた順）→ 解いたことのある問題（古い順）。
  final List<Question> questions;

  /// `tag:<型>` または `q:<問題ID>`。
  String get key => entry.key;

  /// 誤解の型の解き直しか（偽なら間違えた問題 1 問）。
  bool get isTag => entry.tag != null;

  /// 自信ありで誤答した回数がある（思い込みの疑い。説明を先に見せるなどの扱いは呼び出し側）。
  bool get hasConfidentMistakes => entry.confidentWrongCount > 0;
}

/// 回答履歴から、つまずき別の解き直しセットを作る。
///
/// - セットの並び: [prioritizeWeak]（自信ありで誤答が多い型が先、次に最近間違えた型）
/// - 型のセットの中身: 同じ型の**まだ解いていない問題**を先にして、答えを覚えただけで通れないようにする。
///   次に間違えた問題（最近間違えた順）、最後に解いたことのある問題（古い順）。問題が少なければ、あるものだけ
/// - [perSet] 問まで。問題が 1 問も無い型は、セットにしない
/// - [ignoreCareless] が真（既定）なら、ケアレスミスの疑いの誤答は弱点に数えない（誤解ではないため）
/// - [includeOvercome] が真なら、克服済みのセットも後ろに付ける（復習用）
///
/// 同じ入力なら同じ結果。
List<RetrySet> buildRetrySets({
  required Iterable<Attempt> attempts,
  required Iterable<Question> questions,
  int perSet = 5,
  bool ignoreCareless = true,
  bool includeOvercome = false,
}) {
  if (perSet <= 0) throw ArgumentError('perSet must be positive');
  final pool = [...questions]..sort((a, b) => a.id.compareTo(b.id));
  final byId = {for (final q in pool) q.id: q};
  final all = [...attempts]..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));

  final lastAnswered = <String, DateTime>{};
  for (final a in all) {
    lastAnswered[a.questionId] = a.answeredAt;
  }

  final entries = prioritizeWeak(
    buildWeakNotes(all, byId, ignoreCareless: ignoreCareless),
    includeOvercome: includeOvercome,
  );

  // 間違えた回答を 1 回だけ走査して、項目ごとの「間違えた問題と最後に間違えた日時」を作る
  // （項目ごとに全履歴を走査すると、履歴の件数 × 項目数に比例して遅くなる。10 万件で数秒）
  final missedByTag = <String, Map<String, DateTime>>{}; // 誤解の型 → 問題ID → 最後に間違えた日時
  final missedUntagged = <String, DateTime>{}; // 型の付かない誤答 → 問題ID → 最後に間違えた日時
  for (final a in all) {
    if (a.correct) continue;
    final q = byId[a.questionId];
    if (q == null) continue;
    final tag = a.chosenId == null ? null : q.misconceptionTags[a.chosenId];
    if (tag == null) {
      missedUntagged[q.id] = a.answeredAt;
    } else {
      (missedByTag[tag] ??= {})[q.id] = a.answeredAt;
    }
  }

  final out = <RetrySet>[];
  for (final e in entries) {
    // この項目で間違えた問題と、最後に間違えた日時
    final Map<String, DateTime> missed;
    if (e.questionId != null) {
      final qid = e.questionId!;
      missed = missedUntagged.containsKey(qid) ? {qid: missedUntagged[qid]!} : const {};
    } else {
      missed = missedByTag[e.tag] ?? const {};
    }

    int group(Question q) => !lastAnswered.containsKey(q.id) ? 0 : (missed.containsKey(q.id) ? 1 : 2);
    final cands = questionsForWeakEntry(e, pool)
      ..sort((a, b) {
        final ga = group(a), gb = group(b);
        if (ga != gb) return ga.compareTo(gb);
        if (ga == 1) {
          final c = missed[b.id]!.compareTo(missed[a.id]!); // 最近間違えた順
          if (c != 0) return c;
        } else if (ga == 2) {
          final c = lastAnswered[a.id]!.compareTo(lastAnswered[b.id]!); // 古い順
          if (c != 0) return c;
        }
        return a.id.compareTo(b.id);
      });
    if (cands.isEmpty) continue;
    out.add(RetrySet(entry: e, questions: cands.take(perSet).toList()));
  }
  return out;
}
