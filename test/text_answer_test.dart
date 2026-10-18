import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(String type, String answer, {List<String> choices = const []}) => Question(
      id: 'q1',
      unitId: 'u1',
      type: type,
      difficulty: 0.5,
      choices: choices,
      answer: answer,
      explanationId: 'e1',
    );

void main() {
  group('normalizeText', () {
    test('全角・大文字・空白・文末の句読点・カタカナをそろえる', () {
      expect(normalizeText('  Ｔｏｋｙｏ。 '), 'tokyo');
      expect(normalizeText('a   lot　of  it!'), 'a lot of it');
      expect(normalizeText('トウキョウ'), 'とうきょう');
      expect(normalizeText('トウキョウ', foldKana: false), 'トウキョウ');
      expect(normalizeText('１９４５'), '1945');
      expect(normalizeText('don’t'), "don't");
      expect(normalizeText('well‐known'), 'well-known');
    });
    test('途中の記号・語順は変えない', () {
      expect(normalizeText('a.b'), 'a.b');
      expect(normalizeText('a lot'), isNot(normalizeText('alot')));
    });
  });

  group('text', () {
    final t = q('text', '東京|とうきょう|Tokyo');
    test('別解のどれでも正解。表記ゆれは吸収', () {
      for (final ok in ['東京', 'とうきょう', 'トウキョウ', 'tokyo', ' ＴＯＫＹＯ。', 'Tokyo!']) {
        expect(checkAnswer(t, ok).correct, isTrue, reason: ok);
      }
    });
    test('違う答え・空欄は不正解', () {
      for (final ng in ['大阪', '', '   ', '。', 'tokyo city', '東京都']) {
        expect(checkAnswer(t, ng).correct, isFalse, reason: ng);
      }
    });
    test('カタカナ指定の問題は foldKana: false で区別', () {
      final k = q('text', 'コンピュータ');
      expect(checkAnswer(k, 'こんぴゅーた').correct, isTrue);
      expect(checkAnswer(k, 'こんぴゅーた', foldKana: false).correct, isFalse);
      expect(checkAnswer(k, 'コンピュータ', foldKana: false).correct, isTrue);
    });
    test('score は正解 1・不正解 0', () {
      expect(checkAnswer(t, '東京').score, 1.0);
      expect(checkAnswer(t, '大阪').score, 0.0);
    });
  });

  group('multi', () {
    final m = q('multi', '織田信長|のぶなが;豊臣秀吉|ひでよし;徳川家康');
    test('順不同・別解・区切りいろいろで全部合えば正解', () {
      for (final ok in ['織田信長;豊臣秀吉;徳川家康', '徳川家康、豊臣秀吉、織田信長', 'のぶなが, ひでよし, 徳川家康', '徳川家康\nひでよし\nノブナガ', '織田信長；豊臣秀吉；徳川家康']) {
        final r = checkAnswer(m, ok);
        expect((r.correct, r.score), (true, 1.0), reason: ok);
      }
    });
    test('部分点: 合った数 / 全体', () {
      final r = checkAnswer(m, '織田信長;徳川家康');
      expect(r.correct, isFalse);
      expect(r.score, closeTo(2 / 3, 1e-9));
      expect(checkAnswer(m, '織田信長').score, closeTo(1 / 3, 1e-9));
      expect(checkAnswer(m, '').score, 0.0);
    });
    test('同じ項目を 2 回書いても 2 点にならず、減点もされない（別解を両方書いても同じ）', () {
      expect(checkAnswer(m, '織田信長;織田信長').score, closeTo(1 / 3, 1e-9));
      expect(checkAnswer(m, '織田信長;のぶなが').score, closeTo(1 / 3, 1e-9));
    });
    test('余分な項目は減点。全部書いても余分があれば正解にならない', () {
      final extra = checkAnswer(m, '織田信長;豊臣秀吉;徳川家康;明智光秀');
      expect(extra.correct, isFalse);
      expect(extra.score, closeTo(2 / 3, 1e-9));
      // 当て推量で書き並べても 0 を下回らない
      expect(checkAnswer(m, 'a;b;c;d;e;f').score, 0.0);
      expect(checkAnswer(m, '織田信長;a;b').score, 0.0);
    });
  });

  group('問題集の検証', () {
    List<String> codes(Question x) {
      final unit = [const Unit(id: 'u1', subject: 's', grade: 1, title: 'u')];
      return [
        for (final i in validateQuestionBank(questions: [x], tree: UnitTree(1, unit), mistakeLines: const [])) i.code,
      ];
    }

    test('正しい text / multi は問題なし', () {
      expect(codes(q('text', '東京|とうきょう')), isEmpty);
      expect(codes(q('multi', 'a|b;c')), isEmpty);
    });
    test('text: 空の別解は誤り、そろえて同じ別解は警告', () {
      expect(codes(q('text', '')), contains('text_answer_empty'));
      expect(codes(q('text', 'a||b')), contains('text_answer_empty'));
      expect(codes(q('text', 'Tokyo|tokyo。')), contains('text_alt_duplicate'));
      expect(codes(q('text', 'a', choices: ['a', 'b'])), contains('choices_ignored'));
    });
    test('multi: 1 項目・空の項目・区切り文字・項目の重なりは誤り', () {
      expect(codes(q('multi', 'a')), contains('multi_too_few'));
      expect(codes(q('multi', 'a;;b')), contains('multi_item_empty'));
      expect(codes(q('multi', 'a,b;c')), contains('multi_item_separator'));
      expect(codes(q('multi', 'a|x;Ａ|y')), contains('multi_ambiguous'));
    });
  });
}
