import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 中1のレッスンの説明文（教科書のような説明）。例題の行ごとの説明は、例題の変種（型と種）の値を差し込んで読めること。
void main() {
  const dir = 'docs/content_drafts/suugaku_chu1';
  final texts = ContentTexts.parse(File('$dir/texts.json').readAsStringSync());
  final set = TemplateSet.parse(File('$dir/templates.json').readAsStringSync());
  final lessons = LessonSet.parse(File('$dir/lessons.json').readAsStringSync()).lessons;
  String text(String id) => texts.texts[id]!;

  test('全レッスンの文言がそろい、1 つ 300 文字以内。目録は文言の範囲をレッスンに絞っている', () {
    expect(lessons.length, 4);
    for (final l in lessons) {
      for (final id in l.textIds) {
        expect(texts.texts, contains(id), reason: '${l.id} $id');
        expect(text(id).runes.length, lessThanOrEqualTo(ContentTexts.longText), reason: id);
      }
    }
    final r = validateContentPack(File('$dir/manifest.json').readAsStringSync(), (p) => File('$dir/$p').readAsStringSync());
    expect(r.manifest!.textsCover, {'lessons'});
    expect(r.issues.where((i) => i.code.startsWith('pack_text') || i.code.startsWith('text_')), isEmpty);
  });

  test('例題の行ごとの説明: 例題の値を差し込むと読めて、最後の行の説明は答えの値を含む', () {
    for (final l in lessons) {
      for (final b in l.blocks.whereType<ExampleBlock>()) {
        final v = set.templates.firstWhere((t) => t.id == b.template).generate(b.seed);
        expect(b.textIds.length, b.lines.length, reason: l.id);
        final rendered = [for (final id in b.textIds) renderVariantText(text(id), v)];
        for (final r in rendered) {
          expect(r.contains('{') || r.contains('}'), isFalse, reason: '${l.id}: $r');
        }
        // 最後の説明は、最後の行（答えの形）の値を含む
        final last = renderTemplateString(b.lines.last, v.params, lists: v.lists);
        final value = last.contains('=') ? last.split('=').last : last;
        expect(rendered.last, contains(value), reason: '${l.id}: ${rendered.last} / $last');
      }
    }
  });

  test('一次方程式の例題（種 7）: 説明を順に読むと、解き方がそのまま分かる', () {
    final v = set.templates.firstWhere((t) => t.id == 'm1_linear_002').generate(7);
    final a = v.params['a']!.toInt(), b = v.params['b']!.toInt(), c = v.params['c']!.toInt(), k = v.params['k']!.toInt();
    final l = lessons.firstWhere((l) => l.id == 'les_m1_linear_01');
    final ex = l.blocks.whereType<ExampleBlock>().single;
    final r = [for (final id in ex.textIds) renderVariantText(text(id), v)];
    expect(r[0], '解きたい方程式は ${a}x${b >= 0 ? '+' : ''}$b=$c です。');
    expect(r[2], '右辺を計算します。${a}x=${c - b}。');
    expect(r[3], '両辺を $a でわって、x=$k。これが解です。');
    expect(a * k + b, c); // 例題の方程式は x=k で成り立つ
  });

  test('実例の数値が正しい（導入・つまずきの数）', () {
    expect(120 * 3 + 50, 410); // みかん 3 個
    expect(MathExpr.equivalent(MathExpr.parse('3x+100+2x+50'), MathExpr.parse('5x+150')), isTrue); // 導入の式をまとめると 5x+150
    expect(text('les_m1_linear_01_hook'), contains('120x + 50 = 410'));
    expect(text('les_m1_linear_01_s3'), contains('120 × 3 + 50 = 410'));
    expect(text('les_m1_expr_01_hook'), contains('3x + 100 + 2x + 50'));
    expect(text('les_m1_eq_prop_01_p1'), contains('7 + 3 = 10'));
  });
}
