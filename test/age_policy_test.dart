import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('既定（現行の方針）', () {
    const p = AgePolicy();

    test('13歳未満が子ども。ちょうど 13 歳は子どもではない', () {
      expect(p.childUnder, 13);
      expect(p.isChild(12), isTrue);
      expect(p.isChild(13), isFalse);
      expect(p.isChild(0), isTrue);
    });

    test('子どもの扱い: 偏差値と範囲共有は出さない。成長カード共有・週次レポートは保護者ゲート', () {
      expect(p.accessFor(ChildFeature.deviation, age: 12), Access.hidden);
      expect(p.accessFor(ChildFeature.scopeShare, age: 12), Access.hidden);
      expect(p.accessFor(ChildFeature.growthCardShare, age: 12), Access.needsGuardianGate);
      expect(p.accessFor(ChildFeature.weeklyReport, age: 12), Access.needsGuardianGate);
    });

    test('子どもでなければ、すべて使える', () {
      for (final f in ChildFeature.values) {
        expect(p.accessFor(f, age: 13), Access.allowed, reason: '$f');
        expect(p.accessForChild(f, isChild: false), Access.allowed, reason: '$f');
      }
    });

    test('扱いが書かれていない機能は、子どもには出さない（安全側）', () {
      const q = AgePolicy(childAccess: {ChildFeature.weeklyReport: Access.allowed});
      expect(q.accessFor(ChildFeature.weeklyReport, age: 10), Access.allowed);
      expect(q.accessFor(ChildFeature.deviation, age: 10), Access.hidden);
    });
  });

  group('地域ごとの方針', () {
    const kr = AgePolicy(childUnder: 14);
    const eu16 = AgePolicy(childUnder: 16, childAccess: {
      ChildFeature.deviation: Access.hidden,
      ChildFeature.growthCardShare: Access.hidden,
      ChildFeature.weeklyReport: Access.needsGuardianGate,
      ChildFeature.scopeShare: Access.hidden,
    });
    final overrides = {'KR': kr, 'de': eu16};

    test('地域コードで選ぶ（大文字小文字は区別しない。上書きのキーも同じ）', () {
      expect(AgePolicy.forRegion('KR', overrides: overrides).childUnder, 14);
      expect(AgePolicy.forRegion('kr', overrides: overrides).childUnder, 14);
      expect(AgePolicy.forRegion('DE', overrides: overrides).childUnder, 16);
    });

    test('ロケールの形（言語-地域）からも選べる', () {
      expect(AgePolicy.forRegion('ko-KR', overrides: overrides).childUnder, 14);
      expect(AgePolicy.forRegion('de_DE', overrides: overrides).childUnder, 16);
      expect(AgePolicy.forRegion('zh-Hant-KR', overrides: overrides).childUnder, 14);
    });

    test('上書きの無い地域・地域の無いロケールは、現行の方針（13歳）', () {
      expect(AgePolicy.forRegion('US', overrides: overrides).childUnder, 13);
      expect(AgePolicy.forRegion('ja', overrides: overrides).childUnder, 13);
      expect(AgePolicy.forRegion('zh-Hans', overrides: overrides).childUnder, 13);
      expect(AgePolicy.forRegion('es-419', overrides: overrides).childUnder, 13);
      expect(AgePolicy.forRegion('', overrides: overrides).childUnder, 13);
      expect(AgePolicy.forRegion('JP').childUnder, 13);
    });

    test('年齢の線が違えば、同じ年齢でも扱いが変わる', () {
      expect(const AgePolicy().isChild(13), isFalse);
      expect(kr.isChild(13), isTrue);
      expect(eu16.accessFor(ChildFeature.growthCardShare, age: 15), Access.hidden);
      expect(eu16.accessFor(ChildFeature.growthCardShare, age: 16), Access.allowed);
    });

    test('地域コードの取り出し', () {
      expect(AgePolicy.regionCode('en-US'), 'US');
      expect(AgePolicy.regionCode('pt_BR'), 'BR');
      expect(AgePolicy.regionCode('zh-Hant-TW'), 'TW');
      expect(AgePolicy.regionCode('us'), 'US');
      expect(AgePolicy.regionCode('ja'), 'JA'); // 単独の 2 文字は地域として扱う（言語ではない前提で呼ぶ）
      expect(AgePolicy.regionCode('zh-Hans'), '');
      expect(AgePolicy.regionCode('es-419'), '');
      expect(AgePolicy.regionCode('english'), '');
    });
  });

  group('アプリ内偏差値の表示', () {
    const est = DeviationEstimate(55);

    test('子どもには出さない（理由は under13）。大人は本人が選んだときだけ', () {
      const p = AgePolicy();
      final child = deviationDisplayFor(p, isChild: true, optedIn: true, estimate: est);
      expect(child.visible, isFalse);
      expect(child.hiddenReason, DeviationHiddenReason.under13);
      final adultOff = deviationDisplayFor(p, isChild: false, optedIn: false, estimate: est);
      expect(adultOff.hiddenReason, DeviationHiddenReason.notOptedIn);
      final adultOn = deviationDisplayFor(p, isChild: false, optedIn: true, estimate: est);
      expect(adultOn.visible, isTrue);
      expect(deviationDisplayFor(p, isChild: false, optedIn: true, estimate: null).hiddenReason,
          DeviationHiddenReason.notAvailable);
    });

    test('地域の方針で子どもに偏差値を出す設定にすれば、出せる（本人が選んだとき）', () {
      const open = AgePolicy(childAccess: {ChildFeature.deviation: Access.allowed});
      expect(deviationDisplayFor(open, isChild: true, optedIn: true, estimate: est).visible, isTrue);
      expect(deviationDisplayFor(open, isChild: true, optedIn: false, estimate: est).visible, isFalse);
    });

    test('従来の deviationDisplay は変わらない', () {
      expect(deviationDisplay(isUnder13: true, optedIn: true, estimate: est).visible, isFalse);
      expect(deviationDisplay(isUnder13: false, optedIn: true, estimate: est).visible, isTrue);
    });
  });
}
