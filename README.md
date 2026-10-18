# chukore_kit

ちゅうコレ！専用の共通部品（非公開）。仕様: `chukore_kit_仕様_v0_2.md`。

## 実装済みの機能

詳細（使い方・判定の基準・注意点）は [`docs/features.md`](docs/features.md)。

| 分野 | 主な API |
| --- | --- |
| 土台 | モデル・単元ツリー・テスト日逆算 `buildPlan`・習熟度・到達レベル・アプリ内偏差値（段階1・2）・回答履歴ストア（メモリ／SQLite）・問題集の検証 `validateQuestionBank` |
| 復習・弱点 | 弱点ノート `buildWeakNotes`・間隔反復 `buildReviewStates`・ケアレス判定 `classifyMistakes`・自信度 `confidenceKindOf`・誤解の型の傾向 `analyzeMisconceptions`・さかのぼり診断 `diagnoseBacktrace` |
| 計画・目標 | 学習時間の見積もり `estimateDayTimes`・目標点からの逆算 `buildGoalPlan` |
| 模試・振り返り | 模試 `buildMockExam`／`scoreMockExam`・履歴比較 `compareMockExams`・テスト後の振り返り `buildPostTestReview`・本番の点数の比較 `compareRealTests` |
| 成長の見える化 | レーダー・自己ベスト・克服スタンプ・進化・成長カード `renderGrowthCardPng`・成長の年輪 |
| 問題タイプ・画面部品 | 選択・地図タップ・図タップ・数値・記述（別解・部分点）・並べ替え・年表の判定／`RegionTapMap`・`TimelineOrderList` |
| 保護者・先生役 | 保護者ゲート `GateChallenge`・国ごとの年齢条件 `AgePolicy`・週次レポート `buildWeeklyReport`・先生役モード（まちがいキャラ） |
| 引き継ぎ | 学習データの書き出し・取り込み `AttemptBackup`（回答履歴を1つの JSON に。二重取り込みなし、壊れたファイルは全体を拒否） |
| 通知 | 学習を促す通知の判定 `decideNudge`（テスト接近・復習・連続記録。1 日 1 件、うるさくしない）・通知を出す時間帯の提案 `suggestNudgeHour`（履歴から。端末内）・各言語の文言 |
| 出題 | 適応的な出題選び `pickPractice`（計画に沿って、習熟度に合う難しさの問題を 復習・重点・弱点の枠で選ぶ） |
| 複数教科の計画 | 5 教科などの同時計画 `buildMultiPlan`（テストが近い・習熟度が低い教科を厚く、遠い教科も止めない） |
| 解き直し | つまずき別の解き直しセット `buildRetrySets`（誤解の型ごとに、未出題の問題を先にして集める） |
| ふりかえり | 子ども本人向けの週のふりかえり `buildMyWeek`（できたことだけを前に出す。少なかった週も責めない） |
| 直前・当日・共有 | 直前プリント `buildLastMinuteSheet`・当日チェック `DayChecklist`・範囲カードの QR `encodeScope` |

未実装: キャラ収集（キャラ案の確定待ち）、英語アプリとの結合。

SQLite 保存は別入口 `package:chukore_kit/chukore_kit_sqlite.dart`（sqlite3。コード生成なし）。

中核ロジックは Flutter 非依存（`chukore_kit.dart`）。画面部品は別入口 `chukore_kit_ui.dart`（地図タップの描画 `RegionTapMap` など）。UI 連携時に app_common_kit を依存に加える。

```
flutter pub get && flutter analyze && flutter test
```

## 海外対応（i18n）

