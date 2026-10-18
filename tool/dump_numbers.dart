// 保護者ゲートの数の読み上げを一覧にする。ネイティブ確認の依頼用。
// 使い方: `dart run tool/dump_numbers.dart <ロケール> [最小] [最大]`（例: `dart run tool/dump_numbers.dart pl 1 100`）
// 出力は「数<タブ>読み」。既定は 1〜9999。
import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.isEmpty || args.length > 3) {
    print('usage: dart run tool/dump_numbers.dart <locale> [min] [max]');
    return;
  }
  final strings = ChukoreStrings.forLocale(args[0]);
  final min = args.length > 1 ? int.parse(args[1]) : 1;
  final max = args.length > 2 ? int.parse(args[2]) : 9999;
  for (var n = min; n <= max; n++) {
    print('$n\t${strings.gateNumberWords(n)}');
  }
}
