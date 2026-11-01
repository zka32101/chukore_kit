// 地図データを検証する。使い方: `dart run tool/validate_map.dart <map_pack.json> [maxVertices] [maxBytes]`
// エラーがあれば終了コード 1（警告だけなら 0）。形式は docs/shakai_foundation.md §3.3。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.isEmpty || args.length > 3) {
    stderr.writeln('usage: dart run tool/validate_map.dart <map_pack.json> [maxVertices] [maxBytes]');
    exit(64);
  }
  final MapPack pack;
  try {
    pack = MapPack.parse(File(args[0]).readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('ERROR  malformed  ${e.message}');
    exit(1);
  }
  final issues = validateMapPack(
    pack,
    maxVertices: args.length > 1 ? int.parse(args[1]) : 20000,
    maxBytes: args.length > 2 ? int.parse(args[2]) : 150000,
  );
  for (final i in issues) {
    stdout.writeln(i);
  }
  stdout.writeln('${pack.id}: 領域 ${pack.regions.length}・頂点 ${pack.vertexCount}・${pack.encodedBytes} バイト');
  exit(issues.any((i) => i.isError) ? 1 : 0);
}