- 文言は `ChukoreStrings`（`JaStrings` / `EnStrings` / `PtStrings` / `EsStrings` / `FrStrings` / `KoStrings` / `IdStrings` / `ViStrings` / `DeStrings` / `TrStrings` / `ThStrings` / `HiStrings` / `ArStrings` / `RuStrings` / `ItStrings` / `NlStrings` / `PlStrings` / `ZhStrings`）に集約。`ChukoreStrings.forLocale('pt-BR')` のように選ぶ（未対応の言語は英語）。ポルトガル語は既定がブラジル式、`pt-PT` のときだけ欧州式の綴り（dezasseis など）。中国語は簡体（既定）・繁体（`zh-Hant`・`zh-TW`・`zh-HK`・`zh-MO`。スクリプト指定が地域に優先、`zh-Hans-TW` は簡体）で、数の読み上げは同じ字・文言は字体が別。韓国語の読み上げは漢字語の数詞。インドネシア語は `id`（Android の旧式のコード `in` も）で、複数形が無く、小数点はカンマ。ベトナム語は `vi` で、複数形が無く、小数点はカンマ。数の読み上げは mười・mốt・lăm・lẻ・nghìn の規則（北部式）。年は紀元前が `500 TCN`、西暦が `năm 1945`。ドイツ語は `de`（スイス・リヒテンシュタインの `de-CH`・`de-LI` は小数点が `.` で ß を使わず ss）。数の読み上げは一語に続ける形（`vierhundertzweiundachtzig`、一の位だけの 1 は `eins`、二十以上は `einundzwanzig`）。年は紀元前が `500 v. Chr.`、西暦は数字だけ。トルコ語は `tr` で、複数形が無く（数詞のあとは単数形）、小数点はカンマ。数の読み上げは分けて書き、100 は `yüz`・1000 は `bin`（`bir yüz`・`bir bin` とは言わない）。年は紀元前が `M.Ö. 500`、西暦は数字だけ。レポートの割合は `%40`（% が前）。タイ語は `th` で、複数形が無く、小数点はドット。数の読み上げは単語の間に空白を入れず（`สี่ร้อยแปดสิบสอง`）、10 は `สิบ`・20 は `ยี่สิบ`・末尾の 1 は `เอ็ด`（101 = `หนึ่งร้อยเอ็ด`）。年は仏暦に西暦を添える（`พ.ศ. 2488 (ค.ศ. 1945)`、紀元前は `ก่อน ค.ศ. 500`）。保護者ゲートはタイ数字（๑๒๓）の入力も受け付ける。ヒンディー語は `hi` で、複数形の区別は付けず、小数点はドット。数詞は 1〜99 がすべて不規則なので表で持ち（`HiStrings.numbers`）、100 は `एक सौ`・1000 は `एक हज़ार`。年は西暦が `1945 ई.`・紀元前が `500 ई.पू.`。保護者ゲートはデーヴァナーガリー数字（४८२）の入力も受け付ける。綴りの揺れがある数詞（तिरपन など）は一般的な綴りを採ったので、ネイティブ確認が要る。**タイ語・ヒンディー語は端末のフォントが要る**（成長カードの画像化では `fontFamilyFallback` を渡す）。アラビア語は `ar`（現代標準語）で、右から左に書く。`strings.rightToLeft` が真で、UI 部品は `textDirectionOf(strings)` の向きに従い（年表・チェックリストは `Directionality`、成長カードはバッジと文字の位置を左右反転）、直前プリントの HTML は `dir="rtl"`。数字の出力は 0〜9、小数点はドット。複数形は 1・2（双数）・3〜10・11 以上で変え、数の読み上げは男性形（`أربعمئة واثنان وثمانون`）。入力は各地の数字（全角・タイ・デーヴァナーガリー・アラビア・インド数字・ペルシア数字）を `normalizeDigits` で 0〜9 にそろえる（保護者ゲートと数値の答えに適用）。文言に母音記号は付けていない。**アラビア語は端末のフォントが要る**（`Noto Sans Arabic` など）。ロシア語は `ru` で、複数形が 3 つ（1・2〜4・5 以上。11〜14 は 5 以上の形。`RuStrings.plural` で取れる）、小数点はカンマ。数の読み上げは男性形で、千だけ女性形（`одна тысяча`・`две тысячи`）。年は `1945 г.`・`500 г. до н. э.`。ネイティブ確認が要る。イタリア語は `it` で、複数形は 1 とそれ以外、小数点はカンマ。数の読み上げは一語に続ける形で、母音の省略（`ventuno`・`ventotto`・`centotto`・`centottanta`）と、複合語の末尾の 3 のアクセント（`ventitré`・`centotré`。13 の `tredici` は対象外）に従う。年は `500 a.C.`・`1945 d.C.`。ネイティブ確認が要る。オランダ語は `nl`（ベルギーのオランダ語も同じ）で、複数形は 1 とそれ以外、小数点はカンマ。数の読み上げは一語に続ける形で、一の位を十の位の前に `en` でつなぐ（`eenentwintig`・`tweeëntwintig`・`drieëndertig`。語末が e の `twee`・`drie` は `ën`）。1000 は `duizend`・100 は `honderd`。年は `500 v.Chr.`・`1945 n.Chr.`。ネイティブ確認が要る。ポーランド語は `pl` で、複数形は 3 つ（1・2〜4・それ以外。12〜14 は「それ以外」。ロシア語と違い、21・101 などは 1 の形にならない。`PlStrings.plural` で取れる）、小数点はカンマ。数の読み上げは男性形で、千は 2〜4 が `tysiące`・5 以上が `tysięcy`（`tysiąc` は 1000 だけ）。年は `1945 r.`・`500 r. p.n.e.`。ネイティブ確認が要る。フランス語は `fr-BE`・`fr-CH` のとき septante/nonante（80 は quatre-vingts）。フランス語の約物（! ? : %）の前は改行されない空白（U+00A0）、複数形は 2 から（1,5 point）。スペイン語は小数点が地域で違い、`es-MX`・`es-US` など（ベストエフォート）は `.`、それ以外は `,`。小数点は `strings.decimalSeparator` で取れるので、数値入力の `checkAnswer(..., decimalSeparator: strings.decimalSeparator)` にそのまま渡す。成長カード・週次レポート・地図/年表の読み上げ・年の表記に渡す。言語を増やすときは `ChukoreStrings` を実装して `forLocale` に足す。
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

