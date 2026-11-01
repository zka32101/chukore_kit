import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _feat(String id, String label, String type, Object coords, {String idKey = 'ADM0_A3', String labelKey = 'NAME_JA'}) => {
      'type': 'Feature',
      'properties': {idKey: id, labelKey: label},
      'geometry': {'type': type, 'coordinates': coords},
    };

String _fc(List<Map<String, dynamic>> fs) => jsonEncode({'type': 'FeatureCollection', 'features': fs});

const _sq = [[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]];
List<List<num>> _at(num dx, num dy) => [[dx, dy], [dx + 10, dy], [dx + 10, dy + 10], [dx, dy + 10], [dx, dy]];

MapPack _conv(String src, {int scale = 1000, Set<String>? only, String idProp = 'ADM0_A3', String labelProp = 'NAME_JA'}) =>
    mapPackFromGeoJson(src, id: 'w', attribution: '出典', scale: scale, only: only, idProperty: idProp, labelProperty: labelProp);

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

void main() {
  test('Polygon と MultiPolygon。閉じる点は取り除く', () {
    final p = _conv(_fc([
      _feat('AAA', '甲', 'Polygon', [_sq]),
      _feat('BBB', '乙', 'MultiPolygon', [[_at(20, 0)], [_at(40, 0)]]),
    ]));
    expect(p.id, 'w');
    expect(p.attribution, '出典');
    expect([for (final r in p.regions) r.id], ['AAA', 'BBB']);
    expect(p.regions[0].label, '甲');
    expect(p.regions[0].rings.single.length, 4);
    expect(p.regions[1].rings.length, 2);
    expect(p.scale, 1000);
    expect(validateMapPack(p).where((i) => i.isError), isEmpty);
    expect(regionAt(p.regions, const GeoPoint(5, 5)), 'AAA');
    expect(regionAt(p.regions, const GeoPoint(45, 5)), 'BBB');
  });

  test('穴（内側のリング）は捨てる。3 つ目の座標は無視', () {
    final hole = [[3, 3], [3, 6], [6, 6], [6, 3], [3, 3]];
    final p = _conv(_fc([_feat('AAA', '甲', 'Polygon', [_sq, hole])]));
    expect(p.regions.single.rings.length, 1);
    expect(regionAt(p.regions, const GeoPoint(4, 4)), 'AAA');
    expect(regionAt(p.regions, const GeoPoint(1, 1)), 'AAA'); // 外側のリング（穴の方ではない）
    final z = _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0, 99], [10, 0, 99], [10, 10, 99], [0, 0, 99]]])]));
    expect(z.regions.single.rings.single.length, 3);
  });

  test('scale に丸める。続けて同じ点・行って戻るとげは取り除く', () {
    final p = _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], [10.004, 0], [10.002, 0.001], [10, 10], [0, 10], [0, 0]]])]), scale: 100);
    final r = p.regions.single.rings.single;
    expect([for (final q in r) (q.x, q.y)], [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]);
    // A→B→A のとげ
    final spike = _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], [10, 0], [10.01, 0], [10, 0], [10, 10], [0, 10], [0, 0]]])]), scale: 100);
    expect([for (final q in spike.regions.single.rings.single) (q.x, q.y)], [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)]);
    expect(validateMapPack(spike).where((i) => i.isError), isEmpty);
  });

  test('とげを取り除いた結果がまた重複なら続けて取り除く', () {
    final p = _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], [10, 0], [10, 0.01], [10, 0], [10, 10], [0, 10], [0, 0.01], [0, 0]]])]), scale: 100);
    final r = p.regions.single.rings.single;
    expect([for (final q in r) (q.x, q.y)], [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0), (0.0, 0.01)]);
  });

  test('丸めで 2 点になるリング・重複で 3 点が 2 点になるリングも捨てる', () {
    final two = [[0, 0], [1, 0], [1, 0.001], [0, 0]];
    final dupe = [[0, 0], [0.001, 0], [5, 5]];
    final p = _conv(_fc([_feat('AAA', '甲', 'MultiPolygon', [[_sq], [two], [dupe]])]), scale: 100);
    expect(p.regions.single.rings.length, 1);
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [dupe])]), scale: 100), _bad('使えるリング'));
  });

  test('丸めは四捨五入（切り捨てではない）', () {
    final p = _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], [10.006, 0], [10.006, 10.006], [0, 10]]])]), scale: 100);
    expect(p.regions.single.rings.single[1].x, 10.01);
    expect(p.regions.single.rings.single[2].y, 10.01);
  });

  test('既定の scale は 1000', () {
    final p = mapPackFromGeoJson(_fc([_feat('AAA', '甲', 'Polygon', [_sq])]), id: 'w', attribution: 'x');
    expect(p.scale, 1000);
  });

  test('丸めで 3 頂点未満になったリングは捨てる。残りが無ければエラー', () {
    final tiny = [[0, 0], [0.001, 0], [0.001, 0.001], [0, 0]];
    final p = _conv(_fc([_feat('AAA', '甲', 'MultiPolygon', [[_sq], [tiny]])]), scale: 100);
    expect(p.regions.single.rings.length, 1);
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [tiny])]), scale: 100), _bad('使えるリング'));
  });

  test('only で領域を絞る（絞られた領域の label が無くても読める）', () {
    final fs = [
      _feat('AAA', '甲', 'Polygon', [_sq]),
      {'type': 'Feature', 'properties': {'ADM0_A3': 'BBB'}, 'geometry': {'type': 'Polygon', 'coordinates': [_at(20, 0)]}},
    ];
    final p = _conv(_fc(fs), only: {'AAA'});
    expect([for (final r in p.regions) r.id], ['AAA']);
    expect(() => _conv(_fc(fs)), _bad('NAME_JA'));
    expect(() => _conv(_fc(fs), only: {'ZZZ'}), _bad('領域がありません'));
  });

  test('id・表示名の property を選べる', () {
    final src = _fc([_feat('東京', 'Tokyo', 'Polygon', [_sq], idKey: 'nam', labelKey: 'nam_en')]);
    final p = _conv(src, idProp: 'nam', labelProp: 'nam_en');
    expect([p.regions.single.id, p.regions.single.label], ['東京', 'Tokyo']);
  });

  test('形の誤り', () {
    expect(() => _conv('{'), _bad('読めません'));
    expect(() => _conv('[]'), _bad('FeatureCollection'));
    expect(() => _conv('{"type":"Feature"}'), _bad('FeatureCollection'));
    expect(() => _conv('{"type":"FeatureCollection"}'), _bad('FeatureCollection'));
    expect(() => _conv('{"type":"GeometryCollection","features":[]}'), _bad('FeatureCollection'));
    expect(() => _conv(_fc([])), _bad('領域がありません'));
    expect(() => _conv(jsonEncode({'type': 'FeatureCollection', 'features': [1]})), _bad('Feature'));
    expect(() => _conv(jsonEncode({'type': 'FeatureCollection', 'features': [{'type': 'Feature', 'geometry': null}]})), _bad('properties'));
    expect(() => _conv(_fc([_feat('', '甲', 'Polygon', [_sq])])), _bad('ADM0_A3'));
    expect(() => _conv(_fc([_feat('AAA', '', 'Polygon', [_sq])])), _bad('NAME_JA'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [_sq]), _feat('AAA', '乙', 'Polygon', [_sq])])), _bad('重複'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Point', [0, 0])])), _bad('未対応'));
    expect(() => _conv(jsonEncode({'type': 'FeatureCollection', 'features': [{'type': 'Feature', 'properties': {'ADM0_A3': 'A', 'NAME_JA': 'a'}, 'geometry': null}]})), _bad('geometry'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'MultiPolygon', 5)])), _bad('配列'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [])])), _bad('空'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [5])])), _bad('配列'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], [1]]])])), _bad('経度'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], ['x', 1]]])])), _bad('経度'));
    expect(() => _conv(_fc([_feat('AAA', '甲', 'Polygon', [[[0, 0], [1, 'y']]])])), _bad('経度'));
  });

  test('書き出した地図は読み直せて、簡略化しても判定が変わらない', () {
    final p = _conv(_fc([_feat('AAA', '甲', 'Polygon', [_sq]), _feat('BBB', '乙', 'Polygon', [_at(20, 0)])]));
    final q = MapPack.parse(p.encode());
    expect(q.encode(), p.encode());
    final s = simplifyMapPack(q, tolerance: 0.5);
    expect(regionAt(s.regions, const GeoPoint(25, 5)), 'BBB');
  });
}
