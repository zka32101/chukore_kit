import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 数学の中1・中2・中3の草案どうしのつながり。
void main() {
  const root = 'docs/content_drafts';
  Map<String, dynamic> read(String dir, String f) =>
      jsonDecode(File('$root/$dir/$f').readAsStringSync()) as Map<String, dynamic>;
  List<Unit> units(String dir) => [for (final u in (read(dir, 'units.json')['units'] as List)) Unit.fromJson(u as Map<String, dynamic>)];

  for (final entry in {'suugaku_chu2': 2, 'suugaku_chu3': 3}.entries) {
    final dir = entry.key, grade = entry.value;

    test('$dir: 一括検証にエラー・警告なし。末端の単元はすべて前提の定義がある', () {
      final r = validateContentPack(File('$root/$dir/manifest.json').readAsStringSync(), (p) {
        final f = File('$root/$dir/$p');
        return f.existsSync() ? f.readAsStringSync() : null;
      });
      expect(r.issues, isEmpty, reason: r.issues.join('\n'));
      expect(r.manifest!.grades, [grade]);
      expect(r.manifest!.subject, 'math');
      expect(r.counts['units'], greaterThan(0));
    });

    test('$dir: 単元は学年 $grade・教科 math。前提は同じパックの単元か、中1・中2のパックの実在する単元', () {
      final us = units(dir);
      expect(us.every((u) => u.grade == grade && u.subject == 'math'), isTrue);
      final tree = UnitTree.fromJson(read(dir, 'units.json'));
      final graph = PrerequisiteGraph.fromJson(read(dir, 'prerequisites.json'));
      expect(graph.uncoveredLeaves(tree), isEmpty);
      // 他のパック（`パックID:単元ID`）の単元が実在し、学年が低い（前提が上の学年を向かない）
      final packs = {
        'chukore_jp_suugaku_chu1': 'suugaku_chu1',
        'chukore_jp_suugaku_chu2': 'suugaku_chu2',
      };
      var checked = 0;
      for (final n in read(dir, 'prerequisites.json')['prerequisites'] as List) {
        for (final e in (n as Map)['external'] as List? ?? const []) {
          final id = (e as Map)['id'] as String;
          final parts = id.split(':');
          expect(parts.length, 2, reason: id);
          final other = packs[parts[0]];
          expect(other, isNotNull, reason: '未知のパック: $id');
          final unit = units(other!).where((u) => u.id == parts[1]).firstOrNull;
          expect(unit, isNotNull, reason: '$id が実在しません');
          expect(unit!.grade < grade, isTrue, reason: '$id は学年 ${unit.grade}（この学年より低いこと）');
          expect(unit.parentId, isNotNull); // 葉の単元（分野ではなく）を指す
          expect(e['title'], isNotEmpty);
          checked++;
        }
      }
      expect(checked, greaterThan(5));
    });
  }

  test('中2・中3の単元の ID は m2_・m3_ で始まり、全パックで重複しない', () {
    final all = <String>[
      for (final d in ['suugaku_chu1', 'suugaku_chu2', 'suugaku_chu3']) ...units(d).map((u) => u.id),
    ];
    expect(all.toSet().length, all.length);
    expect(units('suugaku_chu2').every((u) => u.id.startsWith('m2_')), isTrue);
    expect(units('suugaku_chu3').every((u) => u.id.startsWith('m3_')), isTrue);
  });
}
