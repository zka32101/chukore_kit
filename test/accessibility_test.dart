import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

List<GeoPoint> _sq(double x, double y, double s) =>
    [GeoPoint(x, y), GeoPoint(x + s, y), GeoPoint(x + s, y + s), GeoPoint(x, y + s)];

final _regions = [
  MapRegion(id: 'a', label: 'Alpha', rings: [_sq(0, 0, 10)]),
  MapRegion(id: 'b', label: 'Beta', rings: [_sq(20, 0, 10)]),
  MapRegion(id: 'c', label: 'Gamma', rings: [_sq(40, 0, 10)]),
];

Widget _map({
  required bool answered,
  String? selected,
  Set<String> available = const {'a', 'b', 'c'},
  void Function(String)? onTap,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 100,
            child: RegionTapMap(
              regions: _regions,
              available: available,
              answered: answered,
              correctId: 'a',
              selectedId: selected,
              strings: const EnStrings(),
              onRegionTapped: onTap ?? (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  test('正解はチェック、不正解はバツ。それ以外は目印なし（色以外の手がかり）', () {
    expect(regionMarkOf(RegionVisual.correct), RegionMark.check);
    expect(regionMarkOf(RegionVisual.wrong), RegionMark.cross);
    for (final v in [RegionVisual.selectable, RegionVisual.disabled, RegionVisual.dimmed]) {
      expect(regionMarkOf(v), RegionMark.none);
    }
    expect(RegionMark.check, isNot(RegionMark.cross));
  });

  testWidgets('回答前: 領域ごとにボタンとして読み上げられ、スクリーンリーダーから選べる', (tester) async {
    final handle = tester.ensureSemantics();
    String? tapped;
    await tester.pumpWidget(_map(answered: false, onTap: (id) => tapped = id));
    for (final label in ['Alpha', 'Beta', 'Gamma']) {
      expect(find.semantics.byLabel(label), findsOneWidget);
    }
    tester.semantics.tap(find.semantics.byLabel('Beta'));
    expect(tapped, 'b');
    handle.dispose();
  });

  testWidgets('選択対象外の領域は操作できない', (tester) async {
    final handle = tester.ensureSemantics();
    String? tapped;
    await tester.pumpWidget(_map(answered: false, available: {'a'}, onTap: (id) => tapped = id));
    final node = find.semantics.byLabel('Gamma').evaluate().single;
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(node.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    expect(tapped, isNull);
    handle.dispose();
  });

  testWidgets('回答後: 正解・不正解を言葉でも読み上げ、操作はできなくなる', (tester) async {
    final handle = tester.ensureSemantics();
    String? tapped;
    await tester.pumpWidget(_map(answered: true, selected: 'b', onTap: (id) => tapped = id));
    expect(find.semantics.byLabel('Alpha (correct)'), findsOneWidget);
    expect(find.semantics.byLabel('Beta (incorrect)'), findsOneWidget);
    expect(find.semantics.byLabel('Gamma'), findsOneWidget); // 関係ない領域は名前だけ
    final node = find.semantics.byLabel('Beta (incorrect)').evaluate().single;
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(tapped, isNull);
    handle.dispose();
  });

  testWidgets('正解を選んだときは正解だけ（不正解の領域は出ない）', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_map(answered: true, selected: 'a'));
    expect(find.semantics.byLabel('Alpha (correct)'), findsOneWidget);
    expect(find.semantics.byLabel(RegExp('incorrect')), findsNothing);
    handle.dispose();
  });

  testWidgets('読み上げの言語を切り替えられる', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 100,
          child: RegionTapMap(
            regions: _regions,
            available: const {'a', 'b', 'c'},
            answered: true,
            correctId: 'a',
            selectedId: 'b',
            strings: const FrStrings(),
            onRegionTapped: (_) {},
          ),
        ),
      ),
    ));
    expect(find.semantics.byLabel('Alpha (correct)'), findsOneWidget);
    expect(find.semantics.byLabel('Beta (incorrect)'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('年表: 回答後は色に加えて ✓ / ✗ のアイコンと読み上げ', (tester) async {
    final handle = tester.ensureSemantics();
    // 正しい順は a(1000) → b(1500)。b, a の順に並べる
    const events = [
      TimelineEvent(id: 'b', label: 'Event B', year: 1500),
      TimelineEvent(id: 'a', label: 'Event A', year: 1000),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimelineOrderList(events: events, onReordered: (_) {}, revealYears: true, strings: const EnStrings()),
      ),
    ));
    expect(find.byIcon(Icons.check_circle), findsNothing); // どちらも位置が違う
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
    // アイコンの読み上げは、各行の読み上げ（見出し・年）と一体になって読まれる
    expect(find.bySemanticsLabel(RegExp(r'Event B[\s\S]*1500 CE[\s\S]*incorrect')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Event A[\s\S]*1000 CE[\s\S]*incorrect')), findsOneWidget);

    // 正しい順なら ✓
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimelineOrderList(
            events: events.reversed.toList(), onReordered: (_) {}, revealYears: true, strings: const EnStrings()),
      ),
    ));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp(r'Event A[\s\S]*1000 CE[\s\S]*correct')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('incorrect')), findsNothing);
    // 回答前は出ない
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TimelineOrderList(events: events, onReordered: (_) {})),
    ));
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    handle.dispose();
  });

  test('正解・不正解の読み上げが全言語にある', () {
    for (final s in ChukoreStrings.supported) {
      expect(s.markCorrect, isNotEmpty);
      expect(s.markWrong, isNotEmpty);
      expect(s.markCorrect, isNot(s.markWrong));
    }
  });
}
