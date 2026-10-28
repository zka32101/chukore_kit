import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

ExamCalendar cal(String json) => ExamCalendar.parse(json);

void main() {
  group('読み込み', () {
    test('サンプルが読め、地域コードやロケールで引ける', () {
      final c = ExamCalendar.parse(File('docs/exam_calendars/example.json').readAsStringSync());
      expect(c.forRegion('BR').map((w) => w.id), ['bim1', 'bim2', 'bim3', 'bim4']);
      expect(c.forRegion('pt-BR'), isNotEmpty);
      expect(c.forRegion('ja-JP').length, 5);
      expect(c.forRegion('FR'), isEmpty);
      expect(const ExamCalendar().forRegion('JP'), isEmpty);
    });

    test('書き間違いは FormatException', () {
      for (final bad in [
        '[]',
        'not json',
        '{"x":1}',
        '{"regions":{"BRA":{"windows":[]}}}',
        '{"regions":{"br":{"windows":[]},"BR":{"windows":[]}}}',
        '{"regions":{"BR":{"win":[]}}}',
        '{"regions":{"BR":{"windows":{}}}}',
        '{"regions":{"BR":{"windows":[{"id":"A","start":"04-10","end":"04-25"}]}}}',
        '{"regions":{"BR":{"windows":[{"id":"a","start":"4-10","end":"04-25"}]}}}',
        '{"regions":{"BR":{"windows":[{"id":"a","start":"13-10","end":"04-25"}]}}}',
        '{"regions":{"BR":{"windows":[{"id":"a","start":"04-31","end":"05-01"}]}}}',
        '{"regions":{"BR":{"windows":[{"id":"a","start":"04-10","end":"04-25","x":1}]}}}',
        '{"regions":{"BR":{"windows":[{"id":"a","start":"04-10","end":"04-25"},{"id":"a","start":"06-01","end":"06-02"}]}}}',
      ]) {
        expect(() => cal(bad), throwsFormatException, reason: bad);
      }
      expect(
        cal('{"regions":{"BR":{"windows":[{"id":"a","start":"02-29","end":"03-01"}]}}}').forRegion('BR'),
        hasLength(1),
        reason: '2/29 は許す',
      );
    });
  });

  group('activeOn', () {
    final c = cal('{"regions":{"BR":{"windows":[{"id":"a","start":"04-10","end":"04-25"}]}}}');

    test('始まりの日と終わりの日を含み、前日・翌日は含まない', () {
      expect(c.activeOn('BR', d(2026, 4, 9)), isEmpty);
      expect(c.activeOn('BR', d(2026, 4, 10)).map((w) => w.id), ['a']);
      expect(c.activeOn('BR', d(2026, 4, 25)).map((w) => w.id), ['a']);
      expect(c.activeOn('BR', d(2026, 4, 26)), isEmpty);
    });

    test('1日だけの時期（始まりと終わりが同じ日）は、その日だけ中で、年をまたがない', () {
      final one = cal('{"regions":{"BR":{"windows":[{"id":"x","start":"05-01","end":"05-01"}]}}}');
      expect(one.forRegion('BR').single.wraps, false);
      expect(one.activeOn('BR', d(2026, 5, 1)), isNotEmpty);
      expect(one.activeOn('BR', d(2026, 5, 2)), isEmpty);
      expect(one.activeOn('BR', d(2026, 11, 1)), isEmpty);
    });

    test('年をまたぐ時期（12/20〜1/10）は、12月にも1月にも中', () {
      final w = cal('{"regions":{"BR":{"windows":[{"id":"w","start":"12-20","end":"01-10"}]}}}');
      expect(w.activeOn('BR', d(2026, 12, 19)), isEmpty);
      expect(w.activeOn('BR', d(2026, 12, 20)), isNotEmpty);
      expect(w.activeOn('BR', d(2027, 1, 10)), isNotEmpty);
      expect(w.activeOn('BR', d(2027, 1, 11)), isEmpty);
      expect(w.forRegion('BR').single.wraps, true);
      expect(c.forRegion('BR').single.wraps, false);
    });

    test('2/29 始まりの時期は、平年では 2/28 に読み替える', () {
      final w = cal('{"regions":{"BR":{"windows":[{"id":"l","start":"02-29","end":"03-05"}]}}}');
      expect(w.activeOn('BR', d(2027, 2, 28)), isNotEmpty);
      expect(w.activeOn('BR', d(2028, 2, 28)), isEmpty, reason: 'うるう年は 2/29 から');
      expect(w.activeOn('BR', d(2028, 2, 29)), isNotEmpty);
    });
  });

  group('upcoming', () {
    final c = cal('''{"regions":{"BR":{"windows":[
      {"id":"b4","start":"11-20","end":"12-10"},
      {"id":"b1","start":"04-10","end":"04-25"},
      {"id":"b2","start":"06-20","end":"07-05"}]}}}''');

    test('今日以降を始まりの早い順に。日数は始まりまで', () {
      final u = c.upcoming('BR', d(2026, 4, 1), count: 3);
      expect(u.map((i) => i.window.id), ['b1', 'b2', 'b4']);
      expect(u.first.daysUntilStart, 9);
      expect(u.first.active, false);
      expect(u.first.start, DateTime.utc(2026, 4, 10));
      expect(u.first.end, DateTime.utc(2026, 4, 25));
    });

    test('今まさに中の時期が先頭で、daysUntilStart は 0 以下', () {
      final u = c.upcoming('BR', d(2026, 4, 15), count: 2);
      expect(u.first.window.id, 'b1');
      expect(u.first.active, true);
      expect(u.first.daysUntilStart, -5);
      expect(u[1].window.id, 'b2');
    });

    test('終わりの日は中。翌日からは次の時期', () {
      expect(c.upcoming('BR', d(2026, 4, 25)).single.window.id, 'b1');
      expect(c.upcoming('BR', d(2026, 4, 26)).single.window.id, 'b2');
    });

    test('年末を過ぎると翌年の最初の時期になる', () {
      final u = c.upcoming('BR', d(2026, 12, 11)).single;
      expect(u.window.id, 'b1');
      expect(u.start, DateTime.utc(2027, 4, 10));
      expect(u.daysUntilStart, 120);
    });

    test('年をまたぐ時期が1月に中のときも拾う', () {
      final w = cal('{"regions":{"BR":{"windows":[{"id":"w","start":"12-20","end":"01-10"}]}}}');
      final u = w.upcoming('BR', d(2027, 1, 5)).single;
      expect(u.active, true);
      expect(u.start, DateTime.utc(2026, 12, 20));
    });

    test('地域が無ければ空。count が1未満ならエラー。同じ日の始まりは id 順', () {
      expect(c.upcoming('FR', d(2026, 1, 1)), isEmpty);
      expect(() => c.upcoming('BR', d(2026, 1, 1), count: 0), throwsArgumentError);
      final tie = cal(
        '{"regions":{"BR":{"windows":[{"id":"zz","start":"05-01","end":"05-02"},{"id":"aa","start":"05-01","end":"05-03"}]}}}',
      );
      expect(tie.upcoming('BR', d(2026, 4, 1), count: 2).map((i) => i.window.id), ['aa', 'zz']);
    });
  });
}
