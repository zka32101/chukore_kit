import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '''
{"version":1,"eras":[
 {"era":"jomon","from":-14000,"to":-301},
 {"era":"yayoi","from":-300,"to":250},
 {"era":"kofun","from":251,"to":592},
 {"era":"asuka","from":593,"to":710},
 {"era":"heian","from":794,"to":1185}
]}''';

Matcher _bad([String part = '']) => throwsA(isA<FormatException>().having((e) => e.message, 'm', contains(part)));

String _one(String body) => '{"version":1,"eras":[$body]}';

void main() {
  final t = EraTable.parse(_json);

  group('時代を引く', () {
    test('年 → 時代（両端を含む。すき間は null）', () {
      expect(t.eraOf(-300), 'yayoi');
      expect(t.eraOf(-301), 'jomon');
      expect(t.eraOf(250), 'yayoi');
      expect(t.eraOf(251), 'kofun');
      expect(t.eraOf(710), 'asuka');
      expect(t.eraOf(711), isNull); // 奈良の分が表にない
      expect(t.eraOf(794), 'heian');
      expect(t.eraOf(1185), 'heian');
      expect(t.eraOf(1186), isNull);
      expect(t.eraOf(-20000), isNull);
      expect(t.indexOf(593), 3);
      expect(t.indexOf(2000), isNull);
    });

    test('時代の前後', () {
      expect(t.compareEras(-300, 100), 0);
      expect(t.compareEras(100, 300), -1);
      expect(t.compareEras(300, 100), 1);
      expect(t.compareEras(300, 711), isNull);
      expect(t.compareEras(711, 300), isNull);
    });

    test('表にない年の出来事', () {
      final ev = [
        const TimelineEvent(id: 'a', label: 'A', year: 100),
        const TimelineEvent(id: 'b', label: 'B', year: 720),
        const TimelineEvent(id: 'c', label: 'C', year: 1600),
        const TimelineEvent(id: 'd', label: 'D', year: 1185),
      ];
      expect(t.eventsOutsideEras(ev), ['b', 'c']);
      expect(t.eventsOutsideEras(const []), isEmpty);
    });
  });

  group('世紀', () {
    test('西暦と紀元前', () {
      expect(centuryOf(1), 1);
      expect(centuryOf(100), 1);
      expect(centuryOf(101), 2);
      expect(centuryOf(1868), 19);
      expect(centuryOf(1900), 19);
      expect(centuryOf(2000), 20);
      expect(centuryOf(-1), -1);
      expect(centuryOf(-100), -1);
      expect(centuryOf(-101), -2);
      expect(centuryOf(-300), -3);
      expect(centuryOf(0), isNull);
    });
  });

  group('形の誤り', () {
    test('各種', () {
      expect(() => EraTable.parse('{'), _bad('読めません'));
      expect(() => EraTable.parse('[]'), _bad('オブジェクト'));
      expect(() => EraTable.parse('{"version":2,"eras":[]}'), _bad('版'));
      expect(() => EraTable.parse('{"version":1,"eras":[],"x":1}'), _bad('だけ'));
      expect(() => EraTable.parse('{"version":1,"eras":[]}'), _bad('eras'));
      expect(() => EraTable.parse('{"version":1}'), _bad('eras'));
      expect(() => EraTable.parse(_one('{"era":"a","from":1,"to":2,"x":1}')), _bad('era・from・to'));
      expect(() => EraTable.parse(_one('1')), _bad('era・from・to'));
      expect(() => EraTable.parse(_one('{"era":"","from":1,"to":2}')), _bad('era'));
      expect(() => EraTable.parse(_one('{"era":"a","from":1.5,"to":2}')), _bad('整数'));
      expect(() => EraTable.parse(_one('{"era":"a","from":"1","to":2}')), _bad('整数'));
      expect(() => EraTable.parse(_one('{"era":"a","from":0,"to":2}')), _bad('0 年'));
      expect(() => EraTable.parse(_one('{"era":"a","from":-2,"to":0}')), _bad('0 年'));
      expect(() => EraTable.parse(_one('{"era":"a","from":5,"to":4}')), _bad('後'));
      expect(() => EraTable.parse(_one('{"era":"a","from":1,"to":5},{"era":"a","from":6,"to":9}')), _bad('重複'));
      expect(() => EraTable.parse(_one('{"era":"a","from":1,"to":5},{"era":"b","from":5,"to":9}')), _bad('重なる'));
      expect(() => EraTable.parse(_one('{"era":"a","from":10,"to":20},{"era":"b","from":1,"to":5}')), _bad('古い順'));
    });

    test('境界: 1 年だけの時代・すき間なしの接続・紀元前から西暦へ', () {
      final x = EraTable.parse(_one('{"era":"a","from":-5,"to":-1},{"era":"b","from":1,"to":1},{"era":"c","from":2,"to":9}'));
      expect([x.eraOf(-1), x.eraOf(1), x.eraOf(2)], ['a', 'b', 'c']);
      expect(x.eraOf(0), isNull);
    });
  });
}
