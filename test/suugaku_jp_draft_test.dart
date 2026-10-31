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

  test('数学（中1）の型の草案: エラー・警告なし（問題のない単元を除く）。全変種の正解と誤答が期待どおりに判定される', () {
    const dir = 'docs/content_drafts/suugaku_chu1';
    final tree = UnitTree.fromJson(jsonDecode(File('$dir/units.json').readAsStringSync()) as Map<String, dynamic>);
    final set = TemplateSet.parse(File('$dir/templates.json').readAsStringSync());
    // 答えの取りうる値が少ない型（最頻値は 1〜6、階級の度数は 0〜数個）は、答えの種類が少ないのが性質
    const fewAnswers = {'m1_data_mode_001', 'm1_data_class_001'};
    final issues = validateTemplates(
      set,
      tree: tree,
    ).where((i) => i.code != 'unit_empty' && !(i.code == 'template_answer_dup' && fewAnswers.contains(i.subjectId)));
    expect(issues, isEmpty, reason: issues.join('\n'));
    for (final v in set.expand()) {
      final q = v.question;
      expect(checkAnswer(q, q.answer).correct, isTrue, reason: q.id);
      final fig = v.figure;
      if (fig != null) {
        final svg = fig.toSvg();
        expect(svg, startsWith('<svg'), reason: q.id);
        expect(svg.contains('NaN') || svg.contains('Infinity'), isFalse, reason: q.id);
        expect(fig.altId, isNotEmpty);
      }
      for (final e in q.misconceptionTags.entries) {
        final r = checkAnswer(q, e.key);
        expect(r.correct, isFalse, reason: '${q.id} ${e.key}');
        expect(r.misconceptionTag, e.value, reason: '${q.id} ${e.key}');
      }
    }
  });
}
