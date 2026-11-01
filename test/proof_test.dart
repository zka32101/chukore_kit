import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

ProofSpec _spec() => ProofSpec.fromJson({
  'id': 'p1',
  'unitId': 'u1',
  'titleId': 't',
  'givenId': 'g',
  'goalId': 'z',
  'reasons': [
    {'id': 'r1', 'textId': 'x1'},
    {'id': 'r2', 'textId': 'x2'},
    {'id': 'r3', 'textId': 'x3'},
  ],
  'steps': [
    {'id': 'a', 'claimId': 'ca', 'reasonId': 'r1'},
    {'id': 'b', 'claimId': 'cb', 'reasonId': 'r1'},
    {
      'id': 'c',
      'claimId': 'cc',
      'reasonId': 'r2',
      'after': ['a', 'b'],
    },
  ],
  'decoys': [
    {'id': 'd', 'claimId': 'cd', 'tag': 'oops'},
  ],
});

UnitTree _tree() => UnitTree.fromJson({
  'version': 1,
  'units': [
    {'id': 'u1', 'subject': 'math', 'grade': 2, 'title': '合同', 'order': 1},
  ],
});

void main() {
  test('並べ替え: 前提の順を守れば、前提が同じ行どうしの入れ替えは正解。まぎらわしい行・入れ忘れ・順違いを見分ける', () {
    final s = _spec();
    expect(gradeProofOrder(s, ['a', 'b', 'c']).correct, isTrue);
    expect(gradeProofOrder(s, ['b', 'a', 'c']).correct, isTrue);
    var r = gradeProofOrder(s, ['a', 'c', 'b']);
    expect(r.correct, isFalse);
    expect(r.misplaced, ['c']);
    r = gradeProofOrder(s, ['a', 'b', 'd', 'c']);
    expect(r.decoyPicked, ['d']);
    expect(r.correct, isFalse);
    r = gradeProofOrder(s, ['a', 'c']);
    expect(r.missing, ['b']);
    expect(r.misplaced, ['c']); // 前提の b がない
    expect(gradeProofOrder(s, ['a', 'a', 'b', 'c']).correct, isFalse);
    expect(gradeProofOrder(s, ['a', 'b', 'c', 'zzz']).correct, isFalse);
    expect(gradeProofOrder(s, const []).missing, ['a', 'b', 'c']);
  });

  test('根拠選び: 正解・まちがい・未回答を行ごとに返す', () {
    final s = _spec();
    final r = gradeProofReasons(s, {'a': 'r1', 'b': 'r3'});
    expect(r.rightStepIds, ['a']);
    expect(r.wrongStepIds, ['b']);
    expect(r.blankStepIds, ['c']);
    expect(r.correct, isFalse);
    expect(
      gradeProofReasons(s, {'a': 'r1', 'b': 'r1', 'c': 'r2'}).correct,
      isTrue,
    );
  });

  test('出題: シャッフルは種で決まり、正しい順のままにならない。まぎらわしい根拠は未使用の根拠', () {
    final s = _spec();
    expect(s.shuffledStepIds(5), s.shuffledStepIds(5));
    expect(s.shuffledStepIds(5).toSet(), {'a', 'b', 'c', 'd'});
    for (var seed = 0; seed < 50; seed++) {
      expect(
        s.shuffledStepIds(seed, withDecoys: false),
        isNot(['a', 'b', 'c']),
      );
    }
    expect([for (final r in s.decoyReasons) r.id], ['r3']);
    expect(s.reasonChoices(1).toSet(), {'r1', 'r2', 'r3'});
  });

  test('検証: 正しい証明は問題なし。根拠なし・前を指さない after・結論に結びつかない行・短すぎる証明・重複を見つける', () {
    expect(
      validateProofs(
        ProofSet([_spec()]),
        tree: _tree(),
      ).where((i) => i.isError),
      isEmpty,
    );
    Set<String> codes(Map<String, dynamic> Function(Map<String, dynamic>) f) {
      final base = {
        'id': 'p1',
        'unitId': 'u1',
        'titleId': 't',
        'givenId': 'g',
        'goalId': 'z',
        'reasons': [
          {'id': 'r1', 'textId': 'x1'},
          {'id': 'r2', 'textId': 'x2'},
        ],
        'steps': [
          {'id': 'a', 'claimId': 'ca', 'reasonId': 'r1'},
          {'id': 'b', 'claimId': 'cb', 'reasonId': 'r1'},
          {
            'id': 'c',
            'claimId': 'cc',
            'reasonId': 'r2',
            'after': ['a', 'b'],
          },
        ],
      };
      return validateProofs(
        ProofSet([ProofSpec.fromJson(f(base))]),
        tree: _tree(),
      ).map((i) => i.code).toSet();
    }

    expect(codes((j) => j), {'proof_no_decoy_reason', 'proof_no_decoy_step'}); // 警告だけ
    expect(
      codes((j) => {...j, 'unitId': 'zz'}),
      contains('proof_unit_missing'),
    );
    expect(
      codes(
        (j) => {
          ...j,
          'steps': [(j['steps'] as List).first, (j['steps'] as List)[1]],
        },
      ),
      contains('proof_too_short'),
    );
    expect(
      codes(
        (j) => {
          ...j,
          'steps': [
            {'id': 'a', 'claimId': 'ca', 'reasonId': 'nope'},
            ...(j['steps'] as List).skip(1),
          ],
        },
      ),
      contains('proof_reason_missing'),
    );
    expect(
      codes(
        (j) => {
          ...j,
          'steps': [
            {
              'id': 'a',
              'claimId': 'ca',
              'reasonId': 'r1',
              'after': ['c'],
            },
            ...(j['steps'] as List).skip(1),
          ],
        },
      ),
      contains('proof_after_invalid'),
    );
    expect(
      codes(
        (j) => {
          ...j,
          'steps': [
            ...(j['steps'] as List).take(2),
            {
              'id': 'c',
              'claimId': 'cc',
              'reasonId': 'r2',
              'after': ['a'],
            },
          ],
        },
      ),
      contains('proof_not_connected'),
    ); // b が結論に結びつかない
    expect(
      codes(
        (j) => {
          ...j,
          'steps': [
            ...(j['steps'] as List).take(2),
            {
              'id': 'a',
              'claimId': 'cc',
              'reasonId': 'r2',
              'after': ['b'],
            },
          ],
        },
      ),
      contains('proof_id_duplicate'),
    );
  });

  test('読み込み: 未知のキー・版・重複 ID・空の文字列はエラー', () {
    expect(
      () => ProofSet.parse('{"version":2,"proofs":[]}'),
      throwsFormatException,
    );
    expect(() => ProofSet.parse('[]'), throwsFormatException);
    expect(
      () => ProofSet.parse('{"version":1,"proofs":[{"id":"a b"}]}'),
      throwsFormatException,
    );
    expect(
      () => ProofSpec.fromJson({..._json(), 'extra': 1}),
      throwsFormatException,
    );
    expect(
      () => ProofSet.parse('{"version":1,"proofs":[${_raw()},${_raw()}]}'),
      throwsFormatException,
    );
  });

  for (final dir in ['docs/content_drafts/suugaku_chu2', 'docs/content_drafts/suugaku_chu3']) {
  test('$dir の証明 2 つ: 文言がそろい、全部の遊び方で正解の並びが正解になる', () {
    final r = validateContentPack(
      File('$dir/manifest.json').readAsStringSync(),
      (p) => File('$dir/$p').readAsStringSync(),
    );
    expect(
      r.issues.where((i) => i.isError),
      isEmpty,
      reason: r.issues.join('\n'),
    );
    expect(r.counts['proofs'], 2);
    final set = ProofSet.parse(File('$dir/proofs.json').readAsStringSync());
    for (final p in set.proofs) {
      expect(
        gradeProofOrder(p, [for (final s in p.steps) s.id]).correct,
        isTrue,
        reason: p.id,
      );
      expect(
        gradeProofReasons(p, {
          for (final s in p.steps) s.id: s.reasonId,
        }).correct,
        isTrue,
        reason: p.id,
      );
      for (var seed = 1; seed <= 20; seed++) {
        // 出題のままの並びは正解ではない（まぎらわしい行が入っている）
        expect(
          gradeProofOrder(p, p.shuffledStepIds(seed)).correct,
          isFalse,
          reason: '${p.id}~$seed',
        );
      }
    }
  });
  }
  test('証明の図: 描ける図は通り、壊れた図・説明文のない図はエラー。草案の図は SVG にできる', () {
    const dir = 'docs/content_drafts/suugaku_chu2';
    String read(String f) => File('$dir/$f').readAsStringSync();
    Map<String, dynamic> manifest() => {
          ...jsonDecode(read('manifest.json')) as Map<String, dynamic>,
        };
    Set<String> codes(String proofs, [String? texts]) {
      final r = validateContentPack(
        jsonEncode(manifest()),
        (p) => p == 'proofs.json' ? proofs : (p == 'texts.json' && texts != null ? texts : read(p)),
      );
      return r.issues.where((i) => i.isError).map((i) => i.code).toSet();
    }

    final good = jsonDecode(read('proofs.json')) as Map<String, dynamic>;
    expect(codes(jsonEncode(good)), isEmpty);
    // 壊れた図（未知の点を使う線）
    final bad = jsonDecode(read('proofs.json')) as Map<String, dynamic>;
    ((bad['proofs'] as List).first as Map)['figure'] = {
      'viewBox': [0, 0, 100, 80],
      'points': {'A': [1, 1]},
      'draw': [
        {'seg': ['A', 'Z']},
      ],
      'altId': 'pffig_m2_cong_vertical',
    };
    expect(codes(jsonEncode(bad)), contains('pack_proof_figure_invalid'));
    // 図の説明文がない
    final texts = jsonDecode(read('texts.json')) as Map<String, dynamic>;
    (texts['texts'] as Map).remove('pffig_m2_cong_vertical');
    expect(codes(jsonEncode(good), jsonEncode(texts)), contains('pack_text_missing'));
    // 草案の図は SVG になる
    for (final p in ProofSet.parse(read('proofs.json')).proofs) {
      final svg = FigureTemplate.fromJson(p.figure!, const {}).resolve(const {}, (t) => t)!.toSvg();
      expect(svg, contains('<svg'), reason: p.id);
    }
  });

}

Map<String, dynamic> _json() => {
  'id': 'p1',
  'unitId': 'u1',
  'titleId': 't',
  'givenId': 'g',
  'goalId': 'z',
  'reasons': [
    {'id': 'r1', 'textId': 'x1'},
  ],
  'steps': [
    {'id': 'a', 'claimId': 'ca', 'reasonId': 'r1'},
  ],
};

String _raw() =>
    '{"id":"p1","unitId":"u1","titleId":"t","givenId":"g","goalId":"z","reasons":[{"id":"r1","textId":"x"}],"steps":[{"id":"a","claimId":"c","reasonId":"r1"}]}';
