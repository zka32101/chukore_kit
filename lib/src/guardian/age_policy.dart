import '../assess/assess.dart';
import '../assess/deviation_policy.dart';

/// 子どもの年齢で扱いを変える機能。
enum ChildFeature {
  /// アプリ内偏差値の表示。
  deviation,

  /// 成長カードの共有。
  growthCardShare,

  /// 保護者向けの週次レポート。
  weeklyReport,

  /// 範囲カード（QR）の共有。
  scopeShare,
}

/// 機能の使わせ方。
enum Access {
  /// そのまま使える。
  allowed,

  /// 保護者ゲートを通してから使える。
  needsGuardianGate,

  /// 出さない。
  hidden,
}

/// 国・地域ごとの「子ども」の線と、子どもに対する機能の扱い。
///
/// 年齢は保存しない（名前・生年月日を持たない方針）。年齢の確認画面などで一時的に [isChild] を呼び、
/// 結果の「子どもか」だけをアプリが持つ。
///
/// **初期値は現行の方針**（13歳未満＝子ども）。国ごとの実際の年齢条件（米国 COPPA・EU の GDPR と国別の
/// 年齢、英国、韓国など）は法務確認のあとに、[AgePolicy.forRegion] の `overrides` で与える。
/// このパッケージは、確認前の法的な年齢を勝手に決めない。
class AgePolicy {
  const AgePolicy({this.childUnder = 13, this.childAccess = defaultChildAccess})
      : assert(childUnder > 0);

  /// この年齢未満を子どもとして扱う。
  final int childUnder;

  /// 子どもに対する機能ごとの扱い。書かれていない機能は [Access.hidden]（出さない）。
  final Map<ChildFeature, Access> childAccess;

  /// 現行の方針（仮）。偏差値は出さない。成長カードの共有・週次レポートは保護者ゲートのあと。
  /// 範囲カードの共有は、法務確認が済むまで出さない。
  static const defaultChildAccess = {
    ChildFeature.deviation: Access.hidden,
    ChildFeature.growthCardShare: Access.needsGuardianGate,
    ChildFeature.weeklyReport: Access.needsGuardianGate,
    ChildFeature.scopeShare: Access.hidden,
  };

  /// 地域コード（`JP`・`us`・`en-US` の `US` など）に合う方針。[overrides] に無い地域は現行の方針。
  /// 地域コードは大文字小文字を区別しない。`en-US`・`pt_BR` のような言語つきの形は、地域の部分を使う。
  factory AgePolicy.forRegion(String regionOrLocale, {Map<String, AgePolicy> overrides = const {}}) {
    final region = regionCode(regionOrLocale);
    final table = {for (final e in overrides.entries) e.key.toUpperCase(): e.value};
    return table[region] ?? const AgePolicy();
  }

  /// 地域コードを取り出す。単独の 2 文字（`US`）はそのまま地域、`en-US`・`pt_BR`・`zh-Hant-TW` は
  /// 2 文字の部分（`US`・`BR`・`TW`）。字体（`Hans`）や数字（`419`）だけなら空文字。
  static String regionCode(String s) {
    final two = RegExp(r'^[A-Za-z]{2}$');
    final parts = s.split(RegExp('[-_]'));
    if (parts.length == 1) return two.hasMatch(s) ? s.toUpperCase() : '';
    for (final p in parts.skip(1)) {
      if (two.hasMatch(p)) return p.toUpperCase();
    }
    return '';
  }

  bool isChild(int age) => age < childUnder;

  /// 年齢 [age] の人に対する [feature] の扱い。子どもでなければ [Access.allowed]。
  Access accessFor(ChildFeature feature, {required int age}) =>
      isChild(age) ? (childAccess[feature] ?? Access.hidden) : Access.allowed;

  /// 子ども（[isChild] が true）の扱い。年齢そのものを持たないアプリは、こちらを使う。
  Access accessForChild(ChildFeature feature, {required bool isChild}) =>
      isChild ? (childAccess[feature] ?? Access.hidden) : Access.allowed;
}

/// この方針でのアプリ内偏差値の表示。子どもの扱いが [Access.allowed] 以外なら出さない
/// （保護者ゲートを通す方針でも、偏差値は本人が選ぶ表示なので、ゲートの案内は呼び出し側）。
DeviationDisplay deviationDisplayFor(
  AgePolicy policy, {
  required bool isChild,
  required bool optedIn,
  required DeviationEstimate? estimate,
}) =>
    deviationDisplay(
      isUnder13: policy.accessForChild(ChildFeature.deviation, isChild: isChild) != Access.allowed,
      optedIn: optedIn,
      estimate: estimate,
    );
