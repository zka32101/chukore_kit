import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dir = 'docs/content_drafts/shakai_chu1';
  Map<String, dynamic> read(String f) => jsonDecode(File('$dir/$f').readAsStringSync()) as Map<String, dynamic>;

  test('社会（中1）の草案: 単元・前提・問題にエラー・警告なし、全末端の単元に前提がある', () {
    final unitsJson = read('units.json');
    final units = [for (final u in (unitsJson['units'] as List)) Unit.fromJson(u as Map<String, dynamic>)];
    expect(validateUnitList(units).where((i) => i.isError), isEmpty);
    final tree = UnitTree.fromJson(unitsJson);
    final graph = PrerequisiteGraph.fromJson(read('prerequisites.json'));
    expect(graph.validate(tree), isEmpty);
    expect(graph.uncoveredLeaves(tree), isEmpty);
    final bank = parseQuestionBank(read('questions.json'));
    final issues = [...bank.issues, ...validateQuestionBank(questions: bank.questions, tree: tree, mistakeLines: bank.mistakeLines)];
    expect(issues, isEmpty, reason: issues.join('\n'));
    expect(bank.questions.length, 18);
    // すべての問題タイプを使っている。空でない葉の単元はそれぞれ 1 問以上
    expect({for (final q in bank.questions) q.type}, {'choice', 'multi', 'numeric', 'match', 'map', 'timeline', 'text'});
    expect(units.every((u) => u.subject == 'social'), isTrue);
  });

  test('社会（中1）の草案: 全問の正解が正解と判定され、誤答の型どおりに判定される', () {
    final bank = parseQuestionBank(read('questions.json'));
    // 記述・複数語の答えは別解を `|` でつなぐので、各項目の最初の別解を入力にする
    String input(Question q) => switch (q.type) {
      'text' => q.answer.split('|').first,
      'multi' => q.answer.split(';').map((e) => e.split('|').first).join(';'),
      _ => q.answer,
    };
    for (final q in bank.questions) {
      expect(checkAnswer(q, input(q)).correct, isTrue, reason: q.id);
      if (q.type == 'text') expect(checkAnswer(q, q.answer.split('|').last).correct, isTrue, reason: '${q.id} 別解');
      for (final e in q.misconceptionTags.entries) {
        final r = checkAnswer(q, e.key);
        expect(r.correct, isFalse, reason: '${q.id} ${e.key}');
        expect(r.misconceptionTag, e.value, reason: '${q.id} ${e.key}');
      }
    }
  });

  test('社会（中1）の草案: 世紀の問題は式 ceil(y/100) の答えと一致する', () {
    final bank = parseQuestionBank(read('questions.json'));
    final q = bank.questions.firstWhere((q) => q.id == 'soc1_era_001');
    expect(MathExpr.parse('ceil(y/100)').eval({'y': 1868}).toInt().toString(), q.answer);
    expect(centuryOf(1868).toString(), q.answer);
  });

  test('社会（中1）の草案: 雨温図は読めて SVG になり、選択肢の ID と対応し、正解の図は降水量が最も少ない', () {
    final charts = read('charts.json')['charts'] as Map<String, dynamic>;
    final specs = {for (final e in charts.entries) e.key: ChartSpec.fromJson(e.value as Map<String, dynamic>)};
    for (final s in specs.values) {
      expect(s.kind, ChartKind.climate);
      expect(s.toSvg(), startsWith('<svg'));
    }
    final q = parseQuestionBank(read('questions.json')).questions.firstWhere((q) => q.id == 'soc1_chart_001');
    expect(q.choices.toSet(), specs.keys.toSet());
    final driest = specs.entries.reduce((a, b) => a.value.total('rain') <= b.value.total('rain') ? a : b);
    expect(driest.key, q.answer);
    // 他の図との差が十分ある（見本の見分けやすさ）
    final totals = [for (final s in specs.values) s.total('rain')]..sort();
    expect(totals[1] > totals[0] * 3, isTrue);
  });
}
