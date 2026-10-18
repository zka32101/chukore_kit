import 'dart:convert';

import '../models/models.dart';
import 'attempt_store.dart';

/// 学習データ（回答履歴）の書き出しと取り込み。機種変更やアプリの入れ直しの引き継ぎ用で、
/// クラウドや通信は使わない。ファイルの受け渡し（共有・保存）はアプリ側。
///
/// ファイルに入るのは回答履歴だけ（問題ID・単元ID・正誤・選んだ選択肢・時刻・所要時間・モード・自信度・間違えた理由・見たヒントの数）。
/// 名前・ID・メール・生年月日は入らない。時刻は UTC。
/// テスト日の予定や範囲はアプリが持つので、ここには含めない。
class AttemptBackup {
  const AttemptBackup._();

  static const formatName = 'chukore_kit.backup';

  /// ファイル形式の版。項目を足すときは上げ、古い版を読む処理を残す。
  static const version = 1;

  /// [attempts] を JSON 文字列にする。[now] は書き出した時刻（テスト用に差し替え可）。
  static String export(List<Attempt> attempts, {DateTime? now}) {
    final rows = [for (final a in attempts) _toJson(a)];
    return jsonEncode({
      'format': formatName,
      'version': version,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'count': rows.length,
      'checksum': _checksum(jsonEncode(rows)),
      'attempts': rows,
    });
  }

  /// JSON 文字列から回答履歴を読む。形が不正・途中で切れている・新しい版なら [FormatException]。
  /// 1 件でも不正なら全体を受け付けない（一部だけ戻る状態を作らない）。
  static List<Attempt> parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw const FormatException('バックアップのファイルが読めません（壊れているか、別のファイルです）');
    }
    if (root is! Map || root['format'] != formatName) {
      throw const FormatException('ちゅうコレ！のバックアップファイルではありません');
    }
    final v = root['version'];
    if (v is! int || v < 1) throw const FormatException('バックアップの版が不正です');
    if (v > version) throw FormatException('新しい版のバックアップです（$v > $version）。アプリを更新してください');
    final rows = root['attempts'];
    if (rows is! List) throw const FormatException('バックアップに回答履歴がありません');
    if (root['count'] != rows.length) {
      throw const FormatException('バックアップが途中で切れているようです（件数が合いません）');
    }
    if (root['checksum'] != _checksum(jsonEncode(rows))) {
      throw const FormatException('バックアップの内容が変わっています（チェックが合いません）');
    }
    return [for (var i = 0; i < rows.length; i++) _fromJson(rows[i], i)];
  }

  /// [source] を読み、[store] に無い回答だけを足す。同じファイルを何度取り込んでも二重にならない。
  static Future<BackupImportResult> importInto(AttemptStore store, String source) async {
    final incoming = parse(source);
    final existing = {for (final a in await store.query()) _key(a)};
    var added = 0, duplicates = 0;
    for (final a in incoming) {
      if (existing.add(_key(a))) {
        await store.add(a);
        added++;
      } else {
        duplicates++;
      }
    }
    return BackupImportResult(added: added, duplicates: duplicates);
  }

  /// 同じ回答かどうかの判定。同じ問題を同じ時刻に同じ答えで解いた記録は 1 件とみなす。
  static String _key(Attempt a) =>
      '${a.questionId}|${a.unitId}|${a.answeredAt.toUtc().microsecondsSinceEpoch}|${a.chosenId}|${a.correct}|${a.mode}';

  static Map<String, Object?> _toJson(Attempt a) => {
        'q': a.questionId,
        'u': a.unitId,
        'ok': a.correct,
        if (a.chosenId != null) 'c': a.chosenId,
        't': a.answeredAt.toUtc().toIso8601String(),
        'ms': a.elapsedMs,
        'm': a.mode,
        if (a.confident != null) 'cf': a.confident,
        if (a.reason != null) 'rs': a.reason!.name,
        if (a.hintsUsed > 0) 'hu': a.hintsUsed,
      };

  static Attempt _fromJson(Object? j, int index) {
    FormatException bad(String why) => FormatException('バックアップの ${index + 1} 件目が不正です（$why）');
    if (j is! Map) throw bad('形');
    final q = j['q'], u = j['u'], ok = j['ok'], c = j['c'], t = j['t'], ms = j['ms'], m = j['m'], cf = j['cf'], rs = j['rs'], hu = j['hu'];
    if (q is! String || q.isEmpty) throw bad('問題ID');
    if (u is! String || u.isEmpty) throw bad('単元ID');
    if (ok is! bool) throw bad('正誤');
    if (c != null && c is! String) throw bad('選択肢');
    final time = t is String ? DateTime.tryParse(t) : null;
    if (time == null) throw bad('時刻');
    if (ms is! int || ms < 0) throw bad('所要時間');
    if (m is! String || m.isEmpty) throw bad('モード');
    if (cf != null && cf is! bool) throw bad('自信度');
    if (hu != null && (hu is! int || hu < 0 || hu > 20)) throw bad('ヒントの数');
    final reason = rs == null ? null : LossReason.values.where((x) => x.name == rs).firstOrNull;
    if (rs != null && reason == null) throw bad('間違えた理由');
    return Attempt(
      questionId: q,
      unitId: u,
      correct: ok,
      chosenId: c as String?,
      answeredAt: time.toUtc(),
      elapsedMs: ms,
      mode: m,
      confident: cf as bool?,
      reason: reason,
      hintsUsed: (hu as int?) ?? 0,
    );
  }

  /// 32 ビットの FNV-1a。改ざん防止ではなく、途中で切れた・書き換わったことに気づくための確認。
  static String _checksum(String s) {
    var h = 0x811c9dc5;
    for (final unit in utf8.encode(s)) {
      h = ((h ^ unit) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

/// 取り込みの結果。
class BackupImportResult {
  const BackupImportResult({required this.added, required this.duplicates});

  /// 新しく足した件数。
  final int added;

  /// すでにあったので足さなかった件数。
  final int duplicates;
}
