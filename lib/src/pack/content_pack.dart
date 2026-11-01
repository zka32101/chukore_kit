import 'dart:convert';

import '../bank/question_bank.dart';
import '../chart/chart.dart';
import '../experience/experience.dart';
import '../lesson/lesson.dart';
import '../lesson/math_lesson_checker.dart';
import '../map/map_pack.dart';
import '../math/construction.dart';
import '../math/exploration.dart';
import '../math/math_expr.dart';
import '../math/math_template.dart';
import '../models/models.dart';
import '../prereq/prerequisites.dart';
import '../proof/proof.dart';
import '../scene/scene.dart';
import '../scope/unit_tree.dart';
import '../text/content_texts.dart';

/// コンテンツパック（国 × 教科 × 学年の範囲の中身 1 式）の目録 `manifest.json`。仕様は docs/content_pack_spec.md。
/// 内容（問題・レッスンなど）は国ごとのリポジトリ（`chukore_<国>_<教科>`）が持ち、この基盤は形式と検証だけを持つ。
class ContentPackManifest {
  const ContentPackManifest({
    required this.id,
    required this.country,
    required this.locale,
    required this.subject,
    required this.grades,
    required this.curriculum,
    required this.contentVersion,
    required this.attribution,
    required this.files,
    this.textsCover = textKinds,
  });

  final String id;

  /// ISO 3166-1 の 2 文字（大文字）。
  final String country;

  /// 言語（BCP 47 の簡易形: `ja`・`pt-BR`）。
  final String locale;

  /// 教科（`math`・`en`・`social` など）。単元の `subject` と一致させる。
  final String subject;
  final List<int> grades;

  /// 準拠する教育課程の名前（例: 文部科学省 学習指導要領（中学校））。
  final String curriculum;

  /// 中身の版（`1.2.0`）。
  final String contentVersion;

  /// 出典の表示（地図・統計・画像などの原典。空でもよい）。
  final List<String> attribution;

  /// ファイルの場所（目録からの相対パス）。`units` は必須。
  final Map<String, Object> files;

  /// `texts` がそろっていなければならない範囲（既定はすべて）。書いた分だけ増やしていくパック（例: まずレッスンの説明だけ）は
  /// `textsCover` で範囲を絞る。範囲の外の文言は、あってもなくてもよい（あれば差し込みの名前は確かめる）。
  final Set<String> textsCover;

  /// `textsCover` に書ける種類: `scenes`（場面の名前と説明）・`lessons`（レッスン）・`templates`（型の問題文と解説）・
  /// `figures`（型の図の説明）・`questions`（問題集の解説）・`proofs`（証明の題・仮定・結論・各行・根拠）。
  static const textKinds = {'scenes', 'lessons', 'templates', 'figures', 'questions', 'proofs'};

  static const fileKeys = {
    'units', 'prerequisites', 'questions', 'templates', 'lessons',
    'explorations', 'constructions', 'experiences', 'charts', 'scenes', 'proofs', 'texts', 'maps',
  };
  static const _keys = {
    'version', 'id', 'country', 'locale', 'subject', 'grades', 'curriculum', 'contentVersion', 'attribution', 'files', 'textsCover',
  };

