import 'dart:convert';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final base = DateTime.utc(2026, 10, 1, 9);

Attempt wrong(
  String q, {
  int minute = 0,
  int ms = 20000,
  LossReason? reason,
  String unit = 'u1',
  bool ok = false,
  int dayOffset = 0,
}) =>
    Attempt(
      questionId: q,
      unitId: unit,
      correct: ok,
      chosenId: ok ? null : 'b',
      answeredAt: base.add(Duration(days: dayOffset, minutes: minute)),
      elapsedMs: ms,
      reason: reason,
    );

/// 単元 u1 の「ふだんの正解」: 20 秒前後で 6 回（中央値 20 秒）。
List<Attempt> usualCorrect() => [for (var i = 0; i < 6; i++) wrong('c$i', ok: true, minute: -(100 + i * 20))];

CarelessReason? firstReason(MistakeVerdict v) => v.reasons.firstOrNull;

String fnv(String s) {
  var h = 0x811c9dc5;
  for (final u in utf8.encode(s)) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

void main() {
  group('保存: SQLite', () {
    test('理由は保存して読み戻せる。未申告は null のまま', () async {
      final store = SqliteAttemptStore(sqlite3.openInMemory());
      await store.add(wrong('q1', reason: LossReason.forgot));
      await store.add(wrong('q2', minute: 1));
      await store.add(wrong('q3', minute: 2, ok: true));
      final got = await store.query();
      expect(got.map((a) => a.reason), [LossReason.forgot, null, null]);
    });

    test('全ての理由を保存できる', () async {
      final store = SqliteAttemptStore(sqlite3.openInMemory());
      for (final r in LossReason.values) {
        await store.add(wrong('q_${r.name}', reason: r, minute: r.index));
      }
      expect((await store.query()).map((a) => a.reason), LossReason.values);
    });

    test('版 2 の DB（理由の列が無い）を開くと列が足され、古い行は null、新しい行は理由つきで入る', () async {
      final db = sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT, question_id TEXT NOT NULL, unit_id TEXT NOT NULL,
          correct INTEGER NOT NULL, chosen_id TEXT, answered_at TEXT NOT NULL,
          elapsed_ms INTEGER NOT NULL DEFAULT 0, mode TEXT NOT NULL DEFAULT 'practice', confident INTEGER
        );
        INSERT INTO attempts (question_id, unit_id, correct, chosen_id, answered_at, elapsed_ms, mode, confident)
        VALUES ('old', 'u1', 0, 'b', '2026-10-01T09:00:00.000Z', 1000, 'practice', 1);
        PRAGMA user_version = 2;
      ''');
      final store = SqliteAttemptStore(db);
      await store.add(wrong('new', reason: LossReason.careless, minute: 5));
      final got = await store.query();
      expect(got.map((a) => (a.questionId, a.reason, a.confident)), [('old', null, true), ('new', LossReason.careless, null)]);
      expect(db.select('PRAGMA user_version').first.values.first, 3);
    });

    test('知らない理由の値（将来の版で足されたもの）は読み飛ばして null にする', () async {
      final db = sqlite3.openInMemory();
      final store = SqliteAttemptStore(db);
      await store.add(wrong('q1', reason: LossReason.dontKnow));
      db.execute("UPDATE attempts SET reason = 'someFutureReason'");
      expect((await store.query()).single.reason, isNull);
    });
  });

  group('保存: バックアップ', () {
    test('理由は書き出して読み戻せる。未申告の行には理由の項目を付けない', () {
      final json = AttemptBackup.export([wrong('q1', reason: LossReason.timeShort), wrong('q2', minute: 1)]);
      final rows = (jsonDecode(json) as Map)['attempts'] as List;
      expect((rows[0] as Map)['rs'], 'timeShort');
      expect((rows[1] as Map).containsKey('rs'), isFalse);
      expect(AttemptBackup.parse(json).map((a) => a.reason), [LossReason.timeShort, null]);
    });

    test('理由の項目が無い古いバックアップも、そのまま読める', () {
      final rows = [
        {'q': 'q1', 'u': 'u1', 'ok': false, 'c': 'b', 't': '2026-10-01T09:00:00.000Z', 'ms': 1000, 'm': 'practice'},
      ];
      final json = jsonEncode({
        'format': AttemptBackup.formatName,
        'version': 1,
        'exportedAt': '2026-10-18T00:00:00.000Z',
        'count': 1,
        'checksum': fnv(jsonEncode(rows)),
        'attempts': rows,
      });
      expect(AttemptBackup.parse(json).single.reason, isNull);
    });

    test('知らない理由が書かれたファイルは、全体を受け付けない', () {
      final rows = [
        {'q': 'q1', 'u': 'u1', 'ok': false, 't': '2026-10-01T09:00:00.000Z', 'ms': 1000, 'm': 'practice', 'rs': 'bogus'},
      ];
      final json = jsonEncode({
        'format': AttemptBackup.formatName,
        'version': 1,
        'exportedAt': '2026-10-18T00:00:00.000Z',
        'count': 1,
        'checksum': fnv(jsonEncode(rows)),
        'attempts': rows,
      });
      expect(() => AttemptBackup.parse(json), throwsFormatException);
    });

    test('SQLite からバックアップを経由して別の SQLite に移しても、理由が残る', () async {
      final from = SqliteAttemptStore(sqlite3.openInMemory());
      await from.add(wrong('q1', reason: LossReason.forgot));
      final to = SqliteAttemptStore(sqlite3.openInMemory());
      await AttemptBackup.importInto(to, AttemptBackup.export(await from.query()));
      expect((await to.query()).single.reason, LossReason.forgot);
    });
  });

  group('ケアレス判定: 本人の申告が推定より優先', () {
    test('とても速く間違えても、「わからなかった」「忘れていた」と申告したなら理解不足の側', () {
      for (final r in [LossReason.dontKnow, LossReason.forgot]) {
        final v = classifyMistakes([...usualCorrect(), wrong('x', ms: 2000, reason: r)]).single;
        expect(v.careless, isFalse, reason: '$r');
        expect(v.reasons, isEmpty);
      }
      // 申告が無ければ、同じ回答はケアレスの疑い（推定）
      expect(classifyMistakes([...usualCorrect(), wrong('x', ms: 2000)]).single.reasons, {CarelessReason.tooFast});
    });

    test('すぐ正解し直しても、「わからなかった」と申告したなら理解不足の側', () {
      final v = classifyMistakes([
        wrong('x', reason: LossReason.dontKnow),
        wrong('x', ok: true, minute: 2),
      ]).single;
      expect(v.careless, isFalse);
      expect(classifyMistakes([wrong('x'), wrong('x', ok: true, minute: 2)]).single.reasons, {CarelessReason.quickRetry});
    });

    test('「うっかり」の申告は、ふつうの速さで間違えてもケアレス', () {
      final v = classifyMistakes([...usualCorrect(), wrong('x', ms: 20000, reason: LossReason.careless)]).single;
      expect(v.reasons, {CarelessReason.selfReported});
      expect(v.careless, isTrue);
    });

    test('「時間が足りなかった」は知識の不足ではない誤答として扱う', () {
      final v = classifyMistakes([wrong('x', reason: LossReason.timeShort)]).single;
      expect(v.reasons, {CarelessReason.timeShort});
      expect(v.careless, isTrue);
    });

    test('申告の無い誤答は、これまでどおり推定で見立てる', () {
      final v = classifyMistakes([wrong('x')]).single;
      expect(v.reasons, isEmpty);
    });
  });

  group('弱点ノート', () {
    final q = Question(
      id: 'x',
      unitId: 'u1',
      type: 'choice',
      difficulty: 0.6,
      choices: const ['a', 'b'],
      answer: 'a',
      explanationId: 'e',
      misconceptionTags: const {'b': 'sign_error'},
    );
    int count(List<Attempt> a) => buildWeakNotes(a, {'x': q}, ignoreCareless: true).where((e) => !e.overcome).length;

    test('「うっかり」「時間が足りなかった」の誤答は誤解として数えない（ignoreCareless）', () {
      expect(count([wrong('x', reason: LossReason.careless)]), 0);
      expect(count([wrong('x', reason: LossReason.timeShort)]), 0);
    });

    test('「わからなかった」「忘れていた」「未申告」の誤答は数える。速く答えていても申告が優先', () {
      expect(count([wrong('x', reason: LossReason.dontKnow)]), greaterThan(0));
      expect(count([wrong('x', reason: LossReason.forgot)]), greaterThan(0));
      expect(count([wrong('x')]), greaterThan(0));
      expect(count([...usualCorrect(), wrong('x', ms: 2000, reason: LossReason.dontKnow)]), greaterThan(0));
    });
  });

  group('集計', () {
    final attempts = [
      wrong('a', reason: LossReason.careless),
      wrong('b', minute: 1, reason: LossReason.careless),
      wrong('c', minute: 2, reason: LossReason.forgot),
      wrong('d', minute: 3), // 未申告
      wrong('e', minute: 4, ok: true), // 正解は数えない
      wrong('f', minute: 5, reason: LossReason.dontKnow, unit: 'u2'),
      wrong('g', minute: 6, reason: LossReason.timeShort, dayOffset: 10),
    ];

    test('理由ごとの数・未申告・総数・いちばん多い理由・申告のあった分での割合', () {
      final s = summarizeMistakeReasons(attempts);
      expect(s.counts[LossReason.careless], 2);
      expect(s.counts[LossReason.forgot], 1);
      expect(s.counts[LossReason.dontKnow], 1);
      expect(s.counts[LossReason.timeShort], 1);
      expect((s.reported, s.unreported, s.total), (5, 1, 6));
      expect(s.top, LossReason.careless);
      expect(s.shareOf(LossReason.careless), 2 / 5, reason: '未申告は割合の分母に入れない');
    });

    test('単元と期間で絞れる', () {
      expect(summarizeMistakeReasons(attempts, unitId: 'u2').counts[LossReason.dontKnow], 1);
      expect(summarizeMistakeReasons(attempts, unitId: 'u2').total, 1);
      final recent = summarizeMistakeReasons(attempts, since: base.add(const Duration(days: 5)));
      expect((recent.total, recent.top), (1, LossReason.timeShort));
    });

    test('申告が無ければ top は null、割合は 0。誤答が無くても落ちない', () {
      final s = summarizeMistakeReasons([wrong('a')]);
      expect((s.top, s.shareOf(LossReason.careless), s.reported, s.unreported), (null, 0.0, 0, 1));
      expect(summarizeMistakeReasons(const []).total, 0);
    });

    test('同数のときは LossReason の並び順で先の理由', () {
      final s = summarizeMistakeReasons([wrong('a', reason: LossReason.timeShort), wrong('b', reason: LossReason.forgot)]);
      expect(s.top, LossReason.forgot);
    });
  });

  group('文言', () {
    test('全言語で 4 つのラベルと問いかけが空でなく、ラベルは互いに違う', () {
      for (final l in ChukoreStrings.supported) {
        final labels = [for (final r in LossReason.values) l.reasonLabel(r)];
        expect(labels.every((x) => x.trim().isNotEmpty), isTrue, reason: l.tag);
        expect(labels.toSet().length, 4, reason: l.tag);
        expect(l.reasonPrompt.trim().isNotEmpty, isTrue, reason: l.tag);
      }
    });

    test('ラベルは理由に対応する', () {
      const ja = JaStrings();
      expect(ja.reasonLabel(LossReason.dontKnow), 'わからなかった');
      expect(ja.reasonLabel(LossReason.forgot), '忘れていた');
      expect(ja.reasonLabel(LossReason.careless), 'うっかり');
      expect(ja.reasonLabel(LossReason.timeShort), '時間が足りなかった');
    });
  });
}
