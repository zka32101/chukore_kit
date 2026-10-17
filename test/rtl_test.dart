import 'dart:ui' as ui;

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GrowthCardData _card(ChukoreStrings s) => GrowthCardData(
      subjectLabel: 'Math',
      level: Level.b,
      pointsToNext: 5,
      scoreDelta: 4,
      strings: s,
      radar: const [RadarAxis('a', .5), RadarAxis('b', .5), RadarAxis('c', .5)],
    );

/// PNG の (x, y) 画素の色（デザイン座標 1080×1350 を [scale] 倍した画像上）。
Future<Color> _pixel(WidgetTester tester, GrowthCardData d, double scale, double x, double y) async {
  final color = await tester.runAsync(() async {
    final bytes = await renderGrowthCardPng(d, scale: scale);
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = ((y * scale).round() * image.width + (x * scale).round()) * 4;
    final c = Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    image.dispose();
    return c;
  });
  return color!;
}

void main() {
  group('アラビア語', () {
    test('forLocale: ar・ar-EG・ar_SA', () {
      expect(ChukoreStrings.forLocale('ar'), isA<ArStrings>());
      expect(ChukoreStrings.forLocale('ar-EG'), isA<ArStrings>());
      expect(ChukoreStrings.forLocale('ar_SA'), isA<ArStrings>());
      expect(const ArStrings().tag, 'ar');
    });

    test('右から左なのはアラビア語だけ', () {
      expect(const ArStrings().rightToLeft, isTrue);
      for (final l in ChukoreStrings.supported.where((l) => l.languageCode != 'ar')) {
        expect(l.rightToLeft, isFalse, reason: l.tag);
      }
      expect(textDirectionOf(const ArStrings()), TextDirection.rtl);
      expect(textDirectionOf(const EnStrings()), TextDirection.ltr);
    });

    test('数の読み上げ（11・12 は特別、13〜19 は 〜 عشر、一の位 و 十の位、位は و でつなぐ）', () {
      const ar = ArStrings();
      expect(ar.gateNumberWords(1), 'واحد');
      expect(ar.gateNumberWords(10), 'عشرة');
      expect(ar.gateNumberWords(11), 'أحد عشر');
      expect(ar.gateNumberWords(12), 'اثنا عشر');
      expect(ar.gateNumberWords(15), 'خمسة عشر');
      expect(ar.gateNumberWords(20), 'عشرون');
      expect(ar.gateNumberWords(21), 'واحد وعشرون');
      expect(ar.gateNumberWords(99), 'تسعة وتسعون');
      expect(ar.gateNumberWords(100), 'مئة');
      expect(ar.gateNumberWords(101), 'مئة وواحد');
      expect(ar.gateNumberWords(200), 'مئتان');
      expect(ar.gateNumberWords(300), 'ثلاثمئة');
      expect(ar.gateNumberWords(482), 'أربعمئة واثنان وثمانون');
      expect(ar.gateNumberWords(125), 'مئة وخمسة وعشرون');
      expect(ar.gateNumberWords(1000), 'ألف');
      expect(ar.gateNumberWords(1001), 'ألف وواحد');
      expect(ar.gateNumberWords(2000), 'ألفان');
      expect(ar.gateNumberWords(2025), 'ألفان وخمسة وعشرون');
      expect(ar.gateNumberWords(3000), 'ثلاثة آلاف');
      expect(ar.gateNumberWords(9999), 'تسعة آلاف وتسعمئة وتسعة وتسعون');
      expect(() => ar.gateNumberWords(0), throwsRangeError);
    });

    test('1〜9999 のすべてで、空白の乱れや「و」の付け方の誤りが出ない', () {
      const ar = ArStrings();
      for (var n = 1; n <= 9999; n++) {
        final w = ar.gateNumberWords(n);
        expect(w, isNotEmpty, reason: '$n');
        expect(w, equals(w.trim()), reason: '$n: "$w"');
        expect(w.contains('  '), isFalse, reason: '$n: "$w"');
        // 先頭に接続詞の「و」は付かない（語 واحد の頭文字は別）
        expect(w.startsWith('و') && !w.startsWith('واحد'), isFalse, reason: '$n: "$w"');
        expect(w.contains(' و '), isFalse, reason: '$n: و は次の語に付く: "$w"');
        expect(w.endsWith(' و'), isFalse, reason: '$n: "$w"');
      }
    });

    test('個数の言い方（1 は単数、2 は双数、3〜10 は複数、11 以上は単数の対格）', () {
      const ar = ArStrings();
      expect(ar.solvableValue(1), 'سؤال واحد');
      expect(ar.solvableValue(2), 'سؤالان');
      expect(ar.solvableValue(5), '5 أسئلة');
      expect(ar.solvableValue(10), '10 أسئلة');
      expect(ar.solvableValue(11), '11 سؤالًا');
      expect(ar.streakDays(2), contains('يومان'));
      expect(ar.streakDays(7), contains('7 أيام'));
      expect(ar.streakDays(30), contains('30 يومًا'));
      expect(ar.reportHeader(3, 12), 'هذا الأسبوع: 3 أيام / 12 سؤالًا');
    });

    test('小数点はドット。年は م / ق.م。レポートの変化は「من … إلى …」', () {
      const ar = ArStrings();
      expect(ar.decimalSeparator, '.');
      expect(ar.formatYear(-500), '500 ق.م');
      expect(ar.formatYear(1945), '1945 م');
      expect(ar.reportItem('فعل', 40, 70), '- فعل (من 40% إلى 70%)');
      expect(ar.formatNumber(2.5), '2.5');
    });
  });

  group('各地の数字の入力', () {
    test('normalizeDigits: 東洋式・ペルシア式・タイ・デーヴァナーガリー・全角を ASCII にし、アラビア語の区切りも直す', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(normalizeDigits('๐๑๒๓๔๕๖๗๘๙'), '0123456789');
      expect(normalizeDigits('०१२३४५६७८९'), '0123456789');
      expect(normalizeDigits('０１２３４５６７８９'), '0123456789');
      expect(normalizeDigits('١٢٫٥'), '12.5'); // アラビア語の小数点
      expect(normalizeDigits('١٬٢٠٠'), '1,200'); // アラビア語の桁区切り
      expect(normalizeDigits('١،٢٠٠'), '1,200'); // アラビア語の読点
      expect(normalizeDigits('abc 12 ٣'), 'abc 12 3'); // それ以外はそのまま
    });

    test('保護者ゲート: 東洋式・ペルシア式の数字でも入力できる', () {
      expect(const GateChallenge(482).promptFor(const ArStrings()), 'أربعمئة واثنان وثمانون');
      expect(const GateChallenge(482).verify('٤٨٢'), isTrue);
      expect(const GateChallenge(482).verify('۴۸۲'), isTrue);
      expect(const GateChallenge(1200).verify('١٬٢٠٠'), isTrue);
      expect(const GateChallenge(482).verify('٤٨٣'), isFalse);
    });

    test('数値入力: 東洋式の数字・アラビア語の小数点でも判定できる', () {
      const q = Question(
        id: 'q', unitId: 'u', type: 'numeric', difficulty: .5,
        choices: [], answer: '12.5', explanationId: 'x',
      );
      expect(checkAnswer(q, '١٢٫٥').correct, isTrue);
      expect(checkAnswer(q, '12.5').correct, isTrue);
      expect(checkAnswer(q, '١٢٫٦').correct, isFalse);
    });
  });

  group('画面部品の向き', () {
    testWidgets('年表: アラビア語では右から左（他の言語は左から右）', (tester) async {
      Future<TextDirection> dir(ChukoreStrings s) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: TimelineOrderList(
              events: const [TimelineEvent(id: 'a', label: 'A', year: 1), TimelineEvent(id: 'b', label: 'B', year: 2)],
              onReordered: (_) {},
              strings: s,
            ),
          ),
        ));
        return Directionality.of(tester.element(find.byType(ListTile).first));
      }

      expect(await dir(const ArStrings()), TextDirection.rtl);
      expect(await dir(const EnStrings()), TextDirection.ltr);
    });

    testWidgets('当日チェック: アラビア語では右から左', (tester) async {
      Future<TextDirection> dir(ChukoreStrings s) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: DayChecklistView(checklist: DayChecklist([for (final (id, l) in s.checklistDefaults) ChecklistItem(id, l)]), onChanged: (_) {}, strings: s)),
        ));
        return Directionality.of(tester.element(find.byType(CheckboxListTile).first));
      }

      expect(await dir(const ArStrings()), TextDirection.rtl);
      expect(await dir(const JaStrings()), TextDirection.ltr);
    });

    testWidgets('成長カード: レベルのバッジはアラビア語では左側、他の言語では右側', (tester) async {
      final accent = const Color(0xFF3B82F6);
      // バッジ（半径 110）の上寄り、文字に重ならない位置
      final ar = _card(const ArStrings());
      final en = _card(const EnStrings());
      expect(await _pixel(tester, ar, 0.25, 200, 250), accent);
      expect(await _pixel(tester, ar, 0.25, 880, 250), isNot(accent));
      expect(await _pixel(tester, en, 0.25, 880, 250), accent);
      expect(await _pixel(tester, en, 0.25, 200, 250), isNot(accent));
    });
  });
}
