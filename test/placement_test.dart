import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 国ごとの型の置き方（placements.json）。核の型を共有し、国ごとに「どの型をどの単元に置くか」だけを変える。
void main() {
  const dir = 'docs/content_drafts/suugaku_chu3';
  final templatesSource = File('$dir/templates.json').readAsStringSync();

  test('置き方の読み込み: 型ID → 単元ID。空・未知のキー・重複・版違いはエラー', () {
    final p = parsePlacements(
      '{"version":1,"placements":[{"template":"a","unitId":"u1"},{"template":"b","unitId":"u2"}]}',
    );
    expect(p, {'a': 'u1', 'b': 'u2'});
    expect(
      () => parsePlacements('{"version":2,"placements":[]}'),
      throwsFormatException,
    );
    expect(
      () => parsePlacements('{"version":1,"placements":[]}'),
      throwsFormatException,
    );
    expect(
      () => parsePlacements(
        '{"version":1,"placements":[{"template":"a","unitId":"u","x":1}]}',
      ),
      throwsFormatException,
    );
    expect(
      () => parsePlacements(
        '{"version":1,"placements":[{"template":"a","unitId":"u"},{"template":"a","unitId":"v"}]}',
      ),
      throwsFormatException,
    );
    expect(
      () => parsePlacements('{"version":1,"placements":[{"template":"a"}]}'),
      throwsFormatException,
    );
    expect(() => parsePlacements('[]'), throwsFormatException);
  });

  test('置き方を渡すと、載っている型だけを使い、単元を付け替える。型にない ID はエラー', () {
    final all = TemplateSet.parse(templatesSource);
    expect(all.templates.length, 35);
    final set = TemplateSet.parse(
      templatesSource,
      placement: {'m3_fn_graph_001': 'x_unit_1', 'm3_pyth_thm_001': 'x_unit_2'},
    );
    expect(set.templates.map((t) => t.id), [
      'm3_fn_graph_001',
      'm3_pyth_thm_001',
    ]);
    expect(set.templates.map((t) => t.unitId), ['x_unit_1', 'x_unit_2']);
    // 付け替えても、変種（問題と答え）は同じ（核は共有）
    final a = all.templates
        .firstWhere((t) => t.id == 'm3_pyth_thm_001')
        .generate(7)
        .question;
    final b = set.templates.last.generate(7).question;
    expect(b.answer, a.answer);
    expect(b.unitId, 'x_unit_2');
    expect(a.unitId, 'm3_pyth_thm');
    expect(
      () => TemplateSet.parse(templatesSource, placement: {'nothing': 'u'}),
      throwsFormatException,
    );
  });

  test('目録の placements: 別の国の単元に置いて、一括検証が通る。置き方の単元がなければエラー', () {
    // 別の国の単元ツリー（日本とは違う ID・並び）
    final units = {
      'version': 1,
      'units': [
        {
          'id': 'x_alg',
          'subject': 'math',
          'grade': 9,
          'title': 'Funções',
          'order': 1,
        },
        {
          'id': 'x_alg_quad',
          'subject': 'math',
          'grade': 9,
          'parentId': 'x_alg',
          'title': 'Função quadrática',
          'order': 1,
        },
        {
          'id': 'x_geo',
          'subject': 'math',
          'grade': 9,
          'title': 'Geometria',
          'order': 2,
        },
        {
          'id': 'x_geo_pyth',
          'subject': 'math',
          'grade': 9,
          'parentId': 'x_geo',
          'title': 'Pitágoras',
          'order': 1,
        },
      ],
    };
    final prereq = {'version': 1, 'prerequisites': <Object>[]};
    String manifest() => jsonEncode({
      'version': 1,
      'id': 'chukore_xx_math_9',
      'country': 'XX',
      'locale': 'pt',
      'subject': 'math',
      'grades': [9],
      'curriculum': '見本',
      'contentVersion': '0.0.1',
      'attribution': [],
      'files': {
        'units': 'units.json',
        'prerequisites': 'prerequisites.json',
        'templates': 'templates.json',
        'placements': 'placements.json',
      },
    });
    ContentPackReport run(Map<String, String> placements) =>
        validateContentPack(manifest(), (p) {
          switch (p) {
            case 'units.json':
              return jsonEncode(units);
            case 'prerequisites.json':
              return jsonEncode(prereq);
            case 'templates.json':
              return templatesSource;
            case 'placements.json':
              return jsonEncode({
                'version': 1,
                'placements': [
                  for (final e in placements.entries)
                    {'template': e.key, 'unitId': e.value},
                ],
              });
          }
          return null;
        });
    final ok = run({
      'm3_quad_solve_001': 'x_alg_quad',
      'm3_pyth_thm_001': 'x_geo_pyth',
      'm3_pyth_thm_002': 'x_geo_pyth',
    });
    expect(
      ok.issues.where((i) => i.isError),
      isEmpty,
      reason: ok.issues.join('\n'),
    );
    expect(ok.counts['templates'], 3); // 載っている型だけ
    // 国の単元にない単元を指す
    final bad = run({'m3_quad_solve_001': 'm3_quad_solve'});
    expect(bad.issues.where((i) => i.isError), isNotEmpty);
    // 型にない ID
    final unknown = run({'nothing': 'x_alg_quad'});
    expect(unknown.issues.map((i) => i.code), contains('pack_file_malformed'));
    // 場面は国の層: 場面を使う型を、場面なしのパックに置くとエラー（場面はその国の暮らしの例に差し替える）
    final scene = run({'m3_fn_graph_001': 'x_alg_quad'});
    expect(scene.issues.map((i) => i.code), contains('pack_scene_missing'));
    // 日本の単元ツリーのままの置き方（置き方なし）では、日本の単元に置かれる
    expect(
      TemplateSet.parse(templatesSource).templates.first.unitId,
      'm3_fn_graph',
    );
  });
}
