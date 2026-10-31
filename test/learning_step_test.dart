import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 2, 10);

Mastery ms(String u, double s) => Mastery(unitId: u, score: s);

Attempt att(
  String u, {
  bool correct = true,
  String? chosen,
  String q = 'q1',
  String mode = 'practice',
  int daysAgo = 1,
}) => Attempt(
  questionId: q,
  unitId: u,
  correct: correct,
  chosenId: chosen,
  mode: mode,
  answeredAt: now.subtract(Duration(days: daysAgo)),
);

Question qn(String id, String unit, {Map<String, String> tags = const {}}) => Question(
  id: id,
  unitId: unit,
  type: 'choice',
  difficulty: 0.5,
  choices: const ['a', 'b', 'c'],
  answer: 'a',
  explanationId: 'e',
  misconceptionTags: tags,
);

Lesson lesson(String id, String unit, {List<Map<String, dynamic>> extra = const []}) => Lesson.fromJson({
  'id': id,
  'version': 1,
  'unitId': unit,
  'minutes': 4,
  'titleId': 't',
  'blocks': [
    {'type': 'hook', 'textId': 'h'},
    ...extra,
    {
      'type': 'check',
      'questions': ['q1'],
    },
    {
      'type': 'summary',
      'textIds': ['s'],
    },
  ],
});

LearningStep? step(
  Map<String, Mastery> mastery, {
  List<String> units = const ['u1'],
  List<Attempt> attempts = const [],
  List<Question> questions = const [],
  LearningContext context = const LearningContext(),
  DateTime? testDate,
}) => nextLearningStep(
  now: now,
  unitIds: units,
  mastery: mastery,
  attempts: attempts,
  questions: questions,
  context: context,
  testDate: testDate,
);

LearningContext ctx({
  List<Lesson> lessons = const [],
  Map<String, LessonProgress> progress = const {},
  PrerequisiteGraph? graph,
  Map<String, List<String>> explorations = const {},
  Set<String> done = const {},
  Map<String, int> due = const {},
}) => LearningContext(
  lessons: LessonSet(lessons),
  progress: progress,
  graph: graph,
  explorations: explorations,
  doneExplorations: done,
  reviewDue: due,
);

LessonProgress finished(Lesson l) {
  var p = LessonProgress(lessonId: l.id);
  for (var i = 0; i < l.blocks.length; i++) {
    p = p.viewBlock(i);
  }
  for (final q in l.checkQuestions) {
    p = p.recordCheck(q, true);
  }
  return p;
}

