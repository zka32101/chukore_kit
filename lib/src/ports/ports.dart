/// アプリ側が実装して差し替える入口（基盤は実装を持たず、契約だけを決める）。
library;

/// 現在時刻。テストや日付をまたぐ検証で差し替える。
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this.current);
  DateTime current;
  @override
  DateTime now() => current;
}

/// 同意の種類。
enum ConsentKind { guardianConsent, notifications, anonymousStats }

/// 同意の保存先。**既定は「同意なし」**。取り消したら以後は使わない。
abstract class ConsentStore {
  Future<bool> isGranted(ConsentKind kind);

  /// 同意した（または取り消した）。[version] は同意文の版（項目が変わったら再同意をとる）。
  Future<void> set(ConsentKind kind, bool granted, {int version = 1});

  /// 同意した版。同意していなければ null。
  Future<int?> grantedVersion(ConsentKind kind);
}

class InMemoryConsentStore implements ConsentStore {
  final _versions = <ConsentKind, int>{};

  @override
  Future<bool> isGranted(ConsentKind kind) async => _versions.containsKey(kind);

  @override
  Future<void> set(ConsentKind kind, bool granted, {int version = 1}) async {
    if (granted) {
      _versions[kind] = version;
    } else {
      _versions.remove(kind);
    }
  }

  @override
  Future<int?> grantedVersion(ConsentKind kind) async => _versions[kind];
}

/// 予約する通知 1 件。文言は [messageKey]（`ChukoreStrings` のキー）で持ち、本文は持たない。
class ScheduledNotice {
  const ScheduledNotice({required this.id, required this.at, required this.messageKey});
  final String id;
  final DateTime at;
  final String messageKey;
}

/// 通知の予約。アプリが OS の仕組みに繋ぐ。呼ぶ前に [ConsentKind.notifications] を確かめるのはアプリの役目。
abstract class NotificationScheduler {
  Future<void> schedule(ScheduledNotice notice);
  Future<void> cancel(String id);
  Future<void> cancelAll();
}

/// 課金の権利（有料機能が使えるか）の読み取り。基盤は課金の仕組みを知らない。
abstract class EntitlementReader {
  Future<bool> hasEntitlement(String key);
}

/// 学習日の境界。日付が変わる時刻（既定 0 時）を、深夜に勉強する子向けに早朝へずらせる。
///
/// 例: [startHour] が 4 なら、午前 3 時 30 分は前日の学習日。
class StudyDay {
  const StudyDay({this.startHour = 0}) : assert(startHour >= 0 && startHour < 24);
  final int startHour;

  /// [t] が属する学習日（時刻は 0 時）。
  DateTime of(DateTime t) {
    final shifted = t.subtract(Duration(hours: startHour));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
}
