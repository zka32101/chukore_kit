import '../models/models.dart';
import 'unit_tree.dart';

/// 国・地域ごとのカリキュラムパック（データ）。単元の木に、その国の学習基準の項目（例: ブラジルの BNCC のコード）を対応づける。
///
/// ```json
/// {
///   "region": "BR", "standard": "BNCC", "version": 1,
///   "codePattern": "^EF\\d{2}MA\\d{2}$",
///   "grades": {"min": 6, "max": 9},
///   "required": ["EF06MA01"],
///   "tree": {"version": 1, "units": [ ... ]},
///   "mapping": {"unit_id": ["EF06MA01"]}
/// }
/// ```
///
/// - 学年の範囲、コードの形、「カバーすべき項目（required）」はパックのデータで決め、コードは国に中立。
/// - 中身（どの単元がどの項目か）は**現地の教育者・ネイティブの確認**を経て入れる。サンプルは形の例で、内容は仮。
/// - 書き間違いは黙って無視せず [FormatException]。整合の問題は [validate] が一覧にする。
class CurriculumPack {
  CurriculumPack({
    required this.region,
    required this.standard,
    required this.version,
    required this.tree,
    required this.mapping,
    this.codePattern,
    this.minGrade,
    this.maxGrade,
    this.required = const [],
  });

  final String region;
  final String standard;
  final int version;
  final UnitTree tree;

  /// 単元ID → 対応する基準の項目コード。
  final Map<String, List<String>> mapping;
  final RegExp? codePattern;
  final int? minGrade;
  final int? maxGrade;

  /// 網羅すべき項目コード（無ければ網羅の検査をしない）。
  final List<String> required;

  static const _keys = {'region', 'standard', 'version', 'codePattern', 'grades', 'required', 'tree', 'mapping'};

  factory CurriculumPack.fromJson(Object? root) {
    if (root is! Map) throw const FormatException('カリキュラムパック: 最上位はオブジェクトにしてください');
    for (final k in root.keys) {
      if (!_keys.contains(k)) throw FormatException('カリキュラムパック: 未知のキー "$k"');
    }
    String str(String k) {
      final v = root[k];
      if (v is! String || v.isEmpty) throw FormatException('カリキュラムパック: $k は空でない文字列です');
      return v;
    }

    final region = str('region');
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(region)) {
      throw FormatException('カリキュラムパック: region は英字 2 文字です ("$region")');
    }
    final version = root['version'];
    if (version is! int || version < 1) throw const FormatException('カリキュラムパック: version は 1 以上の整数です');
    final treeJson = root['tree'];
    if (treeJson is! Map<String, dynamic>) throw const FormatException('カリキュラムパック: tree はオブジェクトです');

    RegExp? pattern;
    if (root['codePattern'] != null) {
      final p = root['codePattern'];
      if (p is! String) throw const FormatException('カリキュラムパック: codePattern は文字列です');
      try {
        pattern = RegExp(p);
      } on FormatException {
        throw FormatException('カリキュラムパック: codePattern が正規表現として読めません ("$p")');
      }
    }

    int? minG, maxG;
    final g = root['grades'];
    if (g != null) {
      if (g is! Map || g.keys.any((k) => k != 'min' && k != 'max')) {
        throw const FormatException('カリキュラムパック: grades は {min, max} です');
      }
      minG = g['min'] as int?;
      maxG = g['max'] as int?;
      if (minG != null && maxG != null && minG > maxG) {
        throw const FormatException('カリキュラムパック: grades の min が max より大きいです');
      }
    }

    List<String> codes(Object? v, String where) {
      if (v == null) return const [];
      if (v is! List || v.any((x) => x is! String || x.isEmpty)) {
        throw FormatException('カリキュラムパック: $where は文字列の配列です');
      }
      return List<String>.from(v);
    }

    final mappingJson = root['mapping'];
    if (mappingJson is! Map) throw const FormatException('カリキュラムパック: mapping はオブジェクトです');
    return CurriculumPack(
      region: region.toUpperCase(),
      standard: str('standard'),
      version: version,
      tree: UnitTree.fromJson(treeJson),
      mapping: {for (final e in mappingJson.entries) e.key.toString(): codes(e.value, 'mapping.${e.key}')},
      codePattern: pattern,
      minGrade: minG,
      maxGrade: maxG,
      required: codes(root['required'], 'required'),
    );
  }

  /// 整合の問題の一覧（空なら問題なし）。
  List<String> validate() {
    final out = <String>[];
    final leaves = tree.allLeaves();
    for (final e in mapping.entries) {
      if (tree[e.key] == null) out.add('mapping: 木に無い単元 "${e.key}"');
      final pattern = codePattern;
      if (pattern != null) {
        for (final c in e.value) {
          if (!pattern.hasMatch(c)) out.add('mapping: コードの形が違います "$c" (${e.key})');
        }
      }
    }
    for (final u in leaves) {
      if ((mapping[u.id] ?? const []).isEmpty) out.add('単元 "${u.id}" に対応する基準の項目がありません');
      if (minGrade != null && u.grade < minGrade!) out.add('単元 "${u.id}" の学年 ${u.grade} が範囲より下です');
      if (maxGrade != null && u.grade > maxGrade!) out.add('単元 "${u.id}" の学年 ${u.grade} が範囲より上です');
    }
    for (final c in uncovered) {
      out.add('基準の項目 "$c" をカバーする単元がありません');
    }
    return out;
  }

  /// [required] のうち、どの単元にも対応づいていない項目。
  List<String> get uncovered {
    final covered = {for (final l in mapping.values) ...l};
    return [
      for (final c in required)
        if (!covered.contains(c)) c,
    ];
  }

  /// 項目コード [code] に対応する単元。
  List<Unit> unitsFor(String code) => [
    for (final e in mapping.entries)
      if (e.value.contains(code) && tree[e.key] != null) tree[e.key]!,
  ];
}
