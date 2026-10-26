import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('既定は最も厳しい側', () {
    const p = RegionProfile();
    expect(p.adsAllowed, false);
    expect(p.trackingAllowed, false);
    expect(p.guardianConsentRequired, true);
    expect(p.dailyLimitMinutes, isNull);
    expect(p.allowsPurchase('x'), true);
    expect(p.remainingMinutes(500), isNull);
  });

  test('サンプルJSONが読め、地域コードやロケールで引ける', () {
    final t = RegionProfileTable.parse(File('docs/region_profiles/example.json').readAsStringSync());
    final br = t.forRegion('pt-BR');
    expect(br.age.childUnder, 18);
    expect(br.dailyLimitMinutes, 120);
    expect(br.allowsPurchase('pix_one_time'), true);
    expect(br.allowsPurchase('subscription'), false);
    expect(br.retentionDays, 365);
    expect(br.requiredNotices, ['privacy_br', 'guardian_consent']);
    expect(t.forRegion('ja-JP').age.childUnder, 13);
    expect(t.forRegion('FR').adsAllowed, false);
    expect(t.ageTable.forRegion('BR').childUnder, 18);
  });

  test('残り時間は 0 未満にならない', () {
    const p = RegionProfile(dailyLimitMinutes: 60);
    expect(p.remainingMinutes(45), 15);
    expect(p.remainingMinutes(60), 0);
    expect(p.remainingMinutes(90), 0);
  });

  test('課金なし（空配列）は何も許可しない', () {
    const p = RegionProfile(purchaseMethods: []);
    expect(p.allowsPurchase('pix_one_time'), false);
  });

  test('書き間違いは黙って無視せずエラー', () {
    for (final s in [
      '[]',
      '{"x":1}',
      '{"regions":{"BRA":{}}}',
      '{"regions":{"br":{},"BR":{}}}',
      '{"regions":{"BR":{"adsAllow":true}}}',
      '{"regions":{"BR":{"adsAllowed":"yes"}}}',
      '{"regions":{"BR":{"dailyLimitMinutes":0}}}',
      '{"regions":{"BR":{"dailyLimitMinutes":1441}}}',
      '{"regions":{"BR":{"retentionDays":1.5}}}',
      '{"regions":{"BR":{"purchaseMethods":[1]}}}',
      '{"regions":{"BR":{"requiredNotices":[""]}}}',
      '{"regions":{"BR":{"age":{"childUnder":0}}}}',
      '{"regions":{"BR":{"age":{"childOver":5}}}}',
      'not json',
    ]) {
      expect(() => RegionProfileTable.parse(s), throwsFormatException, reason: s);
    }
  });
}
