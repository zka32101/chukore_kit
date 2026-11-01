import 'package:chukore_kit/src/util/five_number.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> five(List<num> xs) {
  final f = fiveNumberSummary(xs);
  return [f.min, f.q1, f.median, f.q3, f.max];
}

void main() {
  test('偶数個: 半分に分けて、それぞれの中央値', () {
    expect(five([1, 2, 3, 4, 5, 6, 7, 8]), [1, 2.5, 4.5, 6.5, 8]);
    expect(five([3, 9]), [3, 3, 6, 9, 9]);
    expect(five([1, 2, 3, 4]), [1, 1.5, 2.5, 3.5, 4]);
  });

  test('奇数個: 中央値はどちらの半分にも入れない', () {
    expect(five([1, 2, 3, 4, 5, 6, 7, 8, 9]), [1, 2.5, 5, 7.5, 9]);
    expect(five([1, 5, 9]), [1, 1, 5, 9, 9]);
    expect(five([2, 4, 6, 8, 10, 12, 14]), [2, 4, 8, 12, 14]);
  });

  test('並びは問わない・重複・小数・四分位範囲と範囲', () {
    final f = fiveNumberSummary([8, 1, 6, 3, 7, 2, 5, 4]);
    expect([f.min, f.q1, f.median, f.q3, f.max], [1, 2.5, 4.5, 6.5, 8]);
    expect(f.iqr, 4);
    expect(f.range, 7);
    expect(five([5, 5, 5, 5]), [5, 5, 5, 5, 5]);
    expect(five([0.5, 1.5, 2.5, 3.5]), [0.5, 1, 2, 3, 3.5]);
  });

  test('入力は書き換えない。整数・小数どちらも受ける', () {
    final xs = <num>[3, 1, 2, 5, 4];
    fiveNumberSummary(xs);
    expect(xs, [3, 1, 2, 5, 4]);
    expect(five(<num>[1, 2.5, 4]), [1, 1, 2.5, 4, 4]);
    expect(five(<num>[4, 3, 2, 1]), [1, 1.5, 2.5, 3.5, 4]);
  });

  test('データが 2 個未満なら ArgumentError', () {
    expect(() => fiveNumberSummary(const []), throwsArgumentError);
    expect(() => fiveNumberSummary([1]), throwsArgumentError);
    fiveNumberSummary([1, 2]);
  });
}
