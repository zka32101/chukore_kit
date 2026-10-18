import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Question q(String id, {String answer = 'a', int version = 1, double difficulty = 0.5, List<String>? choices, Map<String, String> tags = const {}}) =>
    Question(
      id: id,
      unitId: 'u1',
      type: 'choice',
      difficulty: difficulty,
      choices: choices ?? ['a', 'b'],
      answer: answer,
      explanationId: 'e_$id',
      misconceptionTags: tags,
      version: version,
    );

List<String> ids(Iterable<Question> qs) => [for (final x in qs) x.id];

void main() {
  final base = [q('q1'), q('q2'), q('q3')];

  group('between', () {
    test('同じなら空', () => expect(BankDiff.between(base, [q('q1'), q('q2'), q('q3')]).isEmpty, isTrue));

    test('追加・削除・変更を分ける', () {
      final next = [q('q1'), q('q2', answer: 'b', version: 2), q('q4')];
      final d = BankDiff.between(base, next);
      expect(ids(d.added), ['q4']);
      expect(d.removed, ['q3']);
      expect(d.changed.map((c) => (c.id, c.fromVersion, c.after.version)), [('q2', 1, 2)]);
    });

    test('どの項目の変更も内容の変更として数える', () {
      for (final changed in [
        q('q1', answer: 'b'),
        q('q1', difficulty: 0.6),
        q('q1', choices: ['b', 'a']),
        q('q1', tags: {'b': 'x'}),
      ]) {
        final d = BankDiff.between([q('q1')], [changed]);
        expect(d.changed.length, 1, reason: '$changed');
        expect(d.check([q('q1')]).map((i) => i.code), ['changed_without_version_bump']);
      }
    });
  });

  group('check', () {
    List<ValidationIssue> check(List<Question> to) => BankDiff.between(base, to).check(base);

    test('内容を変えて版を上げたなら問題なし', () => expect(check([q('q1', answer: 'b', version: 2), q('q2'), q('q3')]), isEmpty));

    test('内容が変わったのに版が同じ → エラー', () {
      final r = check([q('q1', answer: 'b'), q('q2'), q('q3')]);
      expect(r.map((i) => (i.code, i.isError, i.subjectId)), [('changed_without_version_bump', true, 'q1')]);
    });

    test('版が下がった → エラー', () {
      final from = [q('q1', version: 3)];
      final r = BankDiff.between(from, [q('q1', answer: 'b', version: 2)]).check(from);
      expect(r.map((i) => i.code), ['version_decreased']);
    });

    test('内容は同じで版だけ上がった → 警告。エラーが先に並ぶ', () {
      final r = check([q('q1', version: 2), q('q2', answer: 'b'), q('q3')]);
      expect(r.map((i) => (i.code, i.isError)), [('changed_without_version_bump', true), ('version_bumped_without_change', false)]);
    });
  });

  group('apply', () {
    final next = [q('q1'), q('q2', answer: 'b', version: 2), q('q4')];
    final d = BankDiff.between(base, next);

    test('適用すると新しい版と同じ中身になる。変更は元の位置、追加は最後', () {
      final r = d.apply(base);
      expect(ids(r), ['q1', 'q2', 'q4']);
      expect(r[1].answer, 'b');
      expect(r[1].version, 2);
      expect(BankDiff.between(r, next).isEmpty, isTrue);
    });

    test('順序は元を保ち、削除の途中も崩れない', () {
      final d2 = BankDiff.between(base, [q('q2'), q('q3'), q('q9')]);
      expect(ids(d2.apply(base)), ['q2', 'q3', 'q9']);
    });

    test('二重に当てる・元と違う問題集に当てるとエラー。元の問題集は変わらない', () {
      final once = d.apply(base);
      expect(() => d.apply(once), throwsStateError, reason: '追加がすでにある／版が合わない');
      expect(() => d.apply([q('q1')]), throwsStateError, reason: '削除する問題が無い');
      expect(() => d.apply([q('q1'), q('q2', version: 5), q('q3')]), throwsStateError, reason: '版が合わない');
      expect(ids(base), ['q1', 'q2', 'q3']);
    });

    test('追加だけの差分を二重に当てるとエラー（追加がすでにある）', () {
      final onlyAdd = BankDiff.between(base, [...base, q('q9')]);
      final once = onlyAdd.apply(base);
      expect(ids(once), ['q1', 'q2', 'q3', 'q9']);
      expect(() => onlyAdd.apply(once), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('すでにあります'))));
    });

    test('順番に当てれば 2 か月分も追いつける。飛ばすとエラー', () {
      final v1 = base;
      final v2 = d.apply(v1);
      final v3 = [v2[0], q('q2', answer: 'a', version: 3), v2[2]];
      final d23 = BankDiff.between(v2, v3);
      expect(d23.apply(v2)[1].version, 3);
      expect(() => d23.apply(v1), throwsStateError, reason: 'v1 に当てると q2 の版が合わない（1 か月飛ばした）');
    });
  });

  group('JSON', () {
    test('書いて読み戻すと同じ差分', () {
      final d = BankDiff.between(base, [q('q1'), q('q2', answer: 'b', version: 2), q('q4', tags: {'b': 'x'})]);
      final back = BankDiff.parse(d.toJsonString());
      expect(ids(back.added), ['q4']);
      expect(back.added.single.misconceptionTags, {'b': 'x'});
      expect(back.removed, ['q3']);
      expect(back.changed.single.fromVersion, 1);
      expect(back.changed.single.after.answer, 'b');
      expect(ids(back.apply(base)), ['q1', 'q2', 'q4']);
    });

    test('壊れた・別のファイル・新しい版は FormatException', () {
      for (final bad in ['', 'x', '[]', '{"format":"other"}', '{"format":"chukore_kit.bank_diff","version":1}',
          '{"format":"chukore_kit.bank_diff","version":2,"added":[],"removed":[],"changed":[]}',
          '{"format":"chukore_kit.bank_diff","version":1,"added":[{"id":"x"}],"removed":[],"changed":[]}']) {
        expect(() => BankDiff.parse(bad), throwsFormatException, reason: bad);
      }
    });
  });
}
