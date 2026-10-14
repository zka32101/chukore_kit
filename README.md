# chukore_kit

ちゅうコレ！専用の共通部品（非公開）。仕様: `chukore_kit_仕様_v0_2.md`。

実装済み（§9 の 1・2・4 の一部）: モデル、単元ツリー(JSON)、テスト日逆算、習熟度、到達レベル、目安偏差値、弱点ノート(克服判定)。
実装済み追加: 保護者ゲート(漢数字)・週次レポート文面。
実装済み追加: 問題タイプ判定（選択・数値・並べ替え）、回答履歴ストア契約＋メモリ実装。
実装済み追加: 成長機能の計算部（G2レーダー・G3自己ベスト・G4スタンプ・G5できるようになった数・G6進化）。
SQLite 保存: `package:chukore_kit/chukore_kit_sqlite.dart`（sqlite3。コード生成なし）。
実装済み追加: 偏差値 段階2の計算部（exam_stats 互換の3値集計。送受信はアプリがコールバックで注入）。
実装済み追加: 地図タップ問題の判定（小学コレ！社会の JapanRegionTapMap を参考。境界線データ・教科色はアプリ側。描画は `RegionTapMap`、CustomPainter で flutter_map 非依存）。
実装済み追加: 図タップ（`RegionTapMap` の background＋画像座標 flipY=false）、年表（timeline 判定・`TimelineOrderList`）。
実装済み追加: 成長カード（`GrowthCardData`・`GrowthCardView`・`renderGrowthCardPng`。名前/ID/メール欄なし、13歳未満はゲート通過後のみ共有）。
未実装: キャラ収集（キャラ案の確定待ち）、英語アプリとの結合。
中核ロジックは Flutter 非依存（`chukore_kit.dart`）。画面部品は別入口 `chukore_kit_ui.dart`（地図タップの描画 `RegionTapMap` など）。UI 連携時に app_common_kit を依存に加える。

```
flutter pub get && flutter analyze && flutter test
```

## 海外対応（i18n）

- 文言は `ChukoreStrings`（`JaStrings` / `EnStrings`）に集約。`ChukoreStrings.forLocale('en-US')` で選ぶ（未対応の言語は英語）。成長カード・週次レポート・地図/年表の読み上げ・年の表記に渡す。言語を増やすときは `ChukoreStrings` を実装して `forLocale` に足す。
- 保護者ゲートの読み上げは言語ごと（日本語=漢数字、英語=英単語）。`GateChallenge.promptFor(strings)`。入力は全角・桁区切り（`, . 空白`）を許容。
- 数値入力は `checkAnswer(..., decimalSeparator: ',')` で、小数点がカンマの国（欧州など）に対応。マイナス記号の違い（U+2212・全角）も吸収。
- 日付はデバイスの**ローカル暦日**で扱う。SQLite は UTC で保存し、読み出しはローカル時刻、範囲の境界はローカル0時を UTC に直して比較（時差のある国でも日付がずれない）。`dateOnly` には必ずローカル時刻の DateTime を渡す。
- 問題データ・単元名・キャラ名・教科色は教科アプリ側（多言語化はアプリ側）。
