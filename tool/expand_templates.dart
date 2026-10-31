// 問題の型を検証し、変種を展開した問題集を書く。
// 使い方: `dart run tool/expand_templates.dart <units.json> <templates.json> [<出力 questions.json>] [<変種の数>]`
// エラーがあれば出力せず終了コード 1。形式は docs/math_variants_design.md。
import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.length < 2 || args.length > 4) {
    stderr.writeln('usage: dart run tool/expand_templates.dart <units.json> <templates.json> [<out.json>] [<count>]');
    exit(64);
  }
  final count = args.length == 4 ? int.tryParse(args[3]) : 40;
  if (count == null || count < 1) {
    stderr.writeln('変種の数は 1 以上の整数');
    exit(64);
  }
  final unitsJson = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final tree = UnitTree.fromJson(unitsJson);
  final TemplateSet set;
  try {
    set = TemplateSet.parse(File(args[1]).readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('ERROR 型を読めません: ${e.message}');
    exit(1);
  }
  final issues = validateTemplates(set, tree: tree, count: count);
  for (final i in issues) {
    stdout.writeln(i);
  }
  final errors = issues.where((i) => i.isError).length;
  stdout.writeln(
    'templates: ${set.templates.length}, variants: ${set.templates.length * count} / errors: $errors, warnings: ${issues.length - errors}',
  );
  if (errors > 0) exit(1);
  if (args.length >= 3) {
    final questions = [for (final v in set.expand(count: count)) v.question.toJson()];
    File(args[2]).writeAsStringSync(const JsonEncoder.withIndent(' ').convert({'version': 1, 'questions': questions}));
    stdout.writeln('wrote ${args[2]}');
  }
}
