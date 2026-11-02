import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

CharacterSet _set() => CharacterSet.parse(
  File(
    'docs/content_drafts/characters_sample/characters.json',
  ).readAsStringSync(),
);

void main() {
  test('見本: 検証にエラーなし。文言がすべてそろい、1 つ 300 文字以内', () {
    final set = _set();
    expect(validateCharacters(set), isEmpty);
    final texts = ContentTexts.parse(
      File(
        'docs/content_drafts/characters_sample/texts.json',
      ).readAsStringSync(),
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

  test('成長ポイント: 最後までやれば必ず 1 点（正解数に依らない）。立て直しは多め。マイナスはない', () {
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
        .grow('ch_mochi', 3)
        .grow('ch_mochi', -5)
        .grow('ch_mochi', 2);
    expect(p.pointsOf('ch_mochi'), 5); // 負の値は 0 として扱う（下がらない）
    expect(p.pointsOf('ch_sora'), 0);
    p = p.choose('ch_mochi');
    expect(p.activeId, 'ch_mochi');
    expect(p.pointsOf('ch_mochi'), 5);
  });

  test('入手: 国と教科で絞り、実績で解放。はじめの共通キャラは最初から。運で決まる要素なし（同じ実績なら同じ結果）', () {
    final set = _set();
    String ids(List<CharacterSpec> l) => l.map((c) => c.id).join(',');
    expect(ids(set.unlocked(const LearnerMetrics(), region: 'JP')), 'ch_mochi');
    expect(
      ids(
        set.unlocked(
          const LearnerMetrics({'rounds_finished': 10}),
          region: 'JP',
        ),
      ),
      'ch_mochi,ch_sora',
    );
    const m = LearnerMetrics({'rounds_finished': 10, 'regional_units': 3});
    expect(ids(set.unlocked(m, region: 'JP')), 'ch_mochi,ch_sora,ch_kodama');
    expect(ids(set.unlocked(m, region: 'BR')), 'ch_mochi,ch_sora,ch_tatu');
    expect(
      ids(set.unlocked(m, region: 'US')),
      'ch_mochi,ch_sora',
    ); // 国のキャラがない国は共通だけ
    expect(ids(set.unlocked(m)), 'ch_mochi,ch_sora'); // 国が不明なら共通だけ
    expect(
      set.unlocked(m, region: 'JP').map((c) => c.id),
      set.unlocked(m, region: 'JP').map((c) => c.id),
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

  test('検証: 段階の不正・国コード・地域キャラの国なし・知らない実績・はじめのキャラなしを見つける', () {
    Map<String, dynamic> base() =>
        jsonDecode(
              File(
                'docs/content_drafts/characters_sample/characters.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    Set<String> codes(void Function(Map<String, dynamic>) f) {
      final j = base();
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
      codes((j) => ch(j)[2]['regions'] = ['jp']),
      contains('character_region_invalid'),
    );
    expect(
      codes((j) => ch(j)[2].remove('regions')),
      contains('character_regional_no_region'),
    );
    expect(
      codes((j) => ch(j)[1]['unlock']['metric'] = 'streak_days'),
      contains('character_metric_unknown'),
    );
    expect(
      codes((j) => ch(j)[1]['unlock']['atLeast'] = 0),
      contains('character_threshold_invalid'),
    );
    expect(
      codes(
        (j) => ch(j)[0]['unlock'] = {'metric': 'rounds_finished', 'atLeast': 1},
      ),
      contains('character_no_starter'),
    );
    expect(
      codes((j) => (j['badges'] as List)[0]['atLeast'] = 0),
      contains('character_threshold_invalid'),
    );
  });

  test('読み込み: 未知の種類・重複 ID・版違いはエラー', () {
    expect(() => CharacterSet.parse('{"version":2}'), throwsFormatException);
    final j =
        jsonDecode(
              File(
                'docs/content_drafts/characters_sample/characters.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    (j['characters'] as List)[1]['id'] = 'ch_mochi';
    expect(() => CharacterSet.parse(jsonEncode(j)), throwsFormatException);
    final k =
        jsonDecode(
              File(
                'docs/content_drafts/characters_sample/characters.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    (k['characters'] as List)[0]['kind'] = 'rare';
    expect(() => CharacterSet.parse(jsonEncode(k)), throwsFormatException);
  });
}
