import 'dart:convert';

import 'timeline.dart';

/// 時代 1 つ。[from]〜[to] の年（西暦。紀元前は負の値。両端を含む）。西暦 0 年は無い。
class EraSpan {
  const EraSpan(this.era, this.from, this.to);

  final String era;
  final int from, to;
}

/// 西暦 [year] の世紀。1 年〜100 年が 1 世紀、紀元前は -1（前 1 世紀: -100〜-1 年）のように負の値。
/// 0 年は無いので null。
int? centuryOf(int year) {
  if (year == 0) return null;
  return year > 0 ? (year + 99) ~/ 100 : -((-year + 99) ~/ 100);
}

/// 時代区分の表（`{"version":1,"eras":[{"era":"弥生","from":-300,"to":250}, …]}`）。
/// 時代の ID（名前）はコンテンツ側。古い順に並び、重ならないこと（すき間は可）。
class EraTable {
  const EraTable._(this.eras);

  /// 古い順。
  final List<EraSpan> eras;

  /// 読めなければ [FormatException]。
  factory EraTable.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('時代区分の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('時代区分の JSON はオブジェクトです');
    if (j.keys.any((k) => k != 'version' && k != 'eras')) throw const FormatException('時代区分: version と eras だけ');
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final raw = j['eras'];
    if (raw is! List || raw.isEmpty) throw const FormatException('eras が必要です');
    final out = <EraSpan>[];
    for (final e in raw) {
      if (e is! Map || e.keys.any((k) => k != 'era' && k != 'from' && k != 'to')) {
        throw const FormatException('時代は era・from・to だけ');
      }
      final era = e['era'], from = e['from'], to = e['to'];
      if (era is! String || era.isEmpty) throw const FormatException('era は空でない文字列');
      if (from is! int || to is! int) throw FormatException('$era: from・to は整数の年');
      if (from == 0 || to == 0) throw FormatException('$era: 西暦 0 年は無い');
      if (from > to) throw FormatException('$era: from が to より後');
      if (out.any((s) => s.era == era)) throw FormatException('時代名が重複: $era');
      if (out.isNotEmpty && from <= out.last.to) throw FormatException('$era: 前の時代と重なる、または古い順でない');
      out.add(EraSpan(era, from, to));
    }
    return EraTable._(out);
  }

  /// [year] の時代の位置（古い順の 0 始まり）。表にない年は null。
  int? indexOf(int year) {
    for (var i = 0; i < eras.length; i++) {
      if (year >= eras[i].from && year <= eras[i].to) return i;
    }
    return null;
  }

  /// [year] の時代名。表にない年は null。
  String? eraOf(int year) {
    final i = indexOf(year);
    return i == null ? null : eras[i].era;
  }

  /// 年 [a] の時代が [b] の時代より前なら -1、同じなら 0、後なら 1。どちらかが表にない年なら null。
  int? compareEras(int a, int b) {
    final x = indexOf(a), y = indexOf(b);
    return x == null || y == null ? null : x.compareTo(y);
  }

  /// 表にない年の出来事の ID（年表問題の検証用。時代名を付けられない出来事）。入力の順。
  List<String> eventsOutsideEras(Iterable<TimelineEvent> events) => [
    for (final e in events)
      if (indexOf(e.year) == null) e.id,
  ];
}
