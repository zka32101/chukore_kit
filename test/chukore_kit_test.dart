import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

UnitTree _tree() => UnitTree(1, const [
      Unit(id: 'e1', subject: 'en', grade: 1, title: 'be動詞', estimatedQuestions: 20),
      Unit(id: 'e2', subject: 'en', grade: 1, title: '一般動詞', estimatedQuestions: 20),
      Unit(id: 'g', subject: 'en', grade: 1, title: '文法'),
    ].map((u) => u.id == 'g'
        ? u
        : Unit(
            id: u.id,
            subject: u.subject,
            grade: u.grade,
            title: u.title,
            parentId: 'g',
            estimatedQuestions: u.estimatedQuestions,
          )));

TestPlan _plan(DateTime d) =>
    TestPlan(id: 't', subject: 'en', testDate: d, unitIds: const ['g']);

void main() {
  test('親単元は葉へ展開される', () {
    expect(_tree().resolveLeaves(['g']).map((u) => u.id), ['e1', 'e2']);
  });

  test('同じ入力で同じ結果', () {
    final t = DateTime.utc(2026, 11, 1);
    final a = buildPlan(today: DateTime.utc(2026, 10, 20), plan: _plan(t), tree: _tree());
    final b = buildPlan(today: DateTime.utc(2026, 10, 20), plan: _plan(t), tree: _tree());
    expect(a.days.map((d) => d.total), b.days.map((d) => d.total));
    expect(a.days.map((d) => d.focusByUnit), b.days.map((d) => d.focusByUnit));
  });

  test('D=0〜3 は直前モード、D=4 は通常', () {
    final r = buildPlan(
      today: DateTime.utc(2026, 10, 25),
      plan: _plan(DateTime.utc(2026, 11, 1)),
      tree: _tree(),
    );
    expect(r.days.map((d) => d.lastMinute),
        [false, false, false, false, true, true, true, true]);
    expect(r.days.last.daysLeft, 0);
  });

  test('忙しい日は0.3倍、減らした分の50%を通常日へ（上限N×1.3）', () {
    final r = buildPlan(
      today: DateTime.utc(2026, 10, 20),
      plan: _plan(DateTime.utc(2026, 10, 29)), // 10日
      tree: _tree(),
      busyDays: [BusyDay(DateTime.utc(2026, 10, 21))],
    );
    expect(r.days[1].total, 3);
    // 減少7 → 上乗せ3.5 / 通常9日 ≈ 0.39 → 10.39 → 10
    expect(r.days[0].total, 10);
    expect(r.days.every((d) => d.total <= 13), isTrue);
  });

  test('忙しい日が連続しても上限を超えない', () {
    final busy = [
      for (var d = 21; d <= 27; d++) BusyDay(DateTime.utc(2026, 10, d), BusyKind.off),
    ];
    final r = buildPlan(
      today: DateTime.utc(2026, 10, 20),
      plan: _plan(DateTime.utc(2026, 10, 29)),
      tree: _tree(),
      busyDays: busy,
    );
    expect(r.days[1].total, 0);
    expect(r.days.every((d) => d.total <= 13), isTrue);
  });

  test('内訳の合計が1日の量と一致する', () {
    final r = buildPlan(
      today: DateTime.utc(2026, 10, 20),
      plan: _plan(DateTime.utc(2026, 11, 20)),
      tree: _tree(),
    );
    for (final d in r.days) {
      expect(d.focus + d.weak + d.review, d.total);
      expect(d.focusByUnit.values.fold<int>(0, (s, v) => s + v), d.focus);
    }
  });

  test('再出題日はテスト日を超えない', () {
    expect(retryDates(DateTime.utc(2026, 10, 20), DateTime.utc(2026, 10, 24)),
        [DateTime.utc(2026, 10, 21), DateTime.utc(2026, 10, 23)]);
  });

  test('範囲が広いと優先単元を返す', () {
    final r = buildPlan(
      today: DateTime.utc(2026, 10, 20),
      plan: _plan(DateTime.utc(2026, 10, 21)),
      tree: _tree(),
    );
    expect(r.overCapacity, isTrue);
    expect(r.priorityUnitIds, isNotEmpty);
  });

  test('アプリ内偏差値: 期待得点と同じなら50', () {
    final p = List.filled(30, 0.6);
    final d = estimateDeviation(p, 18);
    expect(d.value, closeTo(50, 1e-9));
    expect(d.low, 45);
  });

  test('到達レベルと次までの残り点', () {
    final r = judgeLevel([70, 70, 70]);
    expect(r.level, Level.b);
    expect(r.pointsToNext, closeTo(5, 1e-9));
  });

  test('習熟度は新しい回答を重く見る', () {
    final now = DateTime.utc(2026, 10, 20);
    final m = computeMastery([
      Attempt(questionId: 'q', unitId: 'u', correct: false, answeredAt: now.subtract(const Duration(days: 28))),
      Attempt(questionId: 'q', unitId: 'u', correct: true, answeredAt: now),
    ], now);
    expect(m['u']!.score, closeTo(1 / 1.25, 1e-9));
  });
}
