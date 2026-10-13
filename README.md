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
未実装: 成長カードの描画、キャラ収集、英語アプリとの結合。
中核ロジックは Flutter 非依存（`chukore_kit.dart`）。画面部品は別入口 `chukore_kit_ui.dart`（地図タップの描画 `RegionTapMap` など）。UI 連携時に app_common_kit を依存に加える。

```
flutter pub get && flutter analyze && flutter test
```
