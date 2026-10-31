import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree get tree => UnitTree.fromJson(
  jsonDecode(File('docs/samples/units_math.sample.json').readAsStringSync()) as Map<String, dynamic>,
);

TemplateSet get sample => TemplateSet.parse(File('docs/samples/templates.sample.json').readAsStringSync());

Map<String, dynamic> base([Map<String, dynamic> over = const {}]) => {
  'id': 't1',
  'templateVersion': 1,
  'unitId': 'm1_expr',
  'type': 'expr',
  'difficulty': 0.5,
  'params': {
    'a': {
      'int': [2, 5],
    },
  },
  'display': {'expr': '{a}x'},
  'answer': '{a}x',
  'explanationId': 'e',
  ...over,
};

MathTemplate tpl([Map<String, dynamic> over = const {}]) => MathTemplate.fromJson(base(over));

void main() {
  dataTests();
  group('サンプル（docs/samples）', () {
    test('検証エラー・警告なし。展開した問題集も通常の検証を通る', () {
      final issues = validateTemplates(sample, tree: tree);
      expect(issues, isEmpty, reason: issues.join('\n'));
      final qs = [for (final v in sample.expand()) v.question];
      expect(qs, hasLength(80));
      expect(qs.map((q) => q.id).toSet(), hasLength(80));
    });

    test('同じ種は同じ問題（固定値。変えると過去の変種が変わる）', () {
      final t = sample.templates.first;
      final v = t.generate(1);
      expect(v.question.id, 'm1_expand_001~1');
      expect(v.question.answer, '6x+54');
      expect(v.display['expr'], '6(x+9)');
      expect(v.question.misconceptionTags, {'6x+9': 'distribute_first_only', '6x+15': 'add_instead_of_multiply'});
      expect(jsonEncode(t.generate(7).question.toJson()), jsonEncode(t.generate(7).question.toJson()));
      expect(t.generate(1).question.answer, isNot(t.generate(3).question.answer));
    });

    test('展開の型: 答えは展開済みで、正解の式は解ける。誤答の式は不正解でタグが付く', () {
      for (final v
          in sample.templates.first.generate(1).question.version == 1 ? sample.expand().take(40) : <Variant>[]) {
        final q = v.question;
        expect(checkAnswer(q, q.answer).correct, isTrue, reason: q.id);
        expect(checkAnswer(q, v.display['expr']!).correct, isFalse, reason: '${q.id} 展開前の式'); // 形の指定
        expect(q.misconceptionTags, hasLength(2), reason: q.id); // 正解と同値な誤答は引き直されている
        for (final e in q.misconceptionTags.entries) {
          final r = checkAnswer(q, e.key);
          expect(r.correct, isFalse, reason: q.id);
          expect(r.misconceptionTag, e.value, reason: q.id);
        }
      }
    });

    test('方程式の型: 選択肢は重複せず正解を含み、位置が種で変わる。式の値が整合', () {
      final vs = sample.expand().skip(40).toList();
      final positions = <int>{};
      for (final v in vs) {
        final q = v.question;
        expect(q.choices.toSet(), hasLength(q.choices.length), reason: q.id);
        expect(q.choices, contains(q.answer));
        expect(q.misconceptionTags.keys, isNot(contains(q.answer)));
        expect(q.misconceptionTags, hasLength(3));
        positions.add(q.choices.indexOf(q.answer));
        final k = v.params['k']!, a = v.params['a']!, b = v.params['b']!, c = v.params['c']!;
        expect(a * k + b, c);
        expect(q.answer, k.toInt().toString());
        expect(checkAnswer(q, q.answer).correct, isTrue);
      }
      expect(positions, {0, 1, 2, 3});
    });
  });

  group('読み込み', () {
    test('必須・範囲・未知のキー・型違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        {'extra': 1},
        {'id': 'a~b'},
        {'id': ''},
        {'templateVersion': 0},
        {'type': 'map'},
        {'difficulty': 1.5},
        {'params': <String, dynamic>{}},
        {
          'params': {
            'x': {
              'int': [1, 2],
            },
          },
        },
        {
          'params': {
            'ab': {
              'int': [1, 2],
            },
          },
        },
        {
          'params': {
            'a': {
              'int': [5, 2],
            },
          },
        },
        {
          'params': {
            'a': {
              'int': [1.5, 2],
            },
          },
        },
        {
          'params': {
            'a': {'oneOf': <num>[]},
          },
        },
        {
          'params': {
            'a': {
              'int': [1, 2],
              'oneOf': [1],
            },
          },
        },
        {'form': 'nope'},
        {
          'type': 'choice',
          'choices': ['{a}'],
        },
        {
          'choices': ['{a}', '{a}'],
        },
        {'display': <String, dynamic>{}},
        {'answer': '{z}x'},
        {'answer': '{a'},
        {
          'wrong': [
            {'expr': '{a}', 'tag': 'Bad Tag'},
          ],
        },
        {
          'wrong': [
            {'expr': '{a}'},
          ],
        },
        {
          'constraints': ['a'],
        },
        {
          'constraints': ['q > 0'],
        },
        {
          'derived': {'a': 'a+1'},
        },
        {
          'derived': {'c': 'z+1'},
        },
      ];
      for (final o in bad) {
        expect(() => tpl(o), throwsFormatException, reason: o.toString());
      }
    });
    test('form は expr の型だけ', () {
      expect(
        () => tpl({
          'type': 'choice',
          'choices': ['{a}', '{a+1}'],
          'answer': '{a}',
          'form': 'expanded',
        }),
        throwsFormatException,
      );
    });
    test('TemplateSet: 版・形・id の重複', () {
      expect(() => TemplateSet.parse('{'), throwsFormatException);
      expect(() => TemplateSet.parse('[]'), throwsFormatException);
      expect(() => TemplateSet.parse('{"version":2,"templates":[]}'), throwsFormatException);
      expect(() => TemplateSet.parse('{"version":1}'), throwsFormatException);
      expect(
        () => TemplateSet.parse(
          jsonEncode({
            'version': 1,
            'templates': [base(), base()],
          }),
        ),
        throwsFormatException,
      );
      expect(
        TemplateSet.parse(
          jsonEncode({
            'version': 1,
            'templates': [base()],
          }),
        ).templates,
        hasLength(1),
      );
    });
  });

  group('生成', () {
    test('制約を満たし、満たせなければ StateError', () {
      final t = tpl({
        'constraints': ['a != 3', 'a < 5'],
      });
      for (var s = 1; s <= 60; s++) {
        final a = t.generate(s).params['a']!;
        expect(a != 3 && a < 5, isTrue);
      }
      expect(
        () => tpl({
          'constraints': ['a > 100'],
        }).generate(1),
        throwsStateError,
      );
    });
    test('derived を使える。oneOf から選ぶ', () {
      final t = tpl({
        'params': {
          'a': {
            'oneOf': [10, 20],
          },
        },
        'derived': {'c': 'a*2'},
        'display': {'expr': '{c}'},
        'answer': '{c}',
      });
      final seen = {for (var s = 1; s <= 40; s++) t.generate(s).display['expr']};
      expect(seen, {'20', '40'});
    });
    test('正確に書けない値は引き直す（毎回書けなければ StateError）', () {
      expect(() => tpl({'answer': '{a/1001}x'}).generate(1), throwsStateError);
    });
    test('選択肢の型: 答えが選択肢に無い・誤答が選択肢に無いのは FormatException', () {
      Map<String, dynamic> ch(Map<String, dynamic> o) => {
        'type': 'choice',
        'choices': ['{a}', '{a+1}'],
        'answer': '{a}',
        ...o,
      };
      expect(() => tpl(ch({'answer': '{a+9}'})).generate(1), throwsFormatException);
      expect(
        () => tpl(
          ch({
            'wrong': [
              {'expr': '{a+9}', 'tag': 'x_y'},
            ],
          }),
        ).generate(1),
        throwsFormatException,
      );
      expect(
        tpl(
          ch({
            'wrong': [
              {'expr': '{a+1}', 'tag': 'x_y'},
            ],
          }),
        ).generate(1).question.misconceptionTags,
        hasLength(1),
      );
    });
    test('表示の式がすでに目標の形なら引き直す', () {
      final t = tpl({
        'form': 'expanded',
        'display': {'expr': '{a}x'},
        'answer': '{a}x',
      });
      expect(() => t.generate(1), throwsStateError);
    });
    test('計算できない derived・重複する選択肢・正解と同じ誤答の引き方は引き直す（毎回なら StateError）', () {
      expect(
        () => tpl({
          'derived': {'c': '1/(a-a)'},
        }).generate(1),
        throwsStateError,
      );
      Map<String, dynamic> ch(Map<String, dynamic> o) => {
        'type': 'choice',
        'choices': ['{a}', '{a}', '{a+1}'],
        'answer': '{a}',
        ...o,
      };
      expect(() => tpl(ch({})).generate(1), throwsStateError);
      expect(
        () => tpl(
          ch({
            'choices': ['{a}', '{a+1}'],
            'wrong': [
              {'expr': '{a}', 'tag': 'x_y'},
            ],
          }),
        ).generate(1),
        throwsStateError,
      );
    });
    test('templateVersion が問題の version になる', () {
      expect(tpl({'templateVersion': 3}).generate(1).question.version, 3);
    });
    test('変種の ID の読み取り', () {
      expect(parseVariantId('m1_expand_001~17'), (templateId: 'm1_expand_001', seed: 17));
      expect(parseVariantId('m1_expand_001'), isNull);
      expect(parseVariantId('a~b'), isNull);
      expect(parseVariantId('a~1~2'), isNull);
      expect(parseVariantId('~3'), isNull);
    });
  });

  group('検証 validateTemplates', () {
    TemplateSet one(Map<String, dynamic> over) => TemplateSet([tpl(over)]);
    List<String> codes(TemplateSet s, {int count = 40}) =>
        validateTemplates(s, tree: tree, count: count).map((i) => i.code).toList();

    test('満たせない制約は template_unsatisfiable、選択肢の食い違いは template_expression_invalid', () {
      expect(
        codes(
          one({
            'constraints': ['a > 100'],
          }),
        ),
        contains('template_unsatisfiable'),
      );
      expect(
        codes(
          one({
            'type': 'choice',
            'choices': ['{a}', '{a+1}'],
            'answer': '{a+9}',
          }),
        ),
        contains('template_expression_invalid'),
      );
    });
    test('答えが半分以上かぶる範囲は警告（エラーではない）', () {
      final r = validateTemplates(one({}), tree: tree);
      expect(r.map((i) => i.code), contains('template_answer_dup'));
      expect(r.where((i) => i.code == 'template_answer_dup').every((i) => !i.isError), isTrue);
      expect(
        codes(
          one({
            'params': {
              'a': {
                'int': [1, 400],
              },
            },
          }),
        ),
        isNot(contains('template_answer_dup')),
      );
    });
    test('展開した問題集の検証も働く（単元が無い型は unit_missing）', () {
      expect(
        codes(
          one({
            'unitId': 'nope',
            'params': {
              'a': {
                'int': [1, 400],
              },
            },
          }),
        ),
        contains('unit_missing'),
      );
    });
    test('form を満たさない答えは answer_form_mismatch', () {
      expect(
        codes(
          one({
            'form': 'expanded',
            'answer': '{a}(x+1)',
            'display': {'expr': '{a}x+{a}'},
            'params': {
              'a': {
                'int': [1, 400],
              },
            },
          }),
        ),
        contains('answer_form_mismatch'),
      );
    });
  });
}

