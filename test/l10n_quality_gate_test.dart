import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget scaled(Widget child, {double scale = 2.0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(360, 640), textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  test('lib/src/ui に、文字列としての日本語の直書きがない（文言は ChukoreStrings に置く）', () {
    final cjk = RegExp(r'[぀-ヿ㐀-鿿]');
    final found = <String>[];
    for (final f in Directory('lib/src/ui').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first; // コメントは対象外
        if (cjk.hasMatch(code)) found.add('${f.path}:${i + 1}');
      }
    }
    expect(found, isEmpty, reason: '直書きの日本語: $found');
  });

  group('文字 200% でも全言語でオーバーフローしない', () {
    testWidgets('年輪の図', (tester) async {
      final rings = GrowthRings([for (var i = 0; i < 6; i++) RingMonth(2026, i + 1, i + 1)], 21);
      for (final s in ChukoreStrings.supported) {
        await tester.pumpWidget(scaled(GrowthRingsView(rings: rings, strings: s)));
        expect(tester.takeException(), isNull, reason: s.languageCode);
      }
    });

    testWidgets('年表の並べ替え（年を表示した状態も）', (tester) async {
      const events = [
        TimelineEvent(id: 'a', label: 'Event A is a fairly long label for a narrow screen', year: 1600, order: 0),
        TimelineEvent(id: 'b', label: 'Event B', year: 1700, order: 1),
      ];
      for (final s in ChukoreStrings.supported) {
        for (final reveal in [false, true]) {
          await tester.pumpWidget(
            scaled(
              SizedBox(
                height: 500,
                child: TimelineOrderList(events: events, onReordered: (_) {}, revealYears: reveal, strings: s),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '${s.languageCode} reveal=$reveal');
        }
      }
    });
  });
}
