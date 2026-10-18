import '../l10n/strings.dart';
import '../models/models.dart';

/// 休憩を勧める理由。優先は [rushing] > [mistakeStreak] > [slowingDown] > [longSession]。
enum BreakReason {
  /// 答えるのが極端に速く、しかも間違えている（あてずっぽうの疑い）。ゆっくり読み直すよう促す。
  rushing,

  /// 続けて何問も間違えた（行き詰まり・疲れ）。
  mistakeStreak,

  /// 学習の途中から、1 問にかかる時間が目に見えて長くなった（集中が切れてきた）。
  slowingDown,

  /// 休まずに長く続けている。
  longSession,
}

/// 休憩の提案。
class BreakSuggestion {
  const BreakSuggestion({required this.reason, required this.minutesIntoSession, required this.breakMinutes});

  final BreakReason reason;

  /// 今の学習（途切れずに続けている区間）を始めてからの分数。
  final int minutesIntoSession;

  /// 休憩の目安の分数。
  final int breakMinutes;

  /// 画面に出す文面（責めない短い文。数字を含まない）。
  String text(ChukoreStrings strings) => switch (reason) {
        BreakReason.rushing => strings.breakRushing,
        BreakReason.mistakeStreak => strings.breakMistakes,
        BreakReason.slowingDown => strings.breakSlowing,
        BreakReason.longSession => strings.breakLong,
      };
}

/// 休憩の提案の設定。値は仮決定（ソフトローンチで検証）。
class BreakConfig {
  const BreakConfig({
    this.maxSessionMinutes = 40,
    this.sessionGap = const Duration(minutes: 30),
    this.mistakeStreak = 4,
    this.slowRatio = 2.0,
    this.minAnswersForSlow = 10,
    this.rushMs = 2000,
    this.rushCount = 5,
    this.cooldown = const Duration(minutes: 15),
    this.breakMinutes = 5,
    this.modes = const {'practice'},
  });

  /// この分数、休まずに続けたら提案する。
  final int maxSessionMinutes;

  /// 回答の間がこれ以上あいたら、別の学習（休んだ）とみなす。
  final Duration sessionGap;

  /// 続けてこの数だけ間違えたら提案する。
  final int mistakeStreak;

  /// 直近 5 問の所要時間の中央値が、学習の最初の 5 問の [slowRatio] 倍以上になったら提案する。
  /// 回答が [minAnswersForSlow] 問に満たないときは見ない。
  final double slowRatio;
  final int minAnswersForSlow;

  /// 直近 [rushCount] 問がすべて [rushMs] ミリ秒未満で、しかも誤答なら提案する。
  final int rushMs, rushCount;

  /// 前に提案してからこの時間は、同じ学習の中で繰り返し提案しない。
  final Duration cooldown;
  final int breakMinutes;

  /// 見る回答の種類。模試や本番の記録（`mock`・`real_test`）は途中で止めないので、既定は練習だけ。
  final Set<String> modes;
}

/// いま休憩を勧めるか。勧めるなら理由つきで返し、勧めないなら null。**勧めるだけ**で、止めたり、
/// 先へ進めなくしたりしない（その扱いは画面側）。回答履歴から、いまの学習（回答の間が [BreakConfig.sessionGap]
/// 未満でつながる最後の区間）だけを見る。同じ入力なら同じ結果。
///
/// - 最後の回答から [BreakConfig.sessionGap] 以上たっていれば、すでに休んでいるので null
/// - 前に提案した時刻 [lastSuggestedAt] から [BreakConfig.cooldown] 以内も null（うるさくしない）
/// - 理由の優先: あてずっぽう（速すぎる誤答が続く）> 続けて間違えた > 途中から遅くなった > 長く続けている
BreakSuggestion? suggestBreak(
  Iterable<Attempt> attempts, {
  required DateTime now,
  DateTime? lastSuggestedAt,
  BreakConfig config = const BreakConfig(),
}) {
  if (lastSuggestedAt != null && now.difference(lastSuggestedAt) < config.cooldown) return null;

  final sorted = [
    for (final a in attempts)
      if (config.modes.contains(a.mode) && !a.answeredAt.isAfter(now)) a,
  ]..sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
  if (sorted.isEmpty) return null;
  if (now.difference(sorted.last.answeredAt) >= config.sessionGap) return null; // すでに休んでいる

  // いまの学習 = 最後から、回答の間が sessionGap 未満でつながる区間
  var start = sorted.length - 1;
  while (start > 0 && sorted[start].answeredAt.difference(sorted[start - 1].answeredAt) < config.sessionGap) {
    start--;
  }
  final session = sorted.sublist(start);
  final began = session.first.answeredAt.subtract(Duration(milliseconds: session.first.elapsedMs));
  final minutes = now.difference(began).inMinutes;

  BreakSuggestion make(BreakReason r) =>
      BreakSuggestion(reason: r, minutesIntoSession: minutes, breakMinutes: config.breakMinutes);

  // あてずっぽう: 直近 rushCount 問が、すべて速すぎる誤答
  if (session.length >= config.rushCount) {
    final tail = session.sublist(session.length - config.rushCount);
    if (tail.every((a) => !a.correct && a.elapsedMs > 0 && a.elapsedMs < config.rushMs)) {
      return make(BreakReason.rushing);
    }
  }

  // 続けて間違えた
  if (session.length >= config.mistakeStreak) {
    final tail = session.sublist(session.length - config.mistakeStreak);
    if (tail.every((a) => !a.correct)) return make(BreakReason.mistakeStreak);
  }

  // 途中から遅くなった（所要時間が計れている回答だけ）
  final timed = [for (final a in session) if (a.elapsedMs > 0 && a.elapsedMs <= 5 * 60 * 1000) a.elapsedMs];
  if (timed.length >= config.minAnswersForSlow) {
    final first = _median(timed.sublist(0, 5)), last = _median(timed.sublist(timed.length - 5));
    if (first > 0 && last >= first * config.slowRatio) return make(BreakReason.slowingDown);
  }

  // 長く続けている
  if (minutes >= config.maxSessionMinutes) return make(BreakReason.longSession);
  return null;
}

double _median(List<int> xs) {
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}
