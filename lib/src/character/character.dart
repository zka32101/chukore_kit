import 'dart:convert';

import '../bank/question_bank.dart';
import '../practice/play_round.dart';

/// 相棒（キャラ）とバッジ。国をまたいで使える共通の部品と、その国らしいキャラ（地域キャラ）を、同じ仕組みのデータ
/// （`characters.json`）で扱う。設計は `docs/character_design.md`。
///
/// 守ること（責めない）: 得点や順位に依らない／**運で決まる入手（ガチャ）なし**／ポイントは増えるだけで、休んでも**下がらない**／
/// 課金で進化を早めない／時間で急がせない。文言と絵は ID だけを持ち、国・言語ごとに差し替える。

/// 子どもの学びの実績（アプリが自分の記録から数えて渡す。キットは集めず、送らない）。
class LearnerMetrics {
  const LearnerMetrics([this.values = const {}]);

  final Map<String, int> values;

  int operator [](String metric) => values[metric] ?? 0;
}

/// 実績の種類。累計で数え、**連続日数のように途切れると消えるものは使わない**。
const knownMetrics = {
  'rounds_finished', // 最後までやった遊びの回数
  'best_link', // いちばん長かったつながり
  'comebacks', // 立て直した回数
  'units_done', // 単元テストで「できた」になった単元の数
  'tests_done', // 模擬テスト・単元テストを最後までやった回数
  'overcome_stamps', // 克服スタンプ（まちがいを乗りこえた数）
  'days_studied', // 勉強した日の累計（連続でなくてよい）
  'regional_units', // その地域らしい単元（例: 自国の地理・歴史）を終えた数
};

/// 進化の 1 段階。
class EvolutionStage {
  const EvolutionStage({
    required this.nameId,
    required this.textId,
    required this.artId,
    required this.points,
  });

  final String nameId, textId;

  /// 絵の名前（アプリが持つ素材の名前）。
  final String artId;

  /// この段階になるのに必要な累計の成長ポイント（最初の段階は 0）。
  final int points;
}

/// 入手の条件。無ければ最初から相棒にできる（はじめの 1 匹）。
class UnlockRule {
  const UnlockRule({required this.metric, required this.atLeast});

  final String metric;
  final int atLeast;

  bool met(LearnerMetrics m) => m[metric] >= atLeast;
}

enum CharacterKind { common, regional }

class CharacterSpec {
  const CharacterSpec({
    required this.id,
    required this.kind,
    required this.regions,
    required this.subjects,
    required this.nameId,
    required this.storyId,
    required this.stages,
    this.unlock,
  });

  final String id;

  /// 共通のキャラか、その国らしいキャラ（地域キャラ）か。
  final CharacterKind kind;

  /// 出す国（ISO 3166-1 の 2 文字）。空なら全部の国。
  final List<String> regions;

  /// 出す教科アプリ。空なら全教科。
  final List<String> subjects;
  final String nameId, storyId;
  final List<EvolutionStage> stages;
  final UnlockRule? unlock;

  bool availableIn({String? region, String? subject}) =>
      (regions.isEmpty || (region != null && regions.contains(region))) &&
      (subjects.isEmpty || (subject != null && subjects.contains(subject)));

  /// 成長ポイントからの段階（0 始まり）。ポイントが増えるだけなので、段階も下がらない。
  int stageOf(int points) {
    var s = 0;
    for (var i = 0; i < stages.length; i++) {
      if (points >= stages[i].points) s = i;
    }
    return s;
  }

  /// 次の段階までの残りポイント（最終段階は null）。
  int? pointsToNext(int points) {
    final s = stageOf(points);
    return s + 1 < stages.length ? stages[s + 1].points - points : null;
  }

  Iterable<String> get textIds => [
    nameId,
    storyId,
    for (final s in stages) ...[s.nameId, s.textId],
  ];
}

class BadgeSpec {
  const BadgeSpec({
    required this.id,
    required this.titleId,
    required this.textId,
    required this.artId,
    required this.metric,
    required this.atLeast,
  });

  final String id, titleId, textId, artId, metric;
  final int atLeast;
}

class CharacterSet {
  const CharacterSet({required this.characters, required this.badges});

  final List<CharacterSpec> characters;
  final List<BadgeSpec> badges;

