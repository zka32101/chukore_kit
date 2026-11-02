import 'dart:io';
import 'dart:math';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 検算ツール: 型の答えを、**画面に出る問題文の数字だけ**から、別の方法で求め直して照合する。
/// 型の答えの式は、問題を作るときの隠れた値（パラメータ）から書いてあるので、書き間違いがあっても自分自身とは必ず合ってしまう。
/// ここでは、生徒が見るのと同じ数字（描画した問題文）から、問題の意味どおりに解いて確かめる。
/// 図を読み取る型（図の中の点や長さが唯一の手がかり）は対象外（[figureOnly]）。
void main() {
  /// 問題文に出てくる数（符号つき）を、出てくる順に取り出す。
  List<double> nums(String s) => [
    for (final m in RegExp(r'-?\d+(?:\.\d+)?').allMatches(s))
      double.parse(m.group(0)!),
  ];
  double sq(double x) => x * x;

  /// 中学校の定義の四分位範囲（データを昇順にして、中央で前半・後半に分け、それぞれの中央値の差）。
  double iqr(List<double> d) {
    double med(List<double> v) => v.length.isOdd
        ? v[v.length ~/ 2]
        : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
    final s = [...d]..sort();
    final h = s.length ~/ 2;
    final lower = s.sublist(0, h),
        upper = s.sublist(s.length.isOdd ? h + 1 : h);
    return med(upper) - med(lower);
  }

  String ex(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
  String lin(num a, num b) => '(${ex(a)})*x+(${ex(b)})';

  // 型ID → 問題文の数 n から、正しい答え（数なら num、式なら String）を求める
  final Map<String, Object Function(List<double> n)> oracle = {
    // 中2
    'm2_expr_poly_001': (n) => lin(n[0] + n[2], n[1] + n[3]),
    'm2_expr_poly_002': (n) => lin(n[0] - n[2], n[1] - n[3]),
    'm2_expr_mono_001': (n) => '${ex(n[0] * n[1])}*x^2',
    'm2_expr_mono_002': (n) => '${ex(n[0] / n[1])}*x',
    'm2_expr_use_001': (n) => n[2] * n[0] + n[3] * n[1],
    'm2_sim_solve_001': (n) => (n[0] + n[1]) / 2,
    'm2_sim_solve_002': (n) => (n[0] - n[1]) / 2,
    'm2_sim_solve_003': (n) => (n[2] - n[1]) / (n[0] + 1),
    'm2_sim_word_001': (n) =>
        (n[5] - n[3] * n[4]) / (n[1] - n[3]), // 1 個 a 円・1 個 b 円・あわせて N 個・代金 M 円
    'm2_lin_graph_001': (n) => (n[3] - n[2]) / (n[1] - n[0]),
    'm2_lin_eq_001': (n) => n[2] - n[0] * n[1],
    'm2_lin_eq_002': (n) => (n[4] - n[2]) / (n[3] - n[1]), // 先頭の 2 は「2 点」
    'm2_par_angle_001': (n) => 180 - n.last, // 「2 直線」「1 つ」の数字が先に出る
    'm2_par_angle_002': (n) => 180 * (n[0] - 2),
    'm2_par_angle_003': (n) => 360 / n[0],
    'm2_prob_count_001': (n) => n[0] * (n[0] - 1),
    'm2_prob_count_002': (n) => n[0] * (n[0] - 1) / 2,
    'm2_prob_prob_001': (n) => n[0] / (n[0] + n[1]),
    'm2_data_box_001': (n) => iqr(n),
    'm2_par_cong_001': (n) => 180 - n[0] - n[1],
    'm2_par_cong_002': (n) => n[0] + n[1] + n[2],
    'm2_tri_iso_001': (n) => (180 - n[0]) / 2,
    'm2_tri_iso_002': (n) => 180 - 2 * n[0],
    'm2_tri_iso_003': (n) => 2 * n[0],
    'm2_tri_para_001': (n) => n[0],
    'm2_tri_para_002': (n) => 180 - n[0],
    'm2_tri_para_003': (n) => 2 * (n[0] + n[1]),
    'm2_tri_para_004': (n) => n[0] / 2,
    'm2_lin_sim_001': (n) => (n[4] - n[2]) / (n[1] - n[3]), // 先頭の 2 は「2 直線」,
    'm2_lin_sim_002': (n) => n[1] * (n[4] - n[2]) / (n[1] - n[3]) + n[2],
    'm2_lin_use_001': (n) => n[0] + n[1] * n[2],
    'm2_lin_use_002': (n) => (n[2] - n[0]) / n[1],
    'm2_prob_count_003': (n) => 3 * 2, // 3 人から 2 人を順に選ぶ
    // 中3
    'm3_fn_graph_001': (n) => n[1] / sq(n[0]),
    'm3_fn_graph_002': (n) => n[0] * sq(n[1]),
    'm3_fn_rate_001': (n) => n[0] * (n[1] + n[2]),
    'm3_fn_use_001': (n) => sq(n[2]) / n[1], // 「2 乗」の 2 を飛ばす
    'm3_fn_use_002': (n) => 5 * sq(n[1]),
    'm3_poly_expand_001': (n) =>
        'x^2+(${ex(n[0] + n[1])})*x+(${ex(n[0] * n[1])})',
    'm3_poly_expand_002': (n) => 'x^2+(${ex(2 * n[0])})*x+(${ex(n[0] * n[0])})',
    'm3_poly_expand_003': (n) => 'x^2-(${ex(n[0] * n[0])})',
    'm3_poly_factor_001': (n) {
      final s = n[1], pq = n[2], d = sqrt(sq(s) - 4 * pq);
      return '(x-(${ex((-s + d) / 2)}))*(x-(${ex((-s - d) / 2)}))';
    },
    'm3_poly_factor_002': (n) =>
        '(x+${ex(sqrt(-n[1]))})*(x-${ex(sqrt(-n[1]))})',
    'm3_sqrt_def_001': (n) => sqrt(n[0]),
    'm3_sqrt_calc_001': (n) => sqrt(n[0] * n[1]),
    'm3_quad_solve_001': (n) => (-n[1] + sqrt(sq(n[1]) - 4 * n[2])) / 2,
    'm3_quad_solve_002': (n) => -n[0] + sqrt(n[2]),
    'm3_quad_word_001': (n) => (-1 + sqrt(1 + 4 * n[1])) / 2, // 先頭の 2 は「2 つ」
    'm3_sim_def_001': (n) => n[2] * n[1] / n[0],
    'm3_sim_ratio_001': (n) => n[2] * n[0] / (n[0] + n[1]),
    'm3_sim_ratio_002': (n) => n[2] * n[0] / (n[0] + n[1]),
    'm3_sim_area_001': (n) => n[3] * sq(n[2] / n[1]), // 先頭の 2 は「2 つ」
    'm3_sim_area_002': (n) => n[3] * pow(n[2] / n[1], 3),
    'm3_circ_angle_001': (n) => n[0] / 2,
    'm3_circ_angle_002': (n) => 90 - n[0],
    'm3_circ_angle_003': (n) => n[0] / 2,
    'm3_circ_angle_004': (n) => 90 - n[0],
    'm3_pyth_thm_001': (n) => sqrt(sq(n[1]) + sq(n[2])), // 先頭の 2 は「2 辺」
    'm3_pyth_thm_002': (n) => sqrt(sq(n[0]) - sq(n[2])), // 間の 1 は「1 辺」
    'm3_pyth_use_001': (n) => sqrt(sq(n[0]) + sq(n[1])),
    'm3_pyth_use_002': (n) => sqrt(sq(n[0]) - sq(n[1])),
    'm3_samp_sample_001': (n) => n[0] * n[2] / n[1],
    'm3_poly_use_001': (n) => n[0] * n[1],
    'm3_poly_use_002': (n) => sq(n[0]),
    'm3_poly_use_003': (n) => (n.last - 1) / 2, // 「2 つ」「2 乗」が先に出る
    'm3_poly_use_004': (n) => (n[0] + n[2]) * (n[1] - n[2]),
  };
  // 図の中の点・長さだけが手がかりの型
  const figureOnly = {
    'm2_lin_graph_002',
    'm2_lin_graph_003',
    'm2_lin_sim_003',
    'm3_pyth_thm_003',
    'm3_pyth_thm_004',
  };

  /// 検算: 食い違い（型ID~種と内容）の一覧。
  List<String> verify(TemplateSet set, ContentTexts texts) {
    final bad = <String>[];
    for (final t in set.templates) {
      if (figureOnly.contains(t.id)) continue;
      final f = oracle[t.id];
      if (f == null) {
        bad.add('${t.id} の検算がありません（oracle か figureOnly に入れてください）');
        continue;
      }
      for (var s = 1; s <= 40; s++) {
        final v = t.generate(s);
        final prompt = renderVariantText(texts.texts['prompt_${t.id}']!, v);
        final Object want;
        try {
          want = f(nums(prompt));
        } on RangeError {
          bad.add('${t.id}~$s 問題文の数が足りません: $prompt');
          break;
        }
        final input = want is num ? ex(want) : want as String;
        if (!checkAnswer(v.question, input).correct) {
          bad.add(
            '${t.id}~$s\n  問題文: $prompt\n  型の答え: ${v.question.answer}\n  検算: $input',
          );
          break;
        }
      }
    }
    return bad;
  }

  for (final dir in [
    'docs/content_drafts/suugaku_chu2',
    'docs/content_drafts/suugaku_chu3',
  ]) {
    final texts = ContentTexts.parse(
      File('$dir/texts.json').readAsStringSync(),
    );
    final set = TemplateSet.parse(
      File('$dir/templates.json').readAsStringSync(),
    );

    test('$dir: 検算 — 問題文の数字から解き直した答えが、全型・全変種で型の答えと一致する', () {
      final bad = verify(set, texts);
      expect(bad, isEmpty, reason: bad.join('\n'));
    });
  }

  test('検算は、答えの式を書き間違えた型を見つける（わざと壊した 3 つが全部見つかる）', () {
    const dir = 'docs/content_drafts/suugaku_chu3';
    final texts = ContentTexts.parse(
      File('$dir/texts.json').readAsStringSync(),
    );
    final raw = File('$dir/templates.json').readAsStringSync();
    for (final m in [
      ['"answer": "{12*k}"', '"answer": "{13*k}"'], // 三平方: 辺の長さ
      ['"answer": "{b*b*k}"', '"answer": "{b*b*k+1}"'], // 相似: 面積
      ['"answer": "{90-a}"', '"answer": "{91-a}"'], // 円周角
    ]) {
      expect(raw, contains(m[0]));
      final broken = TemplateSet.parse(raw.replaceFirst(m[0], m[1]));
      expect(
        verify(broken, texts),
        isNotEmpty,
        reason: '${m[0]} → ${m[1]} が見つからない',
      );
    }
  });
}
