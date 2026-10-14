import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = ChukoreStrings.supported;
  final en = stringsCatalog(const EnStrings());

  /// 英語と綴りが同じでも正しい文言（同語源の語）。言語ごとに必要最小限だけ許可する。
  const cognates = {
    // 英語と同じ「N question(s)」。question はフランス語でも同じ綴り
    // フランス語の correct / incorrect も英語と同じ綴り
    'fr': {'solvableValue(1)', 'solvableValue(2)', 'solvableValue(5)', 'markCorrect', 'markWrong', 'sheetQuestion'},
  };

  test('言語タグが重複しない', () {
    final tags = all.map((l) => l.tag).toList();
    expect(tags.toSet().length, tags.length, reason: '$tags');
  });

  for (final l in all) {
    group('文言の検査: ${l.tag}', () {
      final c = stringsCatalog(l);

      test('全キーがそろい、空の文言が無い', () {
        expect(c.keys.toList(), en.keys.toList());
        for (final e in c.entries) {
          // 件数 0 の連続日数などは空になりうるが、文言は必ず何か返す
          expect(e.value.trim(), isNotEmpty, reason: '${l.tag} ${e.key}');
        }
      });

      test('プレースホルダが訳で落ちていない', () {
        void has(String key, List<String> tokens) {
          for (final t in tokens) {
            expect(c[key], contains(t), reason: '${l.tag} $key に $t が無い');
          }
        }

        has('cardTitle', ['{subject}']);
        has('headlineUp', ['{points}']);
        has('nextLevel', ['{points}']);
        has('cardSemantics', ['{headline}', '{level}']);
        has('reportItem', ['{title}', '40', '70']);
        for (final n in [2, 5]) {
          has('streakDays($n)', ['$n']);
          has('solvableValue($n)', ['$n']);
        }
        has('reportHeader(2,5)', ['2', '5']);
        has('formatYear(-500)', ['500']);
        has('formatYear(1868)', ['1868']);
        has('deviationRange', ['{low}', '{high}']);
        has('ringsSemantics(30)', ['30']);
      });

      test('英語のまま残っていない（英語以外）', () {
        if (l.languageCode == 'en') return;
        // 構造が同じで文字列が一致しうるもの（記号だけの差・固有の表記）は除く
        const sameOk = {'reportItem', 'deviationRange', 'decimalSeparator'};
        for (final e in c.entries) {
          if (sameOk.contains(e.key)) continue;
          if (cognates[l.languageCode]?.contains(e.key) ?? false) continue;
          // 数字だけ・記号だけの文言は比較しない
          if (!RegExp('[A-Za-zぁ-んァ-ン一-龥]').hasMatch(e.value)) continue;
          if (c[e.key] == en[e.key]) {
            fail('${l.tag} の ${e.key} が英語と同じ: ${e.value}');
          }
        }
      });

      test('数の読み上げが 100〜999 のすべてで返る', () {
        for (var n = 100; n <= 999; n++) {
          expect(l.gateNumberWords(n).trim(), isNotEmpty, reason: '${l.tag} $n');
        }
      });

      test('小数点が decimalSeparator と点数の表記で一致', () {
        expect(l.formatNumber(2.5), '2${l.decimalSeparator}5');
        expect(l.formatNumber(3), '3');
      });
    });
  }

  test('翻訳確認用の CSV（docs/translation_review.csv）が最新', () {
    final f = File('docs/translation_review.csv');
    expect(f.existsSync(), isTrue, reason: '`dart run tool/export_strings.dart` で書き出す');
    final onDisk = f.readAsStringSync().replaceFirst('﻿', '');
    expect(onDisk, stringsCatalogCsv(),
        reason: '文言を変えたら `dart run tool/export_strings.dart` で docs/translation_review.csv を更新する');
  });

  test('CSV は引用符・改行を含む文言でも崩れない', () {
    final csv = stringsCatalogCsv([const EnStrings()]);
    // 行数 = ヘッダ + キー数（レポート文言の改行は引用符の中）
    final rows = RegExp(r'^"[^"\n]+","', multiLine: true).allMatches(csv).length;
    expect(rows, stringsCatalog(const EnStrings()).length + 1);
  });
}
