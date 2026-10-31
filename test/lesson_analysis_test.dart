import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime(2026, 11, 1);

Lesson _lesson(String id, String unit, {List<LessonBlock>? blocks}) => Lesson(
      id: id, version: 1, unitId: unit, minutes: 4, titleId: 't',
      blocks: blocks ?? const [HookBlock('h'), TextBlock('x'), CheckBlock(['c1', 'c2']), SummaryBlock(['s'])],
    );

Attempt _a(String q, String unit, bool ok, {String mode = 'practice', String? chosen}) =>
    Attempt(questionId: q, unitId: unit, correct: ok, answeredAt: _t, mode: mode, chosenId: chosen);

Question _q(String id, {Map<String, String> tags = const {}}) => Question(
    id: id, unitId: 'u', type: 'choice', difficulty: .5,
    choices: const ['x', 'y', 'z'], answer: 'x', explanationId: 'e', misconceptionTags: tags);

void main() {
  group('学びの流れ', () {
    final lessons = LessonSet([_lesson('L1', 'u1'), _lesson('L2', 'u2')]);
    final done = {'L1': LessonProgress(lessonId: 'L1', completedAt: _t), 'L2': const LessonProgress(lessonId: 'L2')};

    test('レッスン完了・体験・練習・テストの到達を単元ごとに出す', () {
      final f = buildLearningFunnel(
        unitIds: ['u1', 'u2', 'u3'],
        lessons: lessons,
        progress: done,
        explorations: {'u1': ['e1'], 'u2': ['e2']},
        doneExplorations: {'e1'},
        attempts: [_a('q', 'u1', true), _a('q', 'u1', true, mode: 'mock'), _a('q', 'u2', true, mode: 'lesson_check')],
      );
      expect([for (final x in f) x.unitId], ['u1', 'u2', 'u3']);
      expect(f[0].reached, FunnelStage.values.toSet());
      expect(f[0].stuckAt, isNull);
      // u2: レッスン未完了、体験未実施、確認の回答は練習に数えない
      expect(f[1].applicable, FunnelStage.values.toSet());
      expect(f[1].reached, isEmpty);
      expect(f[1].stuckAt, FunnelStage.learn);
      // u3: レッスンも体験も無い → 練習とテストだけ
      expect(f[2].applicable, {FunnelStage.practice, FunnelStage.test});
      expect(f[2].stuckAt, FunnelStage.practice);
    });

    test('止まっている段階は、段階の順で最初の未到達（飛ばして届いていても）', () {
      final f = buildLearningFunnel(
        unitIds: ['u1'],
        lessons: lessons,
        progress: {'L1': const LessonProgress(lessonId: 'L1')},
        explorations: {'u1': ['e1']},
        attempts: [_a('q', 'u1', true), _a('q', 'u1', false, mode: 'unit_test')],
      );
      expect(f.single.reached, {FunnelStage.practice, FunnelStage.test});
      expect(f.single.stuckAt, FunnelStage.learn);
    });

    test('テストとして数える mode は mock / unit_test / real_test / teacher', () {
      for (final m in ['mock', 'unit_test', 'real_test', 'teacher']) {
        final f = buildLearningFunnel(unitIds: ['u'], attempts: [_a('q', 'u', true, mode: m)]);
        expect(f.single.reached, {FunnelStage.test}, reason: m);
      }
      final p = buildLearningFunnel(unitIds: ['u'], attempts: [_a('q', 'u', true, mode: 'review')]);
      expect(p.single.reached, {FunnelStage.practice});
    });

    test('他の単元の回答・レッスンは数えない。2 つレッスンがあればどれか 1 つの完了でよい', () {
      final two = LessonSet([_lesson('A', 'u'), _lesson('B', 'u'), _lesson('C', 'other')]);
      final f = buildLearningFunnel(
        unitIds: ['u'],
        lessons: two,
        progress: {
          'B': LessonProgress(lessonId: 'B', completedAt: _t),
          'C': LessonProgress(lessonId: 'C', completedAt: _t),
        },
        attempts: [_a('q', 'other', true)],
      );
      expect(f.single.reached, {FunnelStage.learn});
    });

    test('合計: 段階ごとに「ある単元」と「届いた単元」', () {
      final f = buildLearningFunnel(
        unitIds: ['u1', 'u2', 'u3'],
        lessons: lessons,
        progress: done,
        attempts: [_a('q', 'u1', true), _a('q', 'u3', true)],
      );
      final s = summarizeFunnel(f);
      expect((s[FunnelStage.learn]!.applicable, s[FunnelStage.learn]!.reached), (2, 1));
      expect((s[FunnelStage.explore]!.applicable, s[FunnelStage.explore]!.reached), (0, 0));
      expect(s[FunnelStage.explore]!.rate, 0);
      expect((s[FunnelStage.practice]!.applicable, s[FunnelStage.practice]!.reached), (3, 2));
      expect(s[FunnelStage.practice]!.rate, closeTo(2 / 3, 1e-9));
      expect(s[FunnelStage.test]!.reached, 0);
    });
  });

  group('ブロックの読まれ方', () {
    final l = _lesson('L1', 'u');
    final ps = [
      const LessonProgress(lessonId: 'L1', viewed: {0, 1, 2, 3}),
      const LessonProgress(lessonId: 'L1', viewed: {0, 1}),
      const LessonProgress(lessonId: 'L1', viewed: {0}),
      const LessonProgress(lessonId: 'L1', viewed: {0, 1, 2}),
      const LessonProgress(lessonId: 'other', viewed: {0, 1, 2, 3}),
    ];

    test('ブロックごとに読んだ人数と割合（他のレッスンの記録は数えない）', () {
      final r = summarizeBlockReads(l, ps);
      expect([for (final b in r) b.type], ['hook', 'text', 'check', 'summary']);
      expect([for (final b in r) b.viewed], [4, 3, 2, 1]);
      expect(r.every((b) => b.learners == 4), isTrue);
      expect(r[3].viewRate, 0.25);
      expect(summarizeBlockReads(l, const []).first.viewRate, 0);
    });

    test('飛ばされるブロック: 割合が below 未満、記録が minLearners 以上のときだけ', () {
      expect([for (final b in skippedBlocks(l, ps, minLearners: 4)) b.index], [3]);
      expect([for (final b in skippedBlocks(l, ps, minLearners: 4, below: 0.6)) b.index], [2, 3]);
      expect(skippedBlocks(l, ps, minLearners: 5), isEmpty);
      // ちょうど below は飛ばされたことにしない
      expect([for (final b in skippedBlocks(l, ps, minLearners: 4, below: 0.5)) b.index], [3]);
    });
  });

  group('確認クイズの誤解の型', () {
    final lesson = _lesson('L1', 'u', blocks: const [
      CheckBlock(['c1', 'c2']),
      PitfallBlock('known', 'p'),
    ]);
    final qs = [
      _q('c1', tags: {'y': 'known', 'z': 'new_a'}),
      _q('c2', tags: {'y': 'new_b'}),
      _q('pre', tags: {'y': 'pre_tag'}),
      _q('other', tags: {'y': 'new_a'}),
    ];

    List<Attempt> wrong(String q, String c, int n) =>
        [for (var i = 0; i < n; i++) _a(q, 'u', false, mode: 'lesson_check', chosen: c)];

    test('誤答を型にして数え、多い順。解説が無く回数が minCount 以上の型が uncovered', () {
      final r = lessonCheckMistakes(lesson, [
        ...wrong('c1', 'y', 2), // known ×2
        ...wrong('c1', 'z', 3), // new_a ×3
        ...wrong('c2', 'y', 3), // new_b ×3
      ], qs);
      expect(r.tags, {'new_a': 3, 'new_b': 3, 'known': 2});
      expect(r.tags.keys.toList(), ['new_a', 'new_b', 'known']);
      expect(r.uncovered, ['new_a', 'new_b']);
    });

    test('解説のある型・回数の足りない型は uncovered に入れない', () {
      final r = lessonCheckMistakes(lesson, [...wrong('c1', 'y', 9), ...wrong('c2', 'y', 2)], qs);
      expect(r.uncovered, isEmpty);
      expect(lessonCheckMistakes(lesson, wrong('c2', 'y', 3), qs, minCount: 4).uncovered, isEmpty);
      expect(lessonCheckMistakes(lesson, wrong('c2', 'y', 3), qs, minCount: 3).uncovered, ['new_b']);
    });

    test('事前の確認・他のレッスンの問題・lesson_check 以外・正解・型の無い誤答は数えない', () {
      final r = lessonCheckMistakes(lesson, [
        ...wrong('pre', 'y', 5),
        ...wrong('other', 'y', 5),
        _a('c1', 'u', false, mode: 'practice', chosen: 'z'),
        _a('c1', 'u', true, mode: 'lesson_check', chosen: 'z'),
        _a('c1', 'u', false, mode: 'lesson_check', chosen: 'x'),
        _a('c1', 'u', false, mode: 'lesson_check'),
        _a('missing', 'u', false, mode: 'lesson_check', chosen: 'y'),
      ], qs);
      expect(r.tags, isEmpty);
    });
  });

  group('効かないレッスン', () {
    LessonEffect e(String id, int n, double? gain) =>
        LessonEffect(lessonId: id, learners: n, completed: n, avgPre: .5, avgPost: .6, avgGain: gain);

    test('伸びが maxGain 以下で、記録が minLearners 以上', () {
      final r = ineffectiveLessons([e('a', 10, .02), e('b', 10, .3), e('c', 4, 0), e('d', 10, null), e('f', 5, .05), e('g', 5, .0501)]);
      expect([for (final x in r) x.lessonId], ['a', 'f']);
    });

    test('マイナスの伸びも対象', () {
      expect(ineffectiveLessons([e('a', 5, -.2)]).single.lessonId, 'a');
    });
  });
}
