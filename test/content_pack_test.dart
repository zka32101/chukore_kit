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

    test('社会・英語・数学の目録: 件数', () {
      int count(String d, String key) {
        final dir = 'docs/content_drafts/$d';
        return validateContentPack(File('$dir/manifest.json').readAsStringSync(), (p) => File('$dir/$p').readAsStringSync()).counts[key]!;
      }

      expect(count('shakai_chu1', 'questions'), 18);
      expect(count('shakai_chu1', 'charts'), 4);
      expect(count('eigo_jp_chu1', 'questions'), 16);
      expect(count('suugaku_chu1', 'templates'), 73);
      expect(count('suugaku_chu1', 'lessons'), 4);
    });
  });
}
