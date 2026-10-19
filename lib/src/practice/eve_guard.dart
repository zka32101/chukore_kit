import '../l10n/strings.dart';
import '../models/models.dart';
import '../planner/planner.dart';
import 'question_picker.dart';

/// 直前の日の出題の制限。
class EveGuardConfig {
  const EveGuardConfig({this.eveMax = 15, this.testDayMax = 8});

  /// 前日（テストまで 1 日）と当日の、出題の上限。
  final int eveMax, testDayMax;
}

enum EveNotice {
  /// 制限なし（前日・当日ではない）。
  none,

  /// 前日。
  eve,

  /// 当日。
  testDay,
}

/// 前日・当日の出題を整えた結果。
class GuardedPractice {
  const GuardedPractice({required this.set, required this.notice, required this.removedNew, required this.trimmed});

  /// 整えた出題。
  final PracticeSet set;
  final EveNotice notice;

  /// まだ解いたことのない問題を外した数と、上限で減らした数。
  final int removedNew, trimmed;

  /// 子どもに見せる一言（制限なしなら null）。
  String? message(ChukoreStrings strings) => switch (notice) {
        EveNotice.none => null,
        EveNotice.eve => strings.eveNotice,
        EveNotice.testDay => strings.testDayNotice,
      };
}

/// テストまでの日数 [daysLeft] から、前日・当日の区分を返す（それ以外は [EveNotice.none]）。
EveNotice eveNoticeOf(int daysLeft) => switch (daysLeft) {
      1 => EveNotice.eve,
      0 => EveNotice.testDay,
      _ => EveNotice.none,
    };

/// 前日・当日は、**新しいことを増やさず**、解いたことのある問題の見直しだけにする。不安からの詰め込みを抑える。
///
/// - テストまで 1 日（前日）と 0 日（当日）に限り効く。それ以外は [set] をそのまま返す
/// - まだ一度も解いていない問題（[attempts] に回答が無い）を外す
/// - 上限を超える分は、後ろ（弱点・補充）から減らす。復習は先頭なので残る（上限は [EveGuardConfig]）
/// - 出せる問題が無くなったら空のまま返す（休むのも準備のうち。穴埋めはしない）
/// - [PracticeSet.shortfall] は変えない（計画どおりに出せなかった数の記録なので）
///
/// 同じ入力なら同じ結果。
GuardedPractice guardLastDays(
  PracticeSet set, {
  required DayPlan plan,
  required Iterable<Attempt> attempts,
  EveGuardConfig config = const EveGuardConfig(),
}) {
  final notice = eveNoticeOf(plan.daysLeft);
  if (notice == EveNotice.none) return GuardedPractice(set: set, notice: notice, removedNew: 0, trimmed: 0);

  final seen = {for (final a in attempts) a.questionId};
  final known = [for (final i in set.items) if (seen.contains(i.question.id)) i];
  final max = notice == EveNotice.eve ? config.eveMax : config.testDayMax;
  final kept = known.take(max).toList();
  return GuardedPractice(
    set: PracticeSet(items: kept, shortfall: set.shortfall),
    notice: notice,
    removedNew: set.items.length - known.length,
    trimmed: known.length - kept.length,
  );
}
