import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('空の表は現行の方針', () {
    final t = AgePolicyTable.parse('{}');
    expect(t.forRegion('JP').childUnder, 13);
    expect(t.forRegion('JP').childAccess, AgePolicy.defaultChildAccess);
  });

  test('地域の上書き。大文字小文字・言語つきの形でも引ける。無い地域は default', () {
    final t = AgePolicyTable.parse('''
{
  "default": {"childUnder": 12},
  "regions": {
    "kr": {"childUnder": 14, "access": {"weeklyReport": "needsGuardianGate", "deviation": "allowed"}}
  }
}''');
    expect(t.forRegion('KR').childUnder, 14);
    expect(t.forRegion('ko-KR').childUnder, 14);
    expect(t.forRegion('US').childUnder, 12);
    expect(t.forRegion('ko-KR').accessForChild(ChildFeature.deviation, isChild: true), Access.allowed);
  });

  test('access を書いたとき、書かれていない機能は出さない', () {
    final t = AgePolicyTable.parse('{"regions":{"DE":{"access":{"weeklyReport":"allowed"}}}}');
    final p = t.forRegion('DE');
    expect(p.accessForChild(ChildFeature.weeklyReport, isChild: true), Access.allowed);
    expect(p.accessForChild(ChildFeature.growthCardShare, isChild: true), Access.hidden);
  });

  test('access を省略したら現行の扱い、childUnder だけ変えられる', () {
    final p = AgePolicyTable.parse('{"regions":{"GB":{"childUnder":16}}}').forRegion('GB');
    expect(p.childUnder, 16);
    expect(p.childAccess, AgePolicy.defaultChildAccess);
  });

  test('書き間違いは黙って通さない', () {
    void bad(String json) => expect(() => AgePolicyTable.parse(json), throwsFormatException, reason: json);
    bad('not json');
    bad('[]');
    bad('{"defualt":{}}');
    bad('{"regions":{"USA":{}}}');
    bad('{"regions":{"US":{},"us":{}}}');
    bad('{"regions":{"US":{"childUnder":0}}}');
    bad('{"regions":{"US":{"childUnder":"13"}}}');
    bad('{"regions":{"US":{"childUnder":13.5}}}');
    bad('{"regions":{"US":{"childUnder":99}}}');
    bad('{"regions":{"US":{"childunder":13}}}');
    bad('{"regions":{"US":{"access":{"deviaton":"hidden"}}}}');
    bad('{"regions":{"US":{"access":{"deviation":"alowed"}}}}');
    bad('{"regions":{"US":{"access":[]}}}');
    bad('{"regions":[]}');
  });
}
