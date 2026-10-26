import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sample() =>
    jsonDecode(File('docs/curriculum_packs/example_BR.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('サンプルは読めて、整合の問題がない', () {
    final p = CurriculumPack.fromJson(sample());
    expect(p.region, 'BR');
    expect(p.validate(), isEmpty);
    expect(p.unitsFor('EF06MA02').map((u) => u.id), ['math_6_b']);
    expect(p.unitsFor('EF99MA99'), isEmpty);
  });

  test('validate が問題を見つける', () {
    final j = sample();
    (j['mapping'] as Map)['ghost'] = ['EF06MA01']; // 木に無い単元
    (j['mapping'] as Map)['math_6_a'] = ['bad-code']; // 形が違う
    final issues = CurriculumPack.fromJson(j).validate();
    expect(issues, hasLength(2));
    expect(issues.any((s) => s.contains('ghost')), true);
    expect(issues.any((s) => s.contains('bad-code')), true);
  });

  test('対応の無い葉と、カバーされない必須項目を見つける', () {
    final j = sample();
    (j['mapping'] as Map).remove('math_6_a');
    final p = CurriculumPack.fromJson(j);
    expect(p.uncovered, ['EF06MA01']);
    final issues = p.validate();
    expect(issues, hasLength(2));
    expect(issues.any((s) => s.contains('math_6_a') && s.contains('対応する')), true);
    expect(issues.any((s) => s.contains('EF06MA01') && s.contains('カバー')), true);
  });

  test('学年の範囲外を見つける', () {
    final j = sample();
    ((j['tree'] as Map)['units'] as List)[1]['grade'] = 5;
    ((j['tree'] as Map)['units'] as List)[2]['grade'] = 10;
    final issues = CurriculumPack.fromJson(j).validate();
    expect(issues.where((s) => s.contains('範囲より下')), hasLength(1));
    expect(issues.where((s) => s.contains('範囲より上')), hasLength(1));
  });

  test('書き間違いは FormatException', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['extra'] = 1,
      (j) => j['region'] = 'BRA',
      (j) => j['standard'] = '',
      (j) => j['version'] = 0,
      (j) => j['codePattern'] = '(',
      (j) => j['grades'] = {'min': 9, 'max': 6},
      (j) => j['grades'] = {'low': 1},
      (j) => j['required'] = [1],
      (j) => j['mapping'] = [],
      (j) => j.remove('tree'),
    ]) {
      final j = sample();
      change(j);
      expect(() => CurriculumPack.fromJson(j), throwsFormatException);
    }
    expect(() => CurriculumPack.fromJson([]), throwsFormatException);
  });
}
