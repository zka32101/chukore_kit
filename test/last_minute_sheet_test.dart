import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question _q(String id, String unit, Map<String, String> tags) => Question(
      id: id, unitId: unit, type: 'choice', difficulty: .5, choices: const ['a', 'b', 'c'],
      answer: 'a', explanationId: 'exp_$id', misconceptionTags: tags,
    );

WeakEntry _w(String key, {String? tag, String? q, int wrong = 1, int day = 1, bool overcome = false}) => WeakEntry(
      key: key, tag: tag, questionId: q, wrongCount: wrong,
      lastWrongAt: DateTime.utc(2026, 10, day), overcome: overcome,
    );

LastMinuteSheet _build(
  List<WeakEntry> weak,
  Map<String, Question> qs, {
  Iterable<Attempt> attempts = const [],
  Set<String>? units,
  int maxSections = 6,
  int perSection = 3,
  bool includeOvercome = false,
}) =>
    buildLastMinuteSheet(
      date: DateTime.utc(2026, 10, 14),
      weakNotes: weak,
      questions: qs,
      tagTitle: (t) => 'TAG:$t',
      promptOf: (q) => 'P:${q.id}',
      answerOf: (q) => 'A:${q.answer}',
      explanationOf: (q) => 'E:${q.explanationId}',
      attempts: attempts,
      unitIds: units,
      maxSections: maxSections,
      itemsPerSection: perSection,
      includeOvercome: includeOvercome,
    );

