import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/src/util/median.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('奇数個は真ん中、偶数個は真ん中 2 つの平均。順不同でも同じ', () {
    expect(median([5]), 5);
    expect(median([3, 1, 2]), 2);
    expect(median([1, 2, 3, 4]), 2.5);
    expect(median([40, 10, 30, 20]), 25);
    expect(median([1.5, 0.5, 1.0]), 1.0);
  });

  test('入力を並べ替えない。空はエラー', () {
    final xs = [3, 1, 2];
    median(xs);
    expect(xs, [3, 1, 2]);
    expect(() => median(const <int>[]), throwsArgumentError);
  });

  test('整数にするときの四捨五入（0.5 は切り上げ）', () {
    expect(median([8, 9, 20, 30]).round(), 15);
    expect(median([1, 2]).round(), 2);
  });

  // 共通化の前後で挙動が変わっていないことの確認（空の履歴や minSamples 0 でも落ちない）
  test('ケアレス判定: minSamples が 0 でも、正解の記録が無くて落ちない', () {
    final a = [Attempt(questionId: 'q', unitId: 'u', correct: false, answeredAt: DateTime(2026, 10, 1), elapsedMs: 100)];
    expect(classifyMistakes(a, minSamples: 0).single.reasons, isEmpty);
  });

  test('克服スタンプの累計は、克服済みの弱点の数（G4。これまで試験が無かった）', () {
    WeakEntry e(String k, bool overcome) => WeakEntry(key: k, wrongCount: 1, lastWrongAt: DateTime(2026, 10, 1), overcome: overcome);
    expect(overcomeStampCount(const []), 0);
    expect(overcomeStampCount([e('a', true), e('b', false), e('c', true)]), 2);
    expect(overcomeStampCount([e('a', false)]), 0);
  });

  group('allocateByWeight（最大剰余法）', () {
    test('合計に一致し、重みに比例する。同率は小さいキーが先に 1 つもらう', () {
      expect(allocateByWeight(10, {'a': 1, 'b': 1, 'c': 1}), {'a': 4, 'b': 3, 'c': 3});
      expect(allocateByWeight(10, {'a': 3, 'b': 1}), {'a': 8, 'b': 2}, reason: '7.5 と 2.5。余りが同じなので a が先に 1 つもらう');
      expect(allocateByWeight(7, {'x': 0.5, 'y': 0.3, 'z': 0.2}).values.fold<int>(0, (a, b) => a + b), 7);
    });

    test('0 になった項目は含めない。合計 0・重みが無い・重みの和が 0 は空', () {
      expect(allocateByWeight(1, {'a': 5, 'b': 1}), {'a': 1});
      expect(allocateByWeight(0, {'a': 1}), isEmpty);
      expect(allocateByWeight(-3, {'a': 1, 'b': 1}), isEmpty, reason: '負の合計は配分しない');
      expect(allocateByWeight(5, const {}), isEmpty);
      expect(allocateByWeight(5, {'a': 0, 'b': 0}), isEmpty);
    });
  });

  group('wilsonInterval（95% 信頼区間）', () {
    test('既知の値: 50% / 100 件 → およそ 0.404〜0.596。全部成功でも上端は 1 を超えず、下端は 1 未満', () {
      final (low, high) = wilsonInterval(0.5, 100, 1.96);
      expect(low, closeTo(0.404, 0.001));
      expect(high, closeTo(0.596, 0.001));
      final (l2, h2) = wilsonInterval(1.0, 10, 1.96);
      expect(l2, closeTo(0.722, 0.001));
      expect(h2, 1.0);
      final (l3, h3) = wilsonInterval(0.0, 10, 1.96);
      expect(l3, 0.0);
      expect(h3, closeTo(0.278, 0.001));
    });

    test('件数が増えると幅が狭まる。区間は 0〜1 に収まる', () {
      double width(int n) {
        final (l, h) = wilsonInterval(0.7, n, 1.96);
        return h - l;
      }

      expect(width(1000), lessThan(width(100)));
      expect(width(100), lessThan(width(10)));
    });
  });

  test('前日・当日の区分（eveNoticeOf）', () {
    expect(eveNoticeOf(1), EveNotice.eve);
    expect(eveNoticeOf(0), EveNotice.testDay);
    for (final d in [-3, -1, 2, 7]) {
      expect(eveNoticeOf(d), EveNotice.none, reason: '$d');
    }
  });
}
