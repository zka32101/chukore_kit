// コンテンツパック（国 × 教科 × 学年の中身 1 式）を検証する。
// 使い方: `dart run tool/validate_pack.dart <パックのディレクトリ>`（`manifest.json` を読む）
// エラーがあれば終了コード 1（警告だけなら 0）。仕様は docs/content_pack_spec.md。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/validate_pack.dart <pack_dir>');
    exit(64);
  }
  final dir = Directory(args[0]);
  final manifest = File('${dir.path}/manifest.json');
  if (!manifest.existsSync()) {
    stderr.writeln('ERROR  pack_manifest_invalid  manifest.json がありません: ${manifest.path}');
    exit(1);
  }
  final report = validateContentPack(manifest.readAsStringSync(), (p) {
    final f = File('${dir.path}/$p');
    return f.existsSync() ? f.readAsStringSync() : null;
  });
  for (final i in report.issues) {
    stdout.writeln(i);
  }
  final m = report.manifest;
  if (m != null) {
    stdout.writeln('${m.id} (${m.country}/${m.locale}/${m.subject}/学年 ${m.grades.join(',')}) v${m.contentVersion}: '
        '${report.counts.entries.map((e) => '${e.key} ${e.value}').join('・')}');
  }
  exit(report.hasErrors ? 1 : 0);
}
