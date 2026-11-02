import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 中2の数学の型と文言（草案）。全変種で値が入って読め、式の問題は解説が答えを含み、誤答は答えと違う。
void main() {
  chu3();
  const dir = 'docs/content_drafts/suugaku_chu2';
  final texts = ContentTexts.parse(File('$dir/texts.json').readAsStringSync());
  final set = TemplateSet.parse(File('$dir/templates.json').readAsStringSync());

  test('36 の型。一括検証にエラーなし', () {
    expect(set.templates.length, 36);
    final r = validateContentPack(
      File('$dir/manifest.json').readAsStringSync(),
      (p) => File('$dir/$p').readAsStringSync(),
    );
    expect(
      r.issues.where((i) => i.severity == IssueSeverity.error),
      isEmpty,
      reason: r.issues.join('\n'),
    );
  });

  test('全変種: 問題文と解説に波かっこが残らず、解説は答えを含み、誤答は答えと異なる', () {
    for (final t in set.templates) {
      for (var s = 1; s <= 30; s++) {
        final v = t.generate(s);
        final p = renderVariantText(texts.texts['prompt_${t.id}']!, v);
        final e = renderVariantText(texts.texts[t.explanationId]!, v);
        expect(
          p.contains('{') || p.contains('}'),
          isFalse,
          reason: '${t.id}~$s $p',
        );
        expect(
          e.contains('{') || e.contains('}'),
          isFalse,
          reason: '${t.id}~$s $e',
        );
        expect(e, contains(v.question.answer), reason: '${t.id}~$s $e');
      }
    }
  });


  test('中2のレッスン 4 つ: 文言がそろい 1 つ 300 文字以内。例題の行の説明は変種の値を差し込んで読める', () {
    final lessons = LessonSet.parse(File('$dir/lessons.json').readAsStringSync()).lessons;
    expect(lessons.length, 4);
    for (final l in lessons) {
      for (final id in l.textIds) {
        expect(texts.texts, contains(id), reason: '${l.id} $id');
        expect(texts.texts[id]!.runes.length, lessThanOrEqualTo(ContentTexts.longText), reason: id);
      }
    }
    final l = lessons.firstWhere((l) => l.id == 'les_m2_expr_poly_01');
    final ex = l.blocks.whereType<ExampleBlock>().single;
    final t = set.templates.firstWhere((t) => t.id == ex.template);
    final v = t.generate(ex.seed);
    final a = v.params['a']!.toInt(), c = v.params['c']!.toInt();
    expect(renderVariantText(texts.texts[ex.textIds.last]!, v), 'x の項と数の項をまとめて、${a - c}x${renderVariantText('{+b-d}', v)}。');
  });


  test('図つきの型: 全変種で図が描け（SVG）、読み取りの答えは図の点と一致する。箱ひげ図の見本は四分位範囲を計算できる', () {
    for (final id in ['m2_lin_graph_002', 'm2_lin_graph_003', 'm2_lin_sim_003', 'm2_prob_count_003']) {
      final t = set.templates.firstWhere((t) => t.id == id);
      expect(t.figure, isNotNull, reason: id);
      for (var s = 1; s <= 30; s++) {
        final v = t.generate(s);
        expect(v.figure!.toSvg(), startsWith('<svg'), reason: '$id~$s');
      }
    }
    final box = ChartSpec.fromJson((jsonDecode(File('$dir/charts.json').readAsStringSync()) as Map)['charts']['chart_box_class_ab'] as Map<String, dynamic>);
    expect([box.iqrOf(0), box.iqrOf(1)], [24, 12]);
  });

  test('代表例を実際の値で読む', () {
    final t = set.templates.firstWhere((t) => t.id == 'm2_par_angle_002');
    final v = t.generate(3);
    final n = v.params['n']!.toInt();
    expect(
      renderVariantText(texts.texts['exp_m2_par_angle_002']!, v),
      '$n 角形は、1 つの頂点から対角線を引くと ${n - 2} 個の三角形に分けられます。180° × ${n - 2} = ${180 * (n - 2)}°。',
    );
  });
}

/// 中3の新しい型の答えを、変種の値から独立に計算し直して確かめる。
void chu3() {
  final set = TemplateSet.parse(
    File('docs/content_drafts/suugaku_chu3/templates.json').readAsStringSync(),
  );
  test('中3の型: 答えを値から計算し直して一致する（相似・三平方・円周角・二次方程式）', () {
    num p(Variant v, String k) => v.params[k]!;
    for (var s = 1; s <= 30; s++) {
      Variant g(String id) =>
          set.templates.firstWhere((t) => t.id == id).generate(s);
      var v = g('m3_pyth_thm_002');
      expect(
        double.parse(v.question.answer),
        closeTo((12 * p(v, 'k')).toDouble(), 1e-9),
      );
      v = g('m3_sim_area_002');
      expect(
        double.parse(v.question.answer),
        closeTo(
          (p(v, 'b') * p(v, 'b') * p(v, 'b') * p(v, 'k')).toDouble(),
          1e-9,
        ),
      );
      v = g('m3_quad_solve_002');
      expect(
        double.parse(v.question.answer),
        closeTo((p(v, 'c') - p(v, 'a')).toDouble(), 1e-9),
      );
      v = g('m3_circ_angle_002');
      expect(
        double.parse(v.question.answer),
        closeTo((90 - p(v, 'a')).toDouble(), 1e-9),
      );
      v = g('m3_poly_use_001');
      expect(double.parse(v.question.answer), closeTo(((10 * p(v, 'k') + 1) * (10 * p(v, 'k') - 1)).toDouble(), 1e-9));
      v = g('m3_poly_use_004');
      expect(double.parse(v.question.answer), closeTo(((p(v, 'a') + p(v, 'k')) * (p(v, 'b') - p(v, 'k'))).toDouble(), 1e-9));
      v = g('m3_samp_sample_001');
      expect(
        double.parse(v.question.answer),
        closeTo((p(v, 'm') * p(v, 'r')).toDouble(), 1e-9),
      );
    }
  });
}
