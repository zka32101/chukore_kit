import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'docs/content_drafts/characters_sample';
CharacterSet _set() =>
    CharacterSet.parse(File('$_dir/characters.json').readAsStringSync());
Map<String, dynamic> _json() =>
    jsonDecode(File('$_dir/characters.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  artTests();
  test('見本: 検証にエラーなし。文言がすべてそろい、1 つ 300 文字以内。教科は 5 つ', () {
    final set = _set();
    expect(validateCharacters(set), isEmpty);
    expect(set.subjects, {'math', 'en', 'social', 'science', 'language'});
    final texts = ContentTexts.parse(
      File('$_dir/texts.json').readAsStringSync(),
    );
    for (final id in set.textIds) {
      expect(texts.texts, contains(id));
      expect(
        texts.texts[id]!.runes.length,
        lessThanOrEqualTo(ContentTexts.longText),
        reason: id,
      );
    }
  });

  test('進化: ポイントが増えるだけで段階が上がり、下がらない。最終段階は次がない', () {
    final c = _set().characters.first;
    expect(
      [
        for (final p in [0, 11, 12, 39, 40, 89, 90, 159, 160, 999])
          c.stageOf(p),
      ],
      [0, 0, 1, 1, 2, 2, 3, 3, 4, 4],
    );
    expect(c.pointsToNext(0), 12);
    expect(c.pointsToNext(11), 1);
    expect(c.pointsToNext(160), isNull);
    var prev = 0;
    for (var p = 0; p < 300; p++) {
      expect(c.stageOf(p), greaterThanOrEqualTo(prev));
      prev = c.stageOf(p);
    }
  });

  test('姿の分岐: 最後の段階で、勉強の仕方（実績）に合う姿になる。運では決まらず、同じ実績なら同じ。それまでは姿はない', () {
    final c = _set().characters.first;
    const persistent = LearnerMetrics({
      'comebacks': 9,
      'best_link': 4,
      'days_studied': 6,
    });
    const quick = LearnerMetrics({
      'comebacks': 2,
      'best_link': 12,
      'days_studied': 6,
    });
    const steady = LearnerMetrics({
      'comebacks': 1,
      'best_link': 3,
      'days_studied': 60,
    });
    expect(c.formFor(100, persistent), isNull); // まだ最後の段階ではない
    expect(c.formFor(160, persistent)!.id, 'f1'); // 立て直しが多い → ねばり型
    expect(c.formFor(160, quick)!.id, 'f2'); // つながりが長い → ひらめき型
    expect(c.formFor(160, steady)!.id, 'f3'); // 日数が多い → こつこつ型
    expect(c.formFor(160, const LearnerMetrics())!.id, 'f1'); // 同点は先に書いた姿
    expect(c.formFor(160, quick)!.id, c.formFor(160, quick)!.id);
  });

  test('成長ポイント: 最後までやれば必ず 1 点。立て直しは多め。マイナスはなく、相棒は教科ごとに 1 匹', () {
    expect(growthPointsForRound({PlayReward.finished}), 1);
    expect(
      growthPointsForRound({
        PlayReward.finished,
        PlayReward.link3,
        PlayReward.link5,
        PlayReward.comeback,
      }),
      5,
    );
    expect(growthPointsForRound(const {}), 0);
    var p = const CompanionProgress()
        .grow('ch_math', 3)
        .grow('ch_math', -5)
        .grow('ch_math', 2);
    expect(p.pointsOf('ch_math'), 5); // 負の値は 0 として扱う（下がらない）
    p = p.choose('math', 'ch_math').choose('en', 'ch_en');
    expect(p.activeIn('math'), 'ch_math');
    expect(p.activeIn('en'), 'ch_en');
    expect(p.activeIn('social'), isNull);
    // 数学の勉強は数学の相棒だけを育てる。育てる相棒がない教科では何も変わらない
    p = p.growActive('math', 4).growActive('social', 9);
    expect(p.pointsOf('ch_math'), 9);
    expect(p.pointsOf('ch_en'), 0);
    expect(p.points.keys.toSet(), {'ch_math'});
  });

  test('はじめに選べる相棒: 教科ごと。その国らしい地域キャラを先に、共通キャラを後に', () {
    final set = _set();
    String ids(List<CharacterSpec> l) => l.map((c) => c.id).join(',');
    expect(ids(set.startersFor('math', region: 'JP')), 'ch_math');
    expect(
      ids(set.startersFor('social', region: 'JP')),
      'ch_social_jp,ch_social',
    );
    expect(
      ids(set.startersFor('social', region: 'BR')),
      'ch_social_br,ch_social',
    );
    expect(
      ids(set.startersFor('social', region: 'US')),
      'ch_social',
    ); // 国のキャラがない国は共通だけ
    expect(ids(set.startersFor('social')), 'ch_social'); // 国が不明なら共通だけ
    expect(ids(set.startersFor('en', region: 'IN')), 'ch_en'); // 地域キャラは社会だけ
    expect(set.startersFor('art'), isEmpty);
  });

  test('入手条件つきのキャラ（任意）: 実績で解放され、国と教科で絞る', () {
    final j = _json();
    (j['characters'] as List).add({
      'id': 'ch_extra',
      'kind': 'common',
      'subjects': ['math'],
      'nameId': 'ch_math_name',
      'storyId': 'ch_math_story',
      'unlock': {'metric': 'units_done', 'atLeast': 3},
      'stages': (j['characters'] as List).first['stages'],
    });
    final set = CharacterSet.parse(jsonEncode(j));
    expect(
      set.unlocked(const LearnerMetrics(), subject: 'math').map((c) => c.id),
      ['ch_math'],
    );
    expect(
      set
          .unlocked(const LearnerMetrics({'units_done': 3}), subject: 'math')
          .map((c) => c.id),
      ['ch_math', 'ch_extra'],
    );
    expect(
      set
          .unlocked(const LearnerMetrics({'units_done': 3}), subject: 'en')
          .map((c) => c.id),
      ['ch_en'],
    );
  });

  test('バッジ: 累計の実績で決まり、連続を求めない（勉強した日は連続でなくてよい）', () {
    final set = _set();
    expect(set.earnedBadges(const LearnerMetrics()), isEmpty);
    final ids = set
        .earnedBadges(
          const LearnerMetrics({
            'rounds_finished': 12,
            'best_link': 5,
            'days_studied': 8,
          }),
        )
        .map((b) => b.id)
        .toSet();
    expect(ids, {'bd_first_round', 'bd_rounds_10', 'bd_link5', 'bd_days7'});
    expect(set.badges.every((b) => knownMetrics.contains(b.metric)), isTrue);
    expect(
      knownMetrics.any((m) => m.contains('streak')),
      isFalse,
    ); // 途切れて消える連続日数は使わない
  });

  test('検証: 段階・姿・国コード・知らない実績・教科ごとのはじめのキャラなしを見つける', () {
    Set<String> codes(void Function(Map<String, dynamic>) f) {
      final j = _json();
      f(j);
      return validateCharacters(
        CharacterSet.parse(jsonEncode(j)),
      ).map((i) => i.code).toSet();
    }

    List ch(Map<String, dynamic> j) => j['characters'] as List;
    expect(
      codes((j) => (ch(j)[0]['stages'] as List).removeLast()),
      isEmpty,
    ); // 4 段階は許す
    expect(
      codes((j) => (ch(j)[0]['stages'] as List).removeRange(2, 5)),
      contains('character_stage_invalid'),
    );
    expect(
      codes((j) => ch(j)[0]['stages'][1]['points'] = 0),
      contains('character_stage_invalid'),
    );
    expect(
      codes((j) => ch(j)[0]['stages'][0]['points'] = 1),
      contains('character_stage_invalid'),
    );
    expect(
      codes((j) => (ch(j)[0]['forms'] as List).removeRange(1, 3)),
      contains('character_form_invalid'),
    );
    expect(
      codes((j) => ch(j)[0]['forms'][0]['scale'] = 0),
      contains('character_form_invalid'),
    );
    expect(
      codes((j) => ch(j)[0]['forms'][0]['metric'] = 'streak_days'),
      contains('character_metric_unknown'),
    );
    expect(
      codes((j) => ch(j)[5]['regions'] = ['jp']),
      contains('character_region_invalid'),
    );
    expect(
      codes((j) => ch(j)[5].remove('regions')),
      contains('character_regional_no_region'),
    );
    expect(
      codes(
        (j) => ch(j)[0]['unlock'] = {'metric': 'rounds_finished', 'atLeast': 1},
      ),
      contains('character_no_starter'),
    ); // 数学のはじめの相棒がいなくなる
    expect(
      codes((j) => ch(j)[0]['unlock'] = {'metric': 'streak', 'atLeast': 1}),
      contains('character_metric_unknown'),
    );
    expect(
      codes((j) => ch(j)[0]['unlock'] = {'metric': 'units_done', 'atLeast': 0}),
      contains('character_threshold_invalid'),
    );
    expect(
      codes((j) => (j['badges'] as List)[0]['atLeast'] = 0),
      contains('character_threshold_invalid'),
    );
  });

  test('読み込み: 未知の種類・重複 ID・版違いはエラー', () {
    expect(() => CharacterSet.parse('{"version":2}'), throwsFormatException);
    final j = _json();
    (j['characters'] as List)[1]['id'] = 'ch_math';
    expect(() => CharacterSet.parse(jsonEncode(j)), throwsFormatException);
    final k = _json();
    (k['characters'] as List)[0]['kind'] = 'rare';
    expect(() => CharacterSet.parse(jsonEncode(k)), throwsFormatException);
  });
}

/// 取得の記録つきの偽の取得先（URL → 中身）と、メモリ上の保存先。
class _Fetcher implements ArtFetcher {
  _Fetcher(this.files);
  final Map<String, Uint8List> files;
  final List<Uri> asked = [];
  @override
  Future<Uint8List?> get(Uri url) async {
    asked.add(url);
    return files[url.toString()];
  }
}

class _Cache implements ArtCache {
  final Map<String, Uint8List> data = {};
  @override
  Future<Uint8List?> read(String id) async => data[id];
  @override
  Future<void> write(String id, Uint8List d) async => data[id] = d;
}

void artTests() {
  ArtManifest manifest() =>
      ArtManifest.parse(File('$_dir/art.json').readAsStringSync());
  Map<String, Uint8List> served(ArtManifest m) => {
    for (final e in m.arts.values)
      m.urlOf(e).toString(): Uint8List.fromList(
        File('$_dir/art/${e.path}').readAsBytesSync(),
      ),
  };

  test('SHA-256: 既知の値と一致する（空・abc・長い入力・境界の長さ）', () {
    expect(
      sha256Hex(const []),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex('abc'.codeUnits),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Hex(
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'.codeUnits,
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(
      sha256Hex(List.filled(1000000, 0x61)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
    // 55・56・63・64 バイトはパディングの境界
    expect(
      sha256Hex(List.filled(55, 0x61)),
      '9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318',
    );
    expect(
      sha256Hex(List.filled(56, 0x61)),
      'b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a',
    );
    expect(
      sha256Hex(List.filled(64, 0x61)),
      'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb',
    );
  });

  test('見本の画像: 検証にエラーなし。キャラ・バッジの絵がすべてそろい、使われない画像もない', () {
    final m = manifest();
    expect(validateArt(m, characters: _set()), isEmpty);
    for (final e in m.arts.values) {
      final data = File('$_dir/art/${e.path}').readAsBytesSync();
      expect(sha256Hex(data), e.sha256, reason: e.id);
      expect(data.length, e.bytes, reason: e.id);
    }
    expect(
      m.arts.values.where((e) => e.bundled).length,
      4,
    ); // はじめの相棒の最初の姿だけアプリに入れる
  });

  test('画像の検証: https 以外・クエリ・危ないパス・ハッシュ・大きさ・形式・足りない絵を見つける', () {
    Set<String> codes(void Function(Map<String, dynamic>) f) {
      final j =
          jsonDecode(File('$_dir/art.json').readAsStringSync())
              as Map<String, dynamic>;
      f(j);
      return validateArt(
        ArtManifest.parse(jsonEncode(j)),
        characters: _set(),
      ).where((i) => i.isError).map((i) => i.code).toSet();
    }

    List arts(Map<String, dynamic> j) => j['arts'] as List;
    expect(
      codes((j) => j['baseUrl'] = 'http://example.invalid/'),
      contains('art_base_invalid'),
    );
    expect(
      codes((j) => j['baseUrl'] = 'https://example.invalid/a?user=1'),
      contains('art_base_invalid'),
    );
    expect(
      codes((j) => arts(j)[0]['path'] = '../x.svg'),
      contains('art_path_invalid'),
    );
    expect(
      codes((j) => arts(j)[0]['path'] = 'https://evil.invalid/x.svg'),
      contains('art_path_invalid'),
    );
    expect(
      codes((j) => arts(j)[0]['path'] = 'x.svg?id=1'),
      contains('art_path_invalid'),
    );
    expect(
      codes((j) => arts(j)[0]['sha256'] = 'ABC'),
      contains('art_sha_invalid'),
    );
    expect(
      codes((j) => arts(j)[0]['bytes'] = 5 * 1024 * 1024),
      contains('art_size_invalid'),
    );
    expect(
      codes((j) => arts(j)[0]['format'] = 'exe'),
      contains('art_format_invalid'),
    );
    expect(codes((j) => arts(j).removeAt(0)), contains('art_missing'));
  });

  test('ダウンロード: 既定では取りに行かない。有効にすると取得して確かめて保存する。2 回目は保存済みを使う', () async {
    final m = manifest();
    final fetcher = _Fetcher(served(m));
    final cache = _Cache();
    final ids = ['ch_math_s1', 'ch_math_s2', 'ch_math_f1'];
    // 既定（無効）: アプリに入っているもの以外は仮の絵。ネットワークには出ない
    var st = await ensureArt(m, ids, fetcher: fetcher, cache: cache);
    expect(st, {
      'ch_math_s1': ArtStatus.bundled,
      'ch_math_s2': ArtStatus.disabled,
      'ch_math_f1': ArtStatus.disabled,
    });
    expect(fetcher.asked, isEmpty);
    // 有効
    st = await ensureArt(
      m,
      ids,
      fetcher: fetcher,
      cache: cache,
      downloadEnabled: true,
    );
    expect(st['ch_math_s2'], ArtStatus.downloaded);
    expect(st['ch_math_f1'], ArtStatus.downloaded);
    expect(fetcher.asked.length, 2);
    // 取りに行く URL は固定で、クエリや識別子を含まない
    for (final u in fetcher.asked) {
      expect(u.scheme, 'https');
      expect(u.hasQuery, isFalse);
      expect(u.userInfo, isEmpty);
    }
    // 2 回目は保存済み。無効にしても使える
    fetcher.asked.clear();
    st = await ensureArt(m, ids, fetcher: fetcher, cache: cache);
    expect(st['ch_math_s2'], ArtStatus.cached);
    expect(fetcher.asked, isEmpty);
  });

  test(
    'ダウンロード: 中身が違う・大きさが違う・取れない・知らない画像は failed（勉強は止めない）。壊れた保存は取り直す',
    () async {
      final m = manifest();
      final files = served(m);
      final url = m.urlOf(m.arts['ch_math_s2']!).toString();
      final other = m.urlOf(m.arts['ch_math_s3']!).toString();
      files[url] = Uint8List.fromList(
        [...files[url]!]..[10] ^= 1,
      ); // 1 バイトだけ違う（同じ大きさ）
      files.remove(other); // 取れない
      final cache = _Cache();
      final st = await ensureArt(
        m,
        ['ch_math_s2', 'ch_math_s3', 'nothing'],
        fetcher: _Fetcher(files),
        cache: cache,
        downloadEnabled: true,
      );
      expect(st, {
        'ch_math_s2': ArtStatus.failed,
        'ch_math_s3': ArtStatus.failed,
        'nothing': ArtStatus.failed,
      });
      expect(cache.data, isEmpty); // 確かめられなかったものは保存しない
      // 保存済みが壊れていたら、取り直す
      final good = served(m);
      cache.data['ch_math_s2'] = Uint8List.fromList([1, 2, 3]);
      final st2 = await ensureArt(
        m,
        ['ch_math_s2'],
        fetcher: _Fetcher(good),
        cache: cache,
        downloadEnabled: true,
      );
      expect(st2['ch_math_s2'], ArtStatus.downloaded);
      expect(
        sha256Hex(cache.data['ch_math_s2']!),
        m.arts['ch_math_s2']!.sha256,
      );
    },
  );

  test('単元のキャラ: 単元ごとに 1 匹。その単元の正解の数で育ち、下がらない。単元がない・重複はエラー', () {
    final set = _set();
    expect(set.unitCharacters.map((c) => c.unitId).toSet(), {
      'm1_linear',
      'm2_sim_solve',
      'm3_quad_solve',
    });
    final c = set.unitCharacterFor('m1_linear')!;
    expect(c.kind, CharacterKind.unit);
    expect(set.unitCharacterFor('m1_data_rep'), isNull);
    expect(growthPointsForUnit(correct: 12, done: false), 12);
    expect(growthPointsForUnit(correct: 12, done: true), 17);
    expect(growthPointsForUnit(correct: -3, done: false), 0);
    expect(
      [
        for (final pts in [0, 4, 5, 14, 15, 29, 30])
          c.stageOf(growthPointsForUnit(correct: pts, done: false)),
      ],
      [0, 0, 1, 1, 2, 2, 3],
    );
    // 単元のキャラははじめの相棒には入らない
    expect(set.startersFor('math', region: 'JP').map((x) => x.id), ['ch_math']);
    // 単元の確認（実際の単元ツリーと突き合わせる）
    final units = <String>{};
    for (final d in ['suugaku_chu1', 'suugaku_chu2', 'suugaku_chu3']) {
      final j =
          jsonDecode(
                File('docs/content_drafts/$d/units.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final u in j['units'] as List) {
        units.add((u as Map)['id'] as String);
      }
    }
    expect(validateCharacters(set, unitIds: units), isEmpty);
    expect(
      validateCharacters(
        set,
        unitIds: {'m1_linear'},
      ).map((i) => i.code).toSet(),
      {'character_unit_missing'},
    );
    final j =
        jsonDecode(File('$_dir/characters.json').readAsStringSync())
            as Map<String, dynamic>;
    final extra = Map<String, dynamic>.from(
      (j['characters'] as List).last as Map,
    )..['id'] = 'ch_unit_dup';
    (j['characters'] as List).add(extra);
    expect(
      validateCharacters(CharacterSet.parse(jsonEncode(j))).map((i) => i.code),
      contains('character_unit_duplicate'),
    );
    (j['characters'] as List).removeLast();
    ((j['characters'] as List).last as Map).remove('unitId');
    expect(
      validateCharacters(CharacterSet.parse(jsonEncode(j))).map((i) => i.code),
      contains('character_unit_missing'),
    );
  });
}
