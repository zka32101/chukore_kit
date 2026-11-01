import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _s([Map<String, dynamic> over = const {}]) =>
    {'id': 'scene_a', 'titleId': 't', 'textId': 'x', 'unitIds': ['u1'], ...over};

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

UnitTree _tree() => UnitTree(1, [
      Unit(id: 'u1', subject: 'math', grade: 1, title: 'U1'),
      Unit(id: 'u2', subject: 'math', grade: 1, title: 'U2'),
    ]);

void main() {
  group('Scene', () {
    test('読み取り', () {
      final s = Scene.fromJson(_s({'unitIds': ['u1', 'u2']}));
      expect([s.id, s.titleId, s.textId, s.unitIds], ['scene_a', 't', 'x', ['u1', 'u2']]);
    });

    test('形の誤り', () {
      expect(() => Scene.fromJson(_s({'zzz': 1})), _bad('未知のキー'));
      expect(() => Scene.fromJson(_s({'id': 'a-b'})), _bad('id'));
      expect(() => Scene.fromJson(_s({'id': ''})), _bad('id'));
      expect(() => Scene.fromJson(_s({'titleId': ''})), _bad('titleId'));
      expect(() => Scene.fromJson(_s({'textId': 1})), _bad('textId'));
      expect(() => Scene.fromJson(_s({'unitIds': []})), _bad('unitIds'));
      expect(() => Scene.fromJson(_s({'unitIds': [1]})), _bad('unitIds'));
      expect(() => Scene.fromJson(_s({'unitIds': ['u1', 'u1']})), _bad('unitIds'));
      expect(() => Scene.fromJson(_s({'unitIds': ['']})), _bad('unitIds'));
      expect(() => Scene.fromJson(_s({'unitIds': [for (var i = 0; i < 21; i++) 'u$i']})), _bad('unitIds'));
      Scene.fromJson(_s({'unitIds': [for (var i = 0; i < 20; i++) 'u$i']}));
      for (final k in ['id', 'titleId', 'textId', 'unitIds']) {
        expect(() => Scene.fromJson({..._s()}..remove(k)), _bad(), reason: '$k なし');
      }
    });
  });

  group('SceneSet', () {
    String set(List<Map<String, dynamic>> xs, {int version = 1}) => jsonEncode({'version': version, 'scenes': xs});

    test('読み取り・ID の一覧', () {
      final s = SceneSet.parse(set([_s(), _s({'id': 'scene_b'})]));
      expect(s.scenes.length, 2);
      expect(s.ids, {'scene_a', 'scene_b'});
    });

    test('誤り: JSON・版・重複', () {
      expect(() => SceneSet.parse('{'), _bad('読めません'));
      expect(() => SceneSet.parse('[]'), _bad('オブジェクト'));
      expect(() => SceneSet.parse(set([], version: 2)), _bad('版'));
      expect(() => SceneSet.parse('{"version":1}'), _bad('scenes'));
      expect(() => SceneSet.parse(set([_s(), _s()])), _bad('重複'));
    });

    test('検証: 単元がなければ scene_unit_missing', () {
      final ok = SceneSet.parse(set([_s({'unitIds': ['u1', 'u2']})]));
      expect(validateScenes(ok, tree: _tree()), isEmpty);
      final bad = SceneSet.parse(set([_s({'unitIds': ['u1', 'zz']})]));
      final issues = validateScenes(bad, tree: _tree());
      expect([for (final i in issues) '${i.code}:${i.subjectId}:${i.severity.name}'], ['scene_unit_missing:scene_a:error']);
    });
  });
}
