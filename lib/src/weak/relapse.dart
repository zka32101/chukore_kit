import '../models/models.dart';
import 'careless.dart';
import 'weak_notes.dart';

/// 弱点（誤解の型・間違えた問題）を克服した出来事 1 つ。
class OvercomeEvent {
  const OvercomeEvent({required this.key, required this.tag, required this.questionId, required this.overcameAt, required this.relapsedAt});

  /// `tag:<型>` または `q:<問題ID>`（弱点ノートと同じ）。
  final String key;
  final String? tag;
  final String? questionId;

  /// 克服と判定された時刻（連続正解の最後の回答の時刻）。
  final DateTime overcameAt;

  /// そのあと同じ弱点でまた間違えた時刻（再発しなければ null）。
  final DateTime? relapsedAt;

  bool get relapsed => relapsedAt != null;

  /// 克服してから再発するまでの日数（再発していなければ null）。
  int? get daysHeld => relapsedAt == null ? null : dateOnly(relapsedAt!).difference(dateOnly(overcameAt)).inDays;
}

/// 克服の「戻り」の集計。
class RelapseReport {
  const RelapseReport({required this.events, required this.settled, required this.settledRelapsed});

  /// 克服の出来事すべて（克服した時刻の古い順）。
  final List<OvercomeEvent> events;

  /// 克服から [minAgeDays] 日以上たった（結果が見えるまで待った）克服の数と、そのうち再発した数。
  final int settled, settledRelapsed;

  /// 再発した克服の数（時期を問わない）。
  int get relapsedCount => events.where((e) => e.relapsed).length;

  /// 戻り率 = 待った克服のうち、再発した割合。待った克服が無ければ null。
  /// 克服したばかりのものを入れると、まだ再発していないだけで低く出るので、[minAgeDays] 日たったものだけで見る。
  double? get relapseRate => settled == 0 ? null : settledRelapsed / settled;

  /// 再発したものの、克服から再発までの日数の中央値（再発が無ければ null）。短いほど「克服」の基準が甘い疑い。
  double? get medianDaysHeld {
    final d = [for (final e in events) if (e.daysHeld != null) e.daysHeld!]..sort();
    if (d.isEmpty) return null;
    final m = d.length ~/ 2;
    return d.length.isOdd ? d[m].toDouble() : (d[m - 1] + d[m]) / 2;
  }
}

/// 回答履歴から、弱点の克服と、そのあとの再発を調べる。**克服の基準（`isOvercome` の連続正解の回数と日数）を
/// 見直す根拠**にする（再発が多い・早いなら基準が甘い）。検証計画の「克服後の戻り率」。
///
/// 弱点ノート（`buildWeakNotes`）と同じ定義で、履歴を時刻順にたどる:
/// - 弱点の項目 = 誤答の選択肢の型（あれば）か、型の無い誤答の問題
/// - 間違えたあとの回答が `isOvercome`（既定: 連続 [streak] 回正解・[minDays] 日以上）を満たした時点が、克服
/// - 克服のあと、同じ項目でまた間違えたら再発
/// - [ignoreCareless] が真（既定）なら、ケアレスミスの疑いの誤答は再発に数えない（誤解ではないため）
///
/// [today] の [minAgeDays] 日前までに克服したものだけを、戻り率の分母にする。同じ入力なら同じ結果。
RelapseReport analyzeRelapses(
  Iterable<Attempt> attempts,
  Map<String, Question> questions, {
  required DateTime today,
  int streak = 3,
  int minDays = 2,
  int minAgeDays = 14,
  bool ignoreCareless = true,
}) {
  final sorted = attempts.toList()..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
  final careless = ignoreCareless ? {for (final v in classifyMistakes(sorted)) if (v.careless) v.attempt} : const <Attempt>{};

  final history = <String, List<Attempt>>{};
  final marker = <Attempt, String>{}; // 弱点を示す誤答 → 項目のキー
  final meta = <String, (String?, String?)>{};
  for (final a in sorted) {
    final q = questions[a.questionId];
    if (q == null) continue;
    for (final t in q.misconceptionTags.values.toSet()) {
      (history['tag:$t'] ??= []).add(a);
      meta['tag:$t'] = (t, null);
    }
    (history['q:${q.id}'] ??= []).add(a);
    meta['q:${q.id}'] = (null, q.id);
    if (!a.correct && !careless.contains(a)) {
      final tag = a.chosenId == null ? null : q.misconceptionTags[a.chosenId];
      marker[a] = tag != null ? 'tag:$tag' : 'q:${q.id}';
    }
  }

  final events = <OvercomeEvent>[];
  for (final e in history.entries) {
    final key = e.key;
    var seenWeak = false;
    var segment = <Attempt>[];
    DateTime? overcameAt;
    void close(DateTime? relapsedAt) {
      if (overcameAt == null) return;
      events.add(OvercomeEvent(key: key, tag: meta[key]!.$1, questionId: meta[key]!.$2, overcameAt: overcameAt!, relapsedAt: relapsedAt));
      overcameAt = null;
    }

    for (final a in e.value) {
      if (marker[a] == key) {
        close(a.answeredAt); // 克服していたのに、また間違えた = 再発
        seenWeak = true;
        segment = [];
        continue;
      }
      segment.add(a);
      if (seenWeak && overcameAt == null && isOvercome(segment, streak: streak, minDays: minDays)) {
        overcameAt = a.answeredAt;
      }
    }
    close(null);
  }
  events.sort((a, b) {
    final c = a.overcameAt.compareTo(b.overcameAt);
    return c != 0 ? c : a.key.compareTo(b.key);
  });

  final cutoff = dateOnly(today).subtract(Duration(days: minAgeDays));
  final settled = events.where((e) => !dateOnly(e.overcameAt).isAfter(cutoff)).toList();
  return RelapseReport(events: events, settled: settled.length, settledRelapsed: settled.where((e) => e.relapsed).length);
}
