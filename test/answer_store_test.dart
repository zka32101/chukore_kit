import 'package:chukore_kit/chukore_kit.dart';
import 'package:test/test.dart';

Question _q(String type, String answer, [Map<String, String> tags = const {}]) =>
    Question(
      id: 'q',
      unitId: 'u',
      type: type,
      difficulty: 0.5,
      choices: const ['a', 'b'],
      answer: answer,
      explanationId: 'x',
      misconceptionTags: tags,
    );

void main() {
  test('選択: 誤答は型を返す', () {
    final q = _q('choice', 'a', {'b': 'sign_error'});
    expect(checkAnswer(q, 'a').correct, isTrue);
    final r = checkAnswer(q, 'b');
    expect(r.correct, isFalse);
    expect(r.misconceptionTag, 'sign_error');
  });

  test('数値: 全角・カンマ・小数を許容', () {
    expect(checkAnswer(_q('numeric', '1200'), '１，２００').correct, isTrue);
    expect(checkAnswer(_q('numeric', '-2.5'), '－２．５').correct, isTrue);
    expect(checkAnswer(_q('numeric', '3'), 'abc').correct, isFalse);
  });

  test('並べ替え: 順序が一致すれば正解', () {
    final q = _q('order', 'a,b,c');
    expect(checkAnswer(q, 'a, b, c').correct, isTrue);
    expect(checkAnswer(q, 'a,c,b').correct, isFalse);
    expect(checkAnswer(q, 'a,b').correct, isFalse);
  });

  test('未知のタイプは例外', () {
    expect(() => checkAnswer(_q('map', 'x'), 'x'), throwsUnsupportedError);
  });

  test('ストアは期間・単元で絞れる', () async {
    final s = InMemoryAttemptStore();
    Attempt at(String u, int d) => Attempt(
        questionId: 'q', unitId: u, correct: true, answeredAt: DateTime.utc(2026, 10, d, 9));
    await s.add(at('u1', 5));
    await s.add(at('u2', 6));
    await s.add(at('u1', 7));
    expect((await s.query(from: DateTime.utc(2026, 10, 6), to: DateTime.utc(2026, 10, 7))).length, 1);
    expect((await s.query(unitId: 'u1')).length, 2);
  });
}
