import 'dart:io';
import 'dart:math';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 検算ツール: 型の答えを、**画面に出る問題文の数字だけ**から、別の方法で求め直して照合する。
/// 型の答えの式は、問題を作るときの隠れた値（パラメータ）から書いてあるので、書き間違いがあっても自分自身とは必ず合ってしまう。
/// ここでは、生徒が見るのと同じ数字（描画した問題文）から、問題の意味どおりに解いて確かめる。
/// 図を読み取る型（図の中の点や長さが唯一の手がかり）は対象外（[figureOnly]）。
void main() {
  /// 問題文に出てくる数を、出てくる順に取り出す。「)」の直後の「−」は引き算なので、数に符号をつけない。
  List<double> nums(String s) => [
    for (final m in RegExp(
      r'(?<!\))-?\d+(?:\.\d+)?|\d+(?:\.\d+)?',
    ).allMatches(s))
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

  double median(List<double> d) {
    final v = [...d]..sort();
    return v.length.isOdd
        ? v[v.length ~/ 2]
        : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
  }

  double mode(List<double> d) {
    final c = <double, int>{};
    for (final x in d) {
      c[x] = (c[x] ?? 0) + 1;
    }
    final top = c.values.reduce(max);
    final ms = [
      for (final e in c.entries)
        if (e.value == top) e.key,
    ];
    expect(ms.length, 1, reason: '最頻値が一つに決まらない: $d');
    return ms.single;
  }

  int gcd(int a, int b) => b == 0 ? a.abs() : gcd(b, a % b);

  /// 既約分数の文字列（分母が 1 なら整数）。
  String frac(int n, int d) {
    final g = gcd(n, d);
    return d ~/ g == 1 ? '${n ~/ g}' : '${n ~/ g}/${d ~/ g}';
  }

  /// (n/d)π の文字列。
  String pi(num n, num d) => '${frac(n.round(), d.round())}π';

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
    'm2_lin_use_003': (n) => n[0] + n[1] * n[3], // 乗りはじめ b 円・距離 p km・「1 km」の 1 を飛ばして a 円
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

    // 中1
    'm1_expand_001': (n) => lin(n[0], n[0] * n[1]),
    'm1_linear_001': (n) => ex((n[2] - n[1]) / n[0]),
    'm1_expr_combine_001': (n) => lin(n[0] + n[2], n[1] + n[3]),
    'm1_expr_paren_001': (n) => lin(n[0] - n[1], -n[2]),
    'm1_alg_value_001': (n) => n[1] * n[0] + n[2],
    'm1_linear_002': (n) => (n[2] - n[1]) / n[0],
    'm1_linear_003': (n) => (n[3] - n[1]) / (n[0] - n[2]),
    'm1_eq_prop_001': (n) => '両辺から${ex(n[0])}をひく',
    'm1_alg_rel_001': (n) => '${ex(n[1])}x+${ex(n[2])}円',
    'm1_num_abs_001': (n) => n[0].abs(),
    'm1_num_add_001': (n) => n[0] + n[1],
    'm1_num_add_002': (n) => n[0] + n[1],
    'm1_num_mul_001': (n) => n[0] * n[1],
    'm1_num_div_001': (n) => n[0] / n[1],
    'm1_num_pow_001': (n) => -sq(n[0]),
    'm1_num_pow_002': (n) => sq(n[0]),
    'm1_num_mix_001': (n) => n[0] + n[1] * n[2],
    'm1_func_coord_001': (n) => n[1],
    'm1_func_prop_001': (n) => n[0] * n[1],
    'm1_func_prop_002': (n) => n[1] / n[0],
    'm1_func_inv_001': (n) => n[0] / n[1],
    'm1_func_inv_002': (n) => n[0] * n[1],
    'm1_func_graph_001': (n) => n[1] / n[0] * n[2],
    'm1_data_mean_001': (n) =>
        frac(n.reduce((a, b) => a + b).round(), n.length),
    'm1_data_median_001': (n) => median(n),
    'm1_data_mode_001': (n) => mode(n),
    'm1_data_range_001': (n) => n.reduce(max) - n.reduce(min),
    'm1_data_class_001': (n) =>
        n.skip(2).where((x) => x >= n[0] && x < n[1]).length,
    'm1_data_relfreq_001': (n) => frac(
      n.skip(2).where((x) => x >= n[0] && x < n[1]).length,
      n.length - 2,
    ),
    'm1_geo_circle_001': (n) => pi(2 * n[0], 1),
    'm1_geo_circle_002': (n) => pi(sq(n[0]), 1),
    'm1_geo_sector_001': (n) => pi(2 * n[0] * n[1], 360),
    'm1_geo_sector_002': (n) => pi(sq(n[0]) * n[1], 360),
    'm1_geo_sector_003': (n) => pi(2 * n[0] * n[1], 360),
    'm1_space_vol_001': (n) => pi(sq(n[0]) * n[1], 1),
    'm1_space_vol_002': (n) => pi(sq(n[0]) * n[1], 3),
    'm1_space_vol_003': (n) => pi(4 * n[0] * n[0] * n[0], 3),
    'm1_space_vol_004': (n) => pi(4 * sq(n[0]), 1),
    'm1_space_vol_005': (n) => pi(2 * n[0] * (n[0] + n[1]), 1),
    'm1_geo_angle_001': (n) => 180 - n[1] - n[2],
    'm1_geo_angle_002': (n) => n.last,
    'm1_geo_angle_003': (n) => 180 - n.last,
    'm1_geo_angle_004': (n) => (180 - n.last) / 2,
    'm1_space_fig_001': (n) => pi(sq(n[0]) * n[1], 1),
    'm1_space_fig_002': (n) => pi(sq(n[0]) * n[1], 3),
    'm1_space_fig_003': (n) => pi(4 * sq(n[0]), 1),
    'm1_space_fig_004': (n) => n[0] * n[1] * n[2],
    'm1_space_fig_005': (n) => 2 * (n[0] * n[1] + n[1] * n[2] + n[2] * n[0]),
    'm1_space_net_001': (n) => pi(2 * n[0], 1),
    'm1_space_net_002': (n) => frac((360 * n[1]).round(), n[0].round()),
    'm1_eq_word_001': (n) => (n[3] - n[2]) / n[1],
    'm1_eq_word_002': (n) => (n[1] + n[3]) / (n[2] - n[0]),
    'm1_eq_word_003': (n) => (n[1] - n[2] * n[0]) / (n[2] - 1),
    'm1_geo_move_001': (n) => n[0] + n[2],
    'm1_geo_move_002': (n) => n[1] + n[3],
    'm1_geo_move_003': (n) => -n[1],
    'm1_geo_move_004': (n) => -n[0],
    'm1_geo_move_005': (n) => -n[1],
    'm1_geo_parallel_001': (n) => n.last,
    'm1_geo_parallel_002': (n) => n.last,
    'm1_geo_parallel_003': (n) => 180 - n.last,
    'm1_space_prism_001': (n) => n[0] * n[1],
    'm1_space_pyramid_001': (n) => n[0] * n[1] / 3,
    'm1_space_prism_002': (n) => n[0] * n[1],
    'm1_space_pyramid_002': (n) => n[0] * n[1] / 3,
    'm1_space_solid_face_001': (n) => n[0] + 2,
    'm1_space_solid_edge_001': (n) => 3 * n[0],
    'm1_space_solid_vertex_001': (n) => n[0] + 1,
    'm1_space_solid_edge_002': (n) => 2 * n[0],
    'm1_space_cut_001': (n) => '円',
    'm1_space_cut_002': (n) => '長方形',
    'm1_space_cut_003': (n) => '円',
    'm1_space_cut_004': (n) => '二等辺三角形',
    'm1_space_cut_005': (n) => '円',
    'm1_space_cut_face_001': (n) => 6 + n[0],
    'm1_space_cut_vertex_001': (n) => 8 + 2 * n[0],
    'm1_space_cut_edge_001': (n) => 12 + 3 * n[0],
    'm1_linear_check_001': (n) => n[0] * n[3] + n[1],
    'm1_num_mul_sign_001': (n) =>
        n.skip(2).where((x) => x < 0).length.isEven ? 1 : -1,
  };
  // 数の並びだけでは式の形が決まらない型は、問題文の式そのものから解く
  final Map<String, Object Function(String prompt)> byText = {
    'm1_num_sub_001': (p) {
      // 「A−B」（A、B は整数または (整数)）
      final m = RegExp(r'(\(?-?\d+\)?)-(\(?-?\d+\)?)$').firstMatch(p)!;
      double v(String t) =>
          double.parse(t.replaceAll('(', '').replaceAll(')', ''));
      return v(m.group(1)!) - v(m.group(2)!);
    },
  };
  // 図の中の点・長さだけが手がかりの型
  const figureOnly = {
    'm1_space_netchoice_001',
    'm1_space_solidchoice_001',
    'm1_space_solidchoice_002',
    'm1_func_graphchoice_001',
    'm1_space_solid_face_002',
    'm1_space_solid_edge_003',
    'm1_space_solid_vertex_002',
    'm1_space_solid_face_003',
    'm1_space_solid_edge_004',
    'm1_space_solid_vertex_003',
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
      if (f == null && byText[t.id] == null && t.id != 'm1_func_choice_001') {
        bad.add('${t.id} の検算がありません（oracle か figureOnly に入れてください）');
        continue;
      }
      for (var s = 1; s <= 40; s++) {
        final v = t.generate(s);
        if (t.id == 'm1_func_choice_001') {
          // 選択肢のうち「y=kx」の形（比例）はちょうど 1 つで、それが答え
          final good = [
            for (final c in v.question.choices)
              if (RegExp(r'^y=-?\d*x$').hasMatch(c)) c,
          ];
          if (good.length != 1 || good.single != v.question.answer) {
            bad.add(
              '${t.id}~$s 比例の選択肢が答えと一致しません: ${v.question.choices} 答え ${v.question.answer}',
            );
          }
          continue;
        }
        final prompt = renderVariantText(texts.texts['prompt_${t.id}']!, v);
        final Object want;
        try {
          want = byText[t.id]?.call(prompt) ?? f!(nums(prompt));
        } on RangeError {
          bad.add('${t.id}~$s 問題文の数が足りません: $prompt');
          break;
        }
        var input = want is num ? ex(want) : want as String;
        if (t.choiceLabels) {
          // 選択肢が ID の型: 解き直した文言（国・言語の文言）に合う選択肢の ID に直す
          final key = t.choices.where((c) => renderVariantText(texts.texts[choiceLabelTextId(t.id, c)]!, v) == input).firstOrNull;
          input = key ?? 'no_such_label:$input';
        }
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
    'docs/content_drafts/suugaku_chu1',
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