  /// 読めなければ [FormatException]。
  factory ContentPackManifest.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('manifest の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('manifest はオブジェクトです');
    final map = j;
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('manifest の未知のキー: ${unknown.join(', ')}');
    if (j['version'] != 1) throw FormatException('manifest の未対応の版: ${j['version']}');
    String str(String k, RegExp re, String what) {
      final v = map[k];
      if (v is! String || !re.hasMatch(v)) throw FormatException('manifest: $k は$what: $v');
      return v;
    }

    final id = str('id', RegExp(r'^[a-z][a-z0-9_]*$'), '小文字・数字・_（先頭は英字）');
    final country = str('country', RegExp(r'^[A-Z]{2}$'), '大文字 2 文字の国コード（JP など）');
    final locale = str('locale', RegExp(r'^[a-z]{2,3}(-[A-Z]{2})?$'), '言語コード（ja・pt-BR など）');
    final subject = str('subject', RegExp(r'^[a-z][a-z0-9_]*$'), '小文字・数字・_（先頭は英字）');
    final version = str('contentVersion', RegExp(r'^\d+\.\d+\.\d+$'), '1.2.3 の形');
    final curriculum = j['curriculum'];
    if (curriculum is! String || curriculum.trim().isEmpty) throw const FormatException('manifest: curriculum は空でない文字列');
    final rg = j['grades'];
    if (rg is! List || rg.isEmpty || rg.any((e) => e is! int || e < 1 || e > 12) || rg.toSet().length != rg.length) {
      throw const FormatException('manifest: grades は 1〜12 の整数（重複なし）の 1 つ以上');
    }
    final ra = j['attribution'] ?? const [];
    if (ra is! List || ra.any((e) => e is! String || e.trim().isEmpty)) {
      throw const FormatException('manifest: attribution は空でない文字列の並び');
    }
    final rc = j['textsCover'];
    if (rc != null &&
        (rc is! List || rc.isEmpty || rc.any((e) => e is! String || !textKinds.contains(e)) || rc.toSet().length != rc.length)) {
      throw FormatException('manifest: textsCover は ${textKinds.join('・')} の重複しない 1 つ以上');
    }
    final rf = j['files'];
    if (rf is! Map) throw const FormatException('manifest: files が必要です');
    final badKey = rf.keys.where((k) => !fileKeys.contains(k));
    if (badKey.isNotEmpty) throw FormatException('manifest: files の未知のキー: ${badKey.join(', ')}');
    final files = <String, Object>{};
    for (final e in rf.entries) {
      final v = e.value;
      if (e.key == 'maps') {
        if (v is! List || v.isEmpty || v.any((p) => p is! String || p.isEmpty)) {
          throw const FormatException('manifest: files.maps は空でない文字列の並び');
        }
        files['maps'] = [for (final p in v) p as String];
      } else {
        if (v is! String || v.isEmpty) throw FormatException('manifest: files.${e.key} は空でない文字列');
        files[e.key as String] = v;
      }
    }
    if (!files.containsKey('units')) throw const FormatException('manifest: files.units は必須です');
    return ContentPackManifest(
      id: id,
      country: country,
      locale: locale,
      subject: subject,
      grades: [for (final g in rg) g as int],
      curriculum: curriculum,
      contentVersion: version,
      attribution: [for (final a in ra) a as String],
      files: files,
      textsCover: rc == null ? textKinds : {for (final e in rc as List) e as String},
    );
  }

  /// 読み込むファイルのパス（`maps` は 1 つずつ）。
  List<String> get paths => [
    for (final e in files.entries)
      if (e.value is List) ...(e.value as List<String>) else e.value as String,
  ];
}

/// コンテンツパックの検証結果。
class ContentPackReport {
  const ContentPackReport({required this.manifest, required this.issues, required this.counts});

  /// 目録（読めなければ null。そのとき [issues] にエラーがある）。
  final ContentPackManifest? manifest;
  final List<ValidationIssue> issues;

  /// ファイルの種類 → 件数（単元・前提・問題・型・レッスン・体験型・体験・作図・グラフ・地図・領域）。
  final Map<String, int> counts;

  bool get hasErrors => issues.any((i) => i.isError);
}

