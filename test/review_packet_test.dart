import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

// 簡易な CSV 読み（二重引用符で囲み、"" をエスケープ、改行を含まない前提）
List<List<String>> parse(String csv) => [
      for (final line in csv.trim().split('\n'))
        RegExp(r'"((?:[^"]|"")*)"').allMatches(line).map((m) => m.group(1)!.replaceAll('""', '"')).toList(),
    ];

void main() {
  group('確認シート', () {
    test('見出しと、全キー分の行がある。列は 9 つ', () {
      final rows = parse(reviewPacketCsv(const EnStrings()));
      expect(rows.first, ['key', 'まとまり', '日本語', 'English', 'en', '長さ', '残すもの', '直した文言', '理由']);
      expect(rows.length - 1, stringsCatalog(const EnStrings()).length);
      expect(rows.every((r) => r.length == 9), isTrue);
    });

    test('基準の日本語・英語と、この言語の文言が並ぶ。言語が違えば本文の列だけが変わる', () {
      final pl = {for (final r in parse(reviewPacketCsv(const PlStrings())).skip(1)) r[0]: r};
      final de = {for (final r in parse(reviewPacketCsv(const DeStrings())).skip(1)) r[0]: r};
      final k = 'headlinePersonalBest';
      expect(pl[k]![2], const JaStrings().headlinePersonalBest);
      expect(pl[k]![3], const EnStrings().headlinePersonalBest);
      expect(pl[k]![4], const PlStrings().headlinePersonalBest);
      expect(de[k]![4], const DeStrings().headlinePersonalBest);
      expect(pl[k]![2], de[k]![2], reason: '基準は同じ');
      expect(pl[k]![0], de[k]![0]);
    });

    test('直した文言と理由の欄は空。残すものにはプレースホルダが出る', () {
      final rows = parse(reviewPacketCsv(const FrStrings())).skip(1).toList();
      expect(rows.every((r) => r[7].isEmpty && r[8].isEmpty), isTrue);
      final card = rows.firstWhere((r) => r[0] == 'cardTitle');
      expect(card[6], '{subject}');
      expect(rows.firstWhere((r) => r[0] == 'headlineFirst')[6], '');
    });

    test('長さ = この言語の文字数 ÷ 日本語の文字数（小数 1 桁）', () {
      final rows = {for (final r in parse(reviewPacketCsv(const EnStrings())).skip(1)) r[0]: r};
      final ja = const JaStrings().headlineFirst.runes.length;
      final en = const EnStrings().headlineFirst.runes.length;
      expect(rows['headlineFirst']![5], (en / ja).toStringAsFixed(1));
    });

    test('引用符を含む文言も、列がずれずに書き出せる', () {
      // 全言語を通して、列数が崩れない
      for (final l in ChukoreStrings.supported) {
        final rows = parse(reviewPacketCsv(l));
        expect(rows.every((r) => r.length == 9), isTrue, reason: l.tag);
      }
    });

    test('まとまり（接頭辞）の取り出し', () {
      expect(stringsKeyGroup('nudgeReview'), 'nudge');
      expect(stringsKeyGroup('checklistDefault(pencil)'), 'checklist');
      expect(stringsKeyGroup('myWeekGrew'), 'myWeek');
      expect(stringsKeyGroup('scopeQrHint'), 'scopeQr');
      expect(stringsKeyGroup('testDayNotice'), 'testDay');
      expect(stringsKeyGroup('talkGrew'), 'talk');
      expect(stringsKeyGroup('X'), 'X');
    });
  });

  group('数の読み上げ', () {
    test('境目の数の読みが「数<タブ>読み」で並ぶ', () {
      final lines = numberWordsTsv(const PlStrings()).trim().split('\n');
      expect(lines.length, reviewBoundaryNumbers.length);
      expect(lines.first, '1\t${const PlStrings().gateNumberWords(1)}');
      expect(lines.last, '9999\t${const PlStrings().gateNumberWords(9999)}');
    });

    test('数を指定すればその数だけ', () {
      expect(numberWordsTsv(const EnStrings(), [21, 100]).trim().split('\n'),
          ['21\t${const EnStrings().gateNumberWords(21)}', '100\t${const EnStrings().gateNumberWords(100)}']);
    });

    test('境目の数は昇順で、重複しない', () {
      final sorted = [...reviewBoundaryNumbers]..sort();
      expect(reviewBoundaryNumbers, sorted);
      expect(reviewBoundaryNumbers.toSet().length, reviewBoundaryNumbers.length);
    });
  });
}
