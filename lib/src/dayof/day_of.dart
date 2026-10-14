import '../l10n/strings.dart';
import '../models/models.dart';
import '../sheet/last_minute_sheet.dart';
import '../weak/weak_notes.dart';

/// 持ち物チェックリストの1項目。[custom] は本人が足した項目。
class ChecklistItem {
  const ChecklistItem(this.id, this.label, {this.custom = false});

  final String id;
  final String label;
  final bool custom;
}

/// F 当日チェック: 持ち物チェックリスト。不変の値で、操作すると新しい状態を返す。
/// 既定の項目は言語ごとの文言（[ChukoreStrings.checklistDefaults]）。本人が項目を足せる。
class DayChecklist {
  DayChecklist(List<ChecklistItem> items, {Set<String> checked = const {}})
      : items = List.unmodifiable(items),
        checked = Set.unmodifiable({
          // 無くなった項目のチェックは持ち越さない
          for (final i in items)
            if (checked.contains(i.id)) i.id,
        });

  factory DayChecklist.defaults(ChukoreStrings strings) =>
      DayChecklist([for (final (id, label) in strings.checklistDefaults) ChecklistItem(id, label)]);

  /// 保存した状態（[toJson]）から戻す。項目の文言は保存せず、既定の項目は今の言語で出し直す。
  factory DayChecklist.fromJson(Map<String, dynamic> j, ChukoreStrings strings) {
    final removed = {for (final r in (j['removed'] as List? ?? const [])) r as String};
    final items = [
      for (final i in DayChecklist.defaults(strings).items)
        if (!removed.contains(i.id)) i,
      for (final c in (j['custom'] as List? ?? const []))
        ChecklistItem((c as Map)['id'] as String, c['label'] as String, custom: true),
    ];
    return DayChecklist(items, checked: {for (final c in (j['checked'] as List? ?? const [])) c as String});
  }

  final List<ChecklistItem> items;
  final Set<String> checked;

  int get total => items.length;
  int get done => checked.length;

  /// 項目があり、すべてそろっている。
  bool get allChecked => total > 0 && done == total;

  bool isChecked(String id) => checked.contains(id);

  /// チェックを入れる／外す。項目に無いIDは何もしない。
  DayChecklist toggle(String id) {
    if (!items.any((i) => i.id == id)) return this;
    final next = {...checked};
    if (!next.add(id)) next.remove(id);
    return DayChecklist(items, checked: next);
  }

  /// 本人が項目を足す。空の文言は足さない。IDは使われていない `custom_N`。
  DayChecklist withItem(String label) {
    final text = label.trim();
    if (text.isEmpty) return this;
    var n = 1;
    final used = {for (final i in items) i.id};
    while (used.contains('custom_$n')) {
      n++;
    }
    return DayChecklist([...items, ChecklistItem('custom_$n', text, custom: true)], checked: checked);
  }

  /// 項目を外す（既定の項目も外せる）。
  DayChecklist without(String id) =>
      DayChecklist([for (final i in items) if (i.id != id) i], checked: checked);

  /// 保存用。既定の項目の文言は保存しない（言語を変えても追従する）。外した既定の項目は `removed`。
  Map<String, dynamic> toJson(ChukoreStrings strings) {
    final defaultIds = [for (final (id, _) in strings.checklistDefaults) id];
    return {
      'removed': [for (final id in defaultIds) if (!items.any((i) => i.id == id)) id],
      'custom': [
        for (final i in items)
          if (i.custom) {'id': i.id, 'label': i.label},
      ],
      'checked': checked.toList()..sort(),
    };
  }
}

/// 直前5分カード: 試験の直前に見る、いちばん直したい弱点を1つにつき1問ずつ、最大 [maxItems] つ。
/// 弱点ノートの選び方は直前プリント（[buildLastMinuteSheet]）と同じ。
LastMinuteSheet buildFiveMinuteCard({
  required DateTime date,
  required List<WeakEntry> weakNotes,
  required Map<String, Question> questions,
  required String Function(String tag) tagTitle,
  required String Function(Question q) promptOf,
  required String Function(Question q) answerOf,
  required String Function(Question q) explanationOf,
  Iterable<Attempt> attempts = const [],
  Set<String>? unitIds,
  int maxItems = 5,
}) =>
    buildLastMinuteSheet(
      date: date,
      weakNotes: weakNotes,
      questions: questions,
      tagTitle: tagTitle,
      promptOf: promptOf,
      answerOf: answerOf,
      explanationOf: explanationOf,
      attempts: attempts,
      unitIds: unitIds,
      maxSections: maxItems,
      itemsPerSection: 1,
    );
