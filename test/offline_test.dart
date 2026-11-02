import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// オフライン対応（docs/offline_design.md）: 基盤は、ネットワークを使うライブラリを持たない。
/// 通信は、アプリが実装する入口（ArtFetcher など）だけ。
void main() {
  test(
    'lib/ は dart:io・HTTP・WebSocket・Isolate・html のネットワーク用ライブラリを import しない（オフラインで動く基盤）',
    () {
      const forbidden = [
        'dart:io',
        'dart:html',
        'dart:js',
        'dart:js_interop',
        'package:http/',
        'package:dio/',
        'package:web_socket_channel/',
        'package:connectivity',
        'package:firebase',
      ];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      final offenders = <String>[];
      for (final f in files) {
        for (final line in f.readAsLinesSync()) {
          final m = RegExp(
            r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
          ).firstMatch(line);
          if (m == null) continue;
          final target = m.group(1)!;
          if (forbidden.any(target.startsWith)) {
            offenders.add('${f.path}: $target');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );

  test('画像の取得は、アプリが実装する入口（ArtFetcher）を通してだけ。基盤に実装（HTTP クライアント）がない', () {
    final src = File('lib/src/character/art_pack.dart').readAsStringSync();
    expect(src.contains('abstract class ArtFetcher'), isTrue);
    expect(src.contains('HttpClient'), isFalse);
    expect(src.contains('http.get'), isFalse);
  });

  test('設計書がある（オフラインの約束と、通信が要るものの一覧）', () {
    final doc = File('docs/offline_design.md').readAsStringSync();
    expect(doc, contains('通信なしで最後まで動く'));
    expect(doc, contains('初回起動から'));
  });
}
