// 大量の履歴（10 万件）でも、処理が実用的な時間で終わることを守る。履歴の件数の 2 乗に比例して遅くなる実装を
// 入れてしまったとき（過去に `classifyMistakes` と `buildRetrySets` で起きた。10 万件で十数秒）に落ちる。
// 時間の上限は、通常の十数倍の余裕を見ている（環境が遅くても落ちにくく、2 乗の遅さは確実に捉える）。
// 全関数の時間は `dart run tool/bench.dart` で見られる。
import 'dart:math' show Random;

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/bench.dart' show BenchData;

void main() {
  late BenchData data;
  late Map<String, Question> byId;
  setUpAll(() {
    data = BenchData.generate(100000);
    byId = {for (final q in data.questions) q.id: q};
  });

  const limit = Duration(seconds: 4);

  void within(String name, Object? Function() f) {
    test('10 万件でも ${limit.inSeconds} 秒以内: $name', () {
      final sw = Stopwatch()..start();
      f();
      expect(sw.elapsed, lessThan(limit), reason: name);
    });
  }

  within('classifyMistakes', () => classifyMistakes(data.attempts));
  within('buildRetrySets', () => buildRetrySets(attempts: data.attempts, questions: data.questions));
  within('buildWeakNotes', () => buildWeakNotes(data.attempts, byId));
  within('computeMastery + buildReviewStates', () {
    computeMastery(data.attempts, data.today);
    return dueForReview(buildReviewStates(data.attempts), data.today);
  });
  within('pickPractice', () => pickPractice(
        plan: data.plan.first,
        questions: data.questions,
        mastery: computeMastery(data.attempts, data.today),
        attempts: data.attempts,
        today: data.today,
      ));
  within('buildWeeklyReport', () => buildWeeklyReport(data.attempts, data.tree, data.today.subtract(const Duration(days: 6)), questions: byId));
  within('buildTodayCard', () => buildTodayCard(now: data.today, attempts: data.attempts, plan: data.plan));
  within('buildQualityReport', () => buildQualityReport(data.attempts, data.questions));

  test('速くしても結果は同じ: 履歴の順序に依らない（シャッフルしても同じ判定）', () {
    // 同じ時刻の回答があると、並べ替えの順が決まらない（時刻だけで並べるため）。時刻が重ならない回答だけにする
    final seen = <int>{};
    final a = [for (final x in data.attempts) if (seen.add(x.answeredAt.microsecondsSinceEpoch)) x].take(3000).toList();
    final shuffled = [...a]..shuffle(_Rng());
    String key(List<MistakeVerdict> v) => v.map((x) => '${x.attempt.questionId}@${x.attempt.answeredAt.microsecondsSinceEpoch}:${(x.reasons.map((r) => r.name).toList()..sort()).join("+")}').join('|');
    expect(key(classifyMistakes(shuffled)), key(classifyMistakes(a)));
    final r1 = buildRetrySets(attempts: a, questions: data.questions).map((r) => r.key).toList();
    final r2 = buildRetrySets(attempts: shuffled, questions: data.questions).map((r) => r.key).toList();
    expect(r2, r1);
  });
}

class _Rng implements Random {
  var _s = 7;
  @override
  int nextInt(int max) {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s % max;
  }

  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);
  @override
  bool nextBool() => nextInt(2) == 0;
}
