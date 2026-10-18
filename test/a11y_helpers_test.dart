import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('コントラスト比', () {
    test('黒と白は 21、同じ色は 1。順番は関係ない', () {
      expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 1e-9));
      expect(contrastRatio(0xFFFFFFFF, 0xFF000000), closeTo(21, 1e-9));
      expect(contrastRatio(0xFF3B82F6, 0xFF3B82F6), closeTo(1, 1e-9));
    });

    test('成長カード・リングの既定の教科色は、白地で文字以外の基準（3）を満たすが、小さな文字の基準（4.5）は満たさない', () {
      const accent = 0xFF3B82F6;
      expect(contrastRatio(accent, 0xFFFFFFFF), closeTo(3.68, 0.01));
      expect(meetsGraphicContrast(accent, 0xFFFFFFFF), isTrue);
      expect(meetsTextContrast(accent, 0xFFFFFFFF), isFalse, reason: 'この色で小さな文字を書かない');
      expect(meetsTextContrast(accent, 0xFFFFFFFF, largeText: true), isTrue);
    });

    test('文字以外の基準（3）に届かない色もある', () {
      expect(meetsGraphicContrast(0xFF999999, 0xFFFFFFFF), isFalse, reason: '約 2.85');
      expect(meetsGraphicContrast(0xFF949494, 0xFFFFFFFF), isTrue, reason: '約 3.03');
    });

    test('透明度は無視する。境目の値（4.5 / 3）は満たす側', () {
      expect(contrastRatio(0x00000000, 0xFFFFFFFF), closeTo(21, 1e-9));
      // 灰色 #767676 は白地で約 4.54（AA をぎりぎり満たす有名な値）、#777777 は約 4.48
      expect(meetsTextContrast(0xFF767676, 0xFFFFFFFF), isTrue);
      expect(meetsTextContrast(0xFF777777, 0xFFFFFFFF), isFalse);
    });
  });

  group('読みやすい長さに分ける', () {
    test('文末で区切り、maxChars までまとめる', () {
      final r = splitForReading('いちばん。にばん！さんばん？よんばん。', maxChars: 10);
      expect(r, ['いちばん。にばん！', 'さんばん？よんばん。']);
    });

    test('1 文が長いときは読点で、無ければ文字数で切る', () {
      expect(splitForReading('あいうえお、かきくけこ、さしすせそ。', maxChars: 6), ['あいうえお、', 'かきくけこ、', 'さしすせそ。']);
      expect(splitForReading('あいうえおかきくけこ', maxChars: 4), ['あいうえ', 'おかきく', 'けこ']);
      expect(splitForReading('abcdefgh', maxChars: 3).every((s) => s.length <= 3), isTrue);
    });

    test('英語: 小数点や略語の途中では切らない。閉じかっこは文に含める', () {
      expect(splitForReading('Pi is 3.14 here. Next one.', maxChars: 20), ['Pi is 3.14 here. ', 'Next one.']);
      expect(splitForReading('「行こう。」と言った。次へ。', maxChars: 8), ['「行こう。」', 'と言った。次へ。']);
    });

    test('小数点の途中で文を切らない（まとめ直しでは元に戻らない小さな長さで確かめる）', () {
      expect(splitForReading('ab 1.5cd ef.', maxChars: 8), ['ab 1.5cd', ' ef.']);
    });

    test('空文字・空白だけは空。改行を含んでも 1 つにまとまる', () {
      expect(splitForReading(''), isEmpty);
      expect(splitForReading('  \n '), isEmpty);
      expect(splitForReading('  abc  '), ['abc'], reason: '前後の空白は除く');
      expect(splitForReading('A\n\nB', maxChars: 5), ['A\n\nB']);
    });

    test('サロゲートペア（絵文字）を壊さない。maxChars が 1 未満ならエラー', () {
      final r = splitForReading('😀😀😀😀', maxChars: 3);
      expect(r, ['😀😀😀', '😀']);
      expect(() => splitForReading('a', maxChars: 0), throwsArgumentError);
    });
  });

  group('大きな文字（文字拡大 200%）でも崩れない', () {
    Widget scaled(Widget child) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(2.0)),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );

    testWidgets('当日チェックは、全言語でオーバーフローしない', (tester) async {
      for (final s in ChukoreStrings.supported) {
        await tester.pumpWidget(scaled(DayChecklistView(
          checklist: DayChecklist([for (final (id, l) in s.checklistDefaults) ChecklistItem(id, l)]),
          onChanged: (_) {},
          strings: s,
        )));
        expect(tester.takeException(), isNull, reason: s.languageCode);
      }
    });
  });
}
