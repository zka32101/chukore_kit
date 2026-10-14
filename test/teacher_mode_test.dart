import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

MistakeLine _line(String id, String tag, {String q = 'q1', String src = 'b'}) => MistakeLine(
      id: id,
      tag: tag,
      questionId: q,
      sourceChoiceId: src,
      statement: 'He go to school.',
      fixChoices: const ['He goes to school.', 'He going to school.'],
      correctChoice: 'He goes to school.',
      explanation: '三人称単数の s',
    );

WeakEntry _weak(String tag, int day, {bool overcome = false}) => WeakEntry(
      key: 'tag:$tag',
      tag: tag,
      wrongCount: 1,
      lastWrongAt: DateTime.utc(2026, 10, day),
      overcome: overcome,
    );

void main() {
  final lines = [
    _line('a1', 'third_person_s'),
    _line('a2', 'third_person_s'),
    _line('b1', 'past_tense'),
    _line('c1', 'plural_s'),
    _line('d1', 'article'),
  ];

  test('未克服の型を、最近間違えた順に先頭へ', () {
    final r = pickMistakeLines(
      lines: lines,
      weakNotes: [_weak('past_tense', 5), _weak('plural_s', 9), _weak('article', 1, overcome: true)],
      count: 3,
    );
    expect(r.map((l) => l.id), ['c1', 'b1', 'd1']); // 未克服(新→旧)、次に克服済みの復習
  });

  test('まず1つの型から1問ずつ。足りなければ同じ型から足す', () {
    final r = pickMistakeLines(lines: lines, weakNotes: [_weak('third_person_s', 3)], count: 4);
    expect(r.map((l) => l.id), ['a1', 'b1', 'c1', 'd1']);
    final more = pickMistakeLines(lines: lines, weakNotes: [_weak('third_person_s', 3)], count: 5);
    expect(more.map((l) => l.id).toSet(), {'a1', 'a2', 'b1', 'c1', 'd1'});
    expect(more.length, 5);
  });

  test('出した問題は後回し。なければ出し直す', () {
    final r = pickMistakeLines(
      lines: lines,
      weakNotes: [_weak('third_person_s', 3)],
      shownIds: {'a1'},
      count: 2,
    );
    expect(r.first.id, 'a2'); // 同じ型の未表示を、表示済みより先に
    final all = pickMistakeLines(lines: lines, weakNotes: const [], shownIds: lines.map((l) => l.id).toSet(), count: 5);
    expect(all.length, 5);
  });

  test('未克服が残る型は、克服済みの記録より優先', () {
    final r = pickMistakeLines(
      lines: lines,
      weakNotes: [_weak('past_tense', 2), _weak('past_tense', 8, overcome: true)],
      count: 1,
    );
    expect(r.single.tag, 'past_tense');
  });

  test('同じ入力で同じ結果', () {
    final w = [_weak('plural_s', 4)];
    expect(pickMistakeLines(lines: lines, weakNotes: w).map((l) => l.id),
        pickMistakeLines(lines: lines.reversed, weakNotes: w).map((l) => l.id));
  });

  test('進行: 回答すると判定して次へ。終わると null', () {
    final s = TeacherSession([lines[0], lines[2]]);
    expect(s.current!.id, 'a1');
    final f1 = s.answer('He goes to school.')!;
    expect(f1.correct, isTrue);
    expect(f1.explanation, '三人称単数の s');
    final f2 = s.answer('wrong')!;
    expect(f2.correct, isFalse);
    expect(f2.correctChoice, 'He goes to school.');
    expect(s.isFinished, isTrue);
    expect(s.correctCount, 1);
    expect(s.answered, 2);
    expect(s.answer('x'), isNull);
  });

  test('間違えると誤答の型として弱点ノートに載り、続けて直すと克服される', () {
    const q = Question(
      id: 'q1', unitId: 'u', type: 'choice', difficulty: .5,
      choices: ['a', 'b', 'c'], answer: 'a', explanationId: 'x',
      misconceptionTags: {'b': 'third_person_s'},
    );
    final line = _line('a1', 'third_person_s');
    final wrong = teacherAttempt(line, chosen: 'x', unitId: 'u', now: DateTime.utc(2026, 10, 1, 9));
    expect(wrong.correct, isFalse);
    expect(wrong.chosenId, 'b');
    expect(wrong.mode, 'teacher');
    var notes = buildWeakNotes([wrong], {'q1': q});
    expect(notes.single.tag, 'third_person_s');
    expect(notes.single.overcome, isFalse);

    final fixes = [
      for (final d in [2, 2, 3]) teacherAttempt(line, chosen: line.correctChoice, unitId: 'u', now: DateTime.utc(2026, 10, d, 9)),
    ];
    expect(fixes.first.chosenId, isNull);
    notes = buildWeakNotes([wrong, ...fixes], {'q1': q});
    expect(notes.single.overcome, isTrue);
  });

  test('JSON の往復', () {
    final l = _line('a1', 'third_person_s');
    final back = MistakeLine.fromJson(l.toJson());
    expect(back.toJson(), l.toJson());
  });

  test('先生役モードの文言が全言語にある', () {
    for (final s in ChukoreStrings.supported) {
      expect(s.teacherPrompt, isNotEmpty);
      expect(s.teacherCorrect, isNotEmpty);
      expect(s.teacherWrong, isNotEmpty);
    }
  });
}
