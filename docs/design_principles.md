# 設計方針

chukore_kit の設計方針を1か所にまとめる。詳細は各ドキュメントにリンクする。

## 1. 位置づけ

- **中学（ちゅうコレ！）専用**。小学コレ！とは共通にしない（基盤も別）。小学の海外版は別の基盤で作る。
- 売り方: **教科ごとに別アプリ**（英語 → 数学 → 社会 → 理科 → 国語）。入口は弱い1教科の単体で、セットは2教科目を足すとき。
- コンセプトは**「気づいたら、点が上がっている。」**。頑張って使うアプリではなく、毎日ちょっとで伸びが見えるアプリ。計画・診断は手段で、前面に出さない。結果は保証しない（偏差値は日本の言い方で、海外は「点・成績」。詳細は [`competitive_research_middle_school.md`](competitive_research_middle_school.md) §4.2）。
- 目的は**定期テスト・受験の対策**。テスト日から逆算する計画（`buildPlan`）を中心に置く。テスト日のない「習慣モード」は作らない（小学の役割）。

## 2. 守ること

1. **コアは純 Dart**（`chukore_kit.dart`）。画面は `chukore_kit_ui.dart`、SQLite は `chukore_kit_sqlite.dart` に分ける。
2. **国・言語はデータ**。年齢・同意・利用時間・広告・課金手段は `RegionProfile`、単元と学習基準は `CurriculumPack`、文言は `ChukoreStrings`。コードに国名の分岐を書かない。
3. **子どもの安全側が既定**。同意なし・広告なし・トラッキングなし・責めない文面。ゆるくする変更は明示する（書き間違いは `FormatException`）。
4. **基盤は集めない・送らない**。匿名集計は設計だけ（[`anonymous_data_collection.md`](anonymous_data_collection.md)）。送る項目は「落とす項目」をテストで固定する。
5. **法的な数値は決めない**。法務確認の結果を JSON で受け取る。暫定値は暫定と書く。
6. **結果を見る前に基準を決める**。基準の変更は理由と日付を記録する（[`global_rollout_criteria.md`](global_rollout_criteria.md)）。
7. **互換を守る**。バックアップ形式・DB の版を上げるときは、古いファイルが読める互換テストを足す。
8. **遅くしない**。回答 10 万件で各関数が 1 秒未満（`tool/bench.dart`、`test/scale_test.dart`）。
9. **法務確認を行わない間は、確認が要る機能を有効にしない**（2026-10-28 運営者判断）。匿名の送信・集計、範囲カードの共有、13歳未満への通知、結果を示す訴求、海外展開は止めておく。範囲は [`legal_review_questions.md`](legal_review_questions.md) §0。

## 3. 中学の指標

継続の日数より、テストという目的に届いたかを見る。基準値は、結果を見る前に決めて記録する。

- テスト日を登録した割合
- テスト後の振り返りまで進んだ割合
- テスト後の点の変化（本人が入力した範囲で）

## 4. 海外（中学）

- **法務確認を行わない間は、日本のみ**（国ごとの子どもの個人情報の規制の確認が要るため）。以下は、確認を再開したあとの話。
- ちゅうコレ！の海外版は、小学の結果を見てから判断する（国ごとの試験の習慣が日本ほど強くない可能性）。
- 進めるときは [`global_rollout_criteria.md`](global_rollout_criteria.md) の基準に従い、`CurriculumPack` と `RegionProfile` を国ごとに用意する。

## 5. 関連

- コンセプト整理: [`concept.md`](concept.md)
- 機能一覧: [`features.md`](features.md)
- 海外版との対応: [`global_alignment.md`](global_alignment.md)
- アプリ共通部品との接続: [`integration_app_common_kit.md`](integration_app_common_kit.md)
- 法務確認: [`legal_review_questions.md`](legal_review_questions.md)
