import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 20);

Question card(String id, {String unit = 'u1', String answer = 'back', String type = 'card', List<String> choices = const []}) => Question(
      id: id,
      unitId: unit,
      type: type,
      difficulty: 0.6,
      choices: choices,
      answer: answer,
      explanationId: 'e_$id',
    );

DateTime ago(int days, {int hour = 10, int minute = 0}) =>
    DateTime(today.year, today.month, today.day - days, hour, minute);

Attempt rated(Question q, CardRating r, DateTime at) => attemptFromCardRating(q, r, at: at);

List<String> ids(Iterable<Question> qs) => [for (final q in qs) q.id];

void main() {
  final c1 = card('c1');

  group('自己採点 → 回答', () {
    test('わかった: 正解・自信あり', () {
      final a = rated(c1, CardRating.good, ago(0));
      expect((a.correct, a.confident, a.reason, a.mode, a.chosenId), (true, true, null, 'card', 'good'));
      expect((a.questionId, a.unitId), ('c1', 'u1'));
    });
    test('あやしい: 正解だが自信なし', () {
      final a = rated(c1, CardRating.hard, ago(0));
      expect((a.correct, a.confident, a.reason), (true, false, null));
    });
    test('わからない: 誤答。理由は「わからなかった」', () {
      final a = rated(c1, CardRating.again, ago(0));
      expect((a.correct, a.confident, a.reason), (false, null, LossReason.dontKnow));
    });
    test('所要時間と出題の種類を渡せる', () {
      final a = attemptFromCardRating(c1, CardRating.good, at: ago(0), elapsedMs: 4200, mode: 'practice');
      expect((a.elapsedMs, a.mode), (4200, 'practice'));
    });
    test('cardRatingFromName', () {
      expect(cardRatingFromName('hard'), CardRating.hard);
      expect(cardRatingFromName('nope'), isNull);
    });
  });

  group('checkAnswer(card)', () {
    test('good・hard は正解、again・知らない入力は不正解。部分点は 1 / 0.5 / 0', () {
      final g = checkAnswer(c1, 'good'), h = checkAnswer(c1, 'hard'), a = checkAnswer(c1, 'again');
      expect((g.correct, g.score), (true, 1.0));
      expect((h.correct, h.score), (true, 0.5));
      expect((a.correct, a.score), (false, 0.0));
      expect(checkAnswer(c1, 'xyz').correct, isFalse);
      expect(checkAnswer(c1, '').correct, isFalse);
    });
  });

  group('既存の仕組みへの乗り方', () {
    int box(List<Attempt> a) => buildReviewStates(a)['c1']!.box;

    test('間隔反復: わかった は箱が上がり、あやしい は上がらず、わからない は 0 に戻る', () {
      final seed = [rated(c1, CardRating.good, ago(20)), rated(c1, CardRating.good, ago(15))];
      expect(box(seed), 1);
      expect(box([...seed, rated(c1, CardRating.good, ago(8))]), 2);
      expect(box([...seed, rated(c1, CardRating.hard, ago(8))]), 1, reason: 'あやしい は箱を上げない');
      expect(box([...seed, rated(c1, CardRating.again, ago(8))]), 0);
      expect(buildReviewStates([...seed, rated(c1, CardRating.again, ago(8))])['c1']!.lapses, 1);
    });

    test('「わからない」の直後に同じセッションで「わかった」と答えても、ケアレスミスにならない', () {
      final again = rated(c1, CardRating.again, ago(0, minute: 0));
      final good = rated(c1, CardRating.good, ago(0, minute: 2));
      final v = classifyMistakes([again, good]).single;
      expect(v.careless, isFalse);
      // 同じ流れでも、ふつうの問題で理由の申告が無ければ「すぐ正解し直した」でケアレス扱い
      final plain = [
        Attempt(questionId: 'p', unitId: 'u1', correct: false, answeredAt: ago(0, minute: 0)),
        Attempt(questionId: 'p', unitId: 'u1', correct: true, answeredAt: ago(0, minute: 2)),
      ];
      expect(classifyMistakes(plain).single.careless, isTrue);
    });

    test('習熟度: あやしい は正解、わからない は誤答として数える', () {
      final a = [rated(c1, CardRating.good, ago(0)), rated(c1, CardRating.hard, ago(0)), rated(c1, CardRating.again, ago(0)), rated(c1, CardRating.again, ago(0))];
      expect(computeMastery(a, today)['u1']!.score, 0.5);
    });
  });

  group('今日のカード', () {
    final cards = [for (var i = 1; i <= 8; i++) card('c$i')];

    test('期限が来たカードが先、遅れている順。まだ見ていない新しいカードは ID 順で newLimit 枚まで', () {
      final attempts = [
        rated(cards[2], CardRating.good, ago(10)), // c3: 9 日遅れ
        rated(cards[0], CardRating.good, ago(4)), // c1: 3 日遅れ
        rated(cards[1], CardRating.good, ago(0)), // c2: 期限は明日 → 今日は出ない
      ];
      final d = buildCardDeck(questions: cards, attempts: attempts, today: today, newLimit: 3);
      expect(ids(d.due), ['c3', 'c1']);
      expect(ids(d.fresh), ['c4', 'c5', 'c6'], reason: 'c2 は見たことがあるので新しいカードではない');
      expect(ids(d.cards), ['c3', 'c1', 'c4', 'c5', 'c6']);
    });

    test('期限が来たカードが dueLimit 枚以上たまっていたら、新しいカードは出さない（復習が先）', () {
      final attempts = [for (final c in cards.take(5)) rated(c, CardRating.good, ago(10))];
      final d = buildCardDeck(questions: cards, attempts: attempts, today: today, dueLimit: 5, newLimit: 10);
      expect(d.due.length, 5);
      expect(d.fresh, isEmpty);
      final fewer = buildCardDeck(questions: cards, attempts: attempts, today: today, dueLimit: 6, newLimit: 10);
      expect(fewer.fresh.length, 3, reason: '期限が来たカードが dueLimit に届かなければ、新しいカードも出す');
    });

    test('dueLimit で期限のカードの枚数を絞る', () {
      final attempts = [for (final c in cards) rated(c, CardRating.good, ago(10))];
      expect(buildCardDeck(questions: cards, attempts: attempts, today: today, dueLimit: 3).due.length, 3);
    });

    test('card 以外の問題は出さない。単元で絞れる。履歴の無い他の問題は無視', () {
      final mixed = [card('c1'), card('x1', type: 'choice', choices: ['a', 'b'], answer: 'a'), card('c2', unit: 'u2')];
      expect(ids(buildCardDeck(questions: mixed, attempts: const [], today: today).fresh), ['c1', 'c2']);
      expect(ids(buildCardDeck(questions: mixed, attempts: const [], today: today, unitIds: ['u2']).fresh), ['c2']);
      final other = Attempt(questionId: 'zzz', unitId: 'u1', correct: false, answeredAt: ago(5));
      expect(buildCardDeck(questions: mixed, attempts: [other], today: today).due, isEmpty);
    });

    test('「わからない」と答えたカードは翌日に期限が来る。テスト日までは出る', () {
      final a = [rated(c1, CardRating.again, ago(1))];
      expect(ids(buildCardDeck(questions: [c1], attempts: a, today: today).due), ['c1']);
      expect(buildCardDeck(questions: [c1], attempts: [rated(c1, CardRating.again, ago(0))], today: today).due, isEmpty);
    });

    test('0 枚の指定は許す。負の数は不正', () {
      expect(buildCardDeck(questions: cards, attempts: const [], today: today, newLimit: 0).cards, isEmpty);
      expect(() => buildCardDeck(questions: cards, attempts: const [], today: today, newLimit: -1), throwsArgumentError);
    });

    test('同じ入力なら同じ結果', () {
      final a = [rated(cards[2], CardRating.good, ago(10)), rated(cards[0], CardRating.good, ago(10))];
      expect(ids(buildCardDeck(questions: cards, attempts: a, today: today).cards),
          ids(buildCardDeck(questions: cards.reversed.toList(), attempts: a.reversed.toList(), today: today).cards));
    });
  });

  group('学習セッション', () {
    final cs = [for (var i = 1; i <= 6; i++) card('c$i')];
    DateTime t(int i) => ago(0, minute: i);

    test('わかった・あやしい はそのセッションで終わり。回答がたまる', () {
      final s = CardSession(cs.take(3));
      expect((s.total, s.remaining, s.current!.id), (3, 3, 'c1'));
      s.rate(CardRating.good, at: t(0));
      s.rate(CardRating.hard, at: t(1));
      s.rate(CardRating.good, at: t(2));
      expect(s.isFinished, isTrue);
      expect(s.current, isNull);
      expect(s.attempts.map((a) => (a.questionId, a.correct)), [('c1', true), ('c2', true), ('c3', true)]);
      expect(s.lastRatings, {'c1': CardRating.good, 'c2': CardRating.hard, 'c3': CardRating.good});
    });

    test('わからない のカードは 3 枚あとにもう一度出る', () {
      final s = CardSession(cs);
      s.rate(CardRating.again, at: t(0)); // c1 → c2 c3 c4 の後ろ
      final order = <String>[];
      while (!s.isFinished) {
        order.add(s.current!.id);
        s.rate(CardRating.good, at: t(order.length));
      }
      expect(order, ['c2', 'c3', 'c4', 'c1', 'c5', 'c6']);
    });

    test('残りが少なければ末尾に戻る', () {
      final s = CardSession(cs.take(2));
      s.rate(CardRating.again, at: t(0));
      expect([s.current!.id, s.remaining], ['c2', 2]);
      s.rate(CardRating.good, at: t(1));
      expect(s.current!.id, 'c1');
    });

    test('同じカードは maxRepeats 回まで。それでも思い出せなければ今日は切り上げる', () {
      final s = CardSession([c1], maxRepeats: 2);
      for (var i = 0; i < 3; i++) {
        expect(s.isFinished, isFalse, reason: '$i 回目');
        s.rate(CardRating.again, at: t(i));
      }
      expect(s.isFinished, isTrue);
      expect(s.attempts.length, 3);
      expect(s.attempts.every((a) => !a.correct), isTrue);
      expect(s.lastRatings['c1'], CardRating.again);
    });

    test('maxRepeats が 0 なら、繰り返さない', () {
      final s = CardSession([c1], maxRepeats: 0)..rate(CardRating.again, at: t(0));
      expect(s.isFinished, isTrue);
    });

    test('終わったあとに答えるとエラー。空のセッションは最初から終わっている', () {
      final s = CardSession(const []);
      expect(s.isFinished, isTrue);
      expect(() => s.rate(CardRating.good, at: t(0)), throwsStateError);
    });

    test('不正な設定', () {
      expect(() => CardSession([c1], againGap: 0), throwsArgumentError);
      expect(() => CardSession([c1], maxRepeats: -1), throwsArgumentError);
    });

    test('セッションの回答を履歴に入れると、翌日の今日のカードに反映される', () {
      final s = CardSession(cs.take(3));
      s.rate(CardRating.good, at: ago(1, minute: 0));
      s.rate(CardRating.again, at: ago(1, minute: 1));
      s.rate(CardRating.good, at: ago(1, minute: 2)); // c3
      s.rate(CardRating.good, at: ago(1, minute: 3)); // c2（もう一度）
      expect(s.isFinished, isTrue);
      final deck = buildCardDeck(questions: cs, attempts: s.attempts, today: today, newLimit: 0);
      expect(ids(deck.due), ['c1', 'c3'], reason: '昨日 1 回だけ正解した c1・c3 は今日が期限（1 日後）');
      final c2 = buildReviewStates(s.attempts)['c2']!;
      expect((c2.box, c2.lapses), (1, 1), reason: '「わからない」のあと同じ日に「わかった」で箱 1（3 日後）。誤答の回数も残る');
      expect(ids(deck.due).contains('c2'), isFalse);
    });
  });

  group('問題集と模試', () {
    List<String> codes(Question x) {
      final unit = [const Unit(id: 'u1', subject: 's', grade: 1, title: 'u')];
      return [for (final i in validateQuestionBank(questions: [x], tree: UnitTree(1, unit), mistakeLines: const [])) i.code];
    }

    test('正しい card は問題なし。裏面が空なら誤り。選択肢・ヒントは警告', () {
      expect(codes(card('c1')), isEmpty);
      expect(codes(card('c1', answer: ' ')), contains('card_answer_empty'));
      expect(codes(card('c1', choices: ['a', 'b'])), contains('choices_ignored'));
      expect(codes(Question(id: 'c1', unitId: 'u1', type: 'card', difficulty: 0.5, choices: const [], answer: 'b', explanationId: 'e', hintIds: const ['h'])), contains('hints_ignored'));
    });

    test('模試には card を出さない（自己採点で点数にできない）', () {
      final unit = [
        const Unit(id: 'root', subject: 's', grade: 1, title: 'r'),
        const Unit(id: 'u1', subject: 's', grade: 1, title: 'u', parentId: 'root', estimatedQuestions: 10),
      ];
      final qs = [
        for (var i = 0; i < 5; i++) card('c$i'),
        for (var i = 0; i < 5; i++) card('m$i', type: 'choice', choices: ['a', 'b'], answer: 'a'),
      ];
      final exam = buildMockExam(questions: qs, tree: UnitTree(1, unit), unitIds: ['root'], count: 10);
      expect(exam.questions.length, 5);
      expect(exam.questions.every((q) => q.type == 'choice'), isTrue);
      expect(exam.shortfall, isTrue);
    });
  });

  group('文言', () {
    test('全言語で 3 つの自己採点ラベルとめくるボタンが空でなく、ラベルは互いに違う', () {
      for (final l in ChukoreStrings.supported) {
        final labels = [for (final r in CardRating.values) l.cardRatingLabel(r)];
        expect(labels.every((x) => x.trim().isNotEmpty), isTrue, reason: l.tag);
        expect(labels.toSet().length, 3, reason: l.tag);
        expect(l.cardFlip.trim().isNotEmpty, isTrue, reason: l.tag);
      }
    });
    test('ラベルは自己採点に対応する', () {
      const ja = JaStrings();
      expect(ja.cardRatingLabel(CardRating.again), 'わからない');
      expect(ja.cardRatingLabel(CardRating.hard), 'あやしい');
      expect(ja.cardRatingLabel(CardRating.good), 'わかった');
      expect(ja.cardFlip, 'めくる');
    });
  });
}
