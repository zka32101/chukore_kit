import 'dart:convert';
import 'dart:typed_data';

import '../bank/question_bank.dart';
import 'character.dart';

/// キャラとバッジの画像（`art.json`）と、ダウンロードの部品。
/// 画像は容量が大きいので、アプリに全部は入れず、**必要になったときにダウンロード**して端末に保存できる
/// （はじめの 1 匹などの大事なものだけをアプリに入れる＝`bundled`）。
///
/// 守ること: ダウンロードは**ただの取得（GET）だけ**で、子どもの情報・端末の識別子を一切送らない
/// （URL は固定。クエリ文字列を付けない）。取った画像は**ハッシュと大きさを確かめて**から使う。
/// 取れなかったときは仮の絵に差し替えて、勉強は止めない。**ダウンロードは既定で無効**
/// （法務確認が終わるまで有効にしない。`docs/design_principles.md` §2-9）。

/// 画像 1 枚。
class ArtEntry {
  const ArtEntry({
    required this.id,
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.format,
    required this.bundled,
  });

  final String id;

  /// [ArtManifest.baseUrl] からの相対パス。
  final String path;

  /// 中身の SHA-256（小文字 16 進 64 文字）。
  final String sha256;
  final int bytes;

  /// `png`・`webp`・`svg`。
  final String format;

  /// アプリに入れてある（ダウンロード不要）。
  final bool bundled;
}

class ArtManifest {
  const ArtManifest({required this.baseUrl, required this.arts});

  /// ダウンロード元（https。クエリ文字列なし）。
  final String baseUrl;
  final Map<String, ArtEntry> arts;

  /// 1 枚の上限（バイト）。
  static const maxBytes = 2 * 1024 * 1024;
  static const formats = {'png', 'webp', 'svg'};

  Uri urlOf(ArtEntry e) =>
      Uri.parse('${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}${e.path}');

  /// `{"version":1,"baseUrl":"https://…/","arts":[{id,path,sha256,bytes,format,bundled}]}`。読めなければ [FormatException]。
  factory ArtManifest.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('画像の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) {
      throw const FormatException('画像の JSON はオブジェクトです');
    }
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final base = j['baseUrl'];
    if (base is! String || base.isEmpty) {
      throw const FormatException('baseUrl が必要です');
    }
    final arts = <String, ArtEntry>{};
    for (final raw in (j['arts'] as List? ?? const [])) {
      final a = Map<String, dynamic>.from(raw as Map);
      String str(String k) {
        final v = a[k];
        if (v is! String || v.isEmpty) throw FormatException('画像: $k は空でない文字列');
        return v;
      }

      final id = str('id');
      final bytes = a['bytes'];
      if (bytes is! int) throw FormatException('$id: bytes は整数');
      if (arts.containsKey(id)) throw FormatException('id が重複しています: $id');
      arts[id] = ArtEntry(
        id: id,
        path: str('path'),
        sha256: str('sha256'),
        bytes: bytes,
        format: str('format'),
        bundled: a['bundled'] == true,
      );
    }
    return ArtManifest(baseUrl: base, arts: arts);
  }
}

/// 画像の検証。
/// エラー: `art_base_invalid`（https 以外・クエリあり）・`art_path_invalid`（`..`・スキーム・先頭の `/`）・`art_sha_invalid`・`art_size_invalid`（1〜2 MB）・
/// `art_format_invalid`・`art_missing`（キャラ・バッジが使う絵が無い）。警告: `art_unused`（どこからも使われない画像）。
List<ValidationIssue> validateArt(ArtManifest m, {CharacterSet? characters}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  final base = Uri.tryParse(m.baseUrl);
  if (base == null ||
      base.scheme != 'https' ||
      base.host.isEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    err(
      'art_base_invalid',
      'baseUrl',
      'baseUrl は https の URL（クエリ・フラグメントなし）にしてください',
    );
  }
  for (final e in m.arts.values) {
    if (e.path.startsWith('/') ||
        e.path.contains('..') ||
        e.path.contains(':') ||
        e.path.contains('?') ||
        e.path.contains('#')) {
      err('art_path_invalid', e.id, '相対パスにしてください: ${e.path}');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(e.sha256)) {
      err('art_sha_invalid', e.id, 'sha256 は小文字 16 進 64 文字');
    }
    if (e.bytes < 1 || e.bytes > ArtManifest.maxBytes) {
      err(
        'art_size_invalid',
        e.id,
        '大きさは 1〜${ArtManifest.maxBytes} バイト（${e.bytes}）',
      );
    }
    if (!ArtManifest.formats.contains(e.format)) {
      err('art_format_invalid', e.id, '形式は png・webp・svg: ${e.format}');
    }
  }
  if (characters != null) {
    final used = <String>{
      for (final c in characters.characters) ...[
        for (final s in c.stages) s.artId,
        for (final f in c.forms) f.artId,
      ],
      for (final b in characters.badges) b.artId,
    };
    for (final id in used) {
      if (!m.arts.containsKey(id)) err('art_missing', id, '画像 $id がありません');
    }
    for (final id in m.arts.keys.toSet().difference(used)) {
      issues.add(
        ValidationIssue(
          IssueSeverity.warning,
          'art_unused',
          id,
          'どこからも使われていない画像です',
        ),
      );
    }
  }
  return issues;
}

