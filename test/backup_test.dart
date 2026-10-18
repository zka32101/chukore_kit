import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt at(String q, int minute, {bool ok = true, String? chosen, bool? confident, int ms = 1500}) => Attempt(
      questionId: q,
      unitId: 'u1',
      correct: ok,
      chosenId: chosen,
      answeredAt: DateTime.utc(2026, 10, 1, 9, minute, 30, 123, 456),
      elapsedMs: ms,
      mode: 'mock',
      confident: confident,
    );

void main() {
  final sample = [
    at('q1', 0, chosen: 'a', confident: true),
    at('q2', 1, ok: false, chosen: 'b', confident: false),
    at('q3', 2), // 選択肢なし・自信度なし
  ];

  test('書き出して読み戻すと全項目が同じ', () {
    final back = AttemptBackup.parse(AttemptBackup.export(sample));
    expect(back.length, 3);
    for (var i = 0; i < 3; i++) {
      expect(back[i].questionId, sample[i].questionId);
      expect(back[i].unitId, sample[i].unitId);
      expect(back[i].correct, sample[i].correct);
      expect(back[i].chosenId, sample[i].chosenId);
      expect(back[i].answeredAt.isAtSameMomentAs(sample[i].answeredAt), isTrue);
      expect(back[i].elapsedMs, sample[i].elapsedMs);
      expect(back[i].mode, sample[i].mode);
      expect(back[i].confident, sample[i].confident);
    }
  });

  test('空でも書き出せる。個人情報の欄は無い', () {
    final json = AttemptBackup.export([], now: DateTime.utc(2026, 10, 18));
    expect(AttemptBackup.parse(json), isEmpty);
    final m = jsonDecode(json) as Map;
    expect(m.keys.toSet(), {'format', 'version', 'exportedAt', 'count', 'checksum', 'attempts'});
    expect(m['exportedAt'], '2026-10-18T00:00:00.000Z');
  });

  test('取り込み: 無い回答だけ足す。同じファイルを何度入れても二重にならない', () async {
    final store = InMemoryAttemptStore();
    await store.add(sample[0]);
    final json = AttemptBackup.export(sample);
    final r1 = await AttemptBackup.importInto(store, json);
    expect((r1.added, r1.duplicates), (2, 1));
    final r2 = await AttemptBackup.importInto(store, json);
    expect((r2.added, r2.duplicates), (0, 3));
    expect((await store.query()).length, 3);
  });

  test('同じ時刻でも答えが違えば別の回答', () async {
    final store = InMemoryAttemptStore();
    await store.add(at('q1', 0, chosen: 'a'));
    final r = await AttemptBackup.importInto(store, AttemptBackup.export([at('q1', 0, chosen: 'b', ok: false)]));
    expect(r.added, 1);
  });

  test('SQLite の端末から別の SQLite の端末へ引き継げる（自信度・選択肢なしも保つ）', () async {
    final from = SqliteAttemptStore(sqlite3.openInMemory());
    for (final a in sample) {
      await from.add(a);
    }
    final json = AttemptBackup.export(await from.query());
    final to = SqliteAttemptStore(sqlite3.openInMemory());
    final r = await AttemptBackup.importInto(to, json);
    expect(r.added, 3);
    final got = await to.query();
    expect(got.map((a) => a.questionId), ['q1', 'q2', 'q3']);
    expect(got.map((a) => a.confident), [true, false, null]);
    expect(got.map((a) => a.chosenId), ['a', 'b', null]);
  });

  group('壊れたファイルは何も取り込まない', () {
    final good = AttemptBackup.export(sample);
    Map<String, Object?> parsed() => jsonDecode(good) as Map<String, Object?>;
    void bad(String s, [String? reason]) => expect(() => AttemptBackup.parse(s), throwsFormatException, reason: reason);

    test('形式', () {
      bad('', '空');
      bad('not json');
      bad('[]');
      bad(jsonEncode({...parsed(), 'format': 'other'}));
    });

    test('途中で切れた・書き換わった', () {
      bad(good.substring(0, good.length - 20), '途中で切れた');
      final m = parsed();
      m['count'] = 2;
      bad(jsonEncode(m), '件数');
      final m2 = parsed();
      ((m2['attempts'] as List)[1] as Map)['ok'] = true;
      bad(jsonEncode(m2), '正誤を書き換え → チェック不一致');
    });

    test('新しい版は更新を促す', () {
      final m = parsed()..['version'] = AttemptBackup.version + 1;
      expect(() => AttemptBackup.parse(jsonEncode(m)),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('更新'))));
    });

    test('1件でも不正なら全体を受け付けない', () async {
      // チェックサムを合わせた上で、中身だけ不正にしたファイル
      Map<String, Object?> row(Map<String, Object?> o) => {
            'q': 'q1', 'u': 'u1', 'ok': true, 't': '2026-10-01T00:00:00.000Z', 'ms': 1, 'm': 'practice', ...o,
          };
      Future<void> check(Map<String, Object?> o) async {
        final rows = [row({}), row(o)];
        final m = {
          'format': AttemptBackup.formatName,
          'version': 1,
          'exportedAt': '2026-10-18T00:00:00.000Z',
          'count': 2,
          'checksum': _fnv(jsonEncode(rows)),
          'attempts': rows,
        };
        final store = InMemoryAttemptStore();
        await expectLater(AttemptBackup.importInto(store, jsonEncode(m)), throwsFormatException, reason: '$o');
        expect(await store.query(), isEmpty, reason: '一部だけ入らない: $o');
      }

      await check({'q': ''});
      await check({'u': 5});
      await check({'ok': 'yes'});
      await check({'t': 'yesterday'});
      await check({'ms': -1});
      await check({'ms': 1.5});
      await check({'m': ''});
      await check({'cf': 'high'});
      await check({'c': 7});
    });
  });
}

String _fnv(String s) {
  var h = 0x811c9dc5;
  for (final u in utf8.encode(s)) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
