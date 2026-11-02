import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _manifest([Map<String, dynamic> over = const {}]) => {
      'version': 1,
      'id': 'p_jp_social',
      'country': 'JP',
      'locale': 'ja',
      'subject': 'social',
      'grades': [1],
      'curriculum': '学習指導要領',
      'contentVersion': '0.1.0',
      'files': {'units': 'units.json', 'questions': 'questions.json'},
      ...over,
    };

String _units({String subject = 'social', int grade = 1}) => jsonEncode({
      'version': 1,
      'units': [
        {'id': 'root', 'subject': subject, 'grade': grade, 'title': 'R', 'order': 1},
        {'id': 'leaf', 'subject': subject, 'grade': grade, 'parentId': 'root', 'title': 'L', 'order': 1, 'estimatedQuestions': 5},
      ],
    });

String _questions() => jsonEncode({
      'version': 1,
      'questions': [
        {
          'id': 'q1', 'unitId': 'leaf', 'type': 'choice', 'difficulty': 0.5, 'choices': ['a', 'b'], 'answer': 'a',
          'explanationId': 'e', 'version': 1, 'misconceptionTags': {'b': 'tag_b'},
        },
      ],
    });

Map<String, String> _files() => {'units.json': _units(), 'questions.json': _questions()};

ContentPackReport _run(Map<String, dynamic> manifest, [Map<String, String>? files]) {
  final f = files ?? _files();
  return validateContentPack(jsonEncode(manifest), (p) => f[p]);
}

List<String> _codes(ContentPackReport r) => [for (final i in r.issues) '${i.code}:${i.severity.name}'];

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

