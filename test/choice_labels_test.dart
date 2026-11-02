import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 選択肢の文言を国・言語ごとに差し替えられる（choiceLabels）。
Map<String, dynamic> _tpl({List<String>? choices, bool labels = true}) => {
  'id': 't1',
  'templateVersion': 1,
  'unitId': 'u1',
  'type': 'choice',
  'difficulty': 0.5,
  'params': {
    'a': {
      'int': [2, 9],
    },
  },
  if (labels) 'choiceLabels': true,
  'display': {'v': '{a}'},
  'answer': (choices ?? ['ok', 'w1']).first,
  'choices': choices ?? ['ok', 'w1'],
  'wrong': [
    {
      'expr': (choices ?? ['ok', 'w1'])[1],
      'tag': 'oops',
    },
  ],
  'explanationId': 'exp_t1',
};

void main() {
  test('choiceLabels: 選択肢は ID。文言でなくてもよく、{…} や日本語などはエラー。図の選択肢とは同時に使えない', () {
    expect(MathTemplate.fromJson(_tpl()).choiceLabels, isTrue);
    expect(
      () => MathTemplate.fromJson(_tpl(choices: ['円', '長方形'])),
      throwsFormatException,
    );
    expect(
      () => MathTemplate.fromJson(_tpl(choices: ['{a}x', 'w1'])),
      throwsFormatException,
    );
    final withFig = _tpl()..['figures'] = {'ok': {}, 'w1': {}};
    expect(() => MathTemplate.fromJson(withFig), throwsFormatException);
    final expr = _tpl()..['type'] = 'expr';
    expect(() => MathTemplate.fromJson(expr), throwsFormatException);
    final bad = _tpl()..['choiceLabels'] = 'yes';
    expect(() => MathTemplate.fromJson(bad), throwsFormatException);
    expect(choiceLabelTextId('t1', 'ok'), 'choice_t1_ok');
  });

  test('選択肢に国・言語の文字が直接あると警告（choiceLabels にすると出ない）', () {
    final tree = UnitTree.fromJson({
      'version': 1,
      'units': [
        {'id': 'u1', 'subject': 'math', 'grade': 1, 'title': 't', 'order': 1},
      ],
    });
    Set<String> codes(Map<String, dynamic> j) => validateTemplates(
      TemplateSet.parse(
        jsonEncode({
          'version': 1,
          'templates': [j],
        }),
      ),
      tree: tree,
    ).map((i) => i.code).toSet();
    expect(
      codes(_tpl(choices: ['円', '長方形'], labels: false)),
      contains('template_choice_locale_text'),
    );
    expect(
      codes(_tpl(choices: ['ok', 'w1'], labels: false)),
      isNot(contains('template_choice_locale_text')),
    );
    expect(codes(_tpl()), isNot(contains('template_choice_locale_text')));
    // 数式の選択肢（記号 π・√・² など）は国に依存しない
    expect(
      codes(_tpl(choices: ['20π', '√2'], labels: false)),
      isNot(contains('template_choice_locale_text')),
    );
  });

  test(
    '中1の草案: 文言が国ごとに違う選択肢は、すべて ID（警告なし）。文言は texts にあり、別の言語に差し替えても同じ ID で動く',
    () {
      const dir = 'docs/content_drafts/suugaku_chu1';
      final set = TemplateSet.parse(
        File('$dir/templates.json').readAsStringSync(),
      );
      final texts = ContentTexts.parse(
        File('$dir/texts.json').readAsStringSync(),
      );
      final labeled = set.templates.where((t) => t.choiceLabels).toList();
      expect(labeled.map((t) => t.id).toSet(), {
        'm1_eq_prop_001',
        'm1_alg_rel_001',
        'm1_space_cut_001',
        'm1_space_cut_002',
        'm1_space_cut_003',
        'm1_space_cut_004',
        'm1_space_cut_005',
      });
      // 目録の検証に、選択肢の文言の欠けが含まれる
      String read(String p) => File('$dir/$p').readAsStringSync();
      final ok = validateContentPack(read('manifest.json'), read);
      expect(ok.issues.where((i) => i.isError), isEmpty);
      final broken = jsonDecode(read('texts.json')) as Map<String, dynamic>;
      (broken['texts'] as Map).remove('choice_m1_space_cut_001_circle');
      final r = validateContentPack(
        read('manifest.json'),
        (p) => p == 'texts.json' ? jsonEncode(broken) : read(p),
      );
      expect(
        r.issues
            .where((i) => i.code == 'pack_text_missing')
            .map((i) => i.subjectId),
        contains('choice_m1_space_cut_001_circle'),
      );
      // 日本語以外の文言に差し替えても（IDは同じ）、正解の判定は変わらない
      final english = {
        ...texts.texts,
        for (final t in labeled)
          for (final c in t.choices)
            choiceLabelTextId(t.id, c): 'EN ${t.id} $c',
      };
      for (final t in labeled) {
        for (var s = 1; s <= 10; s++) {
          final v = t.generate(s);
          expect(checkAnswer(v.question, t.answer).correct, isTrue);
          for (final c in v.question.choices) {
            expect(
              renderVariantText(english[choiceLabelTextId(t.id, c)]!, v),
              startsWith('EN '),
            );
          }
        }
      }
    },
  );
}
