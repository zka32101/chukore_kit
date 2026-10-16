import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 10, 9);

Attempt _a(String q, int min, bool ok, {int ms = 10000, String unit = 'u1', String? chosen}) => Attempt(
      questionId: q,
      unitId: unit,
      correct: ok,
      chosenId: chosen,
      answeredAt: _t0.add(Duration(minutes: min)),
      elapsedMs: ms,
    );

/// 単元 u1 で、ふだん 10 秒かけて正解している履歴（基準の作成用）。
List<Attempt> _base({String unit = 'u1', int n = 6}) =>
    [for (var i = 0; i < n; i++) _a('base$i', -100 + i, true, unit: unit)];

void main() {
  test('ふだんよりずっと速い誤答は tooFast', () {
    final v = classifyMistakes([..._base(), _a('x', 0, false, ms: 2000)]);
    expect(v.single.reasons, {CarelessReason.tooFast});
    expect(v.single.careless, isTrue);
  });

  test('ふだん並みの時間をかけた誤答は理解不足の疑い（ケアレスではない）', () {
    final v = classifyMistakes([..._base(), _a('x', 0, false, ms: 9000)]);
    expect(v.single.careless, isFalse);
  });

  test('境界: 基準の 35% ちょうどは tooFast ではない', () {
    expect(classifyMistakes([..._base(), _a('x', 0, false, ms: 3500)]).single.careless, isFalse);
    expect(classifyMistakes([..._base(), _a('x', 0, false, ms: 3499)]).single.careless, isTrue);
  });

  test('基準が足りない・未計測なら tooFast と判定しない', () {
    expect(classifyMistakes([..._base(n: 4), _a('x', 0, false, ms: 100)]).single.careless, isFalse);
    expect(classifyMistakes([..._base(), _a('x', 0, false, ms: 0)]).single.careless, isFalse);
  });

  test('その単元の正解が少ないときは、全単元の正解で基準を作る', () {
    final v = classifyMistakes([..._base(unit: 'other'), _a('x', 0, false, ms: 2000, unit: 'u1')]);
    expect(v.single.reasons, {CarelessReason.tooFast});
  });

  test('間違えた直後（10分以内）に同じ問題を正解し直したら quickRetry', () {
    final v = classifyMistakes([_a('x', 0, false), _a('x', 5, true)]);
    expect(v.single.reasons, {CarelessReason.quickRetry});
    // 11分後なら対象外
    expect(classifyMistakes([_a('x', 0, false), _a('x', 11, true)]).single.careless, isFalse);
    // 次も誤答なら対象外
    expect(classifyMistakes([_a('x', 0, false), _a('x', 5, false)]).first.careless, isFalse);
    // 別の問題を正解しても対象外
    expect(classifyMistakes([_a('x', 0, false), _a('y', 5, true)]).single.careless, isFalse);
  });

  test('両方当てはまれば理由は2つ。誤答だけが返り、入力順に依らない', () {
    final xs = [..._base(), _a('x', 0, false, ms: 1000), _a('x', 3, true)];
    final v = classifyMistakes(xs.reversed);
    expect(v.length, 1);
    expect(v.single.reasons, {CarelessReason.tooFast, CarelessReason.quickRetry});
  });

  group('弱点ノートとの連携', () {
    final q = Question(
      id: 'x', unitId: 'u1', type: 'choice', difficulty: .5,
      choices: const ['a', 'b'], answer: 'a', explanationId: 'e',
    );
    final qs = {'x': q};

    test('既定ではケアレスの疑いの誤答も数える（従来どおり）', () {
      final notes = buildWeakNotes([_a('x', 0, false), _a('x', 5, true)], qs);
      expect(notes.single.wrongCount, 1);
    });

    test('ignoreCareless: ケアレスの疑いの誤答は弱点に入れない', () {
      final notes = buildWeakNotes([_a('x', 0, false), _a('x', 5, true)], qs, ignoreCareless: true);
      expect(notes, isEmpty);
    });

    test('ignoreCareless: 理解不足の疑いの誤答は弱点に残る', () {
      final notes = buildWeakNotes([_a('x', 0, false), _a('x', 60, true)], qs, ignoreCareless: true);
      expect(notes.single.wrongCount, 1);
      expect(notes.single.questionId, 'x');
    });
  });
}
