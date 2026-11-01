import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const dir = 'docs/content_drafts/suugaku_chu1';

Map<String, dynamic> lesson([Map<String, dynamic> over = const {}]) => {
  'id': 'les1',
  'version': 1,
  'unitId': 'm1_linear',
  'minutes': 4,
  'titleId': 't',
  'blocks': [
    {'type': 'hook', 'textId': 'h'},
    {'type': 'text', 'textId': 't1'},
    {
      'type': 'check',
      'questions': ['m1_linear_002~11'],
    },
    {
      'type': 'summary',
      'textIds': ['s1'],
    },
  ],
  ...over,
};

Lesson ls([Map<String, dynamic> over = const {}]) => Lesson.fromJson(lesson(over));

Map<String, dynamic> example([Map<String, dynamic> over = const {}]) => {
  'type': 'example',
  'template': 'm1_linear_002',
  'seed': 7,
  'lines': ['{a}x{+b}={c}', '{a}x={c}{+-b}', '{a}x={c-b}', 'x={k}'],
  'target': 'x={k}',
  ...over,
};

Lesson withBlocks(List<Map<String, dynamic>> extra, {Map<String, dynamic> over = const {}}) => ls({
  'blocks': [
    {'type': 'hook', 'textId': 'h'},
    ...extra,
    {
      'type': 'check',
      'questions': ['m1_linear_002~11'],
    },
    {
      'type': 'summary',
      'textIds': ['s1'],
    },
  ],
  ...over,
});

