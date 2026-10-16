import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final _tree = UnitTree(1, [Unit(id: 'u', subject: 'math', grade: 1, title: 'U')]);
final _week = DateTime.utc(2026, 10, 13); // 10/13〜10/19。前の週は 10/6〜10/12

Question _q(String id, Map<String, String> tags) => Question(
      id: id, unitId: 'u', type: 'choice', difficulty: .5,
      choices: const ['ok', 'w1', 'w2'], answer: 'ok', explanationId: 'e', misconceptionTags: tags,
    );

Attempt _a(String q, int day, bool ok, {String? chosen}) => Attempt(
      questionId: q,
      unitId: 'u',
      correct: ok,
      chosenId: chosen ?? (ok ? 'ok' : null),
      answeredAt: DateTime.utc(2026, 10, day, 12),
    );

final _qs = {
  'qa': _q('qa', {'w1': 'tag_a'}),
  'qb': _q('qb', {'w1': 'tag_b'}),
  'qc': _q('qc', {'w1': 'tag_c'}),
};

void main() {
  test('先週の回答数・学習した日数と比べられる', () {
    final r = buildWeeklyReport([
      _a('x', 7, true), _a('x', 8, true), _a('x', 8, false), // 先週: 3 回・2 日
      _a('x', 13, true), _a('x', 14, true), _a('x', 15, true), _a('x', 15, true), _a('x', 16, true), // 今週: 5 回・4 日
      _a('x', 20, true), // 来週は数えない
    ], _tree, _week);
    expect((r.attemptCount, r.activeDays), (5, 4));
    expect((r.previousAttemptCount, r.previousActiveDays), (3, 2));
    expect(r.attemptDelta, 2);
  });

  test('先週が空なら 0。今週が少なければ差はマイナス', () {
    expect(buildWeeklyReport([_a('x', 14, true)], _tree, _week).previousAttemptCount, 0);
    final r = buildWeeklyReport([_a('x', 8, true), _a('x', 9, true), _a('x', 14, true)], _tree, _week);
    expect(r.attemptDelta, -1);
  });

  test('問題集を渡さなければ、克服数・減った型は出さない', () {
    final r = buildWeeklyReport([_a('qa', 8, false, chosen: 'w1')], _tree, _week);
    expect(r.newlyOvercome, 0);
    expect(r.easedMisconceptions, isEmpty);
  });

  test('先週は間違えたが今週は間違えなかった誤解の型（名前順）', () {
    final r = buildWeeklyReport([
      _a('qa', 8, false, chosen: 'w1'), // 先週: tag_a
      _a('qb', 9, false, chosen: 'w1'), // 先週: tag_b
      _a('qc', 10, false, chosen: 'w1'), // 先週: tag_c
      _a('qb', 14, false, chosen: 'w1'), // 今週: tag_b をまた間違えた
    ], _tree, _week, questions: _qs);
    expect(r.easedMisconceptions, ['tag_a', 'tag_c']);
  });

  test('今週だけ間違えた型・先週も今週も無い型は含めない', () {
    final r = buildWeeklyReport([_a('qa', 14, false, chosen: 'w1')], _tree, _week, questions: _qs);
    expect(r.easedMisconceptions, isEmpty);
  });

  test('この週に新しく克服した弱点の数（前の週までに克服済みのものは数えない）', () {
    final r = buildWeeklyReport([
      // qa: 10/1 に間違えて、今週 3 連続正解（2 日以上）で克服
      _a('qa', 1, false, chosen: 'w1'),
      _a('qa', 14, true), _a('qa', 15, true), _a('qa', 16, true),
      // qb: 先週までに克服済み
      _a('qb', 1, false, chosen: 'w1'),
      _a('qb', 3, true), _a('qb', 4, true), _a('qb', 5, true),
      _a('qb', 14, true),
      // qc: 今週正解 1 回だけで、まだ克服していない
      _a('qc', 1, false, chosen: 'w1'),
      _a('qc', 14, true),
    ], _tree, _week, questions: _qs);
    // 型 tag_a と問題 q:qa は同じ回答から出るが、弱点ノートの 1 項目（型があれば型）として数える
    expect(r.newlyOvercome, 1);
  });

  test('伸びた単元・本文は従来どおり（追加の項目は本文に出さない）', () {
    final r = buildWeeklyReport([_a('x', 14, true)], _tree, _week, questions: _qs);
    expect(r.toText().contains('tag_'), isFalse);
    expect(r.activeDays, 1);
  });
}