  Iterable<String> get textIds => [
    for (final c in characters) ...c.textIds,
    for (final b in badges) ...[b.titleId, b.textId],
  ];

  static const _idRe = r'^[A-Za-z0-9_]+$';

  static String _str(Map<String, dynamic> m, String k, String where) {
    final v = m[k];
    if (v is! String || v.isEmpty) throw FormatException('$where: $k は空でない文字列');
    return v;
  }

  static int _int(Map<String, dynamic> m, String k, String where) {
    final v = m[k];
    if (v is! int) throw FormatException('$where: $k は整数');
    return v;
  }

  static List<String> _strs(Map<String, dynamic> m, String k, String where) {
    final v = m[k];
    if (v == null) return const [];
    if (v is! List || v.any((e) => e is! String)) {
      throw FormatException('$where: $k は文字列の配列');
    }
    return [for (final e in v) e as String];
  }

  /// `{"version":1,"characters":[…],"badges":[…]}`。読めなければ [FormatException]。
  factory CharacterSet.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('キャラの JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) {
      throw const FormatException('キャラの JSON はオブジェクトです');
    }
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final chars = <CharacterSpec>[];
    for (final raw in (j['characters'] as List? ?? const [])) {
      final c = Map<String, dynamic>.from(raw as Map);
      final id = _str(c, 'id', 'キャラ');
      if (!RegExp(_idRe).hasMatch(id)) {
        throw FormatException('キャラの id は英数字と _ だけ: $id');
      }
      final kindName = _str(c, 'kind', id);
      final kind = CharacterKind.values
          .where((k) => k.name == kindName)
          .firstOrNull;
      if (kind == null) throw FormatException('$id: kind は common か regional');
      final stages = [
        for (final raw in (c['stages'] as List? ?? const []))
          () {
            final s = Map<String, dynamic>.from(raw as Map);
            return EvolutionStage(
              nameId: _str(s, 'nameId', '$id の段階'),
              textId: _str(s, 'textId', '$id の段階'),
              artId: _str(s, 'artId', '$id の段階'),
              points: _int(s, 'points', '$id の段階'),
            );
          }(),
      ];
      final u = c['unlock'] == null
          ? null
          : Map<String, dynamic>.from(c['unlock'] as Map);
      chars.add(
        CharacterSpec(
          id: id,
          kind: kind,
          regions: _strs(c, 'regions', id),
          subjects: _strs(c, 'subjects', id),
          nameId: _str(c, 'nameId', id),
          storyId: _str(c, 'storyId', id),
          stages: stages,
          unlock: u == null
              ? null
              : UnlockRule(
                  metric: _str(u, 'metric', '$id の入手条件'),
                  atLeast: _int(u, 'atLeast', '$id の入手条件'),
                ),
        ),
      );
    }
    final badges = [
      for (final raw in (j['badges'] as List? ?? const []))
        () {
          final b = Map<String, dynamic>.from(raw as Map);
          return BadgeSpec(
            id: _str(b, 'id', 'バッジ'),
            titleId: _str(b, 'titleId', 'バッジ'),
            textId: _str(b, 'textId', 'バッジ'),
            artId: _str(b, 'artId', 'バッジ'),
            metric: _str(b, 'metric', 'バッジ'),
            atLeast: _int(b, 'atLeast', 'バッジ'),
          );
        }(),
    ];
    final ids = <String>{};
    for (final id in [
      for (final c in chars) c.id,
      for (final b in badges) b.id,
    ]) {
      if (!ids.add(id)) throw FormatException('id が重複しています: $id');
    }
    return CharacterSet(characters: chars, badges: badges);
  }

  /// この国・この教科で出せるキャラのうち、入手条件を満たしたもの。
  List<CharacterSpec> unlocked(
    LearnerMetrics m, {
    String? region,
    String? subject,
  }) => [
    for (final c in characters)
      if (c.availableIn(region: region, subject: subject) &&
          (c.unlock?.met(m) ?? true))
        c,
  ];

  /// もらったバッジ（一度もらったら、アプリが保存して消さない。ここでは今の実績で足りているものを返す）。
  List<BadgeSpec> earnedBadges(LearnerMetrics m) => [
    for (final b in badges)
      if (m[b.metric] >= b.atLeast) b,
  ];
}

