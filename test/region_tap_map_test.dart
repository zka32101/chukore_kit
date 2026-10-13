import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<GeoPoint> _sq(double x, double y, double s) =>
    [GeoPoint(x, y), GeoPoint(x + s, y), GeoPoint(x + s, y + s), GeoPoint(x, y + s)];

final _regions = [
  MapRegion(id: 'a', label: 'A', rings: [_sq(0, 0, 10)]),
  MapRegion(id: 'b', label: 'B', rings: [_sq(20, 0, 10)]),
];

Widget _app({required bool answered, required void Function(String) onTap, Set<String>? available}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 100,
            child: RegionTapMap(
              regions: _regions,
              available: available ?? {'a', 'b'},
              answered: answered,
              correctId: 'a',
              onRegionTapped: onTap,
            ),
          ),
        ),
      ),
    );

void main() {
  test('座標変換は往復で元に戻り、y は上向きに反転する', () {
    final vp = MapViewport(MapBounds.of(_regions), 300, 100);
    final (sx, sy) = vp.toScreen(const GeoPoint(5, 5));
    final p = vp.fromScreen(sx, sy);
    expect(p.x, closeTo(5, 1e-9));
    expect(p.y, closeTo(5, 1e-9));
    final top = vp.toScreen(const GeoPoint(5, 10)).$2;
    final bottom = vp.toScreen(const GeoPoint(5, 0)).$2;
    expect(top, lessThan(bottom));
  });

  testWidgets('領域をタップするとIDが返る', (tester) async {
    String? tapped;
    await tester.pumpWidget(_app(answered: false, onTap: (id) => tapped = id));
    final box = tester.getRect(find.byType(RegionTapMap));
    final vp = MapViewport(MapBounds.of(_regions), box.width, box.height);
    final (x, y) = vp.toScreen(const GeoPoint(25, 5));
    await tester.tapAt(box.topLeft + Offset(x, y));
    expect(tapped, 'b');
  });

  testWidgets('回答後・選択対象外・領域の外では反応しない', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_app(answered: true, onTap: taps.add));
    final box = tester.getRect(find.byType(RegionTapMap));
    final vp = MapViewport(MapBounds.of(_regions), box.width, box.height);
    final (ax, ay) = vp.toScreen(const GeoPoint(5, 5));
    await tester.tapAt(box.topLeft + Offset(ax, ay));
    expect(taps, isEmpty);

    await tester.pumpWidget(_app(answered: false, onTap: taps.add, available: {'b'}));
    await tester.tapAt(box.topLeft + Offset(ax, ay));
    expect(taps, isEmpty);

    final (gx, gy) = vp.toScreen(const GeoPoint(15, 5)); // 領域の間
    await tester.tapAt(box.topLeft + Offset(gx, gy));
    expect(taps, isEmpty);
  });

  test('状態ごとの配色', () {
    expect(regionStyle(RegionVisual.correct, Colors.blue).$2, Colors.green);
    expect(regionStyle(RegionVisual.wrong, Colors.blue).$2, Colors.red);
  });
}
