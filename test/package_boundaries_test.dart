import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 数学の部品（lib/src/math）を、後から別パッケージに切り出せる状態に保つための境界テスト。
/// 方針は docs/math_foundation.md の「パッケージの境界」。
List<String> _imports(File f) => [
  for (final l in f.readAsLinesSync())
    if (RegExp(r'''^\s*(import|export)\s+['"]''').hasMatch(l)) RegExp(r'''['"]([^'"]+)['"]''').firstMatch(l)!.group(1)!,
];

void main() {
  test('lib/src/math は Flutter に依存せず、models・bank・scope/unit_tree 以外の core に依存しない', () {
    const allowed = {'../models/models.dart', '../bank/question_bank.dart', '../scope/unit_tree.dart', '../util/five_number.dart'};
    final files = Directory(
      'lib/src/math',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      for (final i in _imports(f)) {
        if (i.startsWith('dart:')) continue;
        expect(i.startsWith('package:flutter'), isFalse, reason: '${f.path}: $i');
        expect(
          i.startsWith('../') ? allowed.contains(i) : !i.contains('/') || i.startsWith('package:'),
          isTrue,
          reason: '${f.path} が許可されていない import: $i',
        );
        expect(i.startsWith('package:'), isFalse, reason: '${f.path}: パッケージ依存 $i');
      }
    }
  });

  test('core から lib/src/math を使っているのは、問題の判定と問題集の検証だけ', () {
    const users = {
      'lib/src/question/answer.dart',
      'lib/src/bank/question_bank.dart',
      'lib/src/lesson/math_lesson_checker.dart', // 数学のレッスンの検査（教科ごとの検査は lesson 側に置き、math は lesson を知らない）
      'lib/src/pack/content_pack.dart', // コンテンツパックの検証（型・体験型・作図・レッスンの検査をまとめる統合の層）
      'lib/chukore_kit.dart',
    };
    final found = <String>{};
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart') || e.path.startsWith('lib/src/math/')) continue;
      if (_imports(e).any((i) => i.contains('math/') && !i.startsWith('dart:'))) found.add(e.path);
    }
    expect(found, users);
  });

  test('lib/src/experience（教科共通の体験）は数学にも Flutter にも依存しない', () {
    const allowed = {'../bank/question_bank.dart', '../scope/unit_tree.dart'};
    final files = Directory('lib/src/experience').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      for (final i in _imports(f)) {
        expect(i.startsWith('../') ? allowed.contains(i) : i == 'dart:convert', isTrue, reason: '${f.path}: $i');
      }
    }
  });

  test('lib/src/chart（資料のグラフ）は数学にも Flutter にも core にも依存しない', () {
    final files = Directory('lib/src/chart').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      for (final i in _imports(f)) {
        expect(i == 'dart:convert' || i == 'dart:math' || i == '../util/five_number.dart', isTrue, reason: '${f.path}: $i');
      }
    }
  });

  test('lib/src/map（地図データ）は Flutter・数学に依存しない', () {
    const allowed = {'../bank/question_bank.dart', '../question/map_tap.dart', '../question/map_viewport.dart'};
    final files = Directory('lib/src/map').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      for (final i in _imports(f)) {
        expect(i.startsWith('../') ? allowed.contains(i) : (i == 'dart:convert' || i == 'dart:math' || i == 'map_pack.dart'), isTrue, reason: '${f.path}: $i');
      }
    }
  });

  test('画面部品の入口（chukore_kit_ui.dart）は core の入口から出していない', () {
    final core = File('lib/chukore_kit.dart').readAsStringSync();
    expect(core.contains('chukore_kit_ui'), isFalse);
    expect(core.contains('src/ui/'), isFalse);
  });
}