/// 1 回の遊び（ラウンド）で増える成長ポイント。最後までやれば必ず 1 点（正解数に依らない）。
/// つながり・立て直しは少し多く。**マイナスはない**。
int growthPointsForRound(Set<PlayReward> rewards) {
  var p = 0;
  if (rewards.contains(PlayReward.finished)) p += 1;
  if (rewards.contains(PlayReward.link3)) p += 1;
  if (rewards.contains(PlayReward.link5)) p += 1;
  if (rewards.contains(PlayReward.comeback)) p += 2;
  return p;
}

/// 単元テストで「できた」になったときの成長ポイント。
const growthPointsForUnitDone = 5;

/// 相棒ごとの成長ポイント。増えるだけ（負の値は 0 として扱い、休んでも下がらない）。
class CompanionProgress {
  const CompanionProgress({this.points = const {}, this.activeId});

  final Map<String, int> points;

  /// いま連れている相棒。
  final String? activeId;

  int pointsOf(String id) => points[id] ?? 0;

  /// 相棒 [id] に [add] ポイントを足す。
  CompanionProgress grow(String id, int add) => CompanionProgress(
    points: {...points, id: pointsOf(id) + (add < 0 ? 0 : add)},
    activeId: activeId,
  );

  CompanionProgress choose(String id) =>
      CompanionProgress(points: points, activeId: id);
}

/// キャラとバッジの検証。
/// エラー: `character_stage_invalid`（段階は 3〜6 個、最初は 0 点、点は増える順）・`character_region_invalid`（国コードは大文字 2 文字）・
/// `character_regional_no_region`（地域キャラは国を指定する）・`character_metric_unknown`・`character_threshold_invalid`（1 以上）・
/// `character_no_starter`（入手条件のないはじめの共通キャラが無い）。
List<ValidationIssue> validateCharacters(CharacterSet set) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  final art = RegExp(r'^[a-z0-9_]+$');
  for (final c in set.characters) {
    if (c.stages.length < 3 || c.stages.length > 6) {
      err('character_stage_invalid', c.id, '段階は 3〜6 個（${c.stages.length}）');
    }
    if (c.stages.isNotEmpty && c.stages.first.points != 0) {
      err('character_stage_invalid', c.id, '最初の段階は 0 点から');
    }
    for (var i = 1; i < c.stages.length; i++) {
      if (c.stages[i].points <= c.stages[i - 1].points) {
        err('character_stage_invalid', c.id, '点は増える順にしてください（${i + 1} 番目）');
      }
    }
    for (final s in c.stages) {
      if (!art.hasMatch(s.artId)) {
        err('character_stage_invalid', c.id, '絵の名前は小文字・数字・_ だけ: ${s.artId}');
      }
    }
    for (final r in c.regions) {
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(r)) {
        err('character_region_invalid', c.id, '国コードは大文字 2 文字: $r');
      }
    }
    if (c.kind == CharacterKind.regional && c.regions.isEmpty) {
      err('character_regional_no_region', c.id, '地域キャラは国を指定します');
    }
    final u = c.unlock;
    if (u != null) {
      if (!knownMetrics.contains(u.metric)) {
        err('character_metric_unknown', c.id, '知らない実績: ${u.metric}');
      }
      if (u.atLeast < 1) err('character_threshold_invalid', c.id, '入手条件は 1 以上');
    }
  }
  for (final b in set.badges) {
    if (!knownMetrics.contains(b.metric)) {
      err('character_metric_unknown', b.id, '知らない実績: ${b.metric}');
    }
    if (b.atLeast < 1) err('character_threshold_invalid', b.id, 'バッジの条件は 1 以上');
    if (!art.hasMatch(b.artId)) {
      err('character_stage_invalid', b.id, '絵の名前は小文字・数字・_ だけ: ${b.artId}');
    }
  }
  if (set.characters.isNotEmpty &&
      !set.characters.any(
        (c) => c.unlock == null && c.kind == CharacterKind.common,
      )) {
    err(
      'character_no_starter',
      'characters',
      '入手条件のないはじめの共通キャラが必要です（どの国でも最初の相棒がいるように）',
    );
  }
  return issues;
}
