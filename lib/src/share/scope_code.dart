import 'dart:convert';
import 'dart:typed_data';

import '../models/models.dart';
import '../scope/unit_tree.dart';

/// 範囲カードの符号。テスト範囲だけを、短い文字列にする（QR にして友達や家族に渡す用）。
///
/// **個人情報を含まない**: 入るのは、教科・単元ツリーの版・どの葉の単元を選んだか・（任意で）テスト日だけ。
/// 名前・ID・メール・成績・匿名UIDは入らない（テストで保証）。
///
/// 形式: `CKS1.<教科>.<ツリーの版>.<ツリーの指紋>.<選んだ葉のビット列(base64url)>[.<テスト日 yyyymmdd>]`
/// 葉の単元を木の順に並べたビット列なので、単元IDが長くても短くなる。送り手と受け手の単元ツリーが
/// 同じ版・同じ中身のときだけ読める（指紋で確かめる）。
const scopeCodePrefix = 'CKS1';

/// 符号を読んだ結果。
sealed class ScopeDecodeResult {
  const ScopeDecodeResult();
}

class ScopeDecoded extends ScopeDecodeResult {
  const ScopeDecoded({required this.subject, required this.unitIds, this.testDate});

  final String subject;

  /// 選んだ葉の単元ID（木の順）。
  final List<String> unitIds;
  final DateTime? testDate;
}

enum ScopeError {
  /// 形が違う・壊れている。
  malformed,

  /// 知らない版の符号（アプリが古い）。
  unsupportedVersion,

  /// 単元ツリーの版や中身が違う（送り手とアプリの版がずれている）。
  treeMismatch,

  /// 教科が違う。
  subjectMismatch,

  /// 単元が1つも選ばれていない。
  empty,
}

class ScopeDecodeFailure extends ScopeDecodeResult {
  const ScopeDecodeFailure(this.error);

  final ScopeError error;
}

final _subjectPattern = RegExp(r'^[a-z][a-z0-9]{0,15}$');

/// 単元ツリーの指紋（FNV-1a 32bit）。単元IDの並びが同じなら同じ。
String treeFingerprint(UnitTree tree) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(tree.allLeaves().map((u) => u.id).join('\n'))) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

String? _treeSubject(UnitTree tree) {
  final subjects = {for (final u in tree.allLeaves()) u.subject};
  return subjects.length == 1 ? subjects.single : null;
}

/// 選んだ単元（親を選べば配下の葉すべて）を符号にする。
/// 教科は単元ツリーから決まる（1つの教科だけのツリーが前提）。[testDate] は任意で、日付だけを入れる。
String encodeScope(UnitTree tree, {required Iterable<String> unitIds, DateTime? testDate}) {
  final subject = _treeSubject(tree);
  if (subject == null || !_subjectPattern.hasMatch(subject)) {
    throw ArgumentError('単元ツリーの教科が1つの小文字英数字（先頭は英字・16字まで）ではありません: $subject');
  }
  final leaves = tree.allLeaves();
  final selected = {for (final u in tree.resolveLeaves(unitIds)) u.id};
  if (selected.isEmpty) throw ArgumentError('選んだ単元がありません');

  final bytes = Uint8List((leaves.length + 7) ~/ 8);
  for (var i = 0; i < leaves.length; i++) {
    if (selected.contains(leaves[i].id)) bytes[i >> 3] |= 1 << (i & 7);
  }
  final parts = [
    scopeCodePrefix,
    subject,
    '${tree.version}',
    treeFingerprint(tree),
    base64Url.encode(bytes).replaceAll('=', ''),
    if (testDate != null) _ymd(testDate),
  ];
  return parts.join('.');
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

/// 符号を読む。単元ツリーの版・中身・教科が合わないときは、理由つきで失敗を返す。
ScopeDecodeResult decodeScope(String code, UnitTree tree) {
  const bad = ScopeDecodeFailure(ScopeError.malformed);
  final parts = code.trim().split('.');
  if (parts.isEmpty) return bad;
  if (parts.first != scopeCodePrefix) {
    return RegExp(r'^CKS\d+$').hasMatch(parts.first)
        ? const ScopeDecodeFailure(ScopeError.unsupportedVersion)
        : bad;
  }
  if (parts.length != 5 && parts.length != 6) return bad;

  final subject = parts[1];
  final version = int.tryParse(parts[2]);
  if (!_subjectPattern.hasMatch(subject) || version == null) return bad;
  if (version != tree.version || parts[3] != treeFingerprint(tree)) {
    return const ScopeDecodeFailure(ScopeError.treeMismatch);
  }
  if (subject != _treeSubject(tree)) return const ScopeDecodeFailure(ScopeError.subjectMismatch);

  final leaves = tree.allLeaves();
  final Uint8List bytes;
  try {
    final b64 = parts[4];
    bytes = base64Url.decode(b64.padRight((b64.length + 3) & ~3, '='));
  } on FormatException {
    return bad;
  }
  if (bytes.length != (leaves.length + 7) ~/ 8) return bad;
  // 葉の数を超えるビットは 0 でなければならない
  for (var i = leaves.length; i < bytes.length * 8; i++) {
    if (bytes[i >> 3] & (1 << (i & 7)) != 0) return bad;
  }
  final ids = [
    for (var i = 0; i < leaves.length; i++)
      if (bytes[i >> 3] & (1 << (i & 7)) != 0) leaves[i].id,
  ];
  if (ids.isEmpty) return const ScopeDecodeFailure(ScopeError.empty);

  DateTime? date;
  if (parts.length == 6) {
    final s = parts[5];
    if (!RegExp(r'^\d{8}$').hasMatch(s)) return bad;
    final y = int.parse(s.substring(0, 4)), m = int.parse(s.substring(4, 6)), d = int.parse(s.substring(6, 8));
    final parsed = DateTime.utc(y, m, d);
    // 2月30日のような存在しない日付は弾く
    if (parsed.year != y || parsed.month != m || parsed.day != d) return bad;
    date = dateOnly(parsed);
  }
  return ScopeDecoded(subject: subject, unitIds: ids, testDate: date);
}
