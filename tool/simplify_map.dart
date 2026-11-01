// 地図データを簡略化する（Douglas–Peucker）。
// 使い方: `dart run tool/simplify_map.dart <in.json> <out.json> <tolerance> [minRingArea]`
// tolerance は座標の単位（経緯度なら度）。例: 0.05。minRingArea 未満のリング（小さな島）は落とす。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.length < 3 || args.length > 4) {
    stderr.writeln('usage: dart run tool/simplify_map.dart <in.json> <out.json> <tolerance> [minRingArea]');
    exit(64);
  }
  final MapPack pack;
  try {
    pack = MapPack.parse(File(args[0]).readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('ERROR  malformed  ${e.message}');
    exit(1);
  }
  final out = simplifyMapPack(
    pack,
    tolerance: double.parse(args[2]),
    minRingArea: args.length > 3 ? double.parse(args[3]) : 0,
  );
  File(args[1]).writeAsStringSync(out.encode());
  stdout.writeln('${pack.id}: 頂点 ${pack.vertexCount} → ${out.vertexCount}、${pack.encodedBytes} → ${out.encodedBytes} バイト');
  final issues = validateMapPack(out);
  for (final i in issues) {
    stdout.writeln(i);
  }
  exit(issues.any((i) => i.isError) ? 1 : 0);
}
