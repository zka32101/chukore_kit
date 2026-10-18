import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Attempt at(String qid, int d) =>
    Attempt(questionId: qid, unitId: 'u1', correct: true, answeredAt: DateTime.utc(2026, 10, d, 9));

class _NoDelete extends AttemptStore {
  @override
  Future<void> add(Attempt attempt) async {}
  @override
  Future<List<Attempt>> query({DateTime? from, DateTime? to, String? unitId}) async => [];
}

void main() {
  group('回答履歴の全削除', () {
    test('InMemory: 全部消え、そのあとも追加できる', () async {
      final s = InMemoryAttemptStore();
      await s.add(at('a', 1));
      await s.add(at('b', 2));
      await s.deleteAll();
      expect(await s.query(), isEmpty);
      await s.add(at('c', 3));
      expect((await s.query()).single.questionId, 'c');
    });

    test('SQLite: 全部消え、そのあとも追加できる（版はそのまま）', () async {
      final db = sqlite3.openInMemory();
      final s = SqliteAttemptStore(db);
      await s.add(at('a', 1));
      await s.deleteAll();
      expect(await s.query(), isEmpty);
      await s.add(at('b', 2));
      expect((await s.query()).single.questionId, 'b');
      expect(db.select('PRAGMA user_version').first.values.first, SqliteAttemptStore.schemaVersion);
    });

    test('SQLite: 消した回答の内容がファイルに残らない（VACUUM）', () async {
      final dir = Directory.systemTemp.createTempSync('chukore_del_');
      final path = '${dir.path}/a.db';
      try {
        final db = sqlite3.open(path);
        db.execute('PRAGMA secure_delete = OFF'); // 端末の SQLite が上書きしない設定でも残らないことを確かめる
        final s = SqliteAttemptStore(db);
        const marker = 'SECRET_MARKER_QUESTION_ID';
        for (var i = 0; i < 20; i++) {
          await s.add(at('$marker$i', 1 + i % 20));
        }
        expect(File(path).readAsBytesSync().length, greaterThan(0));
        expect(String.fromCharCodes(File(path).readAsBytesSync()).contains(marker), isTrue, reason: '前提: 消す前はファイルにある');
        await s.deleteAll();
        db.dispose();
        expect(String.fromCharCodes(File(path).readAsBytesSync()).contains(marker), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('実装していないストアは UnsupportedError（既定の動き）', () async {
      expect(() => _NoDelete().deleteAll(), throwsUnsupportedError);
    });
  });

  group('言語名（設定画面の言語リスト用）', () {
    test('対応する全言語に名前があり、重複しない。タグそのままではない', () {
      final names = <String>{};
      for (final s in ChukoreStrings.supported) {
        expect(s.languageName.trim(), isNotEmpty, reason: s.tag);
        expect(s.languageName, isNot(s.tag), reason: '${s.tag} の名前が未登録');
        expect(names.add(s.languageName), isTrue, reason: '${s.tag} の名前が重複');
      }
    });

    test('その言語の文字で書かれている。地域つきは地域が分かる', () {
      String name(String tag) => ChukoreStrings.supported.firstWhere((s) => s.tag == tag).languageName;
      expect(name('ja'), '日本語');
      expect(name('zh-Hans'), '简体中文');
      expect(name('zh-Hant'), '繁體中文');
      expect(name('ar'), 'العربية');
      expect(name('de-CH'), contains('Schweiz'));
      expect(name('pt-PT'), contains('Portugal'));
    });
  });
}