/// コンテンツパックを検証する（ファイルの読み込みは [read] に任せる。入出力に依らない純粋な関数）。
/// [manifestSource] は `manifest.json` の本文、[read] は目録からの相対パスの本文を返す（無ければ null）。
/// 個別の検証（単元・前提・問題・型・レッスン・体験・グラフ・地図）に加えて、ファイルをまたぐ検査をする。
/// ファイルをまたぐ検査: `pack_unit_subject_mismatch`（単元の教科が目録と違う）・`pack_file_missing`・
/// `pack_file_path_invalid`（絶対パス・`..`）・`pack_file_malformed`・`pack_experience_id_clash`（体験の ID が体験型と重複）・
/// `pack_scene_missing`（型が使う場面が scenes にない）、警告 `pack_unit_grade_outside`（単元の学年が目録の grades にない）・
/// `pack_prereq_uncovered`（前提の定義がない末端の単元）・`pack_scene_unused`（型もレッスンも使っていない場面）。
/// レッスンの参照（問題・型・体験・作図・誤解の型）は、同じパックの中身で確かめる。
ContentPackReport validateContentPack(String manifestSource, String? Function(String path) read) {
  final issues = <ValidationIssue>[];
  void add(IssueSeverity s, String code, String id, String msg) => issues.add(ValidationIssue(s, code, id, msg));
  void addAll(String file, Iterable<ValidationIssue> xs) {
    for (final i in xs) {
      issues.add(ValidationIssue(i.severity, i.code, i.subjectId, '[$file] ${i.message}'));
    }
  }

  final ContentPackManifest m;
  try {
    m = ContentPackManifest.parse(manifestSource);
  } on FormatException catch (e) {
    add(IssueSeverity.error, 'pack_manifest_invalid', 'manifest', e.message);
    return ContentPackReport(manifest: null, issues: issues, counts: const {});
  }

  final counts = <String, int>{};
  final texts = <String, String>{};
  for (final p in m.paths) {
    if (p.startsWith('/') || p.contains('\\') || p.split('/').contains('..')) {
      add(IssueSeverity.error, 'pack_file_path_invalid', p, '相対パス（`..` なし）にしてください');
      continue;
    }
    final t = read(p);
    if (t == null) {
      add(IssueSeverity.error, 'pack_file_missing', p, 'ファイルがありません');
    } else {
      texts[p] = t;
    }
  }

  Map<String, dynamic>? json(String file) {
    final t = texts[file];
    if (t == null) return null;
    try {
      final j = jsonDecode(t);
      if (j is Map<String, dynamic>) return j;
      add(IssueSeverity.error, 'pack_file_malformed', file, 'JSON のトップはオブジェクトです');
    } on FormatException catch (e) {
      add(IssueSeverity.error, 'pack_file_malformed', file, 'JSON を読めません: ${e.message}');
    }
    return null;
  }

  T? tryParse<T>(String file, T Function(String text) parse) {
    final t = texts[file];
    if (t == null) return null;
    try {
      return parse(t);
    } on FormatException catch (e) {
      add(IssueSeverity.error, 'pack_file_malformed', file, e.message);
    } on TypeError catch (e) {
      add(IssueSeverity.error, 'pack_file_malformed', file, '形が違います: $e');
    }
    return null;
  }

  // 単元
  final unitsFile = m.files['units'] as String;
  UnitTree? tree;
  final unitsJson = json(unitsFile);
  if (unitsJson != null) {
    final units = <Unit>[];
    for (final raw in (unitsJson['units'] as List? ?? const [])) {
      try {
        units.add(Unit.fromJson(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        add(IssueSeverity.error, 'malformed', '${(raw is Map ? raw['id'] : null) ?? '?'}', '[$unitsFile] unit を読めません: $e');
      }
    }
    addAll(unitsFile, validateUnitList(units));
    tree = UnitTree((unitsJson['version'] as int?) ?? 1, units);
    counts['units'] = units.length;
    for (final u in units) {
      if (u.subject != m.subject) {
        add(IssueSeverity.error, 'pack_unit_subject_mismatch', u.id, '[$unitsFile] 単元の教科 ${u.subject} が目録の ${m.subject} と違います');
      }
      if (!m.grades.contains(u.grade)) {
        add(IssueSeverity.warning, 'pack_unit_grade_outside', u.id, '[$unitsFile] 単元の学年 ${u.grade} が目録の grades ${m.grades} にありません');
      }
    }
  }

  // 前提
  final prereqFile = m.files['prerequisites'] as String?;
  if (prereqFile != null && tree != null) {
    final pj = json(prereqFile);
    if (pj != null) {
      try {
        final raw = [
          for (final n in (pj['prerequisites'] as List? ?? const [])) PrereqNode.fromJson(Map<String, dynamic>.from(n as Map)),
        ];
        final graph = PrerequisiteGraph(raw);
        addAll(prereqFile, graph.validate(tree, rawNodes: raw));
        for (final u in graph.uncoveredLeaves(tree)) {
          add(IssueSeverity.warning, 'pack_prereq_uncovered', u.id, '[$prereqFile] 前提の定義がありません');
        }
        counts['prerequisites'] = raw.length;
      } catch (e) {
        add(IssueSeverity.error, 'pack_file_malformed', prereqFile, '前提を読めません: $e');
      }
    }
  }

  // 問題
  final questionIds = <String>{}, tags = <String>{};
  final questionExplanations = <String>{};
  final questionsFile = m.files['questions'] as String?;
  if (questionsFile != null) {
    final qj = json(questionsFile);
    if (qj != null) {
      final bank = parseQuestionBank(qj);
      addAll(questionsFile, bank.issues);
      addAll(questionsFile, validateQuestionBank(questions: bank.questions, tree: tree, mistakeLines: bank.mistakeLines));
      for (final q in bank.questions) {
        questionExplanations.add(q.explanationId);
        questionIds.add(q.id);
        tags.addAll(q.misconceptionTags.values);
      }
      counts['questions'] = bank.questions.length;
    }
  }

  // 場面（現実の具体例）
  final scenesFile = m.files['scenes'] as String?;
  final sceneIds = <String>{};
  SceneSet? sceneSet;
  if (scenesFile != null) {
    final set = tryParse(scenesFile, SceneSet.parse);
    if (set != null) {
      sceneSet = set;
      if (tree != null) addAll(scenesFile, validateScenes(set, tree: tree));
      sceneIds.addAll(set.ids);
      counts['scenes'] = set.scenes.length;
    }
  }
  final usedScenes = <String>{};
  // 証明（合同・相似など）
  final proofsFile = m.files['proofs'] as String?;
  ProofSet? proofSet;
  if (proofsFile != null) {
    final set = tryParse(proofsFile, ProofSet.parse);
    if (set != null) {
      proofSet = set;
      if (tree != null) addAll(proofsFile, validateProofs(set, tree: tree));
      counts['proofs'] = set.proofs.length;
    }
  }

  // 型（変種）
  final templatesFile = m.files['templates'] as String?;
  TemplateSet? templates;
  if (templatesFile != null) {
    templates = tryParse(templatesFile, TemplateSet.parse);
    if (templates != null) {
      if (tree != null) addAll(templatesFile, validateTemplates(templates, tree: tree));
      counts['templates'] = templates.templates.length;
      for (final t in templates.templates) {
        final sc = t.sceneId;
        if (sc != null) {
          usedScenes.add(sc);
          if (!sceneIds.contains(sc)) {
            add(IssueSeverity.error, 'pack_scene_missing', t.id, '[$templatesFile] 場面 $sc が scenes にありません');
          }
        }
        for (final w in t.wrong) {
          tags.add(w.tag);
        }
      }
    }
  }

  // 体験型・作図・体験
  final explorationIds = <String>{}, constructionIds = <String>{};
  final explorationsFile = m.files['explorations'] as String?;
  if (explorationsFile != null) {
    final set = tryParse(explorationsFile, ExplorationSet.parse);
    if (set != null) {
      if (tree != null) addAll(explorationsFile, validateExplorations(set, tree: tree));
      explorationIds.addAll(set.explorations.map((e) => e.id));
      counts['explorations'] = set.explorations.length;
    }
  }
  final constructionsFile = m.files['constructions'] as String?;
  if (constructionsFile != null) {
    final set = tryParse(constructionsFile, ConstructionSet.parse);
    if (set != null) {
      if (tree != null) addAll(constructionsFile, validateConstructions(set, tree: tree));
      constructionIds.addAll(set.constructions.map((c) => c.id));
      counts['constructions'] = set.constructions.length;
    }
  }
  final experiencesFile = m.files['experiences'] as String?;
  if (experiencesFile != null) {
    final set = tryParse(experiencesFile, ExperienceSet.parse);
    if (set != null) {
      if (tree != null) addAll(experiencesFile, validateExperiences(set, tree: tree));
      for (final e in set.experiences) {
        if (!explorationIds.add(e.id)) {
          add(IssueSeverity.error, 'pack_experience_id_clash', e.id, '[$experiencesFile] 体験の ID が体験型（explorations）と重複しています');
        }
      }
      counts['experiences'] = set.experiences.length;
    }
  }

  // レッスン（上の中身を参照として確かめる）
  final lessonsFile = m.files['lessons'] as String?;
  LessonSet? lessonSet;
  if (lessonsFile != null) {
    final set = tryParse(lessonsFile, LessonSet.parse);
    if (set != null) {
      lessonSet = set;
      if (tree != null) {
        addAll(
          lessonsFile,
          validateLessons(
            set,
            tree: tree,
            refs: LessonRefs(
              questionIds: questionIds,
              templateIds: {for (final t in templates?.templates ?? const <MathTemplate>[]) t.id},
              explorationIds: explorationIds,
              constructionIds: constructionIds,
              sceneIds: sceneIds,
              tags: tags,
            ),
            checker: templates == null ? null : MathLessonChecker(templates),
          ),
        );
      }
      counts['lessons'] = set.lessons.length;
      for (final l in set.lessons) {
        for (final b in l.blocks) {
          if (b is HookBlock && b.scene != null) usedScenes.add(b.scene!);
        }
      }
    }
  }

  // 文言（教科書のような説明・問題文・解説）。texts を持つパックでは、使う文言がそろっているか確かめる
  final textsFile = m.files['texts'] as String?;
  if (textsFile != null) {
    final texts = tryParse(textsFile, ContentTexts.parse);
    if (texts != null) {
      counts['texts'] = texts.texts.length;
      if (texts.locale != m.locale) {
        add(IssueSeverity.error, 'pack_texts_locale_mismatch', textsFile, '[$textsFile] locale ${texts.locale} が目録の ${m.locale} と違います');
      }
      addAll(textsFile, validateContentTexts(texts));
      _checkTexts(
        texts: texts,
        file: textsFile,
        templates: templates?.templates ?? const <MathTemplate>[],
        lessons: lessonSet?.lessons ?? const <Lesson>[],
        sceneSet: sceneSet,
        proofs: proofSet?.proofs ?? const <ProofSpec>[],
        questionExplanations: questionExplanations,
        cover: m.textsCover,
        add: add,
      );
    }
  }

  // 場面は、型かレッスンから使われているか
  for (final id in sceneIds.difference(usedScenes)) {
    add(IssueSeverity.warning, 'pack_scene_unused', id, '[$scenesFile] どの型・レッスンからも使われていない場面です');
  }

  // グラフ
  final chartsFile = m.files['charts'] as String?;
  if (chartsFile != null) {
    final cj = json(chartsFile);
    if (cj != null) {
      final charts = cj['charts'];
      if (cj['version'] != 1 || charts is! Map) {
        add(IssueSeverity.error, 'pack_file_malformed', chartsFile, '{"version":1,"charts":{ID: グラフ}} の形にしてください');
      } else {
        var n = 0;
        for (final e in charts.entries) {
          try {
            ChartSpec.fromJson(Map<String, dynamic>.from(e.value as Map));
            n++;
          } on FormatException catch (x) {
            add(IssueSeverity.error, 'pack_file_malformed', '${e.key}', '[$chartsFile] ${x.message}');
          } on TypeError {
            add(IssueSeverity.error, 'pack_file_malformed', '${e.key}', '[$chartsFile] グラフがオブジェクトではありません');
          }
        }
        counts['charts'] = n;
      }
    }
  }

  // 地図
  final maps = (m.files['maps'] as List<String>?) ?? const [];
  var regions = 0;
  for (final p in maps) {
    final pack = tryParse(p, MapPack.parse);
    if (pack != null) {
      addAll(p, validateMapPack(pack));
      regions += pack.regions.length;
    }
  }
  if (maps.isNotEmpty) {
    counts['maps'] = maps.length;
    counts['mapRegions'] = regions;
  }

  return ContentPackReport(manifest: m, issues: issues, counts: counts);
}


/// 文言の検査。使う文言（場面の名前と説明・レッスンの題名と各ブロック・型の問題文 `prompt_<型ID>`・型と問題の解説・図の説明）が
/// すべてあるか（`pack_text_missing`）、本文の `{…}` が型の値の名前だけを使っているか（`pack_text_placeholder_unknown`）、
/// どこからも使われない文言がないか（警告 `pack_text_unused`）。
void _checkTexts({
  required ContentTexts texts,
  required String file,
  required List<MathTemplate> templates,
  required List<Lesson> lessons,
  required SceneSet? sceneSet,
  required List<ProofSpec> proofs,
  required Set<String> questionExplanations,
  required Set<String> cover,
  required void Function(IssueSeverity, String, String, String) add,
}) {
  // 文言 ID → 差し込める名前（null は差し込みなし）
  final required = <String, ({Set<String> keys, Set<String> vars, Set<String> lists})?>{};
  final covered = <String>{}; // そろっていなければならない文言（textsCover の範囲）
  void need(String id, String kind, [({Set<String> keys, Set<String> vars, Set<String> lists})? names]) {
    if (!required.containsKey(id)) required[id] = names;
    if (cover.contains(kind)) covered.add(id);
  }

  ({Set<String> keys, Set<String> vars, Set<String> lists}) namesOf(Iterable<MathTemplate> ts) => (
    keys: {for (final t in ts) ...t.display.keys},
    vars: {for (final t in ts) ...[...t.params.keys, ...t.derived.keys, ...t.stats.keys]},
    lists: {for (final t in ts) ...t.lists.keys},
  );

  for (final s in sceneSet?.scenes ?? const <Scene>[]) {
    need(s.titleId, 'scenes');
    need(s.textId, 'scenes');
  }
  for (final p in proofs) {
    for (final id in p.textIds) {
      need(id, 'proofs');
    }
  }
  final all = namesOf(templates);
  for (final l in lessons) {
    for (final id in l.textIds) {
      need(id, 'lessons', all);
    }
  }
  for (final t in templates) {
    final own = namesOf([t]);
    need('prompt_${t.id}', 'templates', own);
    need(t.explanationId, 'templates', own);
    final f = t.figure;
    if (f != null) need(f.altId, 'figures');
    for (final c in t.figures.values) {
      final one = c.one;
      if (one != null) need(one.altId, 'figures');
      for (final o in c.of) {
        need(o.altId, 'figures');
      }
    }
  }
  for (final id in questionExplanations) {
    need(id, 'questions');
  }

  for (final e in required.entries) {
    final body = texts.texts[e.key];
    if (body == null) {
      if (covered.contains(e.key)) add(IssueSeverity.error, 'pack_text_missing', e.key, '[$file] 文言 ${e.key} がありません');
      continue;
    }
    if (!ContentTexts.balanced(body)) continue; // 別のエラー（text_unbalanced_braces）で報告済み
    final names = e.value;
    for (final ph in ContentTexts.placeholders(body)) {
      if (!_placeholderOk(ph, names)) {
        add(IssueSeverity.error, 'pack_text_placeholder_unknown', e.key, '[$file] {$ph} は差し込める名前ではありません');
      }
    }
  }
  for (final id in texts.texts.keys) {
    if (!required.containsKey(id)) {
      add(IssueSeverity.warning, 'pack_text_unused', id, '[$file] どこからも使われていない文言です');
    }
  }
}

/// 本文の `{…}` の中身 [ph] が、差し込める名前だけでできているか。型の表示の名前（`{point}`）、または式（`{c-b}`・`{+b}`・`{$r*r}`・`{~L}`）。
bool _placeholderOk(String ph, ({Set<String> keys, Set<String> vars, Set<String> lists})? names) {
  if (names == null) return false;
  if (names.keys.contains(ph)) return true;
  final body = ph.isNotEmpty && '+&\$~'.contains(ph[0]) ? ph.substring(1) : ph;
  if (names.lists.contains(body)) return true;
  final x = MathExpr.tryParse(body);
  return x != null && x.variables.every(names.vars.contains);
}
