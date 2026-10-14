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
実装済み追加: 先生役モード（まちがいキャラ）の出題・進行（`MistakeLine`・`pickMistakeLines`・`TeacherSession`・`teacherAttempt`）。誤解の型と弱点ノートの克服判定につながる。セリフなどの中身は問題データ（アプリ側）。
実装済み追加: 問題集・単元ツリーの JSON 形式と検証（`parseQuestionBank`・`validateQuestionBank`・`validateUnitList`、`dart run tool/validate_bank.dart`）。形式は `docs/question_bank_format.md`。
実装済み追加: 成長機能 v1.1（G7 成長の年輪 `buildGrowthRings`・`GrowthRingsView`、G8 本番の点数の記録 `compareRealTests`、G9 偏差値の表示ポリシー `deviationDisplay`・`formatDeviationRange`）。
未実装: キャラ収集（キャラ案の確定待ち）、英語アプリとの結合。
中核ロジックは Flutter 非依存（`chukore_kit.dart`）。画面部品は別入口 `chukore_kit_ui.dart`（地図タップの描画 `RegionTapMap` など）。UI 連携時に app_common_kit を依存に加える。

```
flutter pub get && flutter analyze && flutter test
```

## 海外対応（i18n）

- 文言は `ChukoreStrings`（`JaStrings` / `EnStrings` / `PtStrings` / `EsStrings` / `FrStrings` / `KoStrings` / `ZhStrings`）に集約。`ChukoreStrings.forLocale('pt-BR')` のように選ぶ（未対応の言語は英語）。ポルトガル語は既定がブラジル式、`pt-PT` のときだけ欧州式の綴り（dezasseis など）。中国語は簡体（既定）・繁体（`zh-Hant`・`zh-TW`・`zh-HK`・`zh-MO`。スクリプト指定が地域に優先、`zh-Hans-TW` は簡体）で、数の読み上げは同じ字・文言は字体が別。韓国語の読み上げは漢字語の数詞。フランス語は `fr-BE`・`fr-CH` のとき septante/nonante（80 は quatre-vingts）。フランス語の約物（! ? : %）の前は改行されない空白（U+00A0）、複数形は 2 から（1,5 point）。スペイン語は小数点が地域で違い、`es-MX`・`es-US` など（ベストエフォート）は `.`、それ以外は `,`。小数点は `strings.decimalSeparator` で取れるので、数値入力の `checkAnswer(..., decimalSeparator: strings.decimalSeparator)` にそのまま渡す。成長カード・週次レポート・地図/年表の読み上げ・年の表記に渡す。言語を増やすときは `ChukoreStrings` を実装して `forLocale` に足す。
- 保護者ゲートの読み上げは言語ごと（日本語=漢数字、英語=英単語）。`GateChallenge.promptFor(strings)`。入力は全角・桁区切り（`, . 空白`）を許容。
- 数値入力は `checkAnswer(..., decimalSeparator: ',')` で、小数点がカンマの国（ブラジル・ポルトガルなどの欧州・中南米）に対応。点数の表示の小数点も言語ごと（`formatNumber`）。マイナス記号の違い（U+2212・全角）も吸収。
- 日付はデバイスの**ローカル暦日**で扱う。SQLite は UTC で保存し、読み出しはローカル時刻、範囲の境界はローカル0時を UTC に直して比較（時差のある国でも日付がずれない）。`dateOnly` には必ずローカル時刻の DateTime を渡す。
- 問題データ・単元名・キャラ名・教科色は教科アプリ側（多言語化はアプリ側）。

### 言語を追加・変更するとき

1. `ChukoreStrings` を実装し、`forLocale` と `ChukoreStrings.supported` に足す。
2. `dart run tool/export_strings.dart` で `docs/translation_review.csv`（全言語の全文言を並べた一覧）を更新する。**更新を忘れるとテストが失敗する。**
3. `docs/translation_review.csv` をスプレッドシートで開き、ネイティブに確認してもらう（プレースホルダ `{subject}` `{points}` などは訳の中に残す）。
4. `flutter test`。全言語に対して、空の文言・プレースホルダの欠落・英語のまま残った訳・数の読み上げ（100〜999）・小数点の表記を検査する。英語と同語源で綴りが同じ文言（例: フランス語の `question`）は `test/l10n_consistency_test.dart` の `cognates` に言語限定で足す。

### フォント

成長カードの画像化は端末のフォントで描く。日本語・中国語・韓国語・タイ語などは、`renderGrowthCardPng` / `GrowthCardView` の `fontFamily` / `fontFamilyFallback` を言語ごとに渡すと、端末による文字の四角化（豆腐）を避けられる。