/// 画像を取りに行く部品（アプリが実装する。ネットワークの失敗は null）。**URL 以外は何も送らない**。
abstract class ArtFetcher {
  Future<Uint8List?> get(Uri url);
}

/// 取った画像を端末に保存する部品（アプリが実装する）。
abstract class ArtCache {
  Future<Uint8List?> read(String id);
  Future<void> write(String id, Uint8List data);
}

/// 画像の状態。
enum ArtStatus {
  /// アプリに入っている。
  bundled,

  /// 端末に保存済み（中身を確かめた）。
  cached,

  /// いまダウンロードして保存した。
  downloaded,

  /// ダウンロードが無効（既定）。仮の絵を出す。
  disabled,

  /// 取れなかった・中身が違った。仮の絵を出す（勉強は止めない）。
  failed,
}

/// 画像をそろえる。まず保存済みを確かめ、足りなければ（有効なら）ダウンロードして、ハッシュと大きさを確かめてから保存する。
Future<Map<String, ArtStatus>> ensureArt(
  ArtManifest manifest,
  Iterable<String> ids, {
  required ArtFetcher fetcher,
  required ArtCache cache,
  bool downloadEnabled = false,
}) async {
  final out = <String, ArtStatus>{};
  for (final id in ids) {
    final e = manifest.arts[id];
    if (e == null) {
      out[id] = ArtStatus.failed;
      continue;
    }
    if (e.bundled) {
      out[id] = ArtStatus.bundled;
      continue;
    }
    final have = await cache.read(id);
    if (have != null && _matches(e, have)) {
      out[id] = ArtStatus.cached;
      continue;
    }
    if (!downloadEnabled) {
      out[id] = ArtStatus.disabled;
      continue;
    }
    final got = await fetcher.get(manifest.urlOf(e));
    if (got == null || !_matches(e, got)) {
      out[id] = ArtStatus.failed;
      continue;
    }
    await cache.write(id, got);
    out[id] = ArtStatus.downloaded;
  }
  return out;
}

bool _matches(ArtEntry e, Uint8List data) =>
    data.length == e.bytes &&
    data.length <= ArtManifest.maxBytes &&
    sha256Hex(data) == e.sha256;

/// SHA-256（小文字 16 進）。
String sha256Hex(List<int> data) {
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  final h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final padLen = ((data.length + 9 + 63) ~/ 64) * 64;
  final msg = Uint8List(padLen)..setRange(0, data.length, data);
  msg[data.length] = 0x80;
  final bitLen = data.length * 8;
  for (var i = 0; i < 8; i++) {
    msg[padLen - 1 - i] = (bitLen >> (8 * i)) & 0xff;
  }
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;
  final w = List<int>.filled(64, 0);
  for (var off = 0; off < padLen; off += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] =
          (msg[off + 4 * i] << 24) |
          (msg[off + 4 * i + 1] << 16) |
          (msg[off + 4 * i + 2] << 8) |
          msg[off + 4 * i + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0],
        b = h[1],
        c = h[2],
        d = h[3],
        e = h[4],
        f = h[5],
        g = h[6],
        hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + hh) & 0xffffffff;
  }
  return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}