void main() {
  group('目録 manifest', () {
    test('読み取り', () {
      final m = ContentPackManifest.parse(jsonEncode(_manifest({'attribution': ['出典 A'], 'grades': [1, 2]})));
      expect([m.id, m.country, m.locale, m.subject, m.curriculum, m.contentVersion], ['p_jp_social', 'JP', 'ja', 'social', '学習指導要領', '0.1.0']);
      expect(m.grades, [1, 2]);
      expect(m.attribution, ['出典 A']);
      expect(m.paths, ['units.json', 'questions.json']);
      expect(ContentPackManifest.parse(jsonEncode(_manifest({'locale': 'pt-BR', 'country': 'BR'}))).locale, 'pt-BR');
    });

    test('textsCover: 既定はすべて。指定すれば絞る', () {
      expect(ContentPackManifest.parse(jsonEncode(_manifest())).textsCover, ContentPackManifest.textKinds);
      expect(ContentPackManifest.textKinds, {'scenes', 'lessons', 'templates', 'figures', 'questions', 'proofs', 'characters'});
      final m = ContentPackManifest.parse(jsonEncode(_manifest({'textsCover': ['lessons', 'scenes']})));
      expect(m.textsCover, {'lessons', 'scenes'});
    });

    test('maps は並び。paths に 1 つずつ入る', () {
      final m = ContentPackManifest.parse(jsonEncode(_manifest({'files': {'units': 'u.json', 'maps': ['a.json', 'b.json']}})));
      expect(m.paths, ['u.json', 'a.json', 'b.json']);
    });

    test('形の誤り', () {
      String s(Map<String, dynamic> over) => jsonEncode(_manifest(over));
      expect(() => ContentPackManifest.parse('{'), _bad('読めません'));
      expect(() => ContentPackManifest.parse('[]'), _bad('オブジェクト'));
      expect(() => ContentPackManifest.parse(s({'zzz': 1})), _bad('未知のキー'));
      expect(() => ContentPackManifest.parse(s({'version': 2})), _bad('版'));
      expect(() => ContentPackManifest.parse(s({'id': 'Bad-Id'})), _bad('id'));
      expect(() => ContentPackManifest.parse(s({'id': '1abc'})), _bad('id'));
      expect(() => ContentPackManifest.parse(s({'country': 'jp'})), _bad('country'));
      expect(() => ContentPackManifest.parse(s({'country': 'JPN'})), _bad('country'));
      expect(() => ContentPackManifest.parse(s({'locale': 'JA'})), _bad('locale'));
      expect(() => ContentPackManifest.parse(s({'locale': 'ja-jp'})), _bad('locale'));
      expect(() => ContentPackManifest.parse(s({'subject': 'Social'})), _bad('subject'));
      expect(() => ContentPackManifest.parse(s({'contentVersion': '1.0'})), _bad('contentVersion'));
      expect(() => ContentPackManifest.parse(s({'contentVersion': 'v1.0.0'})), _bad('contentVersion'));
      expect(() => ContentPackManifest.parse(s({'curriculum': ' '})), _bad('curriculum'));
      expect(() => ContentPackManifest.parse(s({'grades': []})), _bad('grades'));
      expect(() => ContentPackManifest.parse(s({'grades': [0]})), _bad('grades'));
      expect(() => ContentPackManifest.parse(s({'grades': [13]})), _bad('grades'));
      expect(() => ContentPackManifest.parse(s({'grades': [1, 1]})), _bad('grades'));
      expect(() => ContentPackManifest.parse(s({'attribution': [1]})), _bad('attribution'));
      expect(() => ContentPackManifest.parse(s({'attribution': ['']})), _bad('attribution'));
      expect(() => ContentPackManifest.parse(s({'textsCover': []})), _bad('textsCover'));
      expect(() => ContentPackManifest.parse(s({'textsCover': ['zzz']})), _bad('textsCover'));
      expect(() => ContentPackManifest.parse(s({'textsCover': ['lessons', 'lessons']})), _bad('textsCover'));
      expect(() => ContentPackManifest.parse(s({'textsCover': 'lessons'})), _bad('textsCover'));
      expect(() => ContentPackManifest.parse(s({'textsCover': [1]})), _bad('textsCover'));
      expect(() => ContentPackManifest.parse(s({'files': 1})), _bad('files'));
      expect(() => ContentPackManifest.parse(s({'files': {'questions': 'q.json'}})), _bad('files.units'));
      expect(() => ContentPackManifest.parse(s({'files': {'units': 'u.json', 'zzz': 'x'}})), _bad('未知のキー'));
      expect(() => ContentPackManifest.parse(s({'files': {'units': ''}})), _bad('files.units'));
      expect(() => ContentPackManifest.parse(s({'files': {'units': 'u.json', 'maps': []}})), _bad('maps'));
      expect(() => ContentPackManifest.parse(s({'files': {'units': 'u.json', 'maps': 'a.json'}})), _bad('maps'));
      expect(() => ContentPackManifest.parse(jsonEncode({..._manifest()}..remove('files'))), _bad('files'));
      for (final k in ['id', 'country', 'locale', 'subject', 'curriculum', 'grades', 'contentVersion']) {
        expect(() => ContentPackManifest.parse(jsonEncode({..._manifest()}..remove(k))), _bad(), reason: '$k なし');
      }
    });
  });

  group('パックの検証', () {
    test('問題のないパックは指摘なしで、件数が出る', () {
      final r = _run(_manifest());
      expect(r.issues, isEmpty);
      expect(r.hasErrors, isFalse);
      expect(r.counts, {'units': 2, 'questions': 1});
      expect(r.manifest!.id, 'p_jp_social');
    });

    test('目録が読めなければ pack_manifest_invalid', () {
      final r = validateContentPack('{', (p) => null);
      expect(_codes(r), ['pack_manifest_invalid:error']);
      expect(r.manifest, isNull);
      expect(r.hasErrors, isTrue);
    });

    test('ファイルがない・パスが不正・JSON が壊れている', () {
      expect(_codes(_run(_manifest(), {'units.json': _units()})), ['pack_file_missing:error']);
      expect(_codes(_run(_manifest({'files': {'units': '../units.json'}}), _files())), ['pack_file_path_invalid:error']);
      expect(_codes(_run(_manifest({'files': {'units': '/etc/units.json'}}), _files())), ['pack_file_path_invalid:error']);
      expect(_codes(_run(_manifest({'files': {'units': 'a\\b.json'}}), _files())), ['pack_file_path_invalid:error']);
      expect(_codes(_run(_manifest(), {'units.json': '{', 'questions.json': _questions()})), contains('pack_file_malformed:error'));
      expect(_codes(_run(_manifest(), {'units.json': '[]', 'questions.json': _questions()})), contains('pack_file_malformed:error'));
      // `..` を含まない（ファイル名の途中の . は可）
      expect(_codes(_run(_manifest({'files': {'units': 'a..b.json', 'questions': 'questions.json'}}), {'a..b.json': _units(), 'questions.json': _questions()})), isEmpty);
    });

    test('単元の教科が目録と違う（エラー）・学年が grades にない（警告）', () {
      final r = _run(_manifest(), {'units.json': _units(subject: 'math'), 'questions.json': _questions()});
      expect(_codes(r).where((c) => c == 'pack_unit_subject_mismatch:error').length, 2);
      final g = _run(_manifest(), {'units.json': _units(grade: 2), 'questions.json': _questions()});
      expect(_codes(g), ['pack_unit_grade_outside:warning', 'pack_unit_grade_outside:warning']);
      expect(g.hasErrors, isFalse);
    });

    test('問題集の問題は、メッセージにファイル名が付いて報告される', () {
      final bad = jsonEncode({
        'version': 1,
        'questions': [
          {'id': 'q1', 'unitId': 'nope', 'type': 'choice', 'difficulty': 0.5, 'choices': ['a', 'b'], 'answer': 'a', 'explanationId': 'e', 'version': 1},
        ],
      });
      final r = _run(_manifest(), {'units.json': _units(), 'questions.json': bad});
      expect(r.hasErrors, isTrue);
      expect(r.issues.every((i) => i.message.startsWith('[questions.json] ')), isTrue);
    });

    test('前提: 末端の単元に定義がなければ警告、壊れていればエラー', () {
      final files = {..._files(), 'p.json': jsonEncode({'version': 1, 'prerequisites': []})};
      final r = _run(_manifest({'files': {'units': 'units.json', 'prerequisites': 'p.json'}}), files);
      expect(_codes(r), ['pack_prereq_uncovered:warning']);
      final ok = {..._files(), 'p.json': jsonEncode({'version': 1, 'prerequisites': [{'unitId': 'leaf', 'external': [{'id': 'x', 'title': 'T', 'link': 'https://e.com'}]}]})};
      final good = _run(_manifest({'files': {'units': 'units.json', 'prerequisites': 'p.json'}}), ok);
      expect(good.issues, isEmpty);
      expect(good.counts['prerequisites'], 1);
      final broken = {..._files(), 'p.json': jsonEncode({'version': 1, 'prerequisites': [1]})};
      expect(_codes(_run(_manifest({'files': {'units': 'units.json', 'prerequisites': 'p.json'}}), broken)), ['pack_file_malformed:error']);
    });

    test('前提: 存在しない単元を前提にしていればエラー（個別の検証の結果も報告される）', () {
      final f = {..._files(), 'p.json': jsonEncode({'version': 1, 'prerequisites': [{'unitId': 'leaf', 'requires': ['nope']}]})};
      final r = _run(_manifest({'files': {'units': 'units.json', 'prerequisites': 'p.json'}}), f);
      expect(_codes(r), contains('prereq_requires_missing:error'));
      expect(r.issues.first.message, startsWith('[p.json] '));
    });

    test('レッスン: 作図の参照はパックの作図で確かめる', () {
      final sample = jsonDecode(File('docs/samples/constructions.sample.json').readAsStringSync()) as Map<String, dynamic>;
      for (final c in sample['constructions'] as List) {
        (c as Map<String, dynamic>)['unitId'] = 'leaf';
      }
      final id = ((sample['constructions'] as List).first as Map)['id'] as String;
      String lesson(String cid) => jsonEncode({
            'version': 1,
            'lessons': [
              {
                'id': 'l1', 'version': 1, 'unitId': 'leaf', 'minutes': 4, 'titleId': 't',
                'blocks': [
                  {'type': 'hook', 'textId': 'h'},
                  {'type': 'explore', 'construction': cid},
                  {'type': 'check', 'questions': ['q1']},
                  {'type': 'summary', 'textIds': ['s']},
                ],
              },
            ],
          });
      final m = _manifest({'files': {'units': 'units.json', 'questions': 'questions.json', 'constructions': 'c.json', 'lessons': 'l.json'}});
      final base = {..._files(), 'c.json': jsonEncode(sample)};
      final ok = _run(m, {...base, 'l.json': lesson(id)});
      expect(ok.hasErrors, isFalse, reason: ok.issues.join('\n'));
      expect(ok.counts['constructions'], greaterThan(0));
      expect(_codes(_run(m, {...base, 'l.json': lesson('con_zz')})), contains('lesson_ref_missing:error'));
    });

    test('数学のレッスン: 例題の途中式がまちがっていればエラー（型から作った例題と照らす）', () {
      const dir = 'docs/content_drafts/suugaku_chu1';
      final lessons = jsonDecode(File('$dir/lessons.json').readAsStringSync()) as Map<String, dynamic>;
      bool broken = false;
      for (final l in lessons['lessons'] as List) {
        for (final b in (l as Map)['blocks'] as List) {
          if (!broken && (b as Map)['type'] == 'example' && b['template'] == 'm1_linear_002') {
            b['lines'] = ['{a}x{+b}={c}', '{a}x={c}{+b}', '{a}x={c-b}']; // 移項で符号を変えていない
            broken = true;
          }
        }
      }
      expect(broken, isTrue);
      final r = validateContentPack(File('$dir/manifest.json').readAsStringSync(), (p) {
        if (p == 'lessons.json') return jsonEncode(lessons);
        final f = File('$dir/$p');
        return f.existsSync() ? f.readAsStringSync() : null;
      });
      expect(_codes(r), contains('lesson_example_mismatch:error'));
    });

    test('場面: 型・レッスンの参照を scenes で確かめる。使われていない場面は警告、単元がなければエラー', () {
      Map<String, dynamic> tpl(String? scene) => {
            'id': 'tp1', 'templateVersion': 1, 'unitId': 'leaf', 'type': 'expr', 'difficulty': 0.5,
            'params': {'p': {'int': [1, 5]}},
            'scene': ?scene,
            'display': {'p': '{p}'}, 'answer': '{p+1}',
            'wrong': [{'expr': '{p+2}', 'tag': 't1'}],
            'explanationId': 'e',
          };
      String scenes(List<String> ids, {String unit = 'leaf'}) => jsonEncode({
            'version': 1,
            'scenes': [for (final i in ids) {'id': i, 'titleId': 't', 'textId': 'x', 'unitIds': [unit]}],
          });
      final m = _manifest({'files': {'units': 'units.json', 'scenes': 's.json', 'templates': 't.json'}});
      Map<String, String> files(String? scene, List<String> ids, {String unit = 'leaf'}) => {
            'units.json': _units(),
            's.json': scenes(ids, unit: unit),
            't.json': jsonEncode({'version': 1, 'templates': [tpl(scene)]}),
          };
      // 型が場面を使う: 問題なし
      final ok = _run(m, files('scene_a', ['scene_a']));
      expect(_codes(ok).where((c) => !c.startsWith('unit_empty') && !c.startsWith('template_answer_dup')), isEmpty, reason: ok.issues.join('\n'));
      expect(ok.counts['scenes'], 1);
      // 型が使う場面が scenes にない
      expect(_codes(_run(m, files('scene_zz', ['scene_a']))), containsAll(['pack_scene_missing:error', 'pack_scene_unused:warning']));
      // どこからも使われていない場面
      expect(_codes(_run(m, files(null, ['scene_a']))), contains('pack_scene_unused:warning'));
      // 場面の単元がない
      expect(_codes(_run(m, files('scene_a', ['scene_a'], unit: 'nope'))), contains('scene_unit_missing:error'));
      // scenes が読めない
      final broken = files('scene_a', ['scene_a'])..['s.json'] = '{';
      expect(_codes(_run(m, broken)), contains('pack_file_malformed:error'));
    });

    test('場面: レッスンの導入（hook.scene）から使われていれば未使用ではない。参照先がなければ lesson_ref_missing', () {
      String lesson(String scene) => jsonEncode({
            'version': 1,
            'lessons': [
              {
                'id': 'l1', 'version': 1, 'unitId': 'leaf', 'minutes': 4, 'titleId': 't',
                'blocks': [
                  {'type': 'hook', 'textId': 'h', 'scene': scene},
                  {'type': 'check', 'questions': ['q1']},
                  {'type': 'summary', 'textIds': ['s']},
                ],
              },
            ],
          });
      final scenes = jsonEncode({'version': 1, 'scenes': [{'id': 'scene_a', 'titleId': 't', 'textId': 'x', 'unitIds': ['leaf']}]});
      final m = _manifest({'files': {'units': 'units.json', 'questions': 'questions.json', 'scenes': 's.json', 'lessons': 'l.json'}});
      final ok = _run(m, {..._files(), 's.json': scenes, 'l.json': lesson('scene_a')});
      expect(ok.issues, isEmpty, reason: ok.issues.join('\n'));
      final missing = _run(m, {..._files(), 's.json': scenes, 'l.json': lesson('scene_zz')});
      expect(_codes(missing), containsAll(['lesson_ref_missing:error', 'pack_scene_unused:warning']));
    });

    group('文言 texts（教科書のような説明・問題文・解説）', () {
      // 場面 1・型 1（問題文と解説）・レッスン 1（導入・説明・要点）を持つ小さなパック
      Map<String, dynamic> manifest() => _manifest({
            'files': {'units': 'units.json', 'scenes': 's.json', 'templates': 't.json', 'lessons': 'l.json', 'texts': 'x.json'},
          });
      final scenes = jsonEncode({'version': 1, 'scenes': [{'id': 'sc', 'titleId': 'sc_title', 'textId': 'sc_text', 'unitIds': ['leaf']}]});
      final templates = jsonEncode({
        'version': 1,
        'templates': [
          {
            'id': 'tp', 'templateVersion': 1, 'unitId': 'leaf', 'type': 'expr', 'difficulty': 0.5,
            'params': {'p': {'int': [1, 5]}},
            'scene': 'sc',
            'display': {'point': '({p}, 0)'}, 'answer': '{p+1}',
            'wrong': [{'expr': '{p+2}', 'tag': 't1'}],
            'explanationId': 'exp_tp',
          },
        ],
      });
      final lessons = jsonEncode({
        'version': 1,
        'lessons': [
          {
            'id': 'l1', 'version': 1, 'unitId': 'leaf', 'minutes': 4, 'titleId': 'l1_title',
            'blocks': [
              {'type': 'hook', 'textId': 'l1_hook', 'scene': 'sc'},
              {'type': 'text', 'textId': 'l1_t1'},
              {'type': 'check', 'questions': ['tp~1']},
              {'type': 'summary', 'textIds': ['l1_s1']},
            ],
          },
        ],
      });
      Map<String, String> good() => {
            'sc_title': '場面',
            'sc_text': '身近な場面の説明。',
            'prompt_tp': '点 {point} から {p} 進む。',
            'exp_tp': '答えは {p+1}。',
            'l1_title': '題',
            'l1_hook': 'はじめに {p+1}',
            'l1_t1': '説明',
            'l1_s1': 'まとめ',
          };
      ContentPackReport run(Map<String, String> texts, {Object locale = 'ja'}) => _run(manifest(), {
            'units.json': _units(),
            's.json': scenes,
            't.json': templates,
            'l.json': lessons,
            'x.json': jsonEncode({'version': 1, 'locale': locale, 'texts': texts}),
          });
      List<String> codes(ContentPackReport r) => [for (final i in r.issues) if (i.code != 'unit_empty' && i.code != 'template_answer_dup') '${i.code}:${i.subjectId}:${i.severity.name}'];

      test('必要な文言がそろっていれば指摘なし。件数が出る', () {
        final r = run(good());
        expect(codes(r), isEmpty, reason: r.issues.join('\n'));
        expect(r.counts['texts'], 8);
      });

      test('足りない文言は pack_text_missing（場面・問題文・解説・レッスンの各ブロック）', () {
        for (final id in good().keys) {
          final t = {...good()}..remove(id);
          final c = codes(run(t));
          expect(c, contains('pack_text_missing:$id:error'), reason: id);
        }
      });

      test('使われていない文言は警告', () {
        final r = run({...good(), 'extra': '余り'});
        expect(codes(r), ['pack_text_unused:extra:warning']);
        expect(r.hasErrors, isFalse);
      });

      test('差し込めない名前は pack_text_placeholder_unknown。型の値の名前・式・display の名前はよい', () {
        expect(codes(run({...good(), 'exp_tp': '答えは {zz}。'})), ['pack_text_placeholder_unknown:exp_tp:error']);
        expect(codes(run({...good(), 'exp_tp': '答えは {p+q}。'})), ['pack_text_placeholder_unknown:exp_tp:error']);
        expect(codes(run({...good(), 'sc_text': '値は {p}。'})), ['pack_text_placeholder_unknown:sc_text:error']); // 場面には差し込みなし
        expect(codes(run({...good(), 'exp_tp': '{point} と {p} と {p*2} と {+p} と {\$p}'})), isEmpty);
        expect(codes(run({...good(), 'exp_tp': '空 {}'})), ['pack_text_placeholder_unknown:exp_tp:error']);
      });

      test('波かっこが合わない文言・長すぎる文言・言語が目録と違う文言', () {
        final unbalanced = run({...good(), 'l1_t1': '{p'});
        expect(unbalanced.issues.map((i) => i.code), contains('text_unbalanced_braces'));
        expect(unbalanced.issues.where((i) => i.code == 'pack_text_placeholder_unknown'), isEmpty);
        expect(run({...good(), 'l1_t1': 'あ' * 301}).issues.map((i) => i.code), contains('text_too_long'));
        expect(codes(run(good(), locale: 'en')), contains('pack_texts_locale_mismatch:x.json:error'));
      });

      test('textsCover: 範囲を絞ると、範囲の外の文言はなくてもよい（あれば差し込みの名前は確かめる）', () {
        // good() から、レッスン以外（場面・問題文・解説）を消す
        final onlyLessons = {for (final e in good().entries) if (e.key.startsWith('l1_')) e.key: e.value};
        ContentPackReport go(List<String>? cover, Map<String, String> texts) => _run(
              _manifest({
                'files': {'units': 'units.json', 'scenes': 's.json', 'templates': 't.json', 'lessons': 'l.json', 'texts': 'x.json'},
                'textsCover': ?cover,
              }),
              {
                'units.json': _units(),
                's.json': scenes,
                't.json': templates,
                'l.json': lessons,
                'x.json': jsonEncode({'version': 1, 'locale': 'ja', 'texts': texts}),
              },
            );
        List<String> miss(ContentPackReport r) => [for (final i in r.issues) if (i.code == 'pack_text_missing') i.subjectId]..sort();
        // 既定（すべて）: 場面・問題文・解説が足りない
        expect(miss(go(null, onlyLessons)), ['exp_tp', 'prompt_tp', 'sc_text', 'sc_title']);
        // レッスンだけ: 足りなくてよい。レッスンの文言が足りなければエラー
        expect(miss(go(['lessons'], onlyLessons)), isEmpty);
        expect(miss(go(['lessons'], {...onlyLessons}..remove('l1_t1'))), ['l1_t1']);
        // 場面だけ・型だけ
        expect(miss(go(['scenes'], onlyLessons)), ['sc_text', 'sc_title']);
        expect(miss(go(['templates'], onlyLessons)), ['exp_tp', 'prompt_tp']);
        // 範囲の外にある文言も、使われていれば未使用ではなく、差し込みの名前は確かめる
        final r = go(['lessons'], {...onlyLessons, 'exp_tp': '答えは {zz}。'});
        List<String> tx(ContentPackReport r) => [for (final i in r.issues) if (i.code.startsWith('pack_text')) i.code];
        expect(tx(r), ['pack_text_placeholder_unknown']);
        // 範囲の外で、どこにも使われない文言は未使用の警告
        expect(tx(go(['lessons'], {...onlyLessons, 'zzz': '余り'})), ['pack_text_unused']);
      });

      test('波かっこが合わない文言は、差し込みの検査をしない（別のエラーで報告済み）', () {
        final r = run({...good(), 'exp_tp': '{zz}}'});
        expect(r.issues.map((i) => i.code), contains('text_unbalanced_braces'));
        expect(r.issues.map((i) => i.code), isNot(contains('pack_text_placeholder_unknown')));
      });

      test('問題集の問題の解説（explanationId）も文言が要る', () {
        final m = _manifest({'files': {'units': 'units.json', 'questions': 'questions.json', 'texts': 'x.json'}});
        String texts(Map<String, String> t) => jsonEncode({'version': 1, 'locale': 'ja', 'texts': t});
        final ok = _run(m, {..._files(), 'x.json': texts({'e': '解説'})});
        expect(ok.issues, isEmpty, reason: ok.issues.join('\n'));
        final missing = _run(m, {..._files(), 'x.json': texts({'other': '別'})});
        // textsCover に questions がなければ、問題集の解説は要らない
        final noQ = _run(_manifest({'files': {'units': 'units.json', 'questions': 'questions.json', 'texts': 'x.json'}, 'textsCover': ['lessons']}),
            {..._files(), 'x.json': texts({'e': '解説'})});
        expect(noQ.issues, isEmpty, reason: noQ.issues.join('\n'));
        final onlyQ = _run(_manifest({'files': {'units': 'units.json', 'questions': 'questions.json', 'texts': 'x.json'}, 'textsCover': ['questions']}),
            {..._files(), 'x.json': texts({'other': '別'})});
        expect([for (final i in onlyQ.issues) i.code], contains('pack_text_missing'));
        expect(
          [for (final i in missing.issues) '${i.code}:${i.subjectId}:${i.severity.name}'],
          containsAll(['pack_text_missing:e:error', 'pack_text_unused:other:warning']),
        );
      });

      test('数列の差し込み {L}・{~L} と、集計の名前。図が選択肢の問題の選択肢の図の説明（altId）も文言が要る', () {
        Map<String, dynamic> fig(String alt) => {
              'viewBox': [0, 0, 100, 100],
              'points': {'A': [10, 10], 'B': [90, 90]},
              'draw': [{'seg': ['A', 'B']}],
              'altId': alt,
            };
        final data = {
          'id': 'dt', 'templateVersion': 1, 'unitId': 'leaf', 'type': 'expr', 'difficulty': 0.5,
          'params': {'L': {'list': {'n': [5, 9], 'int': [1, 20]}}},
          'stats': {'m': 'mean(L)'},
          'display': {'data': '{L}'}, 'answer': '{m}',
          'wrong': [{'expr': '{m+1}', 'tag': 't1'}],
          'explanationId': 'exp_dt',
        };
        final choice = {
          'id': 'ch', 'templateVersion': 1, 'unitId': 'leaf', 'type': 'choice', 'difficulty': 0.5,
          'params': {'k': {'oneOf': [1, 2]}},
          'display': {'k': '{k}'},
          'answer': '{k}',
          'choices': ['1', '2'],
          'figures': {
            '1': fig('alt_one'),
            '2': {'pick': {'index': 'k-1', 'of': [fig('alt_pick_a'), fig('alt_pick_b')]}},
          },
          'wrong': [{'expr': '{3-k}', 'tag': 't2'}],
          'explanationId': 'exp_ch',
        };
        final plainFig = {
          'id': 'fg', 'templateVersion': 1, 'unitId': 'leaf', 'type': 'expr', 'difficulty': 0.5,
          'params': {'p': {'int': [1, 5]}},
          'figure': fig('alt_main'),
          'display': {'p': '{p}'}, 'answer': '{p}',
          'wrong': [{'expr': '{p+1}', 'tag': 't3'}],
          'explanationId': 'exp_fg',
        };
        final m = _manifest({'files': {'units': 'units.json', 'templates': 't.json', 'texts': 'x.json'}});
        Map<String, String> texts() => {
              'prompt_fg': '{p}',
              'exp_fg': '{p}',
              'alt_main': '図',
              'prompt_dt': '次のデータ {L}（小さい順 {~L}）の平均は。',
              'exp_dt': '平均は {m}。',
              'prompt_ch': '{k} 番を選ぶ。',
              'exp_ch': '正解は {k}。',
              'alt_one': '図 1',
              'alt_pick_a': '図 a',
              'alt_pick_b': '図 b',
            };
        ContentPackReport go(Map<String, String> t) => _run(m, {
              'units.json': _units(),
              't.json': jsonEncode({'version': 1, 'templates': [data, choice, plainFig]}),
              'x.json': jsonEncode({'version': 1, 'locale': 'ja', 'texts': t}),
            });
        List<String> only(ContentPackReport r) => [for (final i in r.issues) if (i.code.startsWith('pack_text')) '${i.code}:${i.subjectId}'];
        expect(only(go(texts())), isEmpty, reason: go(texts()).issues.join('\n'));
        for (final id in ['alt_one', 'alt_pick_a', 'alt_pick_b', 'alt_main']) {
          expect(only(go({...texts()}..remove(id))), ['pack_text_missing:$id'], reason: id);
        }
        // 図の説明（altId）は textsCover の figures。templates だけでは要らず、figures だけなら図の説明だけが要る
        ContentPackReport cover(List<String> k, Map<String, String> t) => _run(
              _manifest({'files': {'units': 'units.json', 'templates': 't.json', 'texts': 'x.json'}, 'textsCover': k}),
              {
                'units.json': _units(),
                't.json': jsonEncode({'version': 1, 'templates': [data, choice, plainFig]}),
                'x.json': jsonEncode({'version': 1, 'locale': 'ja', 'texts': t}),
              },
            );
        final noAlt = {...texts()}..removeWhere((k, _) => k.startsWith('alt_'));
        expect(only(cover(['templates'], noAlt)).where((e) => e.startsWith('pack_text_missing')), isEmpty);
        expect(only(cover(['figures'], noAlt)), ['pack_text_missing:alt_one', 'pack_text_missing:alt_pick_a', 'pack_text_missing:alt_pick_b', 'pack_text_missing:alt_main']);
        expect(only(cover(['figures'], {for (final e in texts().entries) if (e.key.startsWith('alt_')) e.key: e.value})), isEmpty);
        // 数列の名前（{L}・{~L}）は数列のある型だけ
        expect(only(go({...texts(), 'prompt_ch': '{L}'})), ['pack_text_placeholder_unknown:prompt_ch']);
        expect(only(go({...texts(), 'prompt_ch': '{~L}'})), ['pack_text_placeholder_unknown:prompt_ch']);
      });

      test('texts がないパックは文言を確かめない。texts が読めなければ pack_file_malformed', () {
        final plain = _manifest({'files': {'units': 'units.json', 's': null}..remove('s')});
        expect(_run(plain).issues, isEmpty);
        final broken = _run(manifest(), {'units.json': _units(), 's.json': scenes, 't.json': templates, 'l.json': lessons, 'x.json': '{'});
        expect(_codes(broken), contains('pack_file_malformed:error'));
      });
    });

    test('グラフ: 読めればよい・形が違えばエラー', () {
      final chart = {'kind': 'bars', 'altId': 'a', 'categories': ['a', 'b'], 'series': [{'id': 's', 'values': [1, 2]}]};
      Map<String, dynamic> m() => _manifest({'files': {'units': 'units.json', 'charts': 'c.json'}});
      final ok = _run(m(), {'units.json': _units(), 'c.json': jsonEncode({'version': 1, 'charts': {'c1': chart}})});
      expect(ok.issues, isEmpty);
      expect(ok.counts['charts'], 1);
      final badChart = _run(m(), {'units.json': _units(), 'c.json': jsonEncode({'version': 1, 'charts': {'c1': {...chart, 'kind': 'x'}}})});
      expect(_codes(badChart), ['pack_file_malformed:error']);
      expect(badChart.issues.single.subjectId, 'c1');
      expect(_codes(_run(m(), {'units.json': _units(), 'c.json': jsonEncode({'version': 2, 'charts': {}})})), ['pack_file_malformed:error']);
      expect(_codes(_run(m(), {'units.json': _units(), 'c.json': jsonEncode({'version': 1})})), ['pack_file_malformed:error']);
      expect(_codes(_run(m(), {'units.json': _units(), 'c.json': jsonEncode({'version': 1, 'charts': {'c1': 5}})})), ['pack_file_malformed:error']);
    });

    test('地図: 出典がなければエラー。領域数が数えられる', () {
      final pack = jsonEncode({
        'version': 1, 'id': 'm', 'attribution': '', 'scale': 1, 'bounds': [0, 0, 10, 10],
        'regions': [{'id': 'a', 'label': 'A', 'rings': [[0, 0, 5, 0, 0, 5]]}],
      });
      final m = _manifest({'files': {'units': 'units.json', 'maps': ['m.json']}});
      final r = _run(m, {'units.json': _units(), 'm.json': pack});
      expect(_codes(r), ['map_attribution_missing:error']);
      expect(r.counts['maps'], 1);
      expect(r.counts['mapRegions'], 1);
      expect(_codes(_run(m, {'units.json': _units(), 'm.json': '{'})), ['pack_file_malformed:error']);
    });

    test('体験: 単元がなければエラー。体験の ID が体験型と重複するとエラー', () {
      Map<String, dynamic> dial(String id, String unit) => {
            'id': id, 'version': 1, 'unitId': unit, 'kind': 'dial', 'promptId': 'p', 'explanationId': 'x',
            'min': 0, 'max': 2, 'step': 1, 'initial': 0, 'target': 2,
          };
      final m = _manifest({'files': {'units': 'units.json', 'experiences': 'e.json'}});
      final ok = _run(m, {'units.json': _units(), 'e.json': jsonEncode({'version': 1, 'experiences': [dial('d1', 'leaf')]})});
      expect(ok.issues, isEmpty);
      expect(ok.counts['experiences'], 1);
      expect(_codes(_run(m, {'units.json': _units(), 'e.json': jsonEncode({'version': 1, 'experiences': [dial('d1', 'zz')]})})), ['experience_unit_missing:error']);
      expect(_codes(_run(m, {'units.json': _units(), 'e.json': 'x'})), ['pack_file_malformed:error']);

      // explorations（数学の体験型）と ID が重なる
      final exploration = {
        'id': 'd1', 'version': 1, 'unitId': 'leaf', 'kind': 'slider_graph', 'promptId': 'p', 'expr': 'a*x',
        'params': [{'name': 'a', 'min': 1, 'max': 3, 'step': 1, 'initial': 1}], 'goal': {'expr': '3x'}, 'explanationId': 'x',
      };
      final both = _manifest({'files': {'units': 'units.json', 'explorations': 'x.json', 'experiences': 'e.json'}});
      final r = _run(both, {
        'units.json': _units(),
        'x.json': jsonEncode({'version': 1, 'explorations': [exploration]}),
        'e.json': jsonEncode({'version': 1, 'experiences': [dial('d1', 'leaf')]}),
      });
      expect(_codes(r), ['pack_experience_id_clash:error']);
      expect(r.counts['explorations'], 1);
    });

    test('レッスン: 参照する問題・体験・誤解の型がパックの中にあれば OK、なければエラー', () {
      Map<String, dynamic> lesson(List<Map<String, dynamic>> blocks) => {
            'version': 1,
            'lessons': [
              {'id': 'l1', 'version': 1, 'unitId': 'leaf', 'minutes': 4, 'titleId': 't', 'blocks': blocks},
            ],
          };
      final m = _manifest({'files': {'units': 'units.json', 'questions': 'questions.json', 'lessons': 'l.json'}});
      final good = lesson([
        {'type': 'hook', 'textId': 'h'},
        {'type': 'check', 'questions': ['q1']},
        {'type': 'pitfall', 'tag': 'tag_b', 'textId': 'p'},
        {'type': 'summary', 'textIds': ['s']},
      ]);
      final r = _run(m, {..._files(), 'l.json': jsonEncode(good)});
      expect(r.hasErrors, isFalse, reason: r.issues.join('\n'));
      expect(r.counts['lessons'], 1);
      final bad = lesson([
        {'type': 'hook', 'textId': 'h'},
        {'type': 'check', 'questions': ['q_missing']},
        {'type': 'pitfall', 'tag': 'no_such_tag', 'textId': 'p'},
        {'type': 'summary', 'textIds': ['s']},
      ]);
      final b = _run(m, {..._files(), 'l.json': jsonEncode(bad)});
      expect(b.hasErrors, isTrue);
      expect(_codes(b).where((c) => c.startsWith('lesson_')).length >= 2, isTrue, reason: b.issues.join('\n'));
      expect(b.issues.every((i) => i.message.startsWith('[l.json] ')), isTrue);
      expect(_codes(_run(m, {..._files(), 'l.json': '{"version":1,"lessons":[1]}'})), contains('pack_file_malformed:error'));
    });
  });

  group('同梱の草案', () {
    for (final d in ['shakai_chu1', 'eigo_jp_chu1', 'suugaku_chu1']) {
      test('$d: エラーなし。目録の件数が中身と合う', () {
        final dir = 'docs/content_drafts/$d';
        final r = validateContentPack(File('$dir/manifest.json').readAsStringSync(), (p) {
          final f = File('$dir/$p');
          return f.existsSync() ? f.readAsStringSync() : null;
        });
        expect(r.hasErrors, isFalse, reason: r.issues.join('\n'));
        expect(r.manifest!.country, 'JP');
        expect(r.counts['units'], greaterThan(0));
        // 警告は数学の型の見かけの種類（答えの取りうる値が少ない型）と、まだ型のない単元だけ
        for (final i in r.issues) {
          expect(['template_answer_dup', 'unit_empty'], contains(i.code), reason: '$d: $i');
        }
      });
    }

    test('数学の天秤の体験: どれもつりあう載せ方があり、レッスンが参照している（体験を消すと参照エラー）', () {
      const dir = 'docs/content_drafts/suugaku_chu1';
      final set = ExperienceSet.parse(File('$dir/experiences.json').readAsStringSync());
      expect(set.experiences.length, 3);
      for (final e in set.experiences) {
        e as BalanceExperience;
        expect(e.solutions(limit: 1), isNotEmpty, reason: e.id);
      }
      List<String> run(String experiences) => [
            for (final i in validateContentPack(File('$dir/manifest.json').readAsStringSync(), (p) {
              if (p == 'experiences.json') return experiences;
              final f = File('$dir/$p');
              return f.existsSync() ? f.readAsStringSync() : null;
            }).issues)
              i.code,
          ];
      expect(run(File('$dir/experiences.json').readAsStringSync()), isNot(contains('lesson_ref_missing')));
      expect(run('{"version":1,"experiences":[]}'), contains('lesson_ref_missing'));
    });

    test('社会・英語・数学の目録: 件数', () {
      int count(String d, String key) {
        final dir = 'docs/content_drafts/$d';
        return validateContentPack(File('$dir/manifest.json').readAsStringSync(), (p) => File('$dir/$p').readAsStringSync()).counts[key]!;
      }

      expect(count('shakai_chu1', 'questions'), 18);
      expect(count('shakai_chu1', 'charts'), 4);
      expect(count('eigo_jp_chu1', 'questions'), 16);
      expect(count('suugaku_chu1', 'templates'), 91);
      expect(count('suugaku_chu1', 'lessons'), 4);
    });
  });
}