void dataTests() {
  Map<String, dynamic> dbase([Map<String, dynamic> over = const {}]) => {
    'id': 'd1',
    'templateVersion': 1,
    'unitId': 'm1_data_rep',
    'type': 'expr',
    'difficulty': 0.5,
    'params': {
      'L': {
        'list': {
          'n': [5, 9],
          'int': [1, 20],
        },
      },
    },
    'stats': {'m': 'mean(L)'},
    'display': {'data': '{L}'},
    'answer': '{m}',
    'explanationId': 'e',
    ...over,
  };
  MathTemplate dt([Map<String, dynamic> over = const {}]) => MathTemplate.fromJson(dbase(over));

  group('データ（数列と集計）', () {
    test('数列は種で決まり、個数・値の範囲に収まる。表示は {L}', () {
      final t = dt();
      for (var s = 1; s <= 40; s++) {
        final v = t.generate(s);
        final l = v.lists['L']!;
        expect(l.length, inInclusiveRange(5, 9));
        expect(l.every((x) => x >= 1 && x <= 20 && x == x.roundToDouble()), isTrue);
        expect(v.display['data'], l.map((x) => x.toInt()).join(', '));
        expect(v.params['m'], closeTo(l.reduce((a, b) => a + b) / l.length, 1e-9));
        expect(checkAnswer(v.question, v.question.answer).correct, isTrue);
      }
      expect(t.generate(3).lists, t.generate(3).lists);
      expect({for (var s = 1; s <= 20; s++) t.generate(s).display['data']}.length, greaterThan(15));
    });

    test('集計関数の値（偶数個の中央値は中央 2 つの平均、count は lo 以上 hi 未満）', () {
      // 数列を固定するため、個数 1 つ・値 1 つの範囲で作る
      MathTemplate fixed(String stat, {List<int> vals = const [3, 8, 5, 8, 1]}) => dt({
        'params': {
          'L': {
            'list': {
              'n': [vals.length, vals.length],
              'int': [1, 1],
            },
          },
        },
        'stats': {'m': stat},
      });
      // 乱数で決まるので、関数の値は _evalStat と同じ定義を使う別の経路（Variant の lists）から検算する
      for (var s = 1; s <= 30; s++) {
        final t = dt({
          'stats': {
            'a': 'sum(L)',
            'b': 'median(L)',
            'c': 'range(L)',
            'd': 'min(L)',
            'e': 'max(L)',
            'f': 'count(L)',
            'g': 'count(L, 5, 12)',
          },
          'derived': {'m': 'a'},
        });
        final v = t.generate(s);
        final l = [...v.lists['L']!]..sort();
        final n = l.length;
        expect(v.params['a'], l.reduce((a, b) => a + b));
        expect(v.params['b'], n.isOdd ? l[n ~/ 2] : (l[n ~/ 2 - 1] + l[n ~/ 2]) / 2);
        expect(v.params['c'], l.last - l.first);
        expect(v.params['d'], l.first);
        expect(v.params['e'], l.last);
        expect(v.params['f'], n);
        expect(v.params['g'], l.where((x) => x >= 5 && x < 12).length);
      }
      expect(fixed('mean(L)').generate(1).params['m'], 1.0);
    });

    test('mode は最頻値が 1 つのときだけ（同数が複数なら引き直す）。count の引数はパラメータ名も使える', () {
      final t = dt({
        'params': {
          'L': {
            'list': {
              'n': [9, 14],
              'int': [1, 6],
            },
          },
          'p': {
            'int': [2, 4],
          },
        },
        'stats': {'m': 'mode(L)', 'k': 'count(L, p, 7)'},
      });
      for (var s = 1; s <= 40; s++) {
        final v = t.generate(s);
        final counts = <double, int>{};
        for (final x in v.lists['L']!) {
          counts[x] = (counts[x] ?? 0) + 1;
        }
        final top = counts.values.reduce((a, b) => a > b ? a : b);
        final modes = counts.entries.where((e) => e.value == top).map((e) => e.key).toList();
        expect(modes, [v.params['m']]);
        expect(v.params['k'], v.lists['L']!.where((x) => x >= v.params['p']!).length);
      }
    });

    test('最頻値が決まらない型（毎回同数）は StateError', () {
      // 値が 1 か 2 で個数 2 → 同数のことが多いが、必ずではない。値の範囲 1..1000 で個数 2 なら毎回同数
      final t = dt({
        'params': {
          'L': {
            'list': {
              'n': [2, 2],
              'int': [1, 1000],
            },
          },
        },
        'stats': {'m': 'mode(L)'},
      });
      var failed = 0;
      for (var s = 1; s <= 10; s++) {
        try {
          t.generate(s);
        } on StateError {
          failed++;
        }
      }
      expect(failed, greaterThan(5));
    });

    test('式の中で stats の値を使える。制約で絞れる', () {
      final t = dt({
        'stats': {'m': 'mean(L)', 'n': 'count(L)'},
        'constraints': ['n >= 8'],
        'answer': '{m*n}',
      });
      for (var s = 1; s <= 30; s++) {
        final v = t.generate(s);
        expect(v.lists['L']!.length, greaterThanOrEqualTo(8));
        expect(v.question.answer, formatExact(v.lists['L']!.reduce((a, b) => a + b)));
      }
    });

    test('書き間違いは FormatException', () {
      final bad = <Map<String, dynamic>>[
        {
          'params': {
            'l': {
              'list': {
                'n': [5, 9],
                'int': [1, 20],
              },
            },
          },
        }, // 小文字は数列にならない（スカラー）
        {
          'params': {
            'L': {
              'list': {
                'n': [0, 9],
                'int': [1, 20],
              },
            },
          },
        },
        {
          'params': {
            'L': {
              'list': {
                'n': [5, 999],
                'int': [1, 20],
              },
            },
          },
        },
        {
          'params': {
            'L': {
              'list': {
                'n': [9, 5],
                'int': [1, 20],
              },
            },
          },
        },
        {
          'params': {
            'L': {
              'list': {
                'n': [5, 9],
                'int': [20, 1],
              },
            },
          },
        },
        {
          'params': {
            'L': {
              'list': {
                'n': [5, 9],
              },
            },
          },
        },
        {
          'params': {
            'L': {
              'int': [1, 20],
            },
          },
        },
        {
          'stats': {'m': 'average(L)'},
        },
        {
          'stats': {'m': 'mean(M)'},
        },
        {
          'stats': {'m': 'mean(L, 1)'},
        },
        {
          'stats': {'m': 'count(L, 1)'},
        },
        {
          'stats': {'m': 'count(L, 1, z)'},
        },
        {
          'stats': {'m': 'mean L'},
        },
        {
          'stats': {'mm': 'mean(L)'},
        },
        {
          'stats': {'x': 'mean(L)'},
        },
        {
          'display': {'data': '{M}'},
        },
        {
          'derived': {'m': '1'},
        }, // stats と名前が重なる
        {'answer': '{z}'},
      ];
      for (final o in bad) {
        expect(() => dt(o), throwsFormatException, reason: o.toString());
      }
      // stats があるのに数列がない
      expect(
        () => MathTemplate.fromJson({
          ...dbase(),
          'params': {
            'a': {
              'int': [1, 2],
            },
          },
          'stats': {'m': 'mean(L)'},
          'display': {'x': '{a}'},
          'answer': '{a}',
        }),
        throwsFormatException,
      );
    });
  });
}