void main() {
  final tpl = TemplateSet.parse(File('$dir/templates.json').readAsStringSync());
  final tree = UnitTree.fromJson(jsonDecode(File('$dir/units.json').readAsStringSync()) as Map<String, dynamic>);
  final explorations = ExplorationSet.parse(File('docs/samples/explorations.sample.json').readAsStringSync());
  final constructions = ConstructionSet.parse(File('docs/samples/constructions.sample.json').readAsStringSync());
  final experiences = ExperienceSet.parse(File('$dir/experiences.json').readAsStringSync());
  final refs = LessonRefs(
    questionIds: const {'q_plain'},
    templateIds: {for (final t in tpl.templates) t.id},
    explorationIds: {
      for (final e in explorations.explorations) e.id,
      ...experiences.experiences.map((e) => e.id),
    },
    constructionIds: {for (final c in constructions.constructions) c.id},
    tags: {
      for (final t in tpl.templates)
        for (final w in t.wrong) w.tag,
    },
  );
  final checker = MathLessonChecker(tpl);
  List<ValidationIssue> check(Lesson l, {LessonChecker? c, LessonRefs? r}) =>
      validateLessons(LessonSet([l]), tree: tree, refs: r ?? refs, checker: c ?? checker);
  List<String> codes(Lesson l) => check(l).map((i) => i.code).toList();

  group('読み込み', () {
    test('正常: すべてのブロックの種類', () {
      final l = ls({
        'pre': ['q_plain'],
        'blocks': [
          {'type': 'hook', 'textId': 'h'},
          {'type': 'text', 'textId': 't'},
          {'type': 'figure', 'template': 'm1_geo_angle_001', 'seed': 3, 'altId': 'a'},
          {'type': 'figure', 'figureId': 'f1', 'altId': 'a'},
          {'type': 'formula', 'expr': 'x+3=7', 'textId': 'f'},
          {'type': 'formula', 'expr': '2x+6'},
          example({
            'textIds': ['a', 'b', 'c', 'd'],
          }),
          {'type': 'explore', 'exploration': 'ex_linear_ab'},
          {'type': 'explore', 'construction': 'ct_perp_bisector'},
          {
            'type': 'check',
            'questions': ['q_plain', 'm1_linear_002~11', 'm1_linear_002~12'],
          },
          {'type': 'pitfall', 'tag': 'move_term_sign', 'textId': 'p'},
          {
            'type': 'summary',
            'textIds': ['s1', 's2'],
          },
        ],
      });
      expect(l.blocks.map((b) => b.type), [
        'hook',
        'text',
        'figure',
        'figure',
        'formula',
        'formula',
        'example',
        'explore',
        'explore',
        'check',
        'pitfall',
        'summary',
      ]);
      expect(l.checkQuestions, ['q_plain', 'm1_linear_002~11', 'm1_linear_002~12']);
      expect(l.pre, ['q_plain']);
      expect((l.blocks[2] as FigureBlock).template, 'm1_geo_angle_001');
      expect((l.blocks[6] as ExampleBlock).lines, hasLength(4));
    });
    test('書き間違いは FormatException', () {
      Map<String, dynamic> blocks(List<Map<String, dynamic>> b) => {'blocks': b};
      final bad = <Map<String, dynamic>>[
        {'extra': 1},
        {'id': 'a~b'},
        {'id': ''},
        {'version': 0},
        {'minutes': 0},
        {'minutes': 31},
        {'minutes': '4'},
        {'titleId': ''},
        {'unitId': null},
        {
          'pre': ['a', 'b', 'c'],
        },
        {
          'pre': [3],
        },
        {'blocks': <dynamic>[]},
        {'blocks': 'x'},
        blocks([
          {'type': 'hook'},
        ]),
        blocks([
          {'type': 'hook', 'textId': 'h', 'extra': 1},
        ]),
        blocks([
          {'type': 'poem', 'textId': 'h'},
        ]),
        blocks([
          {'textId': 'h'},
        ]),
        blocks([
          {'type': 'figure', 'altId': 'a'},
        ]), // template も figureId もない
        blocks([
          {'type': 'figure', 'altId': 'a', 'template': 't', 'seed': 1, 'figureId': 'f'},
        ]), // 両方
        blocks([
          {'type': 'figure', 'altId': 'a', 'template': 't'},
        ]), // seed がない
        blocks([
          {'type': 'figure', 'altId': 'a', 'template': 't', 'seed': 0},
        ]),
        blocks([
          {'type': 'figure', 'template': 't', 'seed': 1},
        ]), // altId がない
        blocks([
          {'type': 'formula'},
        ]),
        blocks([
          example({'seed': 0}),
        ]),
        blocks([
          example({
            'lines': ['{a}x'],
          }),
        ]), // 2 行未満
        blocks([
          example({'lines': List.filled(13, 'x')}),
        ]),
        blocks([
          example({
            'textIds': ['a'],
          }),
        ]), // 行と同じ数でない
        blocks([
          example({'template': ''}),
        ]),
        blocks([
          {'type': 'explore'},
        ]),
        blocks([
          {'type': 'explore', 'exploration': 'a', 'construction': 'b'},
        ]),
        blocks([
          {'type': 'check', 'questions': <dynamic>[]},
        ]),
        blocks([
          {
            'type': 'check',
            'questions': ['a', 'b', 'c', 'd'],
          },
        ]),
        blocks([
          {'type': 'pitfall', 'tag': 'Bad Tag', 'textId': 'p'},
        ]),
        blocks([
          {'type': 'pitfall', 'tag': 'ok_tag'},
        ]),
        blocks([
          {'type': 'summary', 'textIds': <dynamic>[]},
        ]),
        blocks([
          {
            'type': 'summary',
            'textIds': ['1', '2', '3', '4', '5'],
          },
        ]),
        {
          'blocks': [5],
        },
      ];
      for (final b in bad) {
        expect(() => ls(b), throwsFormatException, reason: b.toString());
      }
    });
    test('LessonSet: 版・形・id の重複', () {
      expect(() => LessonSet.parse('{'), throwsFormatException);
      expect(() => LessonSet.parse('[]'), throwsFormatException);
      expect(() => LessonSet.parse('{"version":2,"lessons":[]}'), throwsFormatException);
      expect(() => LessonSet.parse('{"version":1}'), throwsFormatException);
      expect(
        () => LessonSet.parse(
          jsonEncode({
            'version': 1,
            'lessons': [lesson(), lesson()],
          }),
        ),
        throwsFormatException,
      );
      expect(
        LessonSet.parse(
          jsonEncode({
            'version': 1,
            'lessons': [lesson()],
          }),
        ).lessons,
        hasLength(1),
      );
    });
  });

  group('検証 validateLessons', () {
    test('下書きのレッスン（docs/content_drafts）は問題なし。例題の途中式も全部通る', () {
      final set = LessonSet.parse(File('$dir/lessons.json').readAsStringSync());
      expect(set.lessons.length, 4);
      final issues = validateLessons(set, tree: tree, refs: refs, checker: checker);
      expect(issues, isEmpty, reason: issues.join('\n'));
    });
    test('正常な短いレッスンは問題なし', () => expect(check(ls()), isEmpty));
    test('単元がない・葉でない', () {
      expect(codes(ls({'unitId': 'nope'})), contains('lesson_unit_missing'));
      expect(codes(ls({'unitId': 'm1_eq'})), contains('lesson_unit_not_leaf'));
    });
    test('参照先がない（問題・変種の型・図の型・例題の型・体験・作図・事前の確認）', () {
      expect(
        codes(
          withBlocks(
            [],
            over: {
              'pre': ['nope'],
            },
          ),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        codes(
          withBlocks(
            [],
            over: {
              'pre': ['nope_tpl~3'],
            },
          ),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        check(
          withBlocks(
            [],
            over: {
              'pre': ['q_plain', 'm1_linear_002~3'],
            },
          ),
        ).where((i) => i.code == 'lesson_ref_missing'),
        isEmpty,
      );
      expect(
        codes(
          withBlocks([
            {
              'type': 'check',
              'questions': ['zzz'],
            },
          ]),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'figure', 'template': 'nope', 'seed': 1, 'altId': 'a'},
          ]),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        codes(
          withBlocks([
            example({'template': 'nope'}),
          ]),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'explore', 'exploration': 'nope'},
          ]),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'explore', 'construction': 'nope'},
          ]),
        ),
        contains('lesson_ref_missing'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'figure', 'figureId': 'anything', 'altId': 'a'},
          ]),
        ),
        isEmpty,
      ); // コンテンツ側の図は見ない
    });
    test('誤解の型・式の読み取り', () {
      expect(
        codes(
          withBlocks([
            {'type': 'pitfall', 'tag': 'no_such_tag', 'textId': 'p'},
          ]),
        ),
        contains('lesson_tag_unknown'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'formula', 'expr': '2x+'},
          ]),
        ),
        contains('lesson_formula_unreadable'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'formula', 'expr': 'x+3='},
          ]),
        ),
        contains('lesson_formula_unreadable'),
      );
      expect(
        codes(
          withBlocks([
            {'type': 'formula', 'expr': 'x＋3＝7'.replaceAll('＋', '+')},
          ]),
        ),
        isEmpty,
      ); // 全角の ＝
    });
    test('確認クイズ・要点・長さ・最初のブロック', () {
      final noCheck = ls({
        'blocks': [
          {'type': 'hook', 'textId': 'h'},
          {
            'type': 'summary',
            'textIds': ['s'],
          },
        ],
      });
      expect(codes(noCheck), contains('lesson_no_check'));
      final noSummary = ls({
        'blocks': [
          {'type': 'hook', 'textId': 'h'},
          {
            'type': 'check',
            'questions': ['q_plain'],
          },
        ],
      });
      final r = check(noSummary);
      expect(r.map((i) => i.code), contains('lesson_no_summary'));
      expect(r.firstWhere((i) => i.code == 'lesson_no_summary').isError, isFalse);
      expect(codes(ls({'minutes': 6})), contains('lesson_too_long'));
      expect(codes(ls({'minutes': 5})), isNot(contains('lesson_too_long')));
      final many = withBlocks(List.filled(11, {'type': 'text', 'textId': 't'})); // hook + 11 + check + summary = 14
      expect(codes(many), contains('lesson_too_long'));
      final textFirst = ls({
        'blocks': [
          {'type': 'text', 'textId': 't'},
          {
            'type': 'check',
            'questions': ['q_plain'],
          },
          {
            'type': 'summary',
            'textIds': ['s'],
          },
        ],
      });
      expect(codes(textFirst), contains('lesson_first_not_hook'));
    });
    test('checker を渡さなければ例題・式の中身は見ない', () {
      final l = withBlocks([
        example({
          'lines': ['{a}x', 'zzz'],
        }),
        {'type': 'formula', 'expr': '2x+'},
      ]);
      expect(check(l, c: null).where((i) => i.code == 'lesson_example_mismatch'), isNotEmpty); // 既定の checker が使われる
      final noChecker = validateLessons(LessonSet([l]), tree: tree, refs: refs);
      expect(
        noChecker.where((i) => i.code == 'lesson_example_mismatch' || i.code == 'lesson_formula_unreadable'),
        isEmpty,
      );
    });
  });

  group('例題の途中式の検査 MathLessonChecker', () {
    String? ex(Map<String, dynamic> over) =>
        checker.checkExample(withBlocks([example(over)]).blocks[1] as ExampleBlock);

    test('正しい途中式は通る', () {
      expect(ex({}), isNull);
      final noTarget = example({
        'lines': ['{a}x{+b}={c}', '{a}x{+b}{+-b}={c}{+-b}', '{a}x={c-b}'],
      })..remove('target');
      expect(checker.checkExample(withBlocks([noTarget]).blocks[1] as ExampleBlock), isNull); // 目標なしの例題（性質の説明）
    });
    test('途中で式が変わる行を示し、誤解の型を添える', () {
      final why = ex({
        'lines': ['{a}x{+b}={c}', '{a}x={c}{+b}', '{a}x={c-b}', 'x={k}'],
      })!;
      expect(why, contains('2 行目'));
      expect(why, contains('move_term_sign'));
      expect(
        ex({
          'lines': ['{a}x{+b}={c}', '{a}x={c-b}', 'x={c-b}', 'x={k}'],
        })!,
        contains('3 行目'),
      ); // 割り忘れ
      expect(
        ex({
          'lines': ['{a}x{+b}={c}', '{a}x={c-b}', 'x='],
        })!,
        contains('読めない'),
      );
      expect(
        ex({
          'lines': ['{a}x{+b}={c}', '{a}x+'],
        })!,
        contains('読めない'),
      );
      expect(
        ex({
          'lines': ['{a}x{+b}={c}', '{a}x{+b}'],
        })!,
        contains('混ざ'),
      );
    });
    test('目標に着かない・解の形まで整理していない', () {
      expect(
        ex({
          'lines': ['{a}x{+b}={c}', '{a}x={c-b}'],
          'target': 'x={k}',
        })!,
        contains('解の形'),
      );
      expect(
        ex({
          'lines': ['{a}x{+b}={c}', '{a}x={c-b}'],
          'target': 'x={k+1}',
        }),
        isNotNull,
      );
    });
    test('式の例題の形（form）', () {
      final t = {
        'template': 'm1_expr_combine_001',
        'seed': 3,
        'lines': ['{a}x{+b}{+c}x{+d}', '{a}x{+c}x{+b}{+d}', '{a+c}x{+b+d}'],
        'target': '{a+c}x{+b+d}',
        'form': 'expanded',
      };
      expect(ex(t), isNull);
      expect(
        ex({
          ...t,
          'lines': ['{a}x{+b}{+c}x{+d}', '{a}x{+c}x{+b}{+d}'],
          'target': '{a+c}x{+b+d}',
        })!,
        contains('expanded'),
      );
    });
    test('最後の行が型の答えと違えば検出（途中は正しく変形していても、別の問題を解いている）', () {
      // 型 m1_linear_002 の答えは k。最後を x={k+1} にし、途中も合わせて変える（同じ解の変形に見えるよう、問題の行も変える）
      final why = ex({
        'lines': ['{a}x{+b}={c}', 'x={k}'],
        'target': 'x={k}',
      });
      expect(why, isNull); // 正しい 2 行（割り算を 1 手で書いた）
      final other = ex({
        'lines': ['x={k+1}', 'x={k+1}'],
        'target': 'x={k+1}',
      });
      expect(other, contains('型の答え'));
    });
    test('値を差し込めない・変種を作れない', () {
      expect(
        ex({
          'lines': ['{z}x', '{z}x'],
        })!,
        contains('差し込めません'),
      );
      expect(
        ex({
          'lines': ['{a/1001}x=1', '{a/1001}x=1'],
        })!,
        contains('整数・分数'),
      );
      final small = TemplateSet.parse(
        jsonEncode({
          'version': 1,
          'templates': [
            {
              'id': 'never',
              'templateVersion': 1,
              'unitId': 'u',
              'type': 'expr',
              'difficulty': 0.5,
              'params': {
                'a': {
                  'int': [1, 2],
                },
              },
              'constraints': ['a > 5'],
              'display': {'x': '{a}'},
              'answer': '{a}',
              'explanationId': 'e',
            },
          ],
        }),
      );
      final c = MathLessonChecker(small);
      final block = ExampleBlock(template: 'never', seed: 1, lines: const ['x', 'x']);
      expect(c.checkExample(block), contains('変種を作れません'));
      expect(c.checkExample(const ExampleBlock(template: 'nope', seed: 1, lines: ['x', 'x'])), contains('ありません'));
    });
    test('formulaReadable', () {
      expect(checker.formulaReadable('2x+3=11'), isTrue);
      expect(checker.formulaReadable('2x＋3'.replaceAll('＋', '+')), isTrue);
      expect(checker.formulaReadable('x＝4'), isTrue);
      expect(checker.formulaReadable('x=4=5'), isFalse);
      expect(checker.formulaReadable('2x+'), isFalse);
    });
  });

  group('進み具合 LessonProgress', () {
    final l = LessonSet.parse(File('$dir/lessons.json').readAsStringSync()).lessons[1]; // les_m1_linear_01
    test('読んだブロック・確認クイズ・完了の判定', () {
      var p = LessonProgress(lessonId: l.id);
      expect(p.isComplete(l), isFalse);
      for (var i = 0; i < l.blocks.length; i++) {
        p = p.viewBlock(i);
      }
      expect(p.viewedAll(l), isTrue);
      expect(p.checkedAll(l), isFalse);
      expect(p.isComplete(l), isFalse);
      p = p.recordCheck(l.checkQuestions[0], true);
      expect(p.checkedAll(l), isFalse);
      p = p.recordCheck(l.checkQuestions[1], false);
      expect(p.checkedAll(l), isTrue);
      expect(p.isComplete(l), isTrue);
      expect(p.postRate, 0.5);
      // 同じ問題の結果は置き換わる
      p = p.recordCheck(l.checkQuestions[1], true);
      expect(p.postRate, 1.0);
      // 読み残しがあれば完了でない
      final partial = LessonProgress(
        lessonId: l.id,
        viewed: {0, 1, 2},
        post: {for (final q in l.checkQuestions) q: true},
      );
      expect(partial.isComplete(l), isFalse);
      expect(() => p.viewBlock(-1), throwsArgumentError);
    });
    test('更新は新しい値（元は変わらない）', () {
      final a = LessonProgress(lessonId: 'x');
      final b = a.viewBlock(2).recordPre('q', true).recordCheck('c', false).complete(DateTime.utc(2026, 10, 31));
      expect(a.viewed, isEmpty);
      expect(a.pre, isEmpty);
      expect(a.post, isEmpty);
      expect(a.completedAt, isNull);
      expect(b.viewed, {2});
      expect(b.pre, {'q': true});
      expect(b.post, {'c': false});
      expect(b.completedAt, DateTime.utc(2026, 10, 31));
      expect(b.viewBlock(5).completedAt, DateTime.utc(2026, 10, 31)); // 完了日時は引き継ぐ
    });
    test('事前→事後の伸び', () {
      var p = LessonProgress(lessonId: 'x');
      expect(p.preRate, isNull);
      expect(p.postRate, isNull);
      expect(p.gain, isNull);
      p = p.recordPre('a', false).recordPre('b', false);
      expect(p.gain, isNull); // 事後がない
      p = p.recordCheck('c', true).recordCheck('d', true);
      expect(p.preRate, 0.0);
      expect(p.postRate, 1.0);
      expect(p.gain, 1.0);
      final down = LessonProgress(lessonId: 'x', pre: {'a': true}, post: {'c': false});
      expect(down.gain, -1.0);
    });
    test('JSON の往復と、読み込みの書き間違い', () {
      final p = LessonProgress(
        lessonId: 'x',
        viewed: {3, 1},
        pre: {'a': true},
        post: {'c': false},
        completedAt: DateTime.utc(2026, 10, 31, 9),
      );
      final j = p.toJson();
      expect(j['viewed'], [1, 3]);
      final q = LessonProgress.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
      expect(q.lessonId, 'x');
      expect(q.viewed, {1, 3});
      expect(q.pre, {'a': true});
      expect(q.post, {'c': false});
      expect(q.completedAt, DateTime.utc(2026, 10, 31, 9));
      expect(LessonProgress(lessonId: 'x').toJson().containsKey('completedAt'), isFalse);
      for (final bad in <Map<String, dynamic>>[
        {},
        {'lessonId': ''},
        {
          'lessonId': 'x',
          'viewed': [-1],
        },
        {
          'lessonId': 'x',
          'viewed': ['a'],
        },
        {
          'lessonId': 'x',
          'pre': {'a': 1},
        },
        {'lessonId': 'x', 'post': 'z'},
        {'lessonId': 'x', 'completedAt': 'ayer'},
      ]) {
        expect(() => LessonProgress.fromJson(bad), throwsFormatException, reason: bad.toString());
      }
    });
    test('レッスンの効き目の集計: 件数・完了率・平均。最小件数に満たないレッスンは出さない', () {
      final t = DateTime.utc(2026, 10, 31);
      final list = [
        LessonProgress(lessonId: 'b', pre: {'a': false}, post: {'c': true}, completedAt: t),
        LessonProgress(lessonId: 'b', pre: {'a': true}, post: {'c': true}),
        LessonProgress(lessonId: 'b', post: {'c': false}),
        LessonProgress(lessonId: 'a', pre: {'a': false}, post: {'c': true}, completedAt: t),
      ];
      final all = summarizeLessonEffects(list);
      expect(all.map((e) => e.lessonId), ['a', 'b']); // ID 順
      final b = all[1];
      expect(b.learners, 3);
      expect(b.completed, 1);
      expect(b.completionRate, closeTo(1 / 3, 1e-9));
      expect(b.avgPre, 0.5); // 事前に答えた 2 件の平均
      expect(b.avgPost, closeTo(2 / 3, 1e-9));
      expect(b.avgGain, 0.5); // 事前も事後もある 2 件: 1.0 と 0.0 の平均
      expect(summarizeLessonEffects(list, minLearners: 2).map((e) => e.lessonId), ['b']);
      expect(summarizeLessonEffects(const []), isEmpty);
      final none = summarizeLessonEffects([LessonProgress(lessonId: 'z')]).single;
      expect(none.avgPre, isNull);
      expect(none.avgPost, isNull);
      expect(none.avgGain, isNull);
      expect(none.completionRate, 0.0);
      const empty = LessonEffect(lessonId: 'z', learners: 0, completed: 0, avgPre: null, avgPost: null, avgGain: null);
      expect(empty.completionRate, 0.0); // 0 件でも割り算にならない
    });
    test('確認クイズの結果は lesson_check の回答になる', () {
      final a = lessonCheckAttempt(
        questionId: 'q',
        unitId: 'm1_linear',
        correct: true,
        answeredAt: DateTime.utc(2026, 10, 31),
        chosenId: 'c',
        elapsedMs: 900,
        confident: true,
      );
      expect(a.mode, lessonCheckMode);
      expect(a.mode, 'lesson_check');
      expect(a.correct, isTrue);
      expect(a.chosenId, 'c');
      expect(a.elapsedMs, 900);
      expect(a.confident, isTrue);
      expect(a.hintsUsed, 0);
    });
  });
}
