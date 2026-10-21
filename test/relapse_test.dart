import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final d0 = DateTime(2026, 9, 1, 10);

Question q(String id, {Map<String, String> tags = const {}}) => Question(
      id: id,
      unitId: 'u',
      type: 'choice',
      difficulty: 0.5,
      choices: const ['a', 'b', 'c'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: tags,
    );

/// [day] 日目に問題 [qid] を解いた記録。[chosen] が 'a' なら正解。
Attempt at(int day, String qid, String chosen, {int hint = 0, LossReason? reason, int ms = 8000}) => Attempt(
      questionId: qid,
      unitId: 'u',
      correct: chosen == 'a',
      chosenId: chosen,
      answeredAt: d0.add(Duration(days: day)),
      hintsUsed: hint,
      reason: reason,
      elapsedMs: ms,
    );

final tagged = {'x': q('x', tags: {'b': 't1'}), 'y': q('y', tags: {'b': 't1'}), 'z': q('z'), 'w': q('w')};

RelapseReport run(List<Attempt> a, {int today = 100, int minAge = 14, bool ignoreCareless = true}) =>
    analyzeRelapses(a, tagged, today: d0.add(Duration(days: today)), minAgeDays: minAge, ignoreCareless: ignoreCareless);

void main() {
  group('克服と再発', () {
    test('間違えて、3 日連続で正解すれば克服。そのあと同じ型でまた間違えたら再発（日数つき）', () {
      final r = run([at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'a'), at(4, 'x', 'a'), at(20, 'x', 'b')]);
      expect(r.events.length, 1);
      final e = r.events.single;
      expect([e.key, e.tag, e.questionId], ['tag:t1', 't1', null]);
      expect(e.overcameAt, d0.add(const Duration(days: 4)));
      expect(e.relapsedAt, d0.add(const Duration(days: 20)));
      expect(e.relapsed, isTrue);
      expect(e.daysHeld, 16);
      expect(r.relapsedCount, 1);
    });

    test('再発のあとにまた克服すれば、2 つ目の出来事（こちらは再発していない）', () {
      final r = run([
        at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'a'), at(4, 'x', 'a'),
        at(20, 'x', 'b'), at(21, 'x', 'a'), at(22, 'x', 'a'), at(23, 'x', 'a'),
      ]);
      expect(r.events.map((e) => (e.overcameAt.difference(d0).inDays, e.relapsed)), [(4, true), (23, false)]);
    });

    test('克服していなければ、再発ではない（間違えが続いただけ）', () {
      final r = run([at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'a'), at(4, 'x', 'b')]);
      expect(r.events, isEmpty);
    });

    test('型は問題をまたぐ: 別の問題（同じ型）での間違いも再発', () {
      final r = run([at(1, 'x', 'b'), at(2, 'y', 'a'), at(3, 'y', 'a'), at(4, 'x', 'a'), at(10, 'y', 'b')]);
      expect(r.events.single.relapsed, isTrue);
      expect(r.events.single.key, 'tag:t1');
    });

    test('型の無い誤答は問題単位の項目', () {
      final r = run([at(1, 'z', 'b'), at(2, 'z', 'a'), at(3, 'z', 'a'), at(5, 'z', 'a'), at(30, 'z', 'c')]);
      final e = r.events.single;
      expect([e.key, e.tag, e.questionId, e.relapsed], ['q:z', null, 'z', true]);
    });

    test('克服の基準は弱点ノートと同じ: ヒントつきの正解・同じ日だけの正解は数えない', () {
      expect(run([at(1, 'x', 'b'), at(2, 'x', 'a', hint: 1), at(3, 'x', 'a'), at(4, 'x', 'a')]).events, isEmpty);
      final sameDay = [at(1, 'x', 'b'), at(2, 'x', 'a'), at(2, 'x', 'a'), at(2, 'x', 'a')];
      expect(run(sameDay).events, isEmpty, reason: '2 日以上にまたがっていない');
      expect(analyzeRelapses(sameDay, tagged, today: d0.add(const Duration(days: 100)), minDays: 1).events.length, 1);
      expect(analyzeRelapses([at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'a')], tagged, today: d0.add(const Duration(days: 100)), streak: 2).events.length, 1);
    });

    test('別の型を選んだ間違いは、この型の再発ではないが、連続正解は途切れる', () {
      final m = {'x': q('x', tags: {'b': 't1', 'c': 't2'})};
      final a = [at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'c'), at(4, 'x', 'a'), at(5, 'x', 'a')];
      final r = analyzeRelapses(a, m, today: d0.add(const Duration(days: 100)));
      expect(r.events.where((e) => e.key == 'tag:t1'), isEmpty, reason: 'c は t2。t1 の連続は 2 回で途切れた');
    });
  });

  group('ケアレスミス', () {
    final base = [at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'a'), at(4, 'x', 'a')];

    test('ケアレスミスの疑い（自己申告）の間違いは、再発に数えない。数える設定にもできる', () {
      final a = [...base, at(20, 'x', 'b', reason: LossReason.careless)];
      expect(run(a).events.single.relapsed, isFalse);
      expect(run(a, ignoreCareless: false).events.single.relapsed, isTrue);
    });

    test('わからなかった（自己申告）の間違いは再発', () {
      expect(run([...base, at(20, 'x', 'b', reason: LossReason.dontKnow)]).events.single.relapsed, isTrue);
    });
  });

  group('戻り率', () {
    // 克服して 4 日目、14 日以上たった克服だけが分母
    final a = [
      // 型 t1: 4 日目に克服、再発（日 20）
      at(1, 'x', 'b'), at(2, 'x', 'a'), at(3, 'x', 'a'), at(4, 'x', 'a'), at(20, 'x', 'b'),
      // 問題 z: 10 日目に克服、再発なし
      at(5, 'z', 'b'), at(8, 'z', 'a'), at(9, 'z', 'a'), at(10, 'z', 'a'),
    ];

    test('分母は minAgeDays 日以上たった克服。戻り率 = 再発した割合', () {
      final r = run(a, today: 100);
      expect([r.settled, r.settledRelapsed], [2, 1]);
      expect(r.relapseRate, 0.5);
      final early = run(a, today: 23);
      expect([early.settled, early.settledRelapsed, early.relapseRate], [1, 1, 1.0], reason: '分母は待った克服だけ（全体の 2 件ではない）');
    });

    test('克服したばかりのものは分母に入れない（境目は含める）', () {
      expect(run(a, today: 23).settled, 1, reason: '23 日目: 4 日目の克服は 19 日経過、10 日目の克服は 13 日');
      expect(run(a, today: 24).settled, 2, reason: '24 日目: 10 日目の克服が 14 日経過（ちょうど）');
      expect(run(a, today: 14).settled, 0);
      expect(run(a, today: 14).relapseRate, isNull);
    });

    test('克服から再発までの日数の中央値（再発が無ければ null）', () {
      expect(run(a).medianDaysHeld, 16);
      final two = [...a, at(30, 'z', 'c')]; // z も 20 日後に再発
      expect(run(two).medianDaysHeld, (16 + 20) / 2);
      expect(run([at(1, 'x', 'b')]).medianDaysHeld, isNull);
    });

    test('同じ時刻に克服した項目は、キー順に並ぶ', () {
      final both = [
        for (final id in ['z', 'w']) ...[at(1, id, 'b'), at(2, id, 'a'), at(3, id, 'a'), at(4, id, 'a')],
      ];
      expect(run(both).events.map((e) => e.key), ['q:w', 'q:z']);
    });

    test('履歴の順序に依らない。履歴が無ければ空', () {
      expect(run(a.reversed.toList()).events.map((e) => e.key), run(a).events.map((e) => e.key));
      final r = run(const []);
      expect([r.events, r.settled, r.relapseRate], [isEmpty, 0, null]);
    });

    test('問題集に無い問題は数えない', () {
      expect(run([at(1, 'nope', 'b'), at(2, 'nope', 'a'), at(3, 'nope', 'a'), at(4, 'nope', 'a')]).events, isEmpty);
    });
  });
}
