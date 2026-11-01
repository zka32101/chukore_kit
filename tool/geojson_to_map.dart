// GeoJSON（Polygon・MultiPolygon の FeatureCollection）を地図データ（MapPack）に変換する。
// 使い方: `dart run tool/geojson_to_map.dart <in.geojson> <out.json> <id> <attribution> [idProperty] [labelProperty] [scale]`
// 例: `dart run tool/geojson_to_map.dart world.geojson world_map.json world "Natural Earth（パブリックドメイン）"`
// 変換後は `tool/simplify_map.dart` で簡略化し、`tool/validate_map.dart` で検証する。
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.length < 4 || args.length > 7) {
    stderr.writeln('usage: dart run tool/geojson_to_map.dart <in.geojson> <out.json> <id> <attribution> [idProperty] [labelProperty] [scale]');
    exit(64);
  }
  final MapPack pack;
  try {
    pack = mapPackFromGeoJson(
      File(args[0]).readAsStringSync(),
      id: args[2],
      attribution: args[3],
      idProperty: args.length > 4 ? args[4] : 'ADM0_A3',
      labelProperty: args.length > 5 ? args[5] : 'NAME_JA',
      scale: args.length > 6 ? int.parse(args[6]) : 1000,
    );
  } on FormatException catch (e) {
    stderr.writeln('ERROR  malformed  ${e.message}');
    exit(1);
  }
  File(args[1]).writeAsStringSync(pack.encode());
  stdout.writeln('${pack.id}: 領域 ${pack.regions.length}・頂点 ${pack.vertexCount}・${pack.encodedBytes} バイト');
  final issues = validateMapPack(pack);
  for (final i in issues) {
    stdout.writeln(i);
  }
  exit(issues.any((i) => i.isError) ? 1 : 0);
}
