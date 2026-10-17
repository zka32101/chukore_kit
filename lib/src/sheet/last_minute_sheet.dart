import 'dart:convert';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../weak/weak_notes.dart';

/// プリントの1問分。文言は問題データとしてアプリ側から渡す。
class SheetItem {
  const SheetItem({required this.questionId, required this.prompt, required this.answer, required this.explanation});

  final String questionId;
  final String prompt;
  final String answer;
  final String explanation;
}

/// 間違い理由（誤解の型）ごとのまとまり。誤解の型が付かない間違いは、その問題1つのまとまりになる。
class SheetSection {
  const SheetSection({required this.key, required this.title, required this.wrongCount, required this.items});

  /// 弱点ノートのキー（`tag:...` か `q:...`）。
  final String key;
  final String title;
  final int wrongCount;
  final List<SheetItem> items;
}

/// D 直前プリント。間違い理由別の、自分だけの直前プリント。個人情報（名前など）は載せない。
class LastMinuteSheet {
  const LastMinuteSheet({required this.date, required this.sections});

  final DateTime date;
  final List<SheetSection> sections;

  bool get isEmpty => sections.isEmpty;
}

/// 弱点ノートから直前プリントを作る。決まった入力なら同じ結果。
///
/// - 未克服の弱点だけを載せる（[includeOvercome] で克服済みも）。多く間違えた順→最近間違えた順。
/// - 各まとまりには、その型が付いた問題（出題範囲 [unitIds] の中）を最大 [itemsPerSection] 問。
///   実際に間違えた問題（[attempts]）を先に。
/// - 文言は [tagTitle]（型の見出し）・[promptOf]・[answerOf]・[explanationOf] で、アプリ側のデータから引く。
LastMinuteSheet buildLastMinuteSheet({
  required DateTime date,
  required List<WeakEntry> weakNotes,
  required Map<String, Question> questions,
  required String Function(String tag) tagTitle,
  required String Function(Question q) promptOf,
  required String Function(Question q) answerOf,
  required String Function(Question q) explanationOf,
  Iterable<Attempt> attempts = const [],
  Set<String>? unitIds,
  int maxSections = 6,
  int itemsPerSection = 3,
  bool includeOvercome = false,
}) {
  final missed = {for (final a in attempts) if (!a.correct) a.questionId};
  bool inScope(Question q) => unitIds == null || unitIds.contains(q.unitId);
  SheetItem itemOf(Question q) => SheetItem(
        questionId: q.id,
        prompt: promptOf(q),
        answer: answerOf(q),
        explanation: explanationOf(q),
      );

  final entries = [
    for (final w in weakNotes)
      if (includeOvercome || !w.overcome) w,
  ]..sort((a, b) {
      var c = (a.overcome ? 1 : 0).compareTo(b.overcome ? 1 : 0);
      if (c != 0) return c;
      c = b.wrongCount.compareTo(a.wrongCount);
      if (c != 0) return c;
      c = b.lastWrongAt.compareTo(a.lastWrongAt);
      return c != 0 ? c : a.key.compareTo(b.key);
    });

  final sections = <SheetSection>[];
  for (final w in entries) {
    if (sections.length >= maxSections) break;
    final List<Question> qs;
    final String title;
    if (w.tag != null) {
      qs = [
        for (final q in questions.values)
          if (inScope(q) && q.misconceptionTags.values.contains(w.tag)) q,
      ]..sort((a, b) {
          final c = (missed.contains(b.id) ? 1 : 0).compareTo(missed.contains(a.id) ? 1 : 0);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      title = tagTitle(w.tag!);
    } else {
      final q = questions[w.questionId];
      qs = q != null && inScope(q) ? [q] : const [];
      title = q == null ? '' : promptOf(q);
    }
    if (qs.isEmpty) continue; // 範囲外・問題が見つからない型は載せない
    sections.add(SheetSection(
      key: w.key,
      title: title,
      wrongCount: w.wrongCount,
      items: [for (final q in qs.take(itemsPerSection)) itemOf(q)],
    ));
  }
  return LastMinuteSheet(date: date, sections: sections);
}

/// 印刷用の HTML（A4）にする。外部の読み込みは無く、端末のフォントで描くので、
/// 日本語・中国語・韓国語など言語を問わず印刷できる。挿入する文言はすべてエスケープする。
String renderSheetHtml(
  LastMinuteSheet sheet, {
  ChukoreStrings strings = const JaStrings(),
}) {
  const esc = HtmlEscape();
  final d = sheet.date;
  final date = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final b = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="${esc.convert(strings.tag)}" dir="${strings.rightToLeft ? 'rtl' : 'ltr'}">')
    ..writeln('<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('<title>${esc.convert(strings.sheetTitle)}</title>')
    ..writeln('<style>')
    ..writeln('@page { size: A4; margin: 14mm; }')
    ..writeln('body { font-family: system-ui, -apple-system, "Segoe UI", "Hiragino Sans", "Noto Sans CJK JP", "Noto Sans CJK SC", "Noto Sans CJK KR", "Noto Sans Arabic", "Noto Naskh Arabic", "Noto Sans Devanagari", "Noto Sans Thai", sans-serif; color: #111; line-height: 1.6; }')
    ..writeln('h1 { font-size: 1.4em; margin: 0 0 .2em; } .date { color: #555; margin: 0 0 1em; }')
    ..writeln('section { break-inside: avoid; margin: 0 0 1.2em; } h2 { font-size: 1.1em; border-bottom: 2px solid #333; padding-bottom: .15em; }')
    ..writeln('ol { padding-inline-start: 1.4em; } li { margin: 0 0 .8em; } .a { font-weight: 600; } .e { color: #333; }')
    ..writeln('</style></head>')
    ..writeln('<body>')
    ..writeln('<h1>${esc.convert(strings.sheetTitle)}</h1>')
    ..writeln('<p class="date">$date</p>');
  if (sheet.isEmpty) {
    b.writeln('<p>${esc.convert(strings.sheetEmpty)}</p>');
  }
  for (final s in sheet.sections) {
    b
      ..writeln('<section>')
      ..writeln('<h2>${esc.convert(s.title)}</h2>')
      ..writeln('<ol>');
    for (final i in s.items) {
      b
        ..writeln('<li>')
        ..writeln('<div class="q"><span class="label">${esc.convert(strings.sheetQuestion)}</span> ${esc.convert(i.prompt)}</div>')
        ..writeln('<div class="a"><span class="label">${esc.convert(strings.sheetAnswer)}</span> ${esc.convert(i.answer)}</div>')
        ..writeln('<div class="e"><span class="label">${esc.convert(strings.sheetExplanation)}</span> ${esc.convert(i.explanation)}</div>')
        ..writeln('</li>');
    }
    b
      ..writeln('</ol>')
      ..writeln('</section>');
  }
  b
    ..writeln('</body>')
    ..writeln('</html>');
  return b.toString();
}
