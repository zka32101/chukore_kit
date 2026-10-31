import '../l10n/digits.dart';
import '../math/math_expr.dart';
import '../models/models.dart';
import 'text_match.dart';

/// 判定結果。誤答のとき選択肢に型があれば [misconceptionTag] に入る。
class AnswerResult {
  const AnswerResult(this.correct, {this.misconceptionTag, double? score}) : _score = score;

  final bool correct;
  final String? misconceptionTag;
  final double? _score;

  /// 得点の割合（0〜1）。複数の項目を答える `multi` 問題では部分点になる。ほかは正解 1・不正解 0。
  double get score => _score ?? (correct ? 1.0 : 0.0);
}

/// 数値入力の正規化。全角・マイナス記号の違い・桁区切りを吸収する。
/// [decimalSeparator] が `,` の国（欧州など）では `.` を桁区切り、`,` を小数点として読む。
String normalizeNumberInput(String s, String decimalSeparator) {
  var t = normalizeDigits(s.trim())
      .replaceAll('．', '.')
      .replaceAll('，', ',')
      .replaceAll(RegExp('[－−–]'), '-')
      .replaceAll(RegExp('[\\s\u00A0\u202F]'), '');
  if (decimalSeparator == ',') {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else {
    t = t.replaceAll(',', '');
  }
  return t;
}

/// 問題タイプ別の判定。type: `choice`（選択）／`map`（地図タップ）／`numeric`（数値入力）／`expr`（数式。同じ値なら正解）／`order`・`timeline`（並べ替え・年表。
/// answer は選択肢IDをカンマ区切りで並べた正解順）／`text`（短い記述。answer は別解を `|` で区切る）／
/// `multi`（複数の項目を答える。answer は項目を `;`、各項目の別解を `|` で区切る。順不同・部分点あり）／
/// `card`（暗記カード。入力は自己採点の名前 `good`・`hard`・`again`。`good`・`hard` を正解として数える）。
/// 記述（`text`・`multi`）は [normalizeText] で表記ゆれをそろえて比べる。[foldKana] が偽なら、
/// カタカナとひらがなを区別する（カタカナで書く指定の問題用）。
AnswerResult checkAnswer(
  Question q,
  String input, {
  double tolerance = 1e-9,
  String decimalSeparator = '.',
  bool foldKana = true,
}) {
  switch (q.type) {
    case 'choice':
    case 'map': // 地図タップ: 選んだ領域ID と answer（領域ID）の一致
      final ok = input == q.answer;
      return AnswerResult(ok, misconceptionTag: ok ? null : q.misconceptionTags[input]);
    case 'numeric':
      final got = double.tryParse(normalizeNumberInput(input, decimalSeparator));
      final want = double.tryParse(normalizeNumberInput(q.answer, '.'));
      final ok = got != null && want != null && (got - want).abs() <= tolerance;
      return AnswerResult(ok);
    case 'expr': // 数式: 式として同じ値になれば正解（2x+6 と 2(x+3) は同じ）
      final verdict = judgeExpr(q.answer, input, form: q.form);
      if (verdict == ExprVerdict.correct) return const AnswerResult(true);
      return AnswerResult(false, misconceptionTag: _exprMisconception(q, input));
    case 'order':
    case 'timeline': // 年表: 古い順に並べたID列
      final got = input.split(',').map((e) => e.trim()).toList();
      final want = q.answer.split(',').map((e) => e.trim()).toList();
      var ok = got.length == want.length;
      for (var i = 0; ok && i < got.length; i++) {
        ok = got[i] == want[i];
      }
      return AnswerResult(ok);
    case 'text':
      final got = normalizeText(input, foldKana: foldKana);
      final ok = got.isNotEmpty && textAlternatives(q.answer).any((a) => normalizeText(a, foldKana: foldKana) == got);
      return AnswerResult(ok);
    case 'multi':
      return _checkMulti(q.answer, input, foldKana);
    case 'card': // 暗記カード: 入力は自己採点の名前（again・hard・good）。わかった=1、あやしい=0.5、わからない=0
      return switch (input) {
        'good' => const AnswerResult(true, score: 1.0),
        'hard' => const AnswerResult(true, score: 0.5),
        _ => const AnswerResult(false),
      };
    default:
      throw UnsupportedError('unknown question type: ${q.type}');
  }
}

/// `multi` の判定。入力の各項目は、まだ使われていない正解の項目のどれか 1 つにだけ数える
/// （同じ項目を 2 回書いても 2 点にならず、減点もされない）。正解に無い項目が混じると、その数だけ得点が減る
/// （思いつく語を全部書く当て推量を避ける）。全項目が合い、余分な項目が無いときだけ正解。
AnswerResult _checkMulti(String answer, String input, bool foldKana) {
  final want = [
    for (final alts in multiItems(answer)) {for (final a in alts) normalizeText(a, foldKana: foldKana)},
  ];
  final used = List.filled(want.length, false);
  var matched = 0, extra = 0;
  for (final raw in splitMultiInput(input)) {
    final got = normalizeText(raw, foldKana: foldKana);
    final i = want.indexWhere((alts) => alts.contains(got));
    if (i < 0) {
      extra++;
    } else if (!used[i]) {
      used[i] = true;
      matched++;
    } // すでに数えた項目の重ね書きは、加点も減点もしない
  }
  final score = want.isEmpty ? 0.0 : ((matched - extra).clamp(0, want.length) / want.length);
  return AnswerResult(matched == want.length && extra == 0, score: score);
}

/// `expr` の誤答の誤解の型。`misconceptionTags` のキー（式）のうち、入力と同じ値になる最初のもののタグ。
String? _exprMisconception(Question q, String input) {
  final got = MathExpr.tryParse(input);
  if (got == null) return null;
  for (final e in q.misconceptionTags.entries) {
    final k = MathExpr.tryParse(e.key);
    if (k != null && MathExpr.equivalent(got, k)) return e.value;
  }
  return null;
}
