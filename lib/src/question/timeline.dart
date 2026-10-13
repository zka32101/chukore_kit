/// 年表問題の出来事。年が同じ出来事は [order] で前後を決める（小さいほど先）。
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.label,
    required this.year,
    this.order = 0,
  });

  final String id;
  final String label;

  /// 西暦。紀元前は負の値。
  final int year;
  final int order;
}

/// 古い順に並べた出来事。同年は [TimelineEvent.order]、それも同じならID順。
List<TimelineEvent> sortChronologically(Iterable<TimelineEvent> events) =>
    events.toList()
      ..sort((a, b) {
        var c = a.year.compareTo(b.year);
        if (c == 0) c = a.order.compareTo(b.order);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

/// 問題の answer（古い順のID列をカンマ区切り）。`checkAnswer` の `timeline` タイプに使う。
String timelineAnswer(Iterable<TimelineEvent> events) =>
    sortChronologically(events).map((e) => e.id).join(',');

/// 並べ替えの入力文字列（`checkAnswer` に渡す形）。
String timelineInput(Iterable<String> orderedIds) => orderedIds.join(',');
