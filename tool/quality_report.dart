// 問題集の品質レポートを作る。使い方:
//   dart run tool/quality_report.dart <questions.json> <backup.json> [<backup2.json> ...] [--out report.md]
// <backup.json> は `AttemptBackup.export` の形式（匿名で集めた回答の束。複数ファイルは合わせて数える）。
// 難易度のずれ・誤答の選択肢の旗・誤解の型の候補・復習間隔の提案を Markdown で出す。形式は docs/question_bank_format.md。
import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  final rest = [...args];
  String? out;
  final o = rest.indexOf('--out');
  if (o >= 0) {
    if (o + 1 >= rest.length) {
      stderr.writeln('--out にはファイル名が要ります');
      exit(64);
    }
    out = rest[o + 1];
    rest.removeRange(o, o + 2);
  }
  if (rest.length < 2) {
    stderr.writeln('usage: dart run tool/quality_report.dart <questions.json> <backup.json> [<backup2.json> ...] [--out report.md]');
    exit(64);
  }

  String read(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException catch (e) {
      stderr.writeln('$path: 読めません（${e.osError?.message ?? e.message}）');
      exit(66);
    }
  }

  final Map<String, dynamic> json;
  try {
    json = jsonDecode(read(rest.first)) as Map<String, dynamic>;
  } on FormatException catch (e) {
    stderr.writeln('${rest.first}: JSON として読めません（${e.message}）');
    exit(65);
  }
  final bank = parseQuestionBank(json);
  for (final i in bank.issues) {
    stderr.writeln('${rest.first}: $i');
  }
  final attempts = <Attempt>[];
  for (final path in rest.skip(1)) {
    try {
      attempts.addAll(AttemptBackup.parse(read(path)));
    } on FormatException catch (e) {
      stderr.writeln('$path: ${e.message}');
      exit(1);
    }
  }
  final md = buildQualityReport(attempts, bank.questions).toMarkdown();
  if (out == null) {
    stdout.write(md);
  } else {
    File(out).writeAsStringSync(md);
    stdout.writeln('レポートを $out に書きました');
  }
}
