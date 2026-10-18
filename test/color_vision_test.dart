import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';

const red = 0xFFD32F2F, green = 0xFF388E3C, blue = 0xFF1976D2, yellow = 0xFFFBC02D;

void main() {
  group('見え方の近似', () {
    test('白と黒は変わらない。通常の色覚はそのまま。透明度は保つ', () {
      for (final v in ColorVision.values) {
        expect(simulateColorVision(0xFFFFFFFF, v), 0xFFFFFFFF, reason: '$v');
        expect(simulateColorVision(0xFF000000, v), 0xFF000000, reason: '$v');
      }
      expect(simulateColorVision(red, ColorVision.normal), red);
      expect(simulateColorVision(0x80D32F2F, ColorVision.deutan) >> 24, 0x80);
    });

    test('P型では赤が暗く見える（明るさが下がる）', () {
      expect(relativeLuminance(simulateColorVision(0xFFFF0000, ColorVision.protan)), lessThan(relativeLuminance(0xFFFF0000) * 0.6));
    });
  });

  group('色の違い', () {
    test('同じ色は 0、白と黒は大きい。順番は関係ない', () {
      expect(colorDifference(red, red), 0);
      expect(colorDifference(0xFFFFFFFF, 0xFF000000), closeTo(100, 0.1));
      expect(colorDifference(red, green), closeTo(colorDifference(green, red), 1e-9));
    });

    test('赤と緑は、通常では大きく違うが、P型・D型では近づく。青と黄色は影響が少ない', () {
      final normal = colorDifference(red, green);
      expect(normal, greaterThan(80));
      expect(colorDifference(simulateColorVision(red, ColorVision.deutan), simulateColorVision(green, ColorVision.deutan)), lessThan(20));
      expect(colorDifference(simulateColorVision(red, ColorVision.protan), simulateColorVision(green, ColorVision.protan)), lessThan(30));
      expect(colorDifference(simulateColorVision(blue, ColorVision.deutan), simulateColorVision(yellow, ColorVision.deutan)), greaterThan(100));
    });
  });

  group('配色の検査', () {
    test('赤と緑だけで意味を分けた配色は、D型で見つかる。通常では見つからない', () {
      expect(confusablePairs([red, green], ColorVision.normal), isEmpty);
      expect(confusablePairs([red, green], ColorVision.deutan), [(0, 1)]);
    });

    test('組は添字の小さい順。青と赤・青と緑は残る', () {
      final p = confusablePairs([green, blue, red, yellow], ColorVision.deutan);
      expect(p, [(0, 2)], reason: '緑(0)と赤(2)だけが近い');
    });

    test('minDelta を上げると、より多くの組が見つかる', () {
      expect(confusablePairs([red, green], ColorVision.protan, minDelta: 20), isEmpty);
      expect(confusablePairs([red, green], ColorVision.protan, minDelta: 30), [(0, 1)]);
    });

    test('色が 1 つ以下なら空', () {
      expect(confusablePairs([red], ColorVision.deutan), isEmpty);
      expect(confusablePairs(const [], ColorVision.deutan), isEmpty);
    });
  });

  group('画面で使っている正解（緑）・不正解（赤）', () {
    test('D型・P型では近く見えるので、色だけに頼らず ✓/✗ の形と読み上げを付けている（accessibility_test）', () {
      final pair = [Colors.green.shade800.toARGB32(), Colors.red.shade800.toARGB32()];
      expect(confusablePairs(pair, ColorVision.deutan, minDelta: 30), [(0, 1)], reason: 'もし形の手がかりを外すなら、先にこの配色を変える');
      expect(confusablePairs(pair, ColorVision.normal), isEmpty);
    });
  });
}