void main() {
  group('範囲・仕上がり', () {
    test('範囲が空なら null', () => expect(step({}, units: const []), isNull));
    test('すべて仕上がっていれば maintain（最も弱い単元）', () {
      final s = step({'a': ms('a', 0.9), 'b': ms('b', 0.85)}, units: const ['a', 'b'])!;
      expect(s.kind, LearningStepKind.maintain);
      expect(s.reason, LearningStepReason.allDone);
      expect(s.unitId, 'b');
    });
    test('しきい値ちょうど（doneAt）は仕上がり。未満は練習', () {
      expect(step({'u1': ms('u1', 0.8)})!.kind, LearningStepKind.maintain);
      expect(step({'u1': ms('u1', 0.79)})!.kind, LearningStepKind.practice);
    });
    test('単元の重複・並びは結果に影響しない', () {
      final a = step({'a': ms('a', 0.3), 'b': ms('b', 0.5)}, units: const ['b', 'a', 'b']);
      final b = step({'a': ms('a', 0.3), 'b': ms('b', 0.5)}, units: const ['a', 'b']);
      expect(a!.unitId, 'a');
      expect(b!.unitId, 'a');
    });
  });

  group('取り組む単元の選び方', () {
    test('記録のある単元の、習熟度の低い順。同じなら単元 ID 順', () {
      expect(
        step({'a': ms('a', 0.5), 'b': ms('b', 0.3), 'c': ms('c', 0.3)}, units: const ['a', 'b', 'c'])!.unitId,
        'b',
      );
    });
    test('記録がなければ、前提が固まっていて取り組める新しい単元（先が開ける数の多いもの）', () {
      final g = PrerequisiteGraph(const [
        PrereqNode('x', requires: ['base']),
        PrereqNode('y', requires: ['base']),
        PrereqNode('z', requires: ['x']),
      ]);
      // base は仕上がっていて範囲外。x は z の前提なので、先が開ける
      final s = step(
        {'base': ms('base', 0.9)},
        units: const ['x', 'y', 'z'],
        context: ctx(graph: g),
      )!;
      expect(s.unitId, 'x');
    });
    test('新しい単元の選び方は suggestNextUnits の並び（先が開ける数が多いものが先。単元 ID 順ではない）', () {
      final g = PrerequisiteGraph(const [
        PrereqNode('r', requires: ['q']),
      ]);
      final s = step(
        const {},
        units: const ['p', 'q', 'r'],
        context: ctx(graph: g),
      )!;
      expect(s.unitId, 'q'); // q は r の前提で先が開ける。p は ID が先だが開ける先がない
    });
    test('どの単元も前提が弱くて取り組めないときは、前提の弱い単元の土台へ', () {
      final g = PrerequisiteGraph(const [
        PrereqNode('x', requires: ['base']),
      ]);
      final s = step(
        const {},
        units: const ['x', 'base'],
        context: ctx(graph: g),
      )!;
      expect(s.unitId, 'base'); // base は前提がなく取り組める
    });
  });

  group('テストが近い', () {
    final test7 = DateTime.utc(2026, 11, 9);
    test('7 日以内で、直近に受けていなければ test（最も弱い単元と日数）', () {
      final s = step({'a': ms('a', 0.4), 'b': ms('b', 0.6)}, units: const ['a', 'b'], testDate: test7)!;
      expect(s.kind, LearningStepKind.test);
      expect(s.reason, LearningStepReason.testSoon);
      expect(s.unitId, 'a');
      expect(s.daysToTest, 7);
    });
    test('8 日前はまだ（ふつうの流れ）。過ぎたテストも見ない', () {
      expect(step({'u1': ms('u1', 0.5)}, testDate: DateTime.utc(2026, 11, 10))!.kind, LearningStepKind.practice);
      final past = step({'u1': ms('u1', 0.5)}, testDate: DateTime.utc(2026, 11, 1))!;
      expect(past.kind, LearningStepKind.practice);
      expect(past.reason, LearningStepReason.keepPracticing); // 過ぎたテストは「近い」ではない
      expect(past.daysToTest, isNull);
      expect(
        step({'u1': ms('u1', 0.5)}, testDate: DateTime.utc(2026, 11, 10))!.reason,
        LearningStepReason.keepPracticing,
      );
    });
    test('直近 3 日以内に模試・単元テストを受けていれば、また勧めず、弱い単元の練習へ', () {
      for (final mode in ['mock', 'unit_test']) {
        final s = step(
          {'u1': ms('u1', 0.5)},
          attempts: [att('u1', mode: mode, daysAgo: 2)],
          testDate: test7,
        )!;
        expect(s.kind, LearningStepKind.practice, reason: mode);
        expect(s.reason, LearningStepReason.testSoon);
        expect(s.daysToTest, 7);
      }
      // 3 日前は「また勧める」
      expect(
        step(
          {'u1': ms('u1', 0.5)},
          attempts: [att('u1', mode: 'mock', daysAgo: 3)],
          testDate: test7,
        )!.kind,
        LearningStepKind.test,
      );
      // ふつうの練習は受けたことにならない
      expect(
        step({'u1': ms('u1', 0.5)}, attempts: [att('u1', daysAgo: 1)], testDate: test7)!.kind,
        LearningStepKind.test,
      );
    });
    test('当日はテストを勧めない（ガードがあるので練習のまま）', () {
      final s = step({'u1': ms('u1', 0.5)}, testDate: DateTime.utc(2026, 11, 2))!;
      expect(s.kind, LearningStepKind.practice);
      expect(s.daysToTest, 0);
    });
    test('テストが近いときは新しいレッスン・体験を足さない', () {
      final l = lesson('l1', 'u1');
      final c = ctx(
        lessons: [l],
        explorations: {
          'u1': ['ex1'],
        },
      );
      final s = step(
        {'u1': ms('u1', 0.3)},
        context: c,
        testDate: test7,
        attempts: [att('u1', mode: 'mock', daysAgo: 1)],
      )!;
      expect(s.kind, LearningStepKind.practice);
      // テストが近くなければレッスン
      expect(step({'u1': ms('u1', 0.3)}, context: c)!.kind, LearningStepKind.lesson);
    });
    test('全部仕上がっていれば、テストが近くても maintain（テストを勧めない）ではなく test', () {
      // 仕上がっていても、テストが 7 日以内で受けていなければ test を先に勧める
      final s = step({'u1': ms('u1', 0.9)}, testDate: test7)!;
      expect(s.kind, LearningStepKind.test);
      final done = step(
        {'u1': ms('u1', 0.9)},
        testDate: test7,
        attempts: [att('u1', mode: 'mock', daysAgo: 1)],
      )!;
      expect(done.kind, LearningStepKind.maintain);
      expect(done.daysToTest, 7);
    });
  });

  group('前提が弱い', () {
    final g = PrerequisiteGraph(const [
      PrereqNode('eq', requires: ['expr']),
      PrereqNode('expr', requires: ['num']),
    ]);
    test('前提をさかのぼって、土台の単元を対象にする', () {
      final s = step(
        {'eq': ms('eq', 0.4), 'expr': ms('expr', 0.3), 'num': ms('num', 0.2)},
        units: const ['eq', 'expr', 'num'],
        context: ctx(graph: g),
      )!;
      // 範囲に num があり、最も弱いのは num（記録あり・習熟度最低）
      expect(s.unitId, 'num');
      final t = step(
        {'eq': ms('eq', 0.4), 'expr': ms('expr', 0.3)},
        units: const ['eq'],
        context: ctx(graph: g),
      )!;
      expect(t.unitId, 'num'); // eq → expr（弱い）→ num（記録なし＝弱い）
      expect(t.reason, LearningStepReason.prerequisiteWeak);
      expect(t.kind, LearningStepKind.practice);
    });
    test('前提が固まっていれば、その単元のまま', () {
      final s = step(
        {'eq': ms('eq', 0.4), 'expr': ms('expr', 0.7)},
        units: const ['eq'],
        context: ctx(graph: g),
      )!;
      expect(s.unitId, 'eq');
      expect(s.reason, LearningStepReason.keepPracticing);
    });
    test('前提の単元にレッスンがあれば、そのレッスン（前提が弱い理由）', () {
      final l = lesson('l_num', 'num');
      final s = step(
        {'eq': ms('eq', 0.4)},
        units: const ['eq'],
        context: ctx(graph: g, lessons: [l]),
      )!;
      expect(s.unitId, 'num');
      expect(s.kind, LearningStepKind.lesson);
      expect(s.lessonId, 'l_num');
      expect(s.reason, LearningStepReason.prerequisiteWeak);
    });
    test('前提が循環していても止まる', () {
      final cyc = PrerequisiteGraph(const [
        PrereqNode('a', requires: ['b']),
        PrereqNode('b', requires: ['a']),
      ]);
      final s = step(
        {'a': ms('a', 0.3)},
        units: const ['a'],
        context: ctx(graph: cyc),
      )!;
      expect(s.unitId, anyOf('a', 'b'));
    });
  });

  group('レッスン', () {
    final l1 = lesson('l1', 'u1');
    test('記録のない新しい単元は newUnit のレッスン', () {
      final s = step(const {}, context: ctx(lessons: [l1]))!;
      expect(s.kind, LearningStepKind.lesson);
      expect(s.reason, LearningStepReason.newUnit);
      expect(s.lessonId, 'l1');
    });
    test('記録があり、レッスンを読み終えていなければ lessonNotFinished', () {
      final s = step(
        {'u1': ms('u1', 0.3)},
        attempts: [att('u1')],
        context: ctx(lessons: [l1]),
      )!;
      expect(s.reason, LearningStepReason.lessonNotFinished);
      // 習熟度の記録があっても、回答の履歴が無ければ新しい単元
      expect(
        step(
          const {},
          attempts: const [],
          context: ctx(lessons: [l1]),
        )!.reason,
        LearningStepReason.newUnit,
      );
      // 習熟度の記録が無くても、回答の履歴があれば新しい単元ではない
      expect(
        step(
          const {},
          attempts: [att('u1')],
          context: ctx(lessons: [l1]),
        )!.reason,
        LearningStepReason.lessonNotFinished,
      );
    });
    test('読み終えていれば（ブロックを全部読み、確認クイズに答えた）レッスンは勧めない', () {
      final c = ctx(lessons: [l1], progress: {'l1': finished(l1)});
      expect(step({'u1': ms('u1', 0.3)}, context: c)!.kind, LearningStepKind.practice);
      // 読み残しがあれば勧める
      final partial = ctx(
        lessons: [l1],
        progress: {
          'l1': LessonProgress(lessonId: 'l1', viewed: {0, 1}),
        },
      );
      expect(step({'u1': ms('u1', 0.3)}, context: partial)!.kind, LearningStepKind.lesson);
    });
    test('得意（skipLessonAt 以上）ならレッスンは飛ばして練習', () {
      expect(step({'u1': ms('u1', 0.7)}, context: ctx(lessons: [l1]))!.kind, LearningStepKind.practice);
      expect(step({'u1': ms('u1', 0.69)}, context: ctx(lessons: [l1]))!.kind, LearningStepKind.lesson);
    });
    test('単元に複数のレッスンがあれば、読み終えていない最初のもの', () {
      final l2 = lesson('l2', 'u1');
      final c = ctx(lessons: [l1, l2], progress: {'l1': finished(l1)});
      expect(step({'u1': ms('u1', 0.3)}, context: c)!.lessonId, 'l2');
    });
    test('他の単元のレッスンは勧めない', () {
      expect(step(const {}, context: ctx(lessons: [lesson('lx', 'other')]))!.kind, LearningStepKind.practice);
    });
  });

  group('同じ誤解の型の繰り返し', () {
    final withPit = lesson(
      'l1',
      'u1',
      extra: [
        {'type': 'text', 'textId': 't'},
        {'type': 'pitfall', 'tag': 'move_term_sign', 'textId': 'p'},
      ],
    );
    final qs = [
      qn('q1', 'u1', tags: {'b': 'move_term_sign', 'c': 'other_tag'}),
    ];
    List<Attempt> wrongs(int n, {String chosen = 'b', int daysAgo = 2}) => [
      for (var i = 0; i < n; i++) att('u1', correct: false, chosen: chosen, daysAgo: daysAgo),
    ];
    final done = {
      'l1': LessonProgress(lessonId: 'l1', viewed: {0, 1, 2, 3, 4, 5}, post: {'q1': true}),
    };

    test('3 回以上で、その型の解説があるレッスンの pitfall ブロックから', () {
      final s = step(
        {'u1': ms('u1', 0.5)},
        attempts: wrongs(3),
        questions: qs,
        context: ctx(lessons: [withPit], progress: done),
      )!;
      expect(s.kind, LearningStepKind.lesson);
      expect(s.reason, LearningStepReason.repeatedMistake);
      expect(s.tag, 'move_term_sign');
      expect(s.lessonId, 'l1');
      expect(s.blockIndex, 2); // hook(0)・text(1)・pitfall(2)
    });
    test('レッスンの中の、その型の解説のブロックから（別の型の解説の位置ではない）', () {
      final two = lesson(
        'l1',
        'u1',
        extra: [
          {'type': 'pitfall', 'tag': 'other_tag', 'textId': 'p1'},
          {'type': 'text', 'textId': 't'},
          {'type': 'pitfall', 'tag': 'move_term_sign', 'textId': 'p2'},
        ],
      );
      final s = step(
        {'u1': ms('u1', 0.5)},
        attempts: wrongs(3),
        questions: qs,
        context: ctx(lessons: [two], progress: done),
      )!;
      expect(s.tag, 'move_term_sign');
      expect(s.blockIndex, 3); // hook(0)・pitfall other(1)・text(2)・pitfall move(3)
    });
    test('2 回では足りない。正解・期間外・他の単元・型のない選択肢は数えない', () {
      final c = ctx(lessons: [withPit], progress: done);
      expect(
        step({'u1': ms('u1', 0.5)}, attempts: wrongs(2), questions: qs, context: c)!.kind,
        LearningStepKind.practice,
      );
      expect(
        step({'u1': ms('u1', 0.5)}, attempts: wrongs(3, daysAgo: 31), questions: qs, context: c)!.kind,
        LearningStepKind.practice,
      );
      expect(
        step({'u1': ms('u1', 0.5)}, attempts: wrongs(3, daysAgo: 30), questions: qs, context: c)!.kind,
        LearningStepKind.lesson,
      );
      expect(
        step(
          {'u1': ms('u1', 0.5)},
          attempts: wrongs(3, chosen: 'a'),
          questions: qs,
          context: c,
        )!.kind,
        LearningStepKind.practice,
      );
      final other = [for (var i = 0; i < 3; i++) att('zzz', correct: false, chosen: 'b')];
      expect(step({'u1': ms('u1', 0.5)}, attempts: other, questions: qs, context: c)!.kind, LearningStepKind.practice);
      final right = [for (var i = 0; i < 3; i++) att('u1', correct: true, chosen: 'b')];
      expect(step({'u1': ms('u1', 0.5)}, attempts: right, questions: qs, context: c)!.kind, LearningStepKind.practice);
    });
    test('解説のあるレッスンがなければ、ふつうの流れ', () {
      final noPit = lesson('l1', 'u1');
      final s = step(
        {'u1': ms('u1', 0.5)},
        attempts: wrongs(5),
        questions: qs,
        context: ctx(lessons: [noPit], progress: {'l1': finished(noPit)}),
      )!;
      expect(s.kind, LearningStepKind.practice);
    });
    test('複数の型があれば、回数の多い型（同数は名前順）', () {
      final two = lesson(
        'l1',
        'u1',
        extra: [
          {'type': 'pitfall', 'tag': 'move_term_sign', 'textId': 'p'},
          {'type': 'pitfall', 'tag': 'other_tag', 'textId': 'p2'},
        ],
      );
      final attempts = [...wrongs(3, chosen: 'b'), ...wrongs(4, chosen: 'c')];
      final s = step(
        {'u1': ms('u1', 0.5)},
        attempts: attempts,
        questions: qs,
        context: ctx(lessons: [two], progress: done),
      )!;
      expect(s.tag, 'other_tag');
      final tie = [...wrongs(3, chosen: 'b'), ...wrongs(3, chosen: 'c')];
      expect(
        step(
          {'u1': ms('u1', 0.5)},
          attempts: tie,
          questions: qs,
          context: ctx(lessons: [two], progress: done),
        )!.tag,
        'move_term_sign',
      );
    });
    test('テストが近くても、型の解説は勧める（的を絞っているので）', () {
      final s = step(
        {'u1': ms('u1', 0.5)},
        attempts: [
          ...wrongs(3),
          att('u1', mode: 'mock', daysAgo: 1),
        ],
        questions: qs,
        context: ctx(lessons: [withPit], progress: done),
        testDate: DateTime.utc(2026, 11, 8),
      )!;
      expect(s.reason, LearningStepReason.repeatedMistake);
      expect(s.daysToTest, 6);
    });
  });

  group('体験・復習・練習', () {
    test('レッスンのあとで習熟度が低く、体験があればまだの体験', () {
      final c = ctx(
        explorations: {
          'u1': ['ex1', 'ex2'],
        },
        done: {'ex1'},
      );
      final s = step({'u1': ms('u1', 0.3)}, context: c)!;
      expect(s.kind, LearningStepKind.explore);
      expect(s.explorationId, 'ex2');
      expect(s.reason, LearningStepReason.afterLesson);
    });
    test('体験は、習熟度が exploreBelow 以上・全部やった・レッスンが未読のときは勧めない', () {
      final c = ctx(
        explorations: {
          'u1': ['ex1'],
        },
      );
      expect(step({'u1': ms('u1', 0.6)}, context: c)!.kind, LearningStepKind.practice);
      expect(step({'u1': ms('u1', 0.59)}, context: c)!.kind, LearningStepKind.explore);
      expect(
        step(
          {'u1': ms('u1', 0.3)},
          context: ctx(
            explorations: {
              'u1': ['ex1'],
            },
            done: {'ex1'},
          ),
        )!.kind,
        LearningStepKind.practice,
      );
      final l = lesson('l1', 'u1');
      expect(
        step(
          {'u1': ms('u1', 0.3)},
          context: ctx(
            lessons: [l],
            explorations: {
              'u1': ['ex1'],
            },
          ),
        )!.kind,
        LearningStepKind.lesson,
      );
    });
    test('体験はレッスンのあと。レッスンが未読なら、得意で飛ばせても体験を先にしない（設定で体験の対象を広げても）', () {
      final l = lesson('l1', 'u1');
      const wide = LearningStepConfig(exploreBelow: 0.9, skipLessonAt: 0.7);
      final c = LearningContext(
        lessons: LessonSet([l]),
        explorations: const {
          'u1': ['ex1'],
        },
        config: wide,
      );
      expect(step({'u1': ms('u1', 0.75)}, context: c)!.kind, LearningStepKind.practice); // 得意でレッスンは飛ばす。未読なので体験にもしない
      final read = LearningContext(
        lessons: LessonSet([l]),
        progress: {'l1': finished(l)},
        explorations: const {
          'u1': ['ex1'],
        },
        config: wide,
      );
      expect(step({'u1': ms('u1', 0.75)}, context: read)!.kind, LearningStepKind.explore); // 読み終えていれば体験
    });
    test('テストが近いときは、レッスンがなくても体験を足さない', () {
      final s = step(
        {'u1': ms('u1', 0.3)},
        context: ctx(
          explorations: {
            'u1': ['ex1'],
          },
        ),
        testDate: DateTime.utc(2026, 11, 8),
        attempts: [att('u1', mode: 'mock', daysAgo: 1)],
      )!;
      expect(s.kind, LearningStepKind.practice);
      expect(s.reason, LearningStepReason.testSoon);
    });
    test('復習の期限が来た問題が 3 問以上で復習。2 問なら練習', () {
      final s = step({'u1': ms('u1', 0.65)}, context: ctx(due: {'u1': 3}))!;
      expect(s.kind, LearningStepKind.review);
      expect(s.reason, LearningStepReason.reviewDue);
      expect(step({'u1': ms('u1', 0.65)}, context: ctx(due: {'u1': 2}))!.kind, LearningStepKind.practice);
      expect(step({'u1': ms('u1', 0.65)}, context: ctx(due: {'other': 9}))!.kind, LearningStepKind.practice);
    });
    test('しきい値は設定で変えられる', () {
      const c = LearningContext(config: LearningStepConfig(reviewDueMin: 1, doneAt: 0.5));
      expect(step({'u1': ms('u1', 0.65)}, context: c)!.kind, LearningStepKind.maintain); // doneAt 0.5
      final c2 = LearningContext(config: const LearningStepConfig(reviewDueMin: 1), reviewDue: const {'u1': 1});
      expect(step({'u1': ms('u1', 0.65)}, context: c2)!.kind, LearningStepKind.review);
    });
  });

  group('buildDailyHome への組み込み', () {
    test('learning を渡さなければ learningStep は null。渡せば今日の次の 1 手', () {
      final qs = [qn('q1', 'u1'), qn('q2', 'u1')];
      final plan = [
        DayPlan(
          date: DateTime.utc(2026, 11, 2),
          daysLeft: 5,
          total: 2,
          focus: 2,
          weak: 0,
          review: 0,
          focusByUnit: const {'u1': 2},
          lastMinute: false,
        ),
      ];
      final base = buildDailyHome(
        now: now,
        plan: plan,
        questions: qs,
        mastery: {'u1': ms('u1', 0.3)},
        attempts: const [],
      );
      expect(base.learningStep, isNull);
      final l = lesson('l1', 'u1');
      final withStep = buildDailyHome(
        now: now,
        plan: plan,
        questions: qs,
        mastery: {'u1': ms('u1', 0.3)},
        attempts: const [],
        learning: ctx(lessons: [l]),
      );
      expect(withStep.learningStep!.kind, LearningStepKind.lesson);
      expect(withStep.learningStep!.unitId, 'u1');
      // 今日の分が計画に無くても、次の 1 手は返す
      final noPlan = buildDailyHome(
        now: now,
        plan: const [],
        questions: qs,
        mastery: {'u1': ms('u1', 0.3)},
        attempts: const [],
        learning: ctx(lessons: [l]),
      );
      expect(noPlan.hasPlanToday, isFalse);
      expect(noPlan.learningStep!.lessonId, 'l1');
      // scopeUnitIds で範囲を絞れる
      final scoped = buildDailyHome(
        now: now,
        plan: plan,
        questions: [...qs, qn('q9', 'u2')],
        mastery: {'u1': ms('u1', 0.9), 'u2': ms('u2', 0.2)},
        attempts: const [],
        scopeUnitIds: const ['u1'],
        learning: ctx(),
      );
      expect(scoped.learningStep!.kind, LearningStepKind.maintain);
    });
  });
}
