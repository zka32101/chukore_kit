import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt _a(String q, int day, bool ok, {String unit = 'u1'}) => Attempt(
      questionId: q,
      unitId: unit,
      correct: ok,
      answeredAt: DateTime(2026, 10, day, 9),
    );

DateTime _d(int day) => DateTime.utc(2026, 10, day);

void main() {
  test('不正解は箱 0 で翌日、正解を重ねると間隔が 1→3→7→14→30 と伸びる', () {
    var s = buildReviewStates([_a('q', 1, false)])['q']!;
    expect((s.box, s.lapses, s.dueOn), (0, 1, _d(2)));

    final steps = buildReviewStates([
      _a('q', 1, true), _a('q', 2, true), _a('q', 5, true), _a('q', 12, true), _a('q', 26, true),
    ]);
    // 最後の正解で箱 4（30日）。26日 + 30日 = 11/25
    expect(steps['q']!.box, 4);
    expect(steps['q']!.dueOn, DateTime.utc(2026, 11, 25));

    s = buildReviewStates([_a('q', 1, true)])['q']!;
    expect((s.box, s.dueOn), (0, _d(2))); // 初回正解は翌日にもう一度
    s = buildReviewStates([_a('q', 1, true), _a('q', 2, true)])['q']!;
    expect((s.box, s.dueOn), (1, _d(5)));
  });

  test('定着後に間違えると箱 0 に戻り、間違えた回数が増える', () {
    final s = buildReviewStates([
      _a('q', 1, true), _a('q', 2, true), _a('q', 5, true), _a('q', 12, false),
    ])['q']!;
    expect((s.box, s.lapses, s.dueOn), (0, 1, _d(13)));
  });

  test('箱は最後の間隔で頭打ち', () {
    final s = buildReviewStates([
      for (var i = 0; i < 10; i++) _a('q', 1 + i, true),
    ])['q']!;
    expect(s.box, const ReviewConfig().maxBox);
  });

  test('入力の順序に依らない（時刻順に処理する）', () {
    final xs = [_a('q', 1, false), _a('q', 2, true), _a('q', 5, true)];
    final a = buildReviewStates(xs)['q']!;
    final b = buildReviewStates(xs.reversed)['q']!;
    expect((a.box, a.dueOn, a.lapses), (b.box, b.dueOn, b.lapses));
  });

  test('テスト日を超えない。最後に解いた日より前にもならない', () {
    final xs = [_a('q', 1, true), _a('q', 2, true), _a('q', 5, true)]; // 本来 5日+7日=12日
    expect(buildReviewStates(xs, testDate: DateTime(2026, 10, 9))['q']!.dueOn, _d(9));
    expect(buildReviewStates(xs)['q']!.dueOn, _d(12));
    // テスト日が最後に解いた日より前（テスト後に解いたデータ）
    expect(buildReviewStates(xs, testDate: DateTime(2026, 10, 3))['q']!.dueOn, _d(5));
  });

  test('今日の復習: 遅れている順→箱が低い順→ID順、件数と単元で絞れる', () {
    final states = buildReviewStates([
      _a('late', 1, false), // 期日 2日 → 10/10 時点で 8日遅れ
      _a('b2', 8, false), // 期日 9日 → 1日遅れ
      _a('b1', 8, false, unit: 'u2'), // 同じく 1日遅れ・箱 0・ID が先
      _a('future', 9, false), // 期日 10日 → 当日（0日）
      _a('notyet', 10, false), // 期日 11日 → まだ
    ]);
    final today = DateTime(2026, 10, 10);
    expect(dueForReview(states, today).map((s) => s.questionId), ['late', 'b1', 'b2', 'future']);
    expect(dueForReview(states, today, limit: 2).map((s) => s.questionId), ['late', 'b1']);
    expect(dueForReview(states, today, unitIds: {'u2'}).map((s) => s.questionId), ['b1']);
    expect(states['notyet']!.isDue(today), isFalse);
    expect(states['late']!.overdueDays(today), 8);
  });

  test('履歴が無ければ空', () {
    expect(buildReviewStates(const []), isEmpty);
    expect(dueForReview(const {}, DateTime(2026, 10, 10)), isEmpty);
  });

  test('日付はローカル暦日（海外でも日付がずれない）', () {
    final s = buildReviewStates([
      Attempt(questionId: 'q', unitId: 'u', correct: false, answeredAt: DateTime(2026, 10, 1, 23, 59)),
    ])['q']!;
    expect(s.dueOn, _d(2));
  });
}
