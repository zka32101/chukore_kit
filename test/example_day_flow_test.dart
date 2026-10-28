import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/day_flow.dart';

void main() {
  // 結線の確認: 例の 1 日の流れが、最後まで通る（部品の組み合わせが壊れたら、ここで気づく）
  test('example/day_flow.dart が最後まで通り、要所の結果が期待どおり', () async {
    final lines = await runDay(today: DateTime(2026, 10, 20));
    final text = lines.join('\n');
    expect(text, contains('問題 3 問 / 検査の指摘 0 件'));
    expect(text, contains('計画 15 日'));
    expect(text, contains('出題 3 問'));
    expect(text, contains('en1_be_001: 不正解（誤解の型 be_agreement）'), reason: '誤解の型が結びつく');
    expect(text, contains('解き直しセット 1 件（先頭: tag:be_agreement）'));
    expect(text, contains('今日は 1 分だけ: 1 問（見積もり 45 秒 / 予算 60 秒、収まる: true）'), reason: '時間で選ぶ');
    expect(text, contains('学習後の見出し: done'));
    expect(text, contains('保護者向けレポート（12 歳）: needsGuardianGate'), reason: '子どもには保護者ゲートのあと');
    expect(text, contains('声かけ: '));
    expect(text, contains('点を聞く（使い始め）: baseline'));
    expect(text, contains('点を聞く（テストの翌日）: afterTest'));
    expect(text, contains('次の日にもう一度聞くか: 聞かない'), reason: '聞いたら二度と聞かない');
    expect(text, contains('本番の点の変化: up（学習日 1 日）/ ${const JaStrings().outcomeUp}'));
    expect(
      text,
      contains(
        '{"event":"score_entered","subject":"en","region":"JP","grade":1,"kind":"regular","band":"bigUp","usage":"low","baseline":true,"tuning":1}',
      ),
      reason: '外へ出す形には点・日付が無い',
    );
    expect(RegExp(r'"(score|date|name|maxScore)"\s*:').hasMatch(text), false, reason: '項目に点・日付・名前が無い');
    expect(text, contains('バックアップ: 3 件を書き出し、3 件を取り込み（重複 0）'));
    expect(text, contains('追加 0 件（二重にならない）'));
    expect(text, contains('全削除のあとの履歴: 0 件'));
  });

  test('13 歳以上は、保護者向けレポートをそのまま見せてよい。言語を変えれば声かけも変わる', () async {
    final ja = (await runDay(today: DateTime(2026, 10, 20))).join('\n');
    final en = (await runDay(today: DateTime(2026, 10, 20), strings: const EnStrings(), age: 14)).join('\n');
    expect(en, contains('保護者向けレポート（14 歳）: allowed'));
    expect(en, contains(const EnStrings().talkGrew));
    expect(ja, isNot(contains(const EnStrings().talkGrew)));
  });

  test('日付が変わっても同じ流れ（日付に依存しない）', () async {
    final a = await runDay(today: DateTime(2026, 10, 20));
    final b = await runDay(today: DateTime(2027, 3, 5));
    expect(b.where((l) => l.startsWith('  ')), a.where((l) => l.startsWith('  ')));
    expect(b.last, a.last);
  });
}
