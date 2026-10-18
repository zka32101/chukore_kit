import '../models/models.dart';

/// 通知を出すのによい時間帯の提案。
class NudgeHour {
  const NudgeHour({required this.hour, required this.share, required this.days, required this.clamped});

  /// 通知を出す時（0〜23、ローカル時刻）。いつも学習する時間帯の頭。
  final int hour;

  /// 観察した学習日のうち、この時刻の前後 1 時間（計 3 時間）に学習した日の割合（0〜1）。
  final double share;

  /// 観察した学習日の数。
  final int days;

  /// いつもの時間帯が通知に向かない遅い時間・早い時間だったので、許す範囲に寄せた。
  final bool clamped;
}

/// 通知を出す時間帯の既定（提案できないときに使う）。
const defaultNudgeHour = 18;

/// 回答履歴から、その子がいつも学習する時間帯を求め、通知を出す時を提案する。端末内だけで計算し、
/// 履歴は外に出さない。時刻はローカル時刻（履歴の `answeredAt` を `toLocal()` で読む）。
///
/// - 直近 [recentDays] 日の学習日を数える。1 日に何問解いても 1 日（その日の時間帯ごとに 1 回）。
///   問題数の多い日に偏らない
/// - 学習日が [minDays] 日に満たない、またはどの時間帯にも偏りが無い（前後 1 時間に入る日の割合が
///   [minShare] 未満）ときは null。呼び出し側は [defaultNudgeHour] などを使う
/// - 提案する時は [earliestHour]〜[latestHour] の範囲に寄せる（夜遅く・早朝に通知しない）。
///   寄せたときは [NudgeHour.clamped] が真
/// - [forDate] を渡すと、その日と同じ種類（平日／土日）の学習日だけで求める。
///   同じ種類の学習日が [minDays] 日に満たなければ、全体で求める
///
/// 同じ入力なら同じ結果。
NudgeHour? suggestNudgeHour(
  Iterable<Attempt> attempts, {
  required DateTime now,
  DateTime? forDate,
  int recentDays = 28,
  int minDays = 5,
  double minShare = 0.4,
  int earliestHour = 7,
  int latestHour = 20,
}) {
  final today = dateOnly(now);
  final from = today.subtract(Duration(days: recentDays - 1));

  // 学習した (日, 時) を 1 回ずつ数える
  final slots = <DateTime, Set<int>>{};
  for (final a in attempts) {
    final t = a.answeredAt.toLocal();
    final d = dateOnly(t);
    if (d.isBefore(from) || d.isAfter(today)) continue;
    (slots[d] ??= {}).add(t.hour);
  }

  bool weekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
  var days = slots.keys.toList()..sort();
  if (forDate != null) {
    final same = [for (final d in days) if (weekend(d) == weekend(forDate)) d];
    if (same.length >= minDays) days = same;
  }
  if (days.length < minDays) return null;

  // 時刻 h の得点: h 時に学習した日の数。前後 1 時間の学習も半分として数えて、時間帯のゆれをならす
  final count = List.filled(24, 0);
  for (final d in days) {
    for (final h in slots[d]!) {
      count[h]++;
    }
  }
  double score(int h) =>
      count[h] + 0.5 * count[(h + 23) % 24] + 0.5 * count[(h + 1) % 24];
  var best = 0;
  for (var h = 1; h < 24; h++) {
    if (score(h) > score(best)) best = h;
  }

  // 偏り: 前後 1 時間（best-1〜best+1）のどこかに学習した日の割合
  final near = {(best + 23) % 24, best, (best + 1) % 24};
  final hit = days.where((d) => slots[d]!.any(near.contains)).length;
  final share = hit / days.length;
  if (share < minShare) return null;

  final hour = best.clamp(earliestHour, latestHour);
  return NudgeHour(hour: hour, share: share, days: days.length, clamped: hour != best);
}
