import 'dart:convert';

import '../guardian/age_policy.dart';
import '../models/models.dart';

/// 毎年くり返す、試験の時期（月日の範囲）。年をまたぐ範囲（12/20〜1/10 など）も持てる。
class ExamWindow {
  const ExamWindow({
    required this.id,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
  });

  /// 英小文字・数字・`_` の名前（例: `midterm1`）。文言はアプリ側で対応づける。
  final String id;
  final int startMonth, startDay, endMonth, endDay;

  /// 終わりが始まりより前の月日＝翌年にまたぐ。
  bool get wraps => endMonth * 100 + endDay < startMonth * 100 + startDay;

  /// [year] に始まる回の始まりと終わり（日付のみ。2/29 は平年なら 2/28）。
  (DateTime, DateTime) instanceIn(int year) =>
      (_date(year, startMonth, startDay), _date(wraps ? year + 1 : year, endMonth, endDay));
}

DateTime _date(int year, int month, int day) {
  final last = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, day > last ? last : day);
}

/// 試験の時期の 1 回分（ある年の実際の日付）。
class ExamWindowInstance {
  const ExamWindowInstance(this.window, this.start, this.end, this.daysUntilStart);

  final ExamWindow window;
  final DateTime start, end;

  /// 始まりまでの日数。すでに始まっていれば 0 以下。
  final int daysUntilStart;

  /// 今日がその時期の中か。
  bool get active => daysUntilStart <= 0;
}

/// 国・地域ごとの、試験の時期のカレンダー（データ）。**中身は暫定で、現地の学校暦の確認のあとに入れる。**
///
/// ```json
/// {
///   "regions": {
///     "BR": {"windows": [{"id": "bim1", "start": "04-10", "end": "04-25"}]}
///   }
/// }
/// ```
///
/// - 用途: 点を聞く時期や、公開・訴求の時期を決める材料にする。個人のテスト日の代わりではない（テスト日は本人が登録する）
/// - 書き間違い（未知のキー・月日・地域コード・重複する `id`）は黙って無視せず [FormatException]
class ExamCalendar {
  const ExamCalendar([this.regions = const {}]);

  /// 地域コード（大文字 2 文字）→ 時期の一覧。
  final Map<String, List<ExamWindow>> regions;

  /// 地域コード（`BR`・`pt-BR` など）の時期。表に無ければ空。
  List<ExamWindow> forRegion(String regionOrLocale) => regions[AgePolicy.regionCode(regionOrLocale)] ?? const [];

  /// [date] を含む時期。
  List<ExamWindow> activeOn(String regionOrLocale, DateTime date) => [
    for (final w in forRegion(regionOrLocale))
      if (_instances(w, date).any((i) => !dateOnly(date).isBefore(i.$1) && !dateOnly(date).isAfter(i.$2))) w,
  ];

  /// [today] 以降の時期を、始まりの早い順に [count] 件（今まさに中の時期を含む。中の時期が先）。
  List<ExamWindowInstance> upcoming(String regionOrLocale, DateTime today, {int count = 1}) {
    if (count < 1) throw ArgumentError('count must be positive');
    final day = dateOnly(today);
    final out = <ExamWindowInstance>[];
    for (final w in forRegion(regionOrLocale)) {
      for (final i in _instances(w, day)) {
        if (i.$2.isBefore(day)) continue;
        out.add(ExamWindowInstance(w, i.$1, i.$2, i.$1.difference(day).inDays));
      }
    }
    out.sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.window.id.compareTo(b.window.id);
    });
    return out.take(count).toList();
  }

  // [date] の前年・当年・翌年に始まる回。
  static List<(DateTime, DateTime)> _instances(ExamWindow w, DateTime date) => [
    for (final y in [date.year - 1, date.year, date.year + 1]) w.instanceIn(y),
  ];

  factory ExamCalendar.parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('試験カレンダーの JSON が読めません: ${e.message}');
    }
    return ExamCalendar.fromJson(root);
  }

  factory ExamCalendar.fromJson(Object? root) {
    if (root is! Map) throw const FormatException('試験カレンダー: 最上位はオブジェクトにしてください');
    for (final k in root.keys) {
      if (k != 'regions' && k != 'note') throw FormatException('試験カレンダー: 未知のキー "$k"');
    }
    final rj = root['regions'];
    if (rj == null) return const ExamCalendar();
    if (rj is! Map) throw const FormatException('試験カレンダー: regions はオブジェクトにしてください');
    final regions = <String, List<ExamWindow>>{};
    for (final e in rj.entries) {
      final key = e.key.toString();
      if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(key)) throw FormatException('試験カレンダー: 地域コードは英字 2 文字です ("$key")');
      final code = key.toUpperCase();
      if (regions.containsKey(code)) throw FormatException('試験カレンダー: 地域 "$code" が重複しています');
      regions[code] = _windows(e.value, code);
    }
    return ExamCalendar(regions);
  }

  static List<ExamWindow> _windows(Object? json, String where) {
    if (json is! Map || json.keys.any((k) => k != 'windows')) {
      throw FormatException('試験カレンダー($where): {"windows": [...]} の形にしてください');
    }
    final list = json['windows'];
    if (list is! List) throw FormatException('試験カレンダー($where): windows は配列です');
    final ids = <String>{};
    final out = <ExamWindow>[];
    for (final w in list) {
      if (w is! Map || w.keys.any((k) => k != 'id' && k != 'start' && k != 'end')) {
        throw FormatException('試験カレンダー($where): 各時期は {id, start, end} です');
      }
      final id = w['id'];
      if (id is! String || !RegExp(r'^[a-z][a-z0-9_]{0,23}$').hasMatch(id)) {
        throw FormatException('試験カレンダー($where): id は英小文字・数字・_ です ($id)');
      }
      if (!ids.add(id)) throw FormatException('試験カレンダー($where): id "$id" が重複しています');
      final (sm, sd) = _monthDay(w['start'], '$where/$id start');
      final (em, ed) = _monthDay(w['end'], '$where/$id end');
      out.add(ExamWindow(id: id, startMonth: sm, startDay: sd, endMonth: em, endDay: ed));
    }
    return out;
  }

  static (int, int) _monthDay(Object? v, String where) {
    final m = v is String ? RegExp(r'^(\d{2})-(\d{2})$').firstMatch(v) : null;
    if (m == null) throw FormatException('試験カレンダー($where): "MM-DD" の形にしてください ($v)');
    final month = int.parse(m[1]!), day = int.parse(m[2]!);
    if (month < 1 || month > 12) throw FormatException('試験カレンダー($where): 月が範囲外です ($v)');
    final max = DateTime.utc(2024, month + 1, 0).day; // 2024 はうるう年: 2/29 は許す
    if (day < 1 || day > max) throw FormatException('試験カレンダー($where): 日が範囲外です ($v)');
    return (month, day);
  }
}
