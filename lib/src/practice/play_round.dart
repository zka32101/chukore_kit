import '../models/models.dart';
import 'question_picker.dart';

/// 遊びのラウンド（練習を遊びの形にしたもの）。問題と判定は練習と同じ。
/// 残機・ゲームオーバー・順位・速さの点は置かない（責めない）。見た目・音・アニメは画面側。
class PlayRound {
  const PlayRound({required this.items});

  /// 出す順（5〜10 問、足りなければ少なく）。
  final List<PickedQuestion> items;

  List<Question> get questions => [for (final i in items) i.question];

  /// 空のラウンドの進み具合。
  PlayProgress start() => const PlayProgress();
}

/// 練習の出題 [set] から 1 ラウンド（[count] 問、5〜10）を組み立てる。
/// 単元が続けて同じにならないよう混ぜる（`interleaveByUnit`）。同じ入力なら同じ結果。
PlayRound buildPlayRound(PracticeSet set, {int count = 8}) {
  if (count < 5 || count > 10) throw ArgumentError('count must be 5..10');
  final mixed = interleaveByUnit(set).items;
  return PlayRound(items: mixed.take(count).toList());
}

/// ラウンドのごほうび（スタンプなどの素材）。点数や順位に依らず、続けたこと・つながったことを認める。
enum PlayReward {
  /// 最後までやった（正解の数に関係なく必ずもらえる）。
  finished,

  /// 3 つつながった。
  link3,

  /// 5 つつながった。
  link5,

  /// まちがえた直後の問題に正解した（立て直した）。
  comeback,
}

/// ラウンドの終わりのひとこと（文言は画面側。数字は出さない）。
enum PlayClosing {
  /// ぜんぶ正解。
  allRight,

  /// 半分以上正解。
  mostlyRight,

  /// これから伸びる（半分より少ない）。
  keepGoing,
}

/// ラウンドの進み具合（不変）。残機はない。まちがえると「つながり」が 0 に戻るだけ。
class PlayProgress {
  const PlayProgress({
    this.answered = 0,
    this.correct = 0,
    this.link = 0,
    this.bestLink = 0,
    this.missed = const [],
    this.comebacks = 0,
    this.lastWasMiss = false,
  });

  final int answered, correct;

  /// いまの連続正解（つながり）。
  final int link;

  /// このラウンドでいちばん長かったつながり。
  final int bestLink;

  /// まちがえた問題 ID（出た順）。
  final List<String> missed;

  /// 立て直した回数。
  final int comebacks;
  final bool lastWasMiss;

  /// 1 問の答えを記録した次の進み具合。
  PlayProgress record(String questionId, bool isCorrect) {
    final nextLink = isCorrect ? link + 1 : 0;
    return PlayProgress(
      answered: answered + 1,
      correct: correct + (isCorrect ? 1 : 0),
      link: nextLink,
      bestLink: nextLink > bestLink ? nextLink : bestLink,
      missed: isCorrect ? missed : [...missed, questionId],
      comebacks: comebacks + (isCorrect && lastWasMiss ? 1 : 0),
      lastWasMiss: !isCorrect,
    );
  }
}

/// ラウンドの終わりのまとめ。
class PlayRoundSummary {
  const PlayRoundSummary({required this.rewards, required this.closing, required this.retryQuestionId});

  final Set<PlayReward> rewards;
  final PlayClosing closing;

  /// 解き直しの提案（1 問だけ。まちがいがなければ null）。強制しない。
  final String? retryQuestionId;
}

/// ラウンド [round] の終わりのまとめ。最後まで進んだ（[progress] の回答数がラウンドの問題数以上）ときだけ
/// 「finished」のごほうびが付く。途中でやめた場合は、つながりなどの分だけ。
PlayRoundSummary finishPlayRound(PlayRound round, PlayProgress progress) {
  final rewards = <PlayReward>{
    if (progress.answered >= round.items.length && round.items.isNotEmpty) PlayReward.finished,
    if (progress.bestLink >= 3) PlayReward.link3,
    if (progress.bestLink >= 5) PlayReward.link5,
    if (progress.comebacks > 0) PlayReward.comeback,
  };
  final n = progress.answered;
  final closing = n > 0 && progress.correct == n
      ? PlayClosing.allRight
      : (n > 0 && progress.correct * 2 >= n ? PlayClosing.mostlyRight : PlayClosing.keepGoing);
  return PlayRoundSummary(
    rewards: rewards,
    closing: closing,
    retryQuestionId: progress.missed.isEmpty ? null : progress.missed.first,
  );
}
