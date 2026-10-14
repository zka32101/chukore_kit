import 'dart:ui' show CheckedState;

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ja = JaStrings();

  group('持ち物チェックリスト', () {
    test('既定の項目は言語ごとの文言。IDは全言語で同じ', () {
      final ids = [for (final (id, _) in ja.checklistDefaults) id];
      expect(ids.length, 6);
      for (final s in ChukoreStrings.supported) {
        expect([for (final (id, _) in s.checklistDefaults) id], ids, reason: s.tag);
        for (final (_, label) in s.checklistDefaults) {
          expect(label.trim(), isNotEmpty, reason: s.tag);
        }
      }
      expect(DayChecklist.defaults(const EnStrings()).items.first.label, 'Pens and pencils');
    });

    test('チェックを入れる・外す。進み具合と、すべてそろったか', () {
      var c = DayChecklist.defaults(ja);
      expect((c.done, c.total, c.allChecked), (0, 6, false));
      c = c.toggle('pencil').toggle('eraser');
      expect(c.done, 2);
      expect(c.isChecked('pencil'), isTrue);
      c = c.toggle('pencil');
      expect(c.isChecked('pencil'), isFalse);
      for (final i in c.items) {
        if (!c.isChecked(i.id)) c = c.toggle(i.id);
      }
      expect(c.allChecked, isTrue);
    });

    test('元の状態は変わらない（不変）。項目に無いIDは何もしない', () {
      final c = DayChecklist.defaults(ja);
      final next = c.toggle('pencil');
      expect(c.done, 0);
      expect(next.done, 1);
      expect(identical(c.toggle('nope'), c), isTrue);
    });

    test('項目が空のときは、そろったとは言わない', () {
      expect(DayChecklist(const []).allChecked, isFalse);
    });

    test('本人が項目を足せる。空の文言は足さない。IDは重ならない', () {
      var c = DayChecklist.defaults(ja).withItem('  受験票  ');
      expect(c.items.last.label, '受験票');
      expect(c.items.last.custom, isTrue);
      expect(c.items.last.id, 'custom_1');
      c = c.withItem('お守り');
      expect(c.items.last.id, 'custom_2');
      expect(identical(c.withItem('   '), c), isTrue);
      expect(c.total, 8);
      // 途中を外してから足しても、使われているIDとは重ならない
      c = c.without('custom_1').withItem('水筒');
      expect(c.items.map((i) => i.id).toSet().length, c.items.length);
      expect(c.items.last.id, 'custom_1');
    });

    test('項目を外すと、そのチェックも持ち越さない', () {
      final c = DayChecklist.defaults(ja).toggle('watch').without('watch');
      expect(c.total, 5);
      expect(c.done, 0);
      expect(c.isChecked('watch'), isFalse);
    });

    test('保存と復元。既定の項目の文言は保存せず、言語を変えても追従する', () {
      var c = DayChecklist.defaults(ja).withItem('お守り').toggle('pencil').toggle('custom_1').without('tissue');
      final json = c.toJson(ja);
      expect(json['removed'], ['tissue']);
      expect(json['custom'], [
        {'id': 'custom_1', 'label': 'お守り'}
      ]);
      expect(json['checked'], ['custom_1', 'pencil']);
      // 英語で復元すると、既定の項目は英語に、本人が足した項目はそのまま
      final back = DayChecklist.fromJson(json, const EnStrings());
      expect(back.items.map((i) => i.id), ['pencil', 'eraser', 'ruler', 'watch', 'notes', 'custom_1']);
      expect(back.items.first.label, 'Pens and pencils');
      expect(back.items.last.label, 'お守り');
      expect(back.done, 2);
      expect(back.isChecked('pencil'), isTrue);
      expect(back.toJson(const EnStrings()), json);
      // 空の保存からは既定の状態
      expect(DayChecklist.fromJson(const {}, ja).total, 6);
      c = DayChecklist.fromJson(const {'checked': ['ghost']}, ja);
      expect(c.done, 0); // 無い項目のチェックは捨てる
    });
  });

  group('直前5分カード', () {
    Question q(String id, Map<String, String> tags) => Question(
          id: id, unitId: 'u', type: 'choice', difficulty: .5, choices: const ['a', 'b'],
          answer: 'a', explanationId: 'e', misconceptionTags: tags,
        );
    WeakEntry w(String tag, int wrong) => WeakEntry(
          key: 'tag:$tag', tag: tag, wrongCount: wrong, lastWrongAt: DateTime.utc(2026, 10, 1), overcome: false,
        );

    LastMinuteSheet card(List<WeakEntry> weak, Map<String, Question> qs, {int max = 5}) => buildFiveMinuteCard(
          date: DateTime.utc(2026, 10, 14),
          weakNotes: weak,
          questions: qs,
          tagTitle: (t) => 'T:$t',
          promptOf: (x) => 'P:${x.id}',
          answerOf: (x) => 'A',
          explanationOf: (x) => 'E',
          maxItems: max,
        );

    test('弱点1つにつき1問、最大5つ。多く間違えた型から', () {
      final qs = {
        for (var i = 0; i < 7; i++) 'q$i': q('q$i', {'b': 'tag$i'}),
        'extra': q('extra', {'b': 'tag0'}), // 同じ型の2問目は載せない
      };
      final weak = [for (var i = 0; i < 7; i++) w('tag$i', i + 1)];
      final c = card(weak, qs);
      expect(c.sections.length, 5);
      expect(c.sections.every((s) => s.items.length == 1), isTrue);
      expect(c.sections.map((s) => s.key), ['tag:tag6', 'tag:tag5', 'tag:tag4', 'tag:tag3', 'tag:tag2']);
      expect(card(weak, qs, max: 3).sections.length, 3);
    });

    test('弱点が無ければ空', () => expect(card(const [], {'q': q('q', const {})}).isEmpty, isTrue));
  });

  group('画面', () {
    Widget app(DayChecklist c, void Function(DayChecklist) onChanged, {ChukoreStrings s = const JaStrings()}) =>
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DayChecklistView(checklist: c, onChanged: onChanged, strings: s))));

    testWidgets('項目・進み具合を出し、タップで新しい状態を渡す', (tester) async {
      DayChecklist? got;
      await tester.pumpWidget(app(DayChecklist.defaults(ja), (n) => got = n));
      expect(find.text('当日チェック'), findsOneWidget);
      expect(find.text('0/6 そろった'), findsOneWidget);
      expect(find.text('筆記用具'), findsOneWidget);
      await tester.tap(find.text('筆記用具'));
      expect(got!.isChecked('pencil'), isTrue);
      expect(got!.done, 1);
    });

    testWidgets('すべてそろうと、アイコンと文言で伝える（色だけに頼らない）。言語も切り替わる', (tester) async {
      var c = DayChecklist.defaults(const EnStrings());
      for (final i in c.items) {
        c = c.toggle(i.id);
      }
      await tester.pumpWidget(app(c, (_) {}, s: const EnStrings()));
      expect(find.text('6 of 6 ready'), findsOneWidget);
      expect(find.text('Everything is ready. Good luck!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // まだそろっていなければ出ない
      await tester.pumpWidget(app(DayChecklist.defaults(const EnStrings()), (_) {}, s: const EnStrings()));
      expect(find.text('Everything is ready. Good luck!'), findsNothing);
    });

    testWidgets('チェックボックスはスクリーンリーダーで、項目名とチェック状態（入っている／いない）が読まれる', (tester) async {
      final handle = tester.ensureSemantics();
      final c = DayChecklist.defaults(ja).toggle('pencil');
      await tester.pumpWidget(app(c, (_) {}));
      final checked = tester.getSemantics(find.widgetWithText(CheckboxListTile, '筆記用具'));
      final unchecked = tester.getSemantics(find.widgetWithText(CheckboxListTile, '消しゴム'));
      expect(checked.label, contains('筆記用具'));
      expect(checked.getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
      expect(unchecked.getSemanticsData().flagsCollection.isChecked, CheckedState.isFalse);
      handle.dispose();
    });
  });

  test('当日チェックの文言が全言語にある', () {
    for (final s in ChukoreStrings.supported) {
      expect(s.checklistTitle, isNotEmpty);
      expect(s.fiveMinuteTitle, isNotEmpty);
      expect(s.checklistAllDone, isNotEmpty);
      expect(s.checklistProgress(2, 6), allOf(contains('2'), contains('6')));
    }
  });
}
