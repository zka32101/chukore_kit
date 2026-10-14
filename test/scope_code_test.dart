import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

UnitTree _tree({int version = 1, String subject = 'en', List<String>? leaves}) {
  final ids = leaves ?? ['e1', 'e2', 'e3', 'e4', 'e5', 'e6', 'e7', 'e8', 'e9', 'e10'];
  return UnitTree(version, [
    Unit(id: 'g1', subject: subject, grade: 1, title: 'G1', order: 1),
    Unit(id: 'g2', subject: subject, grade: 1, title: 'G2', order: 2),
    for (var i = 0; i < ids.length; i++)
      Unit(id: ids[i], subject: subject, grade: 1, title: ids[i], parentId: i < 5 ? 'g1' : 'g2', order: i),
  ]);
}

ScopeDecoded _ok(ScopeDecodeResult r) {
  expect(r, isA<ScopeDecoded>(), reason: r is ScopeDecodeFailure ? '${r.error}' : '');
  return r as ScopeDecoded;
}

ScopeError _err(ScopeDecodeResult r) => (r as ScopeDecodeFailure).error;

void main() {
  final tree = _tree();

  group('符号', () {
    test('往復できる（葉を選ぶ）', () {
      final code = encodeScope(tree, unitIds: ['e2', 'e7', 'e10']);
      final r = _ok(decodeScope(code, tree));
      expect(r.subject, 'en');
      expect(r.unitIds, ['e2', 'e7', 'e10']);
      expect(r.testDate, isNull);
    });

    test('親を選べば配下の葉すべて。木の順に並ぶ', () {
      final r = _ok(decodeScope(encodeScope(tree, unitIds: ['g2', 'e1']), tree));
      expect(r.unitIds, ['e1', 'e6', 'e7', 'e8', 'e9', 'e10']);
    });

    test('テスト日（任意）も往復できる', () {
      final code = encodeScope(tree, unitIds: ['e1'], testDate: DateTime(2026, 11, 5, 18, 30));
      expect(code, endsWith('.20261105'));
      expect(_ok(decodeScope(code, tree)).testDate, DateTime.utc(2026, 11, 5));
    });

    test('形式と長さ。単元IDが長くても短い', () {
      final code = encodeScope(tree, unitIds: ['e1']);
      expect(code, startsWith('CKS1.en.1.'));
      expect(code.split('.').length, 5);
      final longTree = _tree(leaves: [for (var i = 0; i < 300; i++) 'english_grade1_unit_with_a_very_long_id_$i']);
      final big = encodeScope(longTree, unitIds: ['g1', 'g2']);
      expect(big.length, lessThan(120)); // 300単元でも QR に載る短さ
      expect(_ok(decodeScope(big, longTree)).unitIds.length, 300);
    });

    test('同じ入力で同じ符号', () {
      expect(encodeScope(tree, unitIds: ['e3', 'e1']), encodeScope(tree, unitIds: ['e1', 'e3', 'e1']));
    });

    test('空・教科が複数・教科名が不正だと作れない', () {
      expect(() => encodeScope(tree, unitIds: const []), throwsArgumentError);
      expect(() => encodeScope(tree, unitIds: ['zzz']), throwsArgumentError);
      expect(() => encodeScope(_tree(subject: 'English 1'), unitIds: ['e1']), throwsArgumentError);
      final mixed = UnitTree(1, const [
        Unit(id: 'a', subject: 'en', grade: 1, title: 'a'),
        Unit(id: 'b', subject: 'math', grade: 1, title: 'b'),
      ]);
      expect(() => encodeScope(mixed, unitIds: ['a']), throwsArgumentError);
    });
  });

  group('個人情報を含まない', () {
    test('使える文字は英数字と . - _ だけ。入るのは教科・版・指紋・選択・日付だけ', () {
      final code = encodeScope(tree, unitIds: ['e2', 'e5'], testDate: DateTime(2026, 11, 5));
      expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(code), isTrue);
      final parts = code.split('.');
      expect(parts.length, 6);
      expect(parts[0], 'CKS1');
      expect(parts[1], 'en');
      expect(parts[2], '1');
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(parts[3]), isTrue); // 指紋
      expect(parts[5], '20261105');
    });

    test('単元の名前（タイトル）や単元IDそのものも入らない', () {
      final code = encodeScope(tree, unitIds: ['e2']);
      for (final leaked in ['e2', 'G1', 'G2']) {
        expect(code.contains(leaked), isFalse, reason: leaked);
      }
    });
  });

  group('読み取りの失敗', () {
    final code = encodeScope(tree, unitIds: ['e1', 'e2']);

    test('単元ツリーの版が違う・単元が増えた/減った・並びが違う → treeMismatch', () {
      expect(_err(decodeScope(code, _tree(version: 2))), ScopeError.treeMismatch);
      expect(_err(decodeScope(code, _tree(leaves: ['e1', 'e2', 'e3', 'e4', 'e5', 'e6', 'e7', 'e8', 'e9']))), ScopeError.treeMismatch);
      expect(_err(decodeScope(code, _tree(leaves: ['e1', 'e2', 'e3', 'e4', 'e5', 'e6', 'e7', 'e8', 'e9', 'e10', 'e11']))),
          ScopeError.treeMismatch);
      expect(_err(decodeScope(code, _tree(leaves: ['e2', 'e1', 'e3', 'e4', 'e5', 'e6', 'e7', 'e8', 'e9', 'e10']))),
          ScopeError.treeMismatch);
    });

    test('同じ単元IDでも教科が違えば subjectMismatch', () {
      expect(_err(decodeScope(code, _tree(subject: 'math'))), ScopeError.subjectMismatch);
    });

    test('知らない版 → unsupportedVersion。別物 → malformed', () {
      expect(_err(decodeScope(code.replaceFirst('CKS1', 'CKS2'), tree)), ScopeError.unsupportedVersion);
      for (final bad in ['', 'hello', 'CKS', 'CKS1', 'CKS1.en.1', 'XYZ1.en.1.aaaaaaaa.AA', 'https://example.com/?x=1']) {
        expect(_err(decodeScope(bad, tree)), ScopeError.malformed, reason: bad);
      }
    });

    test('ビット列が壊れている → malformed', () {
      final p = code.split('.');
      String with_(String bits) => [...p.sublist(0, 4), bits].join('.');
      expect(_err(decodeScope(with_('!!!'), tree)), ScopeError.malformed); // base64 でない
      expect(_err(decodeScope(with_('AAAAAA'), tree)), ScopeError.malformed); // 長さが違う
      // 長さは合っている（葉10個＝2バイト）が、葉の数（10）を超えるビットが立っている
      String bits(List<int> bytes) => base64Url.encode(Uint8List.fromList(bytes)).replaceAll('=', '');
      expect(_err(decodeScope(with_(bits([0x01, 0xFC])), tree)), ScopeError.malformed); // ビット 10〜15 が立っている
      expect(_ok(decodeScope(with_(bits([0x01, 0x03])), tree)).unitIds, ['e1', 'e9', 'e10']); // ビット 8・9 は葉 9・10 で正しい
    });

    test('1つも選ばれていない → empty', () {
      final p = code.split('.');
      expect(_err(decodeScope([...p.sublist(0, 4), 'AAA'].join('.'), tree)), ScopeError.empty);
    });

    test('テスト日が不正（桁・存在しない日付）→ malformed', () {
      for (final d in ['2026', '20261305', '20260230', 'abcdefgh', '202611050']) {
        expect(_err(decodeScope('$code.$d', tree)), ScopeError.malformed, reason: d);
      }
      expect(_ok(decodeScope('$code.20240229', tree)).testDate, DateTime.utc(2024, 2, 29)); // うるう日は可
    });

    test('前後の空白は許容', () {
      expect(_ok(decodeScope('  $code\n', tree)).unitIds, ['e1', 'e2']);
    });
  });

  group('QR の表示', () {
    testWidgets('読み上げラベルが言語別に付く', (tester) async {
      final handle = tester.ensureSemantics();
      final code = encodeScope(tree, unitIds: ['e1']);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScopeQrView(code: code, strings: const EnStrings()))));
      expect(find.bySemanticsLabel('QR code for the test scope'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('余白（4モジュール）と、左上のファインダーパターンが正しい位置に描かれる', (tester) async {
      final code = encodeScope(tree, unitIds: ['e1', 'e5']);
      const size = 220.0;
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.grey,
          body: Center(child: RepaintBoundary(key: key, child: ScopeQrView(code: code, size: size))),
        ),
      ));
      final bytes = await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      bool dark(double x, double y) {
        final i = ((y.floor() * size.toInt()) + x.floor()) * 4;
        return bytes!.getUint8(i) < 128 && bytes.getUint8(i + 1) < 128 && bytes.getUint8(i + 2) < 128;
      }

      bool light(double x, double y) => !dark(x, y);

      final qr = QrImage(QrCode.fromData(data: code, errorCorrectLevel: QrErrorCorrectLevel.M));
      final cell = size / (qr.moduleCount + 8);
      double c(int m) => (4 + m + 0.5) * cell; // モジュール m の中心
      // 余白は白（読み取りに必要）
      for (final p in [0.5, 1.5, 2.5, 3.5]) {
        expect(light(p * cell, p * cell), isTrue, reason: '余白 $p');
      }
      // 左上のファインダーパターン 7×7: 外周は黒・その内側1周は白・中心3×3は黒
      for (var i = 0; i < 7; i++) {
        expect(dark(c(i), c(0)), isTrue, reason: '上辺 $i');
        expect(dark(c(0), c(i)), isTrue, reason: '左辺 $i');
        expect(dark(c(i), c(6)), isTrue, reason: '下辺 $i');
        expect(dark(c(6), c(i)), isTrue, reason: '右辺 $i');
      }
      for (var i = 1; i < 6; i++) {
        expect(light(c(i), c(1)), isTrue, reason: '内側の白 $i');
      }
      expect(dark(c(3), c(3)), isTrue);
      // 描画した全モジュールが、QR の行列と一致する
      for (var y = 0; y < qr.moduleCount; y++) {
        for (var x = 0; x < qr.moduleCount; x++) {
          expect(dark(c(x), c(y)), qr.isDark(y, x), reason: '($x,$y)');
        }
      }
    });
  });

  test('範囲カードの文言が全言語にある', () {
    for (final s in ChukoreStrings.supported) {
      for (final v in [s.scopeQrTitle, s.scopeQrHint, s.scopeQrSemantics]) {
        expect(v, isNotEmpty);
      }
    }
  });
}
