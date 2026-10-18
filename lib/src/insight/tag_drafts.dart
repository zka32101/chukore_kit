import '../models/models.dart';
import 'distractor_analysis.dart';

/// 新しい誤解の型の下書き（人が確かめて、名前と先生役のセリフを付けてから採用する）。
class TagDraft {
  const TagDraft({
    required this.questionId,
    required this.unitId,
    required this.optionId,
    required this.suggestedTag,
    required this.chosen,
    required this.shareOfWrong,
  });

  final String questionId;
  final String unitId;

  /// 型を付ける誤答の選択肢。
  final String optionId;

  /// 仮の型名（`<単元>_<問題>_<選択肢>` を小文字・数字・`_` にしたもの）。**採用前に意味の分かる名前へ変える。**
  final String suggestedTag;

  /// その選択肢が選ばれた回数と、誤答の中での割合。
  final int chosen;
  final double shareOfWrong;
}

final _unsafe = RegExp(r'[^a-z0-9_]+');

String _slug(String s) => s.toLowerCase().replaceAll(_unsafe, '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');

/// [analyzeDistractors] の「型の無い人気の誤答」（[DistractorFlag.popularUntagged]）から、型の下書きを作る。
/// 多く選ばれた順（同数は 問題ID → 選択肢ID 順）。型名は仮で、問題集の検証（小文字で始まり、小文字・数字・`_`）を通る形。
List<TagDraft> suggestTagDrafts(Iterable<QuestionDistractors> results) {
  final out = <TagDraft>[
    for (final r in results)
      for (final o in r.popularUntagged)
        TagDraft(
          questionId: r.questionId,
          unitId: r.unitId,
          optionId: o.id,
          suggestedTag: 't_${_slug(r.unitId)}_${_slug(r.questionId)}_${_slug(o.id)}',
          chosen: o.chosen,
          shareOfWrong: r.shareOfWrong(o.id),
        ),
  ]..sort((a, b) {
      final c = b.chosen.compareTo(a.chosen);
      if (c != 0) return c;
      final d = a.questionId.compareTo(b.questionId);
      return d != 0 ? d : a.optionId.compareTo(b.optionId);
    });
  return out;
}

/// 採用した型 [tags]（下書きの `questionId` と `optionId` に、確定した型名）を問題集に反映する。
/// 反映した問題は **version を 1 上げる**（`BankDiff` の検査を通り、差分配信できる）。
/// 問題が無い・選択肢が無い・正解の選択肢・すでに型がある選択肢は反映せず、そのまま返す。
List<Question> applyTagDrafts(Iterable<Question> questions, Iterable<({String questionId, String optionId, String tag})> tags) {
  final byQ = <String, Map<String, String>>{};
  for (final t in tags) {
    byQ.putIfAbsent(t.questionId, () => {})[t.optionId] = t.tag;
  }
  return [
    for (final q in questions)
      () {
        final add = byQ[q.id];
        if (add == null) return q;
        final fresh = {
          for (final e in add.entries)
            if (q.choices.contains(e.key) && e.key != q.answer && !q.misconceptionTags.containsKey(e.key)) e.key: e.value,
        };
        if (fresh.isEmpty) return q;
        return q.copyWith(misconceptionTags: {...q.misconceptionTags, ...fresh}, version: q.version + 1);
      }(),
  ];
}
