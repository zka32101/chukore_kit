import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question _q(String id, String unit) => Question(
    id: id, unitId: unit, type: 'choice', difficulty: .5,
    choices: const ['x', 'y'], answer: 'x', explanationId: 'e');

PracticeSet _set(int a, int b, {bool review = false}) => PracticeSet(items: [
      if (review) PickedQuestion(_q('r0', 'a'), PracticeSlot.review),
      for (var i = 0; i < a; i++) PickedQuestion(_q('a$i', 'a'), PracticeSlot.focus),
      for (var i = 0; i < b; i++) PickedQuestion(_q('b$i', 'b'), PracticeSlot.focus),
    ], shortfall: const {});

PlayProgress _play(PlayProgress p, String s) {
  var i = 0;
  for (final c in s.split('')) {
    p = p.record('q${i++}', c == 'o');
  }
  return p;
}

void main() {
  group('組み立て', () {
    test('件数ぶんだけ取り、単元を混ぜる。復習枠は先頭のまま', () {
      final r = buildPlayRound(_set(6, 6, review: true), count: 6);
      expect(r.items.length, 6);
      expect(r.items.first.slot, PracticeSlot.review);
      expect([for (final i in r.items.skip(1)) i.question.unitId], ['a', 'b', 'a', 'b', 'a']);
      expect(r.questions.length, 6);
    });

    test('既定は 8 問。足りなければ少なく', () {
      expect(buildPlayRound(_set(10, 10)).items.length, 8);
      expect(buildPlayRound(_set(2, 1)).items.length, 3);
      expect(buildPlayRound(const PracticeSet(items: [], shortfall: {})).items, isEmpty);
    });

    test('件数は 5〜10', () {
      expect(() => buildPlayRound(_set(5, 5), count: 4), throwsArgumentError);
      expect(() => buildPlayRound(_set(6, 6), count: 11), throwsArgumentError);
      expect(buildPlayRound(_set(6, 6), count: 5).items.length, 5);
      expect(buildPlayRound(_set(6, 6), count: 10).items.length, 10);
    });
  });

  group('つながり', () {
    test('正解で伸び、まちがえると 0 に戻る。最長は残る。残機はない', () {
      var p = const PlayProgress();
      p = _play(p, 'ooo');
      expect([p.link, p.bestLink], [3, 3]);
      p = _play(p, 'x');
      expect([p.link, p.bestLink, p.answered, p.correct], [0, 3, 4, 3]);
      p = _play(p, 'oo');
      expect([p.link, p.bestLink], [2, 3]);
      p = _play(p, 'ooo');
      expect([p.link, p.bestLink], [5, 5]);
    });

    test('不変（記録しても元は変わらない）', () {
      const p = PlayProgress();
      p.record('a', false);
      expect(p.answered, 0);
      expect(p.missed, isEmpty);
    });

    test('まちがえた問題は出た順に残る。立て直しは直後の正解だけ', () {
      var p = const PlayProgress();
      p = p.record('a', false).record('b', true).record('c', true).record('d', false).record('e', false);
      p = p.record('f', true);
      expect(p.missed, ['a', 'd', 'e']);
      expect(p.comebacks, 2);
    });
  });

  group('まとめ', () {
    final round = buildPlayRound(_set(5, 5), count: 5);

    test('最後までやれば 全問まちがいでも finished がもらえる', () {
      final s = finishPlayRound(round, _play(round.start(), 'xxxxx'));
      expect(s.rewards, {PlayReward.finished});
      expect(s.closing, PlayClosing.keepGoing);
    });

    test('途中でやめると finished は付かない（つながりの分は付く）', () {
      final s = finishPlayRound(round, _play(round.start(), 'ooo'));
      expect(s.rewards, {PlayReward.link3});
    });

    test('つながり 3 / 5 の境目', () {
      expect(finishPlayRound(round, _play(round.start(), 'ooxoo')).rewards.contains(PlayReward.link3), isFalse);
      final s4 = finishPlayRound(round, _play(round.start(), 'ooooxx'));
      expect(s4.rewards.containsAll({PlayReward.link3}), isTrue);
      expect(s4.rewards.contains(PlayReward.link5), isFalse);
      final s5 = finishPlayRound(round, _play(round.start(), 'ooooo'));
      expect(s5.rewards, {PlayReward.finished, PlayReward.link3, PlayReward.link5});
      expect(s5.closing, PlayClosing.allRight);
    });

    test('立て直しの ごほうび', () {
      final s = finishPlayRound(round, _play(round.start(), 'xoooo'));
      expect(s.rewards.contains(PlayReward.comeback), isTrue);
      final n = finishPlayRound(round, _play(round.start(), 'oooox'));
      expect(n.rewards.contains(PlayReward.comeback), isFalse);
    });

    test('ひとことは 全問／半分以上／それ以外。回答 0 は keepGoing', () {
      expect(finishPlayRound(round, _play(round.start(), 'oooo')).closing, PlayClosing.allRight);
      expect(finishPlayRound(round, _play(round.start(), 'ooxx')).closing, PlayClosing.mostlyRight);
      expect(finishPlayRound(round, _play(round.start(), 'oxxx')).closing, PlayClosing.keepGoing);
      expect(finishPlayRound(round, round.start()).closing, PlayClosing.keepGoing);
    });

    test('解き直しの提案は 最初にまちがえた 1 問だけ。まちがいが無ければ無し', () {
      final p = const PlayProgress().record('a', true).record('b', false).record('c', false);
      expect(finishPlayRound(round, p).retryQuestionId, 'b');
      expect(finishPlayRound(round, _play(round.start(), 'ooooo')).retryQuestionId, isNull);
    });

    test('空のラウンドでは finished を付けない', () {
      const empty = PlayRound(items: []);
      expect(finishPlayRound(empty, empty.start()).rewards, isEmpty);
    });
  });
}
