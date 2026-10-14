import 'package:flutter/material.dart';

import '../dayof/day_of.dart';
import '../l10n/strings.dart';

/// F 当日チェックの持ち物チェックリスト。チェックボックスは形で状態が分かる（色だけに頼らない）。
/// 操作すると [onChanged] に新しい状態を渡す。保存はアプリ側。
class DayChecklistView extends StatelessWidget {
  const DayChecklistView({
    super.key,
    required this.checklist,
    required this.onChanged,
    this.strings = const JaStrings(),
  });

  final DayChecklist checklist;
  final void Function(DayChecklist next) onChanged;
  final ChukoreStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(strings.checklistTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(strings.checklistProgress(checklist.done, checklist.total)),
        const SizedBox(height: 8),
        for (final item in checklist.items)
          CheckboxListTile(
            key: ValueKey(item.id),
            value: checklist.isChecked(item.id),
            onChanged: (_) => onChanged(checklist.toggle(item.id)),
            title: Text(item.label),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        if (checklist.allChecked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.check_circle, color: Colors.green.shade800),
              const SizedBox(width: 8),
              Expanded(child: Text(strings.checklistAllDone)),
            ]),
          ),
      ],
    );
  }
}
