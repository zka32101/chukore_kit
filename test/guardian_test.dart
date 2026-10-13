import 'dart:math';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:test/test.dart';

Attempt _at(String unit, int day, bool ok) => Attempt(
      questionId: '$unit-$day',
      unitId: unit,
      correct: ok,
      answeredAt: DateTime.utc(2026, 10, day, 12),
    );

void main() {
  test('漢数字変換', () {
    expect(toKanji(482), '四百八十二');
    expect(toKanji(110), '百十');
    expect(toKanji(305), '三百五');
    expect(toKanji(1000), '千');
    expect(() => toKanji(0), throwsRangeError);
  });

  test('ゲート判定は全角・空白を許容し、誤答は不可', () {
    const c = GateChallenge(482);
    expect(c.prompt, '四百八十二');
    expect(c.verify('482'), isTrue);
    expect(c.verify(' ４８２ '), isTrue);
    expect(c.verify('483'), isFalse);
    expect(c.verify(''), isFalse);
  });

  test('ランダム出題は3桁で、種が同じなら同じ', () {
    final a = GateChallenge.random(Random(1)).value;
    expect(a, inInclusiveRange(100, 999));
    expect(GateChallenge.random(Random(1)).value, a);
  });

  test('週次レポートは伸びた単元だけを並べる', () {
    final tree = UnitTree(1, const [
      Unit(id: 'u1', subject: 'en', grade: 1, title: 'be動詞'),
      Unit(id: 'u2', subject: 'en', grade: 1, title: '一般動詞'),
    ]);
    final r = buildWeeklyReport([
      _at('u1', 1, false), // 週前
      _at('u1', 14, true), // 今週(10/13〜)
      _at('u1', 15, true),
      _at('u2', 14, false), // 伸びなし
    ], tree, DateTime.utc(2026, 10, 13));
    expect(r.attemptCount, 3);
    expect(r.activeDays, 2);
    expect(r.improvements.map((i) => i.unitId), ['u1']);
    expect(r.toText(), contains('今週伸びた所'));
    expect(r.toText(), contains('be動詞'));
  });

  test('伸びが無い週でも責めない文面', () {
    final r = buildWeeklyReport([], UnitTree(1, const []), DateTime.utc(2026, 10, 13));
    expect(r.toText(), contains('ゆっくり'));
  });
}
