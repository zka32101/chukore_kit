import 'dart:convert';

import 'age_policy.dart';

/// 地域ごとの年齢方針の表。法務確認の結果を JSON で渡すための入口。
///
/// ```json
/// {
///   "default": {"childUnder": 13},
///   "regions": {
///     "KR": {"childUnder": 14, "access": {"weeklyReport": "needsGuardianGate"}},
///     "US": {"childUnder": 13}
///   }
/// }
/// ```
///
/// - `default` は省略でき、省略または `childUnder`・`access` の省略は [AgePolicy] の現行の方針。
/// - `access` を書いたときは、書かれていない機能は出さない（[Access.hidden]）。ゆるくする側の変更は明示させる。
/// - 機能名・扱いの名前・地域コードの書き間違いは、黙って無視せず [FormatException] にする
///   （誤字で子どもへの制限がゆるくなるのを避ける）。
class AgePolicyTable {
  const AgePolicyTable({this.defaultPolicy = const AgePolicy(), this.regions = const {}});

  /// 表に無い地域の方針。
  final AgePolicy defaultPolicy;

  /// 地域コード（大文字 2 文字）→ 方針。
  final Map<String, AgePolicy> regions;

  /// 地域コード（`JP`・`en-US` など）に合う方針。無ければ [defaultPolicy]。
  AgePolicy forRegion(String regionOrLocale) =>
      regions[AgePolicy.regionCode(regionOrLocale)] ?? defaultPolicy;

  /// JSON 文字列から読む。形が不正なら [FormatException]。
  factory AgePolicyTable.parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('年齢方針の JSON が読めません: ${e.message}');
    }
    return AgePolicyTable.fromJson(root);
  }

  factory AgePolicyTable.fromJson(Object? root) {
    if (root is! Map) throw const FormatException('年齢方針: 最上位はオブジェクトにしてください');
    for (final k in root.keys) {
      if (k != 'default' && k != 'regions') throw FormatException('年齢方針: 未知のキー "$k"');
    }
    final def = root['default'] == null ? const AgePolicy() : _policy(root['default'], 'default');
    final regionsJson = root['regions'];
    final regions = <String, AgePolicy>{};
    if (regionsJson != null) {
      if (regionsJson is! Map) throw const FormatException('年齢方針: regions はオブジェクトにしてください');
      for (final e in regionsJson.entries) {
        final key = e.key.toString();
        if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(key)) {
          throw FormatException('年齢方針: 地域コードは英字 2 文字です ("$key")');
        }
        final code = key.toUpperCase();
        if (regions.containsKey(code)) throw FormatException('年齢方針: 地域 "$code" が重複しています');
        regions[code] = _policy(e.value, code);
      }
    }
    return AgePolicyTable(defaultPolicy: def, regions: regions);
  }

  static AgePolicy _policy(Object? json, String where) {
    if (json is! Map) throw FormatException('年齢方針($where): オブジェクトにしてください');
    for (final k in json.keys) {
      if (k != 'childUnder' && k != 'access') throw FormatException('年齢方針($where): 未知のキー "$k"');
    }
    final under = json['childUnder'];
    if (under != null && (under is! int || under < 1 || under > 30)) {
      throw FormatException('年齢方針($where): childUnder は 1〜30 の整数です ($under)');
    }
    Map<ChildFeature, Access> access = AgePolicy.defaultChildAccess;
    final accessJson = json['access'];
    if (accessJson != null) {
      if (accessJson is! Map) throw FormatException('年齢方針($where): access はオブジェクトにしてください');
      access = {};
      for (final e in accessJson.entries) {
        final feature = ChildFeature.values.where((f) => f.name == e.key).firstOrNull;
        if (feature == null) throw FormatException('年齢方針($where): 未知の機能 "${e.key}"');
        final mode = Access.values.where((a) => a.name == e.value).firstOrNull;
        if (mode == null) throw FormatException('年齢方針($where): 未知の扱い "${e.value}" (${e.key})');
        access[feature] = mode;
      }
    }
    return AgePolicy(childUnder: (under as int?) ?? 13, childAccess: access);
  }
}
