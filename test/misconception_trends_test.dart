import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question _q(String id, String unit, Map<String, String> tags) => Question(
      id: id, unitId: unit, type: 'choice', difficulty: .5,
      choices: const ['ok', 'w1', 'w2'], answer: 'ok', explanationId: 'e',
      misconceptionTags: tags,
    );

final _now = DateTime(2026, 10, 30);

Attempt _w(String q, String unit, String chosen, int daysAgo, {bool? confident}) => Attempt(
      questionId: q,
      unitId: unit,
      correct: false,
      chosenId: chosen,
      answeredAt: _now.subtract(Duration(days: daysAgo)).add(const Duration(hours: 9)),
      confident: confident,
    );

Attempt _ok(String q, String unit, int daysAgo) => Attempt(
      questionId: q,
      unitId: unit,
      correct: true,
      answeredAt: _now.subtract(Duration(days: daysAgo)).add(const Duration(hours: 9)),
    );

final _qs = {
  'f1': _q('f1', 'frac_add', {'w1': 'denominator_added'}),
  'f2': _q('f2', 'frac_sub', {'w1': 'denominator_added'}),
  'e1': _q('e1', 'eq', {'w1': 'sign_dropped', 'w2': 'denominator_added'}),
};

void main() {
  test('同じ誤解の型を、単元をまたいで数える（単元は回数の多い順）', () {
    final r = analyzeMisconceptions([
      _w('f1', 'frac_add', 'w1', 1),
      _w('f1', 'frac_add', 'w1', 2),
      _w('f2', 'frac_sub', 'w1', 3),
      _w('e1', 'eq', 'w2', 4, confident: true),
    ], _qs, _now);
    final t = r.singleWhere((x) => x.tag == 'denominator_added');
    expect(t.wrongCount, 4);
    expect(t.byUnit.entries.map((e) => (e.key, e.value)), [('frac_add', 2), ('eq', 1), ('frac_sub', 1)]);
    expect(t.crossUnit, isTrue);
    expect(t.questionIds, {'f1', 'f2', 'e1'});
    expect(t.confidentWrongCount, 1);
  });

  test('型の付いていない選択肢・正解・選択肢なしは対象外', () {
    final r = analyzeMisconceptions([
      _w('f1', 'frac_add', 'zzz', 1), // 型なしの選択肢
      _ok('f1', 'frac_add', 1),
      Attempt(questionId: 'f1', unitId: 'frac_add', correct: false, answeredAt: _now), // 選択肢なし
      _w('unknown_q', 'u', 'w1', 1), // 問題集に無い
    ], _qs, _now);
    expect(r, isEmpty);
  });

  test('単元をまたぐ型を先に。次に回数の多い順、同数は型の名前順', () {
    final r = analyzeMisconceptions([
      _w('e1', 'eq', 'w1', 1), _w('e1', 'eq', 'w1', 2), _w('e1', 'eq', 'w1', 3), // sign_dropped が 3 回（1単元）
      _w('f1', 'frac_add', 'w1', 1), _w('f2', 'frac_sub', 'w1', 2), // denominator_added が 2 回（2単元）
    ], _qs, _now);
    expect(r.map((x) => x.tag), ['denominator_added', 'sign_dropped']);
  });

  group('増減', () {
    MisconceptionTrend trendOf(List<Attempt> xs) =>
        analyzeMisconceptions(xs, _qs, _now).single.trend;

    test('直近だけなら newlyAppeared', () {
      expect(trendOf([_w('f1', 'frac_add', 'w1', 2)]), MisconceptionTrend.newlyAppeared);
    });
    test('直近のほうが多ければ rising、少なければ falling、同数なら steady', () {
      expect(trendOf([_w('f1', 'frac_add', 'w1', 2), _w('f1', 'frac_add', 'w1', 3), _w('f1', 'frac_add', 'w1', 20)]),
          MisconceptionTrend.rising);
      expect(trendOf([_w('f1', 'frac_add', 'w1', 2), _w('f1', 'frac_add', 'w1', 20), _w('f1', 'frac_add', 'w1', 21)]),
          MisconceptionTrend.falling);
      expect(trendOf([_w('f1', 'frac_add', 'w1', 2), _w('f1', 'frac_add', 'w1', 20)]), MisconceptionTrend.steady);
    });
    test('直近に出ていなければ quiet', () {
      expect(trendOf([_w('f1', 'frac_add', 'w1', 20)]), MisconceptionTrend.quiet);
    });
    test('その前の期間にも無く、さらに昔だけなら、直近にあれば rising', () {
      expect(trendOf([_w('f1', 'frac_add', 'w1', 2), _w('f1', 'frac_add', 'w1', 60)]), MisconceptionTrend.rising);
    });
    test('期間の境界: 直近 14 日は今日を含み 13 日前まで', () {
      final r = analyzeMisconceptions([_w('f1', 'frac_add', 'w1', 13), _w('f1', 'frac_add', 'w1', 14)], _qs, _now).single;
      expect((r.recentCount, r.previousCount), (1, 1));
    });
  });

  test('克服した型は後ろに回る（弱点ノートと同じ基準）', () {
    final r = analyzeMisconceptions([
      _w('e1', 'eq', 'w1', 25),
      _w('e1', 'eq', 'w1', 20),
      _ok('e1', 'eq', 10), _ok('e1', 'eq', 5), _ok('e1', 'eq', 1), // 3 連続正解・2 日以上
      _w('f1', 'frac_add', 'w1', 1),
    ], _qs, _now);
    expect(r.map((x) => (x.tag, x.overcome)), [('denominator_added', false), ('sign_dropped', true)]);
  });

  test('履歴が無ければ空', () {
    expect(analyzeMisconceptions(const [], _qs, _now), isEmpty);
  });
}
