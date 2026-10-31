import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('決まった種は決まった列（別実装でも同じ値になる固定値。変えると過去の変種が変わる）', () {
    List<int> take(int seed) {
      final r = SeededRandom(seed);
      return [for (var i = 0; i < 4; i++) r.nextUint32()];
    }

    expect(take(1), [3745685276, 411726028, 2229840677, 2684632963]);
    expect(take(2), [3762543891, 3890211971, 1405072676, 108499593]);
    expect(take(17), [4035770412, 2661331688, 2537759830, 2331651058]);
    expect(take(0), [2831543865, 3042595768, 445164014, 4179142836]);
    expect(take(-5), [2065675627, 1004594674, 3431497213, 2780836006]);
  });

  test('nextInt は範囲内で、両端を含む。種 1 の最初の 10 個は固定', () {
    final r = SeededRandom(1);
    expect([for (var i = 0; i < 10; i++) r.nextInt(2, 9)], [6, 6, 7, 5, 3, 4, 7, 8, 4, 8]);
    final r2 = SeededRandom(3);
    final seen = {for (var i = 0; i < 400; i++) r2.nextInt(-2, 2)};
    expect(seen, {-2, -1, 0, 1, 2});
    expect(SeededRandom(5).nextInt(4, 4), 4);
  });

  test('連続した小さい種でも先頭の値が離れる', () {
    final firsts = {for (var s = 1; s <= 50; s++) SeededRandom(s).nextInt(0, 99)};
    expect(firsts.length, greaterThan(25));
  });

  test('同じ種は同じ列。32bit を超える種は下位 32bit だけで決まる', () {
    final a = SeededRandom(7), b = SeededRandom(7);
    expect([for (var i = 0; i < 20; i++) a.nextUint32()], [for (var i = 0; i < 20; i++) b.nextUint32()]);
    expect(SeededRandom(0).nextUint32(), SeededRandom(4294967296).nextUint32());
  });

  test('pick と不正な引数', () {
    final r = SeededRandom(9);
    final seen = {
      for (var i = 0; i < 100; i++) r.pick(['a', 'b', 'c']),
    };
    expect(seen, {'a', 'b', 'c'});
    expect(() => r.pick(<int>[]), throwsArgumentError);
    expect(() => r.nextInt(3, 2), throwsArgumentError);
  });
}
