import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../question/timeline.dart';

/// 年表問題: 出来事をドラッグして古い順に並べ替える。
/// 回答後は [revealYears] を true にして年を表示し、正しい位置との違いを色で示す。
class TimelineOrderList extends StatelessWidget {
  const TimelineOrderList({
    super.key,
    required this.events,
    required this.onReordered,
    this.revealYears = false,
    this.enabled = true,
    this.strings = const JaStrings(),
  });

  /// 現在の並び順（上が古い）。
  final List<TimelineEvent> events;
  final void Function(List<TimelineEvent> newOrder) onReordered;
  final bool revealYears;
  final bool enabled;
  final ChukoreStrings strings;

  @override
  Widget build(BuildContext context) {
    final correct = sortChronologically(events).map((e) => e.id).toList();
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: enabled,
      onReorderItem: (from, to) {
        if (!enabled) return;
        final list = [...events];
        list.insert(to, list.removeAt(from));
        onReordered(list);
      },
      children: [
        for (var i = 0; i < events.length; i++)
          ListTile(
            key: ValueKey(events[i].id),
            leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
            title: Text(events[i].label),
            // 回答後は年に加えて ✓/✗ のアイコンも出す（色だけで正誤を伝えない）
            trailing: revealYears
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(strings.formatYear(events[i].year)),
                    const SizedBox(width: 8),
                    correct[i] == events[i].id
                        ? Icon(Icons.check_circle, color: Colors.green.shade800, semanticLabel: strings.markCorrect)
                        : Icon(Icons.cancel, color: Colors.red.shade800, semanticLabel: strings.markWrong),
                  ])
                : null,
            tileColor: revealYears
                ? (correct[i] == events[i].id
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.12))
                : null,
          ),
      ],
    );
  }
}
