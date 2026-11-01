import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('時差: 経度 15 度で 1 時間（最も近い整数）', () {
    expect(timeOffsetHours(135), 9);
    expect(timeOffsetHours(0), 0);
    expect(timeOffsetHours(-75), -5);
    expect(timeOffsetHours(180), 12);
    expect(timeOffsetHours(-180), -12);
    expect(timeOffsetHours(7), 0);
    expect(timeOffsetHours(8), 1); // 7.5 度以上で次の時間帯
    expect(timeOffsetHours(-8), -1);
    expect(timeOffsetHours(142.5), 10);
  });

  test('経度の範囲外・数でない値は ArgumentError', () {
    for (final v in [181.0, -181.0, double.nan, double.infinity]) {
      expect(() => timeOffsetHours(v), throwsArgumentError);
    }
  });

  test('日本が正午のとき、経度 0 度は午前 3 時（同じ日）', () {
    final t = localTimeAt(hour: 12, fromLon: 135, toLon: 0);
    expect([t.hour, t.dayOffset], [3, 0]);
  });

  test('日付が前日・翌日にずれる', () {
    var t = localTimeAt(hour: 2, fromLon: 135, toLon: 0); // 日本が 2 時 → 0 度は前日の 17 時
    expect([t.hour, t.dayOffset], [17, -1]);
    t = localTimeAt(hour: 20, fromLon: 0, toLon: 135); // 0 度が 20 時 → 日本は翌日の 5 時
    expect([t.hour, t.dayOffset], [5, 1]);
    t = localTimeAt(hour: 12, fromLon: 135, toLon: -75); // 日本が正午 → 西経 75 度は前日の 22 時
    expect([t.hour, t.dayOffset], [22, -1]);
  });

  test('同じ経度なら同じ時刻。ちょうど 0 時・23 時の境目', () {
    var t = localTimeAt(hour: 7, fromLon: 40, toLon: 40);
    expect([t.hour, t.dayOffset], [7, 0]);
    t = localTimeAt(hour: 15, fromLon: 135, toLon: 0); // 6 時（0 度）
    expect([t.hour, t.dayOffset], [6, 0]);
    t = localTimeAt(hour: 9, fromLon: 135, toLon: 0); // ちょうど 0 時
    expect([t.hour, t.dayOffset], [0, 0]);
    t = localTimeAt(hour: 8, fromLon: 135, toLon: 0); // 前日の 23 時
    expect([t.hour, t.dayOffset], [23, -1]);
    t = localTimeAt(hour: 23, fromLon: 0, toLon: 15); // 翌日の 0 時
    expect([t.hour, t.dayOffset], [0, 1]);
  });

  test('hour は 0〜23', () {
    expect(() => localTimeAt(hour: 24, fromLon: 0, toLon: 0), throwsArgumentError);
    expect(() => localTimeAt(hour: -1, fromLon: 0, toLon: 0), throwsArgumentError);
    localTimeAt(hour: 0, fromLon: 0, toLon: 0);
    localTimeAt(hour: 23, fromLon: 0, toLon: 0);
  });

  test('社会の草案の時差の問題と一致する（東経 135 度と 0 度は 9 時間差、正午は午前 3 時）', () {
    expect(timeOffsetHours(135) - timeOffsetHours(0), 9);
    expect(localTimeAt(hour: 12, fromLon: 135, toLon: 0).hour, 3);
  });
}
