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

/// 進化の分岐（最後の段階の姿）。**勉強の仕方**で決まり、どれも同じ価値（上下はない）。
/// 実績 [metric] を [scale] でわった値がいちばん大きい姿になる（同じなら先に書いたもの）。運では決まらない。
class FormSpec {
  const FormSpec({
    required this.id,
    required this.nameId,
    required this.textId,
    required this.artId,
    required this.metric,
    required this.scale,
  });

  final String id, nameId, textId, artId, metric;
  final int scale;
}

/// 種類: 共通の相棒／その国らしい相棒（地域キャラ）／分野のキャラ（その分野の学びといっしょに育つ。図鑑に並ぶ）。
enum CharacterKind { common, regional, field }

class CharacterSpec {
  const CharacterSpec({
    required this.id,
    required this.kind,
    required this.regions,
    required this.subjects,
    required this.nameId,
    required this.storyId,
    required this.stages,
    this.forms = const [],
    this.unlock,
    this.fieldId,
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

  /// 最後の段階の姿の分岐（無ければ空）。
  final List<FormSpec> forms;
  final UnlockRule? unlock;

  /// 分野のキャラ（`kind` が `field`）が育つ分野（単元ツリーの一番上の単元）。成長ポイントは、その分野の正解の数（と「できた」）から数える。
  final String? fieldId;

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

  /// 最後の段階にいるときの姿。勉強の仕方（実績）でいちばん多いものに合う姿（分岐がなければ null）。
  FormSpec? formFor(int points, LearnerMetrics m) {
    if (forms.isEmpty || stageOf(points) != stages.length - 1) return null;
    var best = forms.first;
    for (final f in forms) {
      if (m[f.metric] / f.scale > m[best.metric] / best.scale) best = f;
    }
    return best;
  }

  Iterable<String> get textIds => [
    nameId,
    storyId,
    for (final s in stages) ...[s.nameId, s.textId],
    for (final f in forms) ...[f.nameId, f.textId],
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
      if (kind == null) {
        throw FormatException('$id: kind は common・regional・field のどれか');
      }
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
      final forms = [
        for (final raw in (c['forms'] as List? ?? const []))
          () {
            final f = Map<String, dynamic>.from(raw as Map);
            return FormSpec(
              id: _str(f, 'id', '$id の姿'),
              nameId: _str(f, 'nameId', '$id の姿'),
              textId: _str(f, 'textId', '$id の姿'),
              artId: _str(f, 'artId', '$id の姿'),
              metric: _str(f, 'metric', '$id の姿'),
              scale: _int(f, 'scale', '$id の姿'),
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
          forms: forms,
          unlock: u == null
              ? null
              : UnlockRule(
                  metric: _str(u, 'metric', '$id の入手条件'),
                  atLeast: _int(u, 'atLeast', '$id の入手条件'),
                ),
          fieldId: c['fieldId'] as String?,
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

  /// その国・その教科で、はじめに選べる相棒（入手条件のないもの）。その国らしい地域キャラを先に、共通キャラを後に並べる。
  List<CharacterSpec> startersFor(String subject, {String? region}) {
    final all = [
      for (final c in characters)
        if (c.kind != CharacterKind.field &&
            c.unlock == null &&
            c.availableIn(region: region, subject: subject))
          c,
    ];
    return [
      ...all.where((c) => c.kind == CharacterKind.regional),
      ...all.where((c) => c.kind == CharacterKind.common),
    ];
  }

  /// 分野 [fieldId] のキャラ（無ければ null）。
  CharacterSpec? fieldCharacterFor(String fieldId) {
    for (final c in characters) {
      if (c.kind == CharacterKind.field && c.fieldId == fieldId) return c;
    }
    return null;
  }

  /// 分野のキャラ全部（図鑑に並ぶもの）。
  List<CharacterSpec> get fieldCharacters => [
    for (final c in characters)
      if (c.kind == CharacterKind.field) c,
  ];

  /// キャラに書かれた教科の一覧。
  Set<String> get subjects => {for (final c in characters) ...c.subjects};

  /// この国・この教科で出せるキャラのうち、入手条件を満たしたもの。
  List<CharacterSpec> unlocked(
    LearnerMetrics m, {
    String? region,
    String? subject,
  }) => [
    for (final c in characters)
      if (c.kind != CharacterKind.field &&
          c.availableIn(region: region, subject: subject) &&
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

/// 分野のキャラの成長ポイント: その分野で正解した数（1 問 1 点）に、「できた」になった単元 1 つにつき +5。
/// どちらも増えるだけなので、下がらない。
int growthPointsForField({required int correct, required int unitsDone}) =>
    (correct < 0 ? 0 : correct) +
    (unitsDone < 0 ? 0 : unitsDone) * growthPointsForUnitDone;

/// 単元テストで「できた」になったときの成長ポイント。
const growthPointsForUnitDone = 5;

/// 図鑑の 1 項目: 分野のキャラと、いまの育ち。まだ出会っていない（ポイント 0）ものは `met` が偽（シルエットで見せる）。
/// 図鑑は**自分の育ちを見る**ためのもので、順位や他の子との比較は載せない。
class ZukanEntry {
  const ZukanEntry({
    required this.character,
    required this.points,
    required this.stage,
  });

  final CharacterSpec character;
  final int points;

  /// 段階（0 始まり）。
  final int stage;

  bool get met => points > 0;
}

/// 教科 [subject] の分野のキャラの図鑑（並びは `characters.json` の順）。
/// [fieldPoints] は 分野ID → 成長ポイント（アプリが [growthPointsForField] で数える）。
List<ZukanEntry> zukan(
  CharacterSet set,
  String subject,
  Map<String, int> fieldPoints,
) => [
  for (final c in set.fieldCharacters)
    if (c.availableIn(subject: subject))
      ZukanEntry(
        character: c,
        points: fieldPoints[c.fieldId] ?? 0,
        stage: c.stageOf(fieldPoints[c.fieldId] ?? 0),
      ),
];

/// 相棒ごとの成長ポイント。増えるだけ（負の値は 0 として扱い、休んでも下がらない）。
/// **相棒は教科ごとに 1 匹**: 教科アプリごとに連れる相棒が別で、その教科の勉強でだけ育つ。
class CompanionProgress {
  const CompanionProgress({
    this.points = const {},
    this.activeBySubject = const {},
  });

  final Map<String, int> points;

  /// 教科 → いま育てている相棒。
  final Map<String, String> activeBySubject;

  int pointsOf(String id) => points[id] ?? 0;

  String? activeIn(String subject) => activeBySubject[subject];

  /// 相棒 [id] に [add] ポイントを足す。
  CompanionProgress grow(String id, int add) => CompanionProgress(
    points: {...points, id: pointsOf(id) + (add < 0 ? 0 : add)},
    activeBySubject: activeBySubject,
  );

  /// 教科 [subject] で育てる相棒を [id] にする。
  CompanionProgress choose(String subject, String id) => CompanionProgress(
    points: points,
    activeBySubject: {...activeBySubject, subject: id},
  );

  /// 教科 [subject] の勉強で得た成長ポイント [add] を、育てている相棒に足す（いなければ変えない）。
  CompanionProgress growActive(String subject, int add) {
    final id = activeIn(subject);
    return id == null ? this : grow(id, add);
  }
}

/// キャラとバッジの検証。
/// エラー: `character_stage_invalid`（段階は 3〜6 個、最初は 0 点、点は増える順）・`character_region_invalid`（国コードは大文字 2 文字）・
/// `character_regional_no_region`（地域キャラは国を指定する）・`character_metric_unknown`・`character_threshold_invalid`（1 以上）・
/// `character_field_missing`（分野のキャラの分野がない・分野以外に fieldId）・`character_field_duplicate`（同じ分野に 2 つ）・`character_form_invalid`（姿の分岐は 2〜4 個・scale は 1 以上）・`character_no_starter`（教科ごとに、はじめの共通キャラが無い）。
List<ValidationIssue> validateCharacters(
  CharacterSet set, {
  Set<String>? fieldIds,
}) {
  final issues = <ValidationIssue>[];
  void err(String code, String id, String msg) =>
      issues.add(ValidationIssue(IssueSeverity.error, code, id, msg));
  final art = RegExp(r'^[a-z0-9_]+$');
  final seenUnits = <String>{};
  for (final c in set.characters) {
    final u = c.fieldId;
    if (c.kind != CharacterKind.field || u == null) continue;
    if (!seenUnits.add(u)) {
      err('character_field_duplicate', c.id, '分野 $u のキャラが 2 つあります');
    }
    if (fieldIds != null && !fieldIds.contains(u)) {
      err('character_field_missing', c.id, '分野 $u がありません');
    }
  }
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
    if (c.kind == CharacterKind.field &&
        (c.fieldId == null || c.fieldId!.isEmpty)) {
      err('character_field_missing', c.id, '分野のキャラは fieldId が要ります');
    }
    if (c.kind != CharacterKind.field && c.fieldId != null) {
      err('character_field_missing', c.id, 'fieldId は分野のキャラだけに書きます');
    }
    if (c.kind == CharacterKind.regional && c.regions.isEmpty) {
      err('character_regional_no_region', c.id, '地域キャラは国を指定します');
    }
    if (c.forms.isNotEmpty && (c.forms.length < 2 || c.forms.length > 4)) {
      err('character_form_invalid', c.id, '姿の分岐は 2〜4 個（${c.forms.length}）');
    }
    for (final f in c.forms) {
      if (!knownMetrics.contains(f.metric)) {
        err('character_metric_unknown', c.id, '知らない実績: ${f.metric}');
      }
      if (f.scale < 1) {
        err('character_form_invalid', c.id, '姿 ${f.id} の scale は 1 以上');
      }
      if (!art.hasMatch(f.artId)) {
        err('character_form_invalid', c.id, '絵の名前は小文字・数字・_ だけ: ${f.artId}');
      }
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
  if (set.characters.isNotEmpty) {
    // 教科ごとの相棒: キャラに書かれた教科のそれぞれに、はじめに選べる共通キャラ（入手条件なし）が要る。
    // 教科の指定がなければ、全教科で使うはじめの共通キャラが 1 匹要る。
    bool hasCommonStarter(String? sub) => set.characters.any(
      (c) =>
          c.kind == CharacterKind.common &&
          c.unlock == null &&
          (sub == null ? c.subjects.isEmpty : c.availableIn(subject: sub)),
    );
    final subjects = set.subjects;
    if (subjects.isEmpty && !hasCommonStarter(null)) {
      err('character_no_starter', 'characters', '入手条件のないはじめの共通キャラが必要です');
    }
    for (final sub in subjects) {
      if (!hasCommonStarter(sub)) {
        err(
          'character_no_starter',
          sub,
          '教科 $sub に、入手条件のないはじめの共通キャラが必要です（どの国でも最初の相棒がいるように）',
        );
      }
    }
  }
  return issues;
}
