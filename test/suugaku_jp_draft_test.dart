import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('数学（中1）の単元・前提の草案は検証エラーなし、サンプルの型の単元がある', () {
    Map<String, dynamic> read(String f) =>
        jsonDecode(File('docs/content_drafts/suugaku_chu1/$f').readAsStringSync()) as Map<String, dynamic>;
    final tree = UnitTree.fromJson(read('units.json'));
    final units = [for (final u in (read('units.json')['units'] as List)) Unit.fromJson(u as Map<String, dynamic>)];
    expect(validateUnitList(units).where((i) => i.isError), isEmpty);
    final graph = PrerequisiteGraph.fromJson(read('prerequisites.json'));
    expect(graph.validate(tree), isEmpty);
    expect(graph.uncoveredLeaves(tree), isEmpty);
    final ids = {for (final u in units) u.id};
    // 変種生成の見本が使う単元
    for (final t in TemplateSet.parse(File('docs/samples/templates.sample.json').readAsStringSync()).templates) {
      expect(ids, contains(t.unitId));
    }
  });
}
