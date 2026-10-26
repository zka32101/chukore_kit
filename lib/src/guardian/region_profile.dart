import 'dart:convert';

import 'age_policy.dart';
import 'age_policy_table.dart';

/// 地域ごとのコンプライアンス方針（データ）。コードは地域に中立で、国ごとの違いは JSON で渡す。
///
/// 値は**法務確認の結果**を入れる場所で、このパッケージは法的な数値を決めない。
/// 初期値は最も厳しい側（広告・トラッキング・外部共有なし、制限なし＝アプリ側の判断）。
///
/// ```json
/// {
///   "default": {},
///   "regions": {
///     "BR": {
///       "age": {"childUnder": 18},
///       "guardianConsentRequired": true,
///       "dailyLimitMinutes": 120,
///       "purchaseMethods": ["pix_one_time"],
///       "retentionDays": 365,
///       "requiredNotices": ["privacy_br", "guardian_consent"]
///     }
///   }
/// }
/// ```
class RegionProfile {
  const RegionProfile({
    this.age = const AgePolicy(),
    this.guardianConsentRequired = true,
    this.dailyLimitMinutes,
    this.adsAllowed = false,
    this.trackingAllowed = false,
    this.purchaseMethods,
    this.retentionDays,
    this.requiredNotices = const [],
  });

  /// 子どもの年齢の線と機能の扱い。
  final AgePolicy age;

  /// 子どもの利用に保護者の同意が必要か（既定は必要）。
  final bool guardianConsentRequired;

  /// 1日の利用時間の上限（分）。null は制限なし。
  final int? dailyLimitMinutes;

  final bool adsAllowed;
  final bool trackingAllowed;

  /// 使える課金手段の名前（アプリ側で意味づける）。null は制約なし、空は課金なし。
  final List<String>? purchaseMethods;

  /// 学習データの保持日数。null は期間の定めなし。
  final int? retentionDays;

  /// 表示が必要な通知・同意文のキー（アプリ側の文言に対応づける）。
  final List<String> requiredNotices;

  /// 課金手段 [method] が使えるか。
  bool allowsPurchase(String method) => purchaseMethods == null || purchaseMethods!.contains(method);

  /// [usedMinutes] 分使ったあとの残り時間（分）。制限なしは null。0 未満にはしない。
  int? remainingMinutes(int usedMinutes) {
    final limit = dailyLimitMinutes;
    if (limit == null) return null;
    final r = limit - usedMinutes;
    return r < 0 ? 0 : r;
  }
}

/// 地域コード → [RegionProfile] の表。
class RegionProfileTable {
  const RegionProfileTable({this.defaultProfile = const RegionProfile(), this.regions = const {}});

  final RegionProfile defaultProfile;
  final Map<String, RegionProfile> regions;

  /// 地域コード（`BR`・`pt-BR` など）に合う方針。無ければ [defaultProfile]。
  RegionProfile forRegion(String regionOrLocale) => regions[AgePolicy.regionCode(regionOrLocale)] ?? defaultProfile;

  /// 年齢方針だけの表として見る（既存の API との橋渡し）。
  AgePolicyTable get ageTable =>
      AgePolicyTable(defaultPolicy: defaultProfile.age, regions: {for (final e in regions.entries) e.key: e.value.age});

  factory RegionProfileTable.parse(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('地域プロファイルの JSON が読めません: ${e.message}');
    }
    return RegionProfileTable.fromJson(root);
  }

  factory RegionProfileTable.fromJson(Object? root) {
    if (root is! Map) throw const FormatException('地域プロファイル: 最上位はオブジェクトにしてください');
    for (final k in root.keys) {
      if (k != 'default' && k != 'regions') throw FormatException('地域プロファイル: 未知のキー "$k"');
    }
    final def = root['default'] == null ? const RegionProfile() : _profile(root['default'], 'default');
    final regions = <String, RegionProfile>{};
    final rj = root['regions'];
    if (rj != null) {
      if (rj is! Map) throw const FormatException('地域プロファイル: regions はオブジェクトにしてください');
      for (final e in rj.entries) {
        final key = e.key.toString();
        if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(key)) {
          throw FormatException('地域プロファイル: 地域コードは英字 2 文字です ("$key")');
        }
        final code = key.toUpperCase();
        if (regions.containsKey(code)) throw FormatException('地域プロファイル: 地域 "$code" が重複しています');
        regions[code] = _profile(e.value, code);
      }
    }
    return RegionProfileTable(defaultProfile: def, regions: regions);
  }

  static const _keys = {
    'age',
    'guardianConsentRequired',
    'dailyLimitMinutes',
    'adsAllowed',
    'trackingAllowed',
    'purchaseMethods',
    'retentionDays',
    'requiredNotices',
  };

  static RegionProfile _profile(Object? json, String where) {
    if (json is! Map) throw FormatException('地域プロファイル($where): オブジェクトにしてください');
    for (final k in json.keys) {
      if (!_keys.contains(k)) throw FormatException('地域プロファイル($where): 未知のキー "$k"');
    }
    bool flag(String k, bool d) {
      final v = json[k];
      if (v == null) return d;
      if (v is! bool) throw FormatException('地域プロファイル($where): $k は true/false です');
      return v;
    }

    int? posInt(String k, int max) {
      final v = json[k];
      if (v == null) return null;
      if (v is! int || v < 1 || v > max) throw FormatException('地域プロファイル($where): $k は 1〜$max の整数です ($v)');
      return v;
    }

    List<String>? strings(String k) {
      final v = json[k];
      if (v == null) return null;
      if (v is! List || v.any((x) => x is! String || x.isEmpty)) {
        throw FormatException('地域プロファイル($where): $k は文字列の配列です');
      }
      return List<String>.unmodifiable(v.cast<String>());
    }

    var age = const AgePolicy();
    if (json['age'] != null) {
      age = AgePolicyTable.fromJson({'default': json['age']}).defaultPolicy;
    }
    return RegionProfile(
      age: age,
      guardianConsentRequired: flag('guardianConsentRequired', true),
      dailyLimitMinutes: posInt('dailyLimitMinutes', 1440),
      adsAllowed: flag('adsAllowed', false),
      trackingAllowed: flag('trackingAllowed', false),
      purchaseMethods: strings('purchaseMethods'),
      retentionDays: posInt('retentionDays', 36500),
      requiredNotices: strings('requiredNotices') ?? const [],
    );
  }
}
