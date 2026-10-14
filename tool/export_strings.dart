// 翻訳確認用の CSV を書き出す。使い方: `dart run tool/export_strings.dart [出力先]`
// 既定の出力先は docs/translation_review.csv（Excel で文字化けしないよう BOM つき）。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  final out = File(args.isNotEmpty ? args.first : 'docs/translation_review.csv');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('﻿${stringsCatalogCsv()}');
  stdout.writeln('wrote ${out.path} (${ChukoreStrings.supported.length} languages)');
}
