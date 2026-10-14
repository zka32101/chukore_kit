import '../models/models.dart';

/// 判定結果。誤答のとき選択肢に型があれば [misconceptionTag] に入る。
class AnswerResult {
  const AnswerResult(this.correct, {this.misconceptionTag});

  final bool correct;
  final String? misconceptionTag;
}

/// 数値入力の正規化。全角・マイナス記号の違い・桁区切りを吸収する。
/// [decimalSeparator] が `,` の国（欧州など）では `.` を桁区切り、`,` を小数点として読む。
String _normalize(String s, String decimalSeparator) {
  var t = s
      .trim()
      .replaceAllMapped(RegExp('[０-９]'), (m) => '${m[0]!.codeUnitAt(0) - 0xFF10}')
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

/// 問題タイプ別の判定。type: `choice`（選択）／`map`（地図タップ）／`numeric`（数値入力）／`order`・`timeline`（並べ替え・年表。
/// answer は選択肢IDをカンマ区切りで並べた正解順）。
AnswerResult checkAnswer(
  Question q,
  String input, {
  double tolerance = 1e-9,
  String decimalSeparator = '.',
}) {
  switch (q.type) {
    case 'choice':
    case 'map': // 地図タップ: 選んだ領域ID と answer（領域ID）の一致
      final ok = input == q.answer;
      return AnswerResult(ok, misconceptionTag: ok ? null : q.misconceptionTags[input]);
    case 'numeric':
      final got = double.tryParse(_normalize(input, decimalSeparator));
      final want = double.tryParse(_normalize(q.answer, '.'));
      final ok = got != null && want != null && (got - want).abs() <= tolerance;
      return AnswerResult(ok);
    case 'order':
    case 'timeline': // 年表: 古い順に並べたID列
      final got = input.split(',').map((e) => e.trim()).toList();
      final want = q.answer.split(',').map((e) => e.trim()).toList();
      var ok = got.length == want.length;
      for (var i = 0; ok && i < got.length; i++) {
        ok = got[i] == want[i];
      }
      return AnswerResult(ok);
    default:
      throw UnsupportedError('unknown question type: ${q.type}');
  }
}
