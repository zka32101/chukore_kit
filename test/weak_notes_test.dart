import 'package:chukore_kit/chukore_kit.dart';
import 'package:test/test.dart';

const _q = Question(
  id: 'q1',
  unitId: 'u',
  type: 'choice',
  difficulty: 0.6,
  choices: ['a', 'b', 'c'],
  answer: 'a',
  explanationId: 'x',
  misconceptionTags: {'b': 'third_person_s'},
);

Attempt _at(int day, bool ok, [String? chosen]) => Attempt(
      questionId: 'q1',
      unitId: 'u',
      correct: ok,
      chosenId: chosen,
      answeredAt: DateTime.utc(2026, 10, day, 12),
    );

void main() {
  final qs = {'q1': _q};

  test('型付きの誤答は型として記録される', () {
    final w = buildWeakNotes([_at(1, false, 'b')], qs);
    expect(w.single.tag, 'third_person_s');
    expect(w.single.overcome, isFalse);
  });

  test('型なしの誤答は問題単位', () {
    final w = buildWeakNotes([_at(1, false, 'c')], qs);
    expect(w.single.questionId, 'q1');
  });

  test('3連続正解でも同日のみなら未克服', () {
    final w = buildWeakNotes(
        [_at(1, false, 'b'), _at(2, true), _at(2, true), _at(2, true)], qs);
    expect(w.single.overcome, isFalse);
  });

  test('3連続正解が2日にまたがれば克服', () {
    final w = buildWeakNotes(
        [_at(1, false, 'b'), _at(2, true), _at(2, true), _at(3, true)], qs);
    expect(w.single.overcome, isTrue);
  });

  test('克服後に再び間違えると未克服に戻る', () {
    final w = buildWeakNotes([
      _at(1, false, 'b'), _at(2, true), _at(3, true), _at(4, true),
      _at(5, false, 'b'),
    ], qs);
    expect(w.single.overcome, isFalse);
    expect(w.single.wrongCount, 2);
  });
}
