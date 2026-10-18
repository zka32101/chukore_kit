import '../models/models.dart';
import 'careless.dart';

/// 弱点の1項目。誤解の型（tag）または問題単位（questionId）で管理する。
class WeakEntry {
  const WeakEntry({
    required this.key,
    required this.wrongCount,
    required this.lastWrongAt,
    required this.overcome,
    this.tag,
    this.questionId,
    this.confidentWrongCount = 0,
  });

  /// `tag:<型>` または `q:<問題ID>`。
  final String key;
  final String? tag;
  final String? questionId;
  final int wrongCount;

  /// そのうち「自信ありで誤答」だった回数（思い込み・誤解の疑い）。
  final int confidentWrongCount;
  final DateTime lastWrongAt;
  final bool overcome;
}

/// 克服判定: 直近 [streak] 回が連続正解で、かつ [minDays] 日以上にまたがる。
bool isOvercome(
  List<Attempt> chronological, {
  int streak = 3,
  int minDays = 2,
}) {
  if (chronological.length < streak) return false;
  final tail = chronological.sublist(chronological.length - streak);
  // ヒントを使った正解は、克服の連続正解に数えない（自力で解けて初めて克服）
  if (!tail.every((a) => a.correct && a.hintsUsed == 0)) return false;
  return tail.map((a) => dateOnly(a.answeredAt)).toSet().length >= minDays;
}

/// 回答履歴から弱点ノートを作る。誤答選択肢に型があればその型、無ければ問題単位。
/// [ignoreCareless] が true なら、`classifyMistakes` でケアレスミスの疑いとされた誤答は弱点に数えない。
/// 結果は未克服を先、最近間違えた順。
List<WeakEntry> buildWeakNotes(
  Iterable<Attempt> attempts,
  Map<String, Question> questions, {
  int streak = 3,
  int minDays = 2,
  bool ignoreCareless = false,
}) {
  final sorted = attempts.toList()
    ..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));

  // ケアレスミスの疑いの誤答は、弱点の数え上げから外す（履歴・克服判定には残す）。
  final careless = ignoreCareless
      ? {for (final v in classifyMistakes(sorted)) if (v.careless) v.attempt}
      : const <Attempt>{};

  final history = <String, List<Attempt>>{};
  final wrong = <String, List<Attempt>>{};
  final meta = <String, (String?, String?)>{};

  for (final a in sorted) {
    final q = questions[a.questionId];
    if (q == null) continue;
    final tags = q.misconceptionTags.values.toSet();
    for (final t in tags) {
      (history['tag:$t'] ??= []).add(a);
      meta['tag:$t'] = (t, null);
    }
    (history['q:${q.id}'] ??= []).add(a);
    meta['q:${q.id}'] = (null, q.id);
    if (!a.correct && !careless.contains(a)) {
      final tag = a.chosenId == null ? null : q.misconceptionTags[a.chosenId];
      final key = tag != null ? 'tag:$tag' : 'q:${q.id}';
      (wrong[key] ??= []).add(a);
    }
  }

  final out = [
    for (final e in wrong.entries)
      WeakEntry(
        key: e.key,
        tag: meta[e.key]?.$1,
        questionId: meta[e.key]?.$2,
        wrongCount: e.value.length,
        confidentWrongCount: e.value.where((a) => a.confident == true).length,
        lastWrongAt: e.value.last.answeredAt,
        // 間違えた後の履歴だけで判定する（過去の正解で克服扱いにしない）。
        overcome: isOvercome(
          history[e.key]!
              .where((a) => a.answeredAt.isAfter(e.value.last.answeredAt))
              .toList(),
          streak: streak,
          minDays: minDays,
        ),
      ),
  ];
  out.sort((a, b) {
    if (a.overcome != b.overcome) return a.overcome ? 1 : -1;
    final c = b.lastWrongAt.compareTo(a.lastWrongAt);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return out;
}