## アクセシビリティ

- **色だけに頼らない**: 地図タップの回答後は、正解にチェック（✓）・不正解にバツ（✗）の図形を重ねる（`RegionMark`）。年表の回答後も ✓ / ✗ のアイコンを出す。色覚の多様性や白黒表示でも正誤が分かる。
- **スクリーンリーダー**: 地図は領域ごとにボタンとして読み上げ・操作できる（`CustomPainter.semanticsBuilder`）。回答後は「Alpha (correct)」のように正解・不正解も言う。選択対象外・回答後は操作不可。領域が小さくても押せるよう、最低 24 の大きさにしている。年表のアイコンも、各行の読み上げと一体で正誤を伝える。
- 読み上げの言語は `strings:`（`RegionTapMap`・`TimelineOrderList`）で切り替える。

## 範囲カードの共有（QR）

テスト範囲を、短い符号 `CKS1.<教科>.<ツリーの版>.<指紋>.<選んだ単元のビット列>[.<テスト日>]` にして QR で渡す（`encodeScope` / `decodeScope` / `ScopeQrView`）。

- **個人情報は入らない**: 入るのは教科・単元ツリーの版と指紋・どの葉の単元を選んだか・（任意で）テスト日だけ。名前・ID・メール・成績・匿名UIDは入らない（文字種・構成をテストで保証）。単元の名前や単元IDそのものも入らない。
- 送り手と受け手の単元ツリーが**同じ版・同じ中身**のときだけ読める（指紋で確かめる）。違うときは `ScopeError.treeMismatch`（アプリが古い）や `subjectMismatch` を返すので、アプリは「アプリを更新してください」などを出す。
- 単元ツリーは1つの教科だけで作る前提（教科は単元から決まる）。
- **設計書では「法務確認後」の機能**。このパッケージは符号化と QR の描画までで、共有の画面を実際に公開するかはアプリ側で決める（法務確認が済むまで出さない）。QR を読み取る側（カメラ）もアプリ側。
