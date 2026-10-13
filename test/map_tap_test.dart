import 'package:chukore_kit/chukore_kit.dart';
import 'package:test/test.dart';

List<GeoPoint> _square(double x, double y, double s) =>
    [GeoPoint(x, y), GeoPoint(x + s, y), GeoPoint(x + s, y + s), GeoPoint(x, y + s)];

void main() {
  final regions = [
    MapRegion(id: 'a', label: 'A', rings: [_square(0, 0, 10)]),
    // 離島のように2つのリングを持つ領域
    MapRegion(id: 'b', label: 'B', rings: [_square(20, 0, 10), _square(40, 40, 5)]),
  ];

  test('内側の点だけが当たる', () {
    expect(regionAt(regions, const GeoPoint(5, 5)), 'a');
    expect(regionAt(regions, const GeoPoint(25, 5)), 'b');
    expect(regionAt(regions, const GeoPoint(42, 42)), 'b'); // 離島
    expect(regionAt(regions, const GeoPoint(15, 5)), isNull);
  });

  test('選択対象外の領域は当たらない', () {
    expect(regionAt(regions, const GeoPoint(5, 5), available: {'b'}), isNull);
    expect(regionAt(regions, const GeoPoint(25, 5), available: {'b'}), 'b');
  });

  test('回答前後の見た目の状態', () {
    RegionVisual v(String id, {bool answered = false, String? sel}) => regionVisual(
        regionId: id, available: {'a', 'b'}, answered: answered, correctId: 'a', selectedId: sel);
    expect(v('a'), RegionVisual.selectable);
    expect(regionVisual(regionId: 'c', available: {'a'}, answered: false, correctId: 'a'),
        RegionVisual.disabled);
    expect(v('a', answered: true, sel: 'b'), RegionVisual.correct);
    expect(v('b', answered: true, sel: 'b'), RegionVisual.wrong);
    expect(v('a', answered: true, sel: 'a'), RegionVisual.correct);
    expect(regionVisual(regionId: 'c', available: {'a'}, answered: true, correctId: 'a', selectedId: 'b'),
        RegionVisual.dimmed);
  });

  test('地図タップの正誤判定', () {
    const q = Question(
      id: 'm', unitId: 'u', type: 'map', difficulty: 0.5,
      choices: ['a', 'b'], answer: 'a', explanationId: 'x',
    );
    expect(checkAnswer(q, 'a').correct, isTrue);
    expect(checkAnswer(q, 'b').correct, isFalse);
  });

  test('重心は頂点の平均', () {
    final c = regions.first.centroid;
    expect(c.x, 5);
    expect(c.y, 5);
  });
}
