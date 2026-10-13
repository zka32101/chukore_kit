import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _events = [
  TimelineEvent(id: 'meiji', label: '明治維新', year: 1868),
  TimelineEvent(id: 'kamakura', label: '鎌倉幕府', year: 1185),
  TimelineEvent(id: 'jomon', label: '縄文時代', year: -10000),
  TimelineEvent(id: 'b', label: '同年B', year: 1600, order: 2),
  TimelineEvent(id: 'a', label: '同年A', year: 1600, order: 1),
];

Question _q(String type, String answer) => Question(
      id: 'q', unitId: 'u', type: type, difficulty: 0.5,
      choices: const [], answer: answer, explanationId: 'x',
    );

void main() {
  test('年表: 古い順（紀元前・同年の順序を含む）', () {
    expect(sortChronologically(_events).map((e) => e.id),
        ['jomon', 'kamakura', 'a', 'b', 'meiji']);
    expect(timelineAnswer(_events), 'jomon,kamakura,a,b,meiji');
  });

  test('年表の正誤判定', () {
    final q = _q('timeline', timelineAnswer(_events));
    expect(checkAnswer(q, 'jomon,kamakura,a,b,meiji').correct, isTrue);
    expect(checkAnswer(q, timelineInput(['kamakura', 'jomon', 'a', 'b', 'meiji'])).correct, isFalse);
  });

  test('画像座標（flipY=false）では y が下向きのまま', () {
    final vp = MapViewport(const MapBounds(0, 0, 1, 1), 100, 100, padding: 0, flipY: false);
    expect(vp.toScreen(const GeoPoint(0.5, 0.25)).$2, closeTo(25, 1e-9));
    final p = vp.fromScreen(50, 25);
    expect(p.y, closeTo(0.25, 1e-9));
  });

  testWidgets('図タップ: 画像の上の領域をタップするとIDが返る', (tester) async {
    String? tapped;
    final hotspots = [
      MapRegion(id: 'heart', label: '心臓', rings: [
        [const GeoPoint(0.1, 0.1), const GeoPoint(0.4, 0.1), const GeoPoint(0.4, 0.4), const GeoPoint(0.1, 0.4)],
      ]),
      MapRegion(id: 'lung', label: '肺', rings: [
        [const GeoPoint(0.6, 0.6), const GeoPoint(0.9, 0.6), const GeoPoint(0.9, 0.9), const GeoPoint(0.6, 0.9)],
      ]),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: RegionTapMap(
              regions: hotspots,
              available: const {'heart', 'lung'},
              answered: false,
              correctId: 'heart',
              bounds: const MapBounds(0, 0, 1, 1),
              flipY: false,
              showLabels: false,
              background: const ColoredBox(color: Colors.white),
              onRegionTapped: (id) => tapped = id,
            ),
          ),
        ),
      ),
    ));
    final box = tester.getRect(find.byType(RegionTapMap));
    // 画像の左上寄り(0.25,0.25) = 心臓、右下寄り(0.75,0.75) = 肺
    await tester.tapAt(box.topLeft + Offset(box.width * 0.25, box.height * 0.25));
    expect(tapped, 'heart');
    await tester.tapAt(box.topLeft + Offset(box.width * 0.75, box.height * 0.75));
    expect(tapped, 'lung');
  });

  testWidgets('年表リスト: ドラッグで並べ替わり、回答後は年を表示', (tester) async {
    var order = [..._events.take(3)];
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return MaterialApp(
        home: Scaffold(
          body: TimelineOrderList(
            events: order,
            onReordered: (o) => setState(() => order = o),
          ),
        ),
      );
    }));
    expect(find.text('明治維新'), findsOneWidget);
    expect(find.text('1868年'), findsNothing);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimelineOrderList(events: order, onReordered: (_) {}, revealYears: true),
      ),
    ));
    expect(find.text('1868年'), findsOneWidget);
    expect(find.text('前10000年'), findsOneWidget);
  });
}
