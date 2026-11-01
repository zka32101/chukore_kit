import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

String _j({Object version = 1, Object? locale = 'ja', Object? texts}) =>
    jsonEncode({'version': version, 'locale': locale, 'texts': texts ?? {'a_1': '本文'}});

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

void main() {
  group('ContentTexts.parse', () {
    test('読み取り', () {
      final t = ContentTexts.parse(_j(texts: {'id_1': 'こんにちは {a}', 'ID2': '二つ目'}));
      expect(t.locale, 'ja');
      expect(t.texts, {'id_1': 'こんにちは {a}', 'ID2': '二つ目'});
      expect(ContentTexts.parse(_j(locale: 'pt-BR')).locale, 'pt-BR');
      expect(ContentTexts.parse(_j(texts: <String, String>{})).texts, isEmpty);
    });

    test('形の誤り', () {
      expect(() => ContentTexts.parse('{'), _bad('読めません'));
      expect(() => ContentTexts.parse('[]'), _bad('だけ'));
      expect(() => ContentTexts.parse('{"version":1,"locale":"ja","texts":{},"x":1}'), _bad('だけ'));
      expect(() => ContentTexts.parse(_j(version: 2)), _bad('版'));
      expect(() => ContentTexts.parse(_j(locale: 'JA')), _bad('locale'));
      expect(() => ContentTexts.parse(_j(locale: 'ja-jp')), _bad('locale'));
      expect(() => ContentTexts.parse(_j(locale: 5)), _bad('locale'));
      expect(() => ContentTexts.parse(_j(texts: [])), _bad('texts'));
      expect(() => ContentTexts.parse(_j(texts: {'a-b': 'x'})), _bad('ID'));
      expect(() => ContentTexts.parse(_j(texts: {'': 'x'})), _bad('ID'));
      expect(() => ContentTexts.parse(_j(texts: {'a': ''})), _bad('本文'));
      expect(() => ContentTexts.parse(_j(texts: {'a': '  \n'})), _bad('本文'));
      expect(() => ContentTexts.parse(_j(texts: {'a': 5})), _bad('本文'));
    });
  });

  group('差し込み {…}', () {
    test('placeholders: 中身の一覧', () {
      expect(ContentTexts.placeholders('{a}x{+b}={c-b}'), ['a', '+b', 'c-b']);
      expect(ContentTexts.placeholders('なし'), isEmpty);
      expect(ContentTexts.placeholders('{}'), ['']);
    });

    test('balanced: 対応・入れ子なし', () {
      for (final ok in ['', 'a', '{a}', '{a}{b}', 'x{a}y']) {
        expect(ContentTexts.balanced(ok), isTrue, reason: ok);
      }
      for (final ng in ['{', '}', '{a', 'a}', '}{', '{{a}}', '{a{b}}', '{a}}']) {
        expect(ContentTexts.balanced(ng), isFalse, reason: ng);
      }
    });
  });

  group('validateContentTexts', () {
    test('問題なし', () {
      expect(validateContentTexts(ContentTexts.parse(_j(texts: {'a': '短い {x}'}))), isEmpty);
    });

    test('エラー: 波かっこが合わない。警告: 長すぎる（300 文字まではよい）', () {
      final t = ContentTexts(locale: 'ja', texts: {
        'ok300': 'あ' * 300,
        'long301': 'あ' * 301,
        'bad': '{a',
      });
      final codes = [for (final i in validateContentTexts(t)) '${i.code}:${i.subjectId}:${i.severity.name}'];
      expect(codes, ['text_too_long:long301:warning', 'text_unbalanced_braces:bad:error']);
    });

    test('文字数は文字（コードポイント）で数える。絵文字・結合文字でも 1 文字ずつ', () {
      final t = ContentTexts(locale: 'ja', texts: {'e': '😀' * 300});
      expect(validateContentTexts(t), isEmpty);
    });
  });

  group('Lesson.textIds', () {
    test('題名と、各ブロックの文言の ID（出てくる順・重複なし）', () {
      final l = Lesson(
        id: 'l',
        version: 1,
        unitId: 'u',
        minutes: 4,
        titleId: 'title',
        blocks: const [
          HookBlock('hook', scene: 's'),
          TextBlock('t1'),
          FigureBlock(altId: 'alt1', template: 'tp', seed: 1),
          FormulaBlock('x+1', textId: 'f1'),
          FormulaBlock('x+2'),
          ExampleBlock(template: 'tp', seed: 1, lines: ['a', 'b'], textIds: ['e1', 'e2']),
          ExploreBlock(exploration: 'ex'),
          CheckBlock(['q']),
          PitfallBlock('tag', 'p1'),
          SummaryBlock(['s1', 't1']),
        ],
      );
      expect(l.textIds, ['title', 'hook', 't1', 'alt1', 'f1', 'e1', 'e2', 'p1', 's1']);
    });
  });
}