void main() {
  final qs = {
    'q1': _q('q1', 'u1', {'b': 't_s'}),
    'q2': _q('q2', 'u1', {'b': 't_s'}),
    'q3': _q('q3', 'u2', {'b': 't_s'}),
    'q4': _q('q4', 'u1', {'c': 'past'}),
    'q5': _q('q5', 'u1', const {}),
  };

  test('未克服だけ。多く間違えた順→最近の順', () {
    final s = _build([
      _w('tag:past', tag: 'past', wrong: 2, day: 9),
      _w('tag:t_s', tag: 't_s', wrong: 5, day: 1),
      _w('tag:done', tag: 'done', wrong: 9, overcome: true),
    ], qs);
    expect(s.sections.map((e) => e.key), ['tag:t_s', 'tag:past']);
    expect(s.sections.first.title, 'TAG:t_s');
    expect(s.sections.first.wrongCount, 5);
  });

  test('同じ回数なら最近間違えた型が先', () {
    final s = _build([_w('tag:t_s', tag: 't_s', day: 2), _w('tag:past', tag: 'past', day: 8)], qs);
    expect(s.sections.map((e) => e.key), ['tag:past', 'tag:t_s']);
  });

  test('克服済みは既定では載せない。includeOvercome で載せ、最後に並ぶ', () {
    final weak = [_w('tag:past', tag: 'past', wrong: 9, overcome: true), _w('tag:t_s', tag: 't_s')];
    expect(_build(weak, qs).sections.map((e) => e.key), ['tag:t_s']);
    expect(_build(weak, qs, includeOvercome: true).sections.map((e) => e.key), ['tag:t_s', 'tag:past']);
  });

  test('各まとまりの問題数の上限。実際に間違えた問題を先に', () {
    final attempts = [
      Attempt(questionId: 'q3', unitId: 'u2', correct: false, answeredAt: DateTime.utc(2026, 10, 1)),
      Attempt(questionId: 'q2', unitId: 'u1', correct: true, answeredAt: DateTime.utc(2026, 10, 1)),
    ];
    final s = _build([_w('tag:t_s', tag: 't_s')], qs, attempts: attempts, perSection: 2);
    expect(s.sections.single.items.map((i) => i.questionId), ['q3', 'q1']); // 間違えた q3 → 残りは ID 順
    final i = s.sections.single.items.first;
    expect([i.prompt, i.answer, i.explanation], ['P:q3', 'A:a', 'E:exp_q3']);
  });

  test('出題範囲の外の問題は載せない。載せる問題が無い型は出さない', () {
    final s = _build([_w('tag:t_s', tag: 't_s'), _w('tag:past', tag: 'past')], qs, units: {'u2'});
    expect(s.sections.map((e) => e.key), ['tag:t_s']);
    expect(s.sections.single.items.map((i) => i.questionId), ['q3']);
  });

  test('型が付かない間違いは、その問題1つのまとまり。見出しは問題文', () {
    final s = _build([_w('q:q5', q: 'q5')], qs);
    expect(s.sections.single.title, 'P:q5');
    expect(s.sections.single.items.single.questionId, 'q5');
    expect(_build([_w('q:gone', q: 'gone')], qs).isEmpty, isTrue);
  });

  test('まとまりの数の上限', () {
    final weak = [for (var i = 0; i < 4; i++) _w('tag:t$i', tag: 't$i')];
    final bank = {for (var i = 0; i < 4; i++) 'q$i': _q('q$i', 'u1', {'b': 't$i'})};
    expect(_build(weak, bank, maxSections: 2).sections.length, 2);
  });

  test('同じ入力で同じ結果', () {
    final weak = [_w('tag:t_s', tag: 't_s'), _w('tag:past', tag: 'past')];
    List<String> ids(LastMinuteSheet s) => [for (final e in s.sections) for (final i in e.items) i.questionId];
    expect(ids(_build(weak, qs)), ids(_build(weak.reversed.toList(), Map.fromEntries(qs.entries.toList().reversed))));
  });

  group('HTML', () {
    test('見出し・日付・問題・答え・解説が出て、言語を切り替えられる', () {
      final s = _build([_w('tag:t_s', tag: 't_s')], qs, perSection: 1);
      final ja = renderSheetHtml(s);
      expect(ja, contains('<html lang="ja">'));
      expect(ja, contains('<title>直前プリント</title>'));
      expect(ja, contains('2026-10-14'));
      expect(ja, contains('問題'));
      expect(ja, contains('答え'));
      expect(ja, contains('解説'));
      expect(ja, contains('TAG:t_s'));
      final en = renderSheetHtml(s, strings: const EnStrings());
      expect(en, contains('<html lang="en">'));
      expect(en, contains('Last-minute sheet'));
      expect(en, contains('Explanation'));
      expect(renderSheetHtml(s, strings: const ZhStrings(traditional: true)), contains('lang="zh-Hant"'));
    });

    test('問題データに混じった HTML はエスケープされる（スクリプトが動かない）', () {
      const evil = '<script>alert("x")</script> & <img src=x onerror=alert(1)>';
      final s = buildLastMinuteSheet(
        date: DateTime.utc(2026, 10, 14),
        weakNotes: [_w('tag:t_s', tag: 't_s')],
        questions: {'q1': _q('q1', 'u1', {'b': 't_s'})},
        tagTitle: (_) => evil,
        promptOf: (_) => evil,
        answerOf: (_) => evil,
        explanationOf: (_) => evil,
      );
      final html = renderSheetHtml(s);
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('<img')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&amp;'));
    });

    test('弱点が無いときは励ましの文言。外部の読み込みは無い', () {
      final html = renderSheetHtml(_build(const [], qs));
      expect(html, contains('よくがんばったね'));
      expect(html, isNot(contains('<section>')));
      for (final bad in ['<link', '<script', 'src=', 'http://', 'https://', '@import', 'url(']) {
        expect(html, isNot(contains(bad)), reason: bad);
      }
    });

    test('名前・ID・メールの欄が無い（個人情報を載せない）', () {
      final html = renderSheetHtml(_build([_w('tag:t_s', tag: 't_s')], qs));
      final body = html.substring(html.indexOf('<body>')); // <head> の meta name などは対象外
      for (final bad in ['name', 'email', 'mail', 'user', '氏名', '名前', 'メール']) {
        expect(body.toLowerCase(), isNot(contains(bad.toLowerCase())), reason: bad);
      }
      for (final bad in ['<input', '<form', '<textarea']) {
        expect(body, isNot(contains(bad)), reason: bad);
      }
    });

    test('A4 印刷の指定がある', () {
      expect(renderSheetHtml(_build(const [], qs)), contains('@page { size: A4;'));
    });
  });

  test('プリントの文言が全言語にある', () {
    for (final s in ChukoreStrings.supported) {
      for (final v in [s.sheetTitle, s.sheetQuestion, s.sheetAnswer, s.sheetExplanation, s.sheetEmpty]) {
        expect(v, isNotEmpty);
      }
    }
  });
}
