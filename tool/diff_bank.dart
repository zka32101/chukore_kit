// 問題集の差分を作って検査する。使い方: `dart run tool/diff_bank.dart <今の questions.json> <新しい questions.json> [<出力する diff.json>]`
// 内容を変えたのに version を上げていない問題などがあれば終了コード 1。形式は docs/question_bank_format.md。
import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.length != 2 && args.length != 3) {
    stderr.writeln('usage: dart run tool/diff_bank.dart <old questions.json> <new questions.json> [<diff.json>]');
    exit(64);
  }
  List<Question> load(String path) {
    final bank = parseQuestionBank(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);
    for (final i in bank.issues) {
      stdout.writeln('$path: $i');
    }
    return bank.questions;
  }

  final from = load(args[0]);
  final to = load(args[1]);
  final diff = BankDiff.between(from, to);
  final issues = diff.check(from);
  for (final i in issues) {
    stdout.writeln(i);
  }
  final errors = issues.where((i) => i.isError).length;
  stdout.writeln('追加 ${diff.added.length} / 削除 ${diff.removed.length} / 変更 ${diff.changed.length} '
      '/ errors: $errors, warnings: ${issues.length - errors}');
  if (args.length == 3 && errors == 0) {
    File(args[2]).writeAsStringSync(diff.toJsonString());
    stdout.writeln('差分を ${args[2]} に書きました');
  }
  exit(errors == 0 ? 0 : 1);
}
