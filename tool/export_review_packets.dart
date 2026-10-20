// ネイティブ確認の依頼用に、言語ごとの確認シート（CSV）と数の読み上げ（TSV）を書き出す。
// 使い方: `dart run tool/export_review_packets.dart [出力先ディレクトリ] [言語タグ ...]`
// 既定の出力先は build/native_review（git の管理外）。言語タグを省略すると全言語。
// 例: `dart run tool/export_review_packets.dart build/native_review pl ar`
// 依頼書は docs/native_review_checklist.md。直してもらった文言は strings.dart に反映して、
// `dart run tool/export_strings.dart` で docs/translation_review.csv を更新する。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args.first : 'build/native_review')..createSync(recursive: true);
  final tags = args.skip(1).toSet();
  final langs = [
    for (final l in ChukoreStrings.supported)
      if (tags.isEmpty || tags.contains(l.tag) || tags.contains(l.languageCode)) l,
  ];
  if (langs.isEmpty) {
    stderr.writeln('該当する言語がありません: ${tags.join(', ')}（例: ${ChukoreStrings.supported.map((l) => l.tag).join(' ')}）');
    exit(64);
  }
  for (final l in langs) {
    // Excel で文字化けしないよう BOM つき
    File('${dir.path}/review_${l.tag}.csv').writeAsStringSync('﻿${reviewPacketCsv(l)}');
    File('${dir.path}/numbers_${l.tag}.tsv').writeAsStringSync('﻿${numberWordsTsv(l)}');
  }
  stdout.writeln('${langs.length} 言語ぶんを ${dir.path} に書きました（review_<言語>.csv と numbers_<言語>.tsv）');
}
