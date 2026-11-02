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
      // 型がまだ少ない単元の警告（unit_empty）と、答えの種類が少ない型の警告だけは許す
      final other = r.issues.where((i) => i.code != 'unit_empty' && i.code != 'template_answer_dup');
      expect(other, isEmpty, reason: r.issues.join('\n'));
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

  test('中3の場面（現実の具体例）: 型の変種はすべて現実にありえる値で、場面は型・レッスンから使われている', () {
    const dir = '$root/suugaku_chu3';
    final scenes = SceneSet.parse(File('$dir/scenes.json').readAsStringSync());
    final set = TemplateSet.parse(File('$dir/templates.json').readAsStringSync());
    final withScene = set.templates.where((t) => t.sceneId != null).toList();
    expect(withScene.length, 3);
    for (final t in withScene) {
      expect(scenes.ids, contains(t.sceneId), reason: t.id);
      for (var s = 1; s <= 60; s++) {
        final v = t.generate(s);
        expect(v.sceneId, t.sceneId);
        for (final e in t.plausible.entries) {
          expect(v.params[e.key], inInclusiveRange(e.value.lo, e.value.hi), reason: '${t.id} ${e.key}');
        }
      }
    }
    // 落下距離は動く図（点が曲線の上を p 秒まで動く）
    final fall = set.templates.firstWhere((t) => t.id == 'm3_fn_use_002');
    for (var s = 1; s <= 12; s++) {
      final v = fall.generate(s);
      final a = v.animation!;
      expect(a.frames.length, 13);
      expect(a.times.last, v.params['p']);
      expect(a.durationMs, 2600);
      expect(v.figure!.toSvg(), a.frames.last.toSvg());
    }
    // 制動距離: 速さ p m/s、停止距離 y = p²/d（現実の範囲）
    final braking = set.templates.firstWhere((t) => t.id == 'm3_fn_use_001');
    for (var s = 1; s <= 30; s++) {
      final v = braking.generate(s);
      expect(v.params['y'], v.params['p']! * v.params['p']! / v.params['d']!);
      expect(v.question.answer, '${v.params['y']!.round()}');
    }
  });

  test('中3の文言（教科書のような説明）: 全変種で問題文・解説の差し込みができ、解説は答えを含む', () {
    const dir = '$root/suugaku_chu3';
    final texts = ContentTexts.parse(File('$dir/texts.json').readAsStringSync());
    final set = TemplateSet.parse(File('$dir/templates.json').readAsStringSync());
    for (final t in set.templates) {
      final prompt = texts.texts['prompt_${t.id}']!, exp = texts.texts[t.explanationId]!;
      for (var s = 1; s <= 40; s++) {
        final v = t.generate(s);
        final p = renderVariantText(prompt, v), e = renderVariantText(exp, v);
        expect(p.contains('{') || p.contains('}'), isFalse, reason: '${t.id} $p');
        expect(e.contains('{') || e.contains('}'), isFalse, reason: '${t.id} $e');
        expect(e, contains(v.question.answer), reason: '${t.id}~$s 解説が答えを含む: $e');
      }
    }
    // 実例（ボール）の解説: x = 3 のとき 5 × 3² = 45
    final fall = set.templates.firstWhere((t) => t.id == 'm3_fn_use_002');
    final v = fall.generate(4);
    final p = v.params['p']!.toInt(), y = v.params['y']!.toInt();
    expect(renderVariantText(texts.texts['exp_m3_fn_use_002']!, v), 'y = 5x² に x = $p を代入します。y = 5 × $p² = 5 × ${p * p} = $y。$p 秒間に $y m 落ちます。');
    // 場面の文言と、レッスンの文言の一覧
    final lessons = LessonSet.parse(File('$dir/lessons.json').readAsStringSync()).lessons;
    expect(lessons.length, 5);
    for (final lesson in lessons) {
      for (final id in lesson.textIds) {
        expect(texts.texts, contains(id));
        expect(texts.texts[id]!.runes.length, lessThanOrEqualTo(ContentTexts.longText), reason: id);
      }
    }
    expect(texts.texts.length, greaterThan(20));
  });

  test('中2・中3の単元の ID は m2_・m3_ で始まり、全パックで重複しない', () {
    final all = <String>[
      for (final d in ['suugaku_chu1', 'suugaku_chu2', 'suugaku_chu3']) ...units(d).map((u) => u.id),
    ];
    expect(all.toSet().length, all.length);
    expect(units('suugaku_chu2').every((u) => u.id.startsWith('m2_')), isTrue);
    expect(units('suugaku_chu3').every((u) => u.id.startsWith('m3_')), isTrue);
  });
}
