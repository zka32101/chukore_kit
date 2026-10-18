import '../models/models.dart';
import '../review/spaced_review.dart';

/// 暗記カードの自己採点。表を見て答えを思い出し、裏を見たあとで自分で選ぶ。
enum CardRating {
  /// わからない（思い出せなかった）。
  again,

  /// あやしい（なんとなく合っていた・自信がない）。
  hard,

  /// わかった（すぐ思い出せた）。
  good,
}

/// 名前（`again`・`hard`・`good`）から [CardRating] を引く。知らない名前は null。
CardRating? cardRatingFromName(String name) => CardRating.values.where((r) => r.name == name).firstOrNull;

/// 自己採点を回答（[Attempt]）にする。出題の種類は `card`。既存の仕組みにそのまま乗る:
/// - **わかった**: 正解（自信あり）。間隔反復で箱が上がる
/// - **あやしい**: 正解だが自信なし。習熟度には正解として数え、間隔反復では箱を上げない（まぐれかもしれない）
/// - **わからない**: 誤答。理由は「わからなかった」にする。同じセッションですぐ正解し直すのは
///   ふつうの暗記の流れなので、「すぐ正解し直したから、うっかり」と見なされないようにするため
Attempt attemptFromCardRating(
  Question card,
  CardRating rating, {
  required DateTime at,
  int elapsedMs = 0,
  String mode = 'card',
}) =>
    Attempt(
      questionId: card.id,
      unitId: card.unitId,
      correct: rating != CardRating.again,
      chosenId: rating.name,
      answeredAt: at,
      elapsedMs: elapsedMs,
      mode: mode,
      confident: switch (rating) {
        CardRating.good => true,
        CardRating.hard => false,
        CardRating.again => null,
      },
      reason: rating == CardRating.again ? LossReason.dontKnow : null,
    );

/// 今日のカード。期限が来たカードを先に、次にまだ見ていない新しいカード。
class CardDeck {
  const CardDeck({required this.due, required this.fresh});

  /// 期限が来たカード（遅れている順、自信ありで誤答した順）。
  final List<Question> due;

  /// まだ一度も見ていない新しいカード（問題IDの順）。
  final List<Question> fresh;

  List<Question> get cards => [...due, ...fresh];
}

/// 今日のカードを選ぶ。カードは `type: card` の問題。同じ入力なら同じ結果。
///
/// - 期限が来たカード: 最大 [dueLimit] 枚（間隔反復の期限。`testDate` を渡すと期限はテスト日を超えない）
/// - 新しいカード: 最大 [newLimit] 枚。ただし期限が来たカードが [dueLimit] 枚以上たまっているときは 0 枚
///   （復習が先。たまったまま新しいカードを増やさない）
/// - [unitIds] を渡すと、その単元（葉）のカードだけ
CardDeck buildCardDeck({
  required Iterable<Question> questions,
  required Iterable<Attempt> attempts,
  required DateTime today,
  Iterable<String>? unitIds,
  int dueLimit = 30,
  int newLimit = 10,
  DateTime? testDate,
}) {
  if (dueLimit < 0 || newLimit < 0) throw ArgumentError('dueLimit と newLimit は 0 以上');
  final scope = unitIds?.toSet();
  final pool = [
    for (final q in questions)
      if (q.type == 'card' && (scope == null || scope.contains(q.unitId))) q,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final byId = {for (final q in pool) q.id: q};

  final history = [for (final a in attempts) if (byId.containsKey(a.questionId)) a];
  final seen = {for (final a in history) a.questionId};
  final states = buildReviewStates(history, testDate: testDate);
  final due = [
    for (final s in dueForReview(states, today))
      if (byId.containsKey(s.questionId)) byId[s.questionId]!,
  ].take(dueLimit).toList();

  final room = due.length >= dueLimit ? 0 : newLimit;
  final fresh = [for (final q in pool) if (!seen.contains(q.id)) q].take(room).toList();
  return CardDeck(due: due, fresh: fresh);
}

/// 1 回の暗記カードの学習の進み方。表を見る → めくる → 自己採点、の繰り返しを管理する。
///
/// - 「わからない」のカードは、[againGap] 枚あとにもう一度出す（同じカードは最大 [maxRepeats] 回まで。
///   それでも思い出せないカードは、今日は切り上げて、間隔反復で明日また出す）
/// - 「あやしい」「わかった」のカードは、そのセッションではもう出さない
/// - 自己採点のたびに [Attempt] を返し、[attempts] にたまる（保存はアプリ側）
class CardSession {
  CardSession(Iterable<Question> cards, {this.againGap = 3, this.maxRepeats = 2})
      : _queue = [...cards],
        total = cards.length {
    if (againGap < 1) throw ArgumentError('againGap は 1 以上');
    if (maxRepeats < 0) throw ArgumentError('maxRepeats は 0 以上');
  }

  final int againGap;
  final int maxRepeats;

  /// 最初のカードの枚数。
  final int total;

  final List<Question> _queue;
  final _repeats = <String, int>{};
  final _attempts = <Attempt>[];
  final _final = <String, CardRating>{};

  /// 今のカード（終わっていれば null）。
  Question? get current => _queue.isEmpty ? null : _queue.first;

  bool get isFinished => _queue.isEmpty;

  /// これまでの自己採点の回答（古い順）。
  List<Attempt> get attempts => List.unmodifiable(_attempts);

  /// 残りの枚数（もう一度出すカードも数える）。
  int get remaining => _queue.length;

  /// カードごとの最後の自己採点。
  Map<String, CardRating> get lastRatings => Map.unmodifiable(_final);

  /// 今のカードを自己採点する。終わっていれば [StateError]。
  Attempt rate(CardRating rating, {required DateTime at, int elapsedMs = 0}) {
    if (_queue.isEmpty) throw StateError('カードはもうありません');
    final card = _queue.removeAt(0);
    final attempt = attemptFromCardRating(card, rating, at: at, elapsedMs: elapsedMs);
    _attempts.add(attempt);
    _final[card.id] = rating;
    if (rating == CardRating.again) {
      final n = _repeats[card.id] ?? 0;
      if (n < maxRepeats) {
        _repeats[card.id] = n + 1;
        _queue.insert(againGap < _queue.length ? againGap : _queue.length, card);
      }
    }
    return attempt;
  }
}
