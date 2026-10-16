# chukore_kit

ちゅうコレ！専用の共通部品（非公開）。仕様: `chukore_kit_仕様_v0_2.md`。

実装済み（§9 の 1・2・4 の一部）: モデル、単元ツリー(JSON)、テスト日逆算、習熟度、到達レベル、アプリ内偏差値、弱点ノート(克服判定)。
実装済み追加: 保護者ゲート(漢数字)・週次レポート文面。
実装済み追加: 問題タイプ判定（選択・数値・並べ替え）、回答履歴ストア契約＋メモリ実装。
実装済み追加: 成長機能の計算部（G2レーダー・G3自己ベスト・G4スタンプ・G5できるようになった数・G6進化）。
SQLite 保存: `package:chukore_kit/chukore_kit_sqlite.dart`（sqlite3。コード生成なし）。
実装済み追加: アプリ内偏差値 段階2の計算部（exam_stats 互換の3値集計。送受信はアプリがコールバックで注入）。
実装済み追加: 地図タップ問題の判定（小学コレ！社会の JapanRegionTapMap を参考。境界線データ・教科色はアプリ側。描画は `RegionTapMap`、CustomPainter で flutter_map 非依存）。
実装済み追加: 図タップ（`RegionTapMap` の background＋画像座標 flipY=false）、年表（timeline 判定・`TimelineOrderList`）。
実装済み追加: 成長カード（`GrowthCardData`・`GrowthCardView`・`renderGrowthCardPng`。名前/ID/メール欄なし、13歳未満はゲート通過後のみ共有）。
実装済み追加: 先生役モード（まちがいキャラ）の出題・進行（`MistakeLine`・`pickMistakeLines`・`TeacherSession`・`teacherAttempt`）。誤解の型と弱点ノートの克服判定につながる。セリフなどの中身は問題データ（アプリ側）。

実装済み追加: 間隔反復（`buildReviewStates`・`dueForReview`）。問題ごとに、正解で箱が上がり復習間隔が 1→3→7→14→30 日と伸び、不正解で箱 0 に戻って翌日に出す。テスト日を超えない。今日の復習は「遅れている順→箱が低い順」で、件数・単元で絞れる。固定の再出題日（`retryDates`）とは別に使える。

実装済み追加: 模試モード（`buildMockExam`・`scoreMockExam`）。範囲と問題数・制限時間を決めると、単元の重み（estimatedQuestions）に比例して出題する（同じ seed なら同じ出題）。採点は単元別の成績・未回答（不正解扱い）・時間切れ・アプリ内偏差値（段階1）を返し、回答履歴は `mode: 'mock'` で習熟度・間隔反復・弱点ノートにそのまま使える。正答率の低い単元は `weakUnits()`。

実装済み追加: ケアレスミス判定（`classifyMistakes`）。誤答を「ケアレスの疑い」（その単元で正解するときの中央値の 35% 未満で答えた＝`tooFast`、直後 10 分以内に同じ問題を正解し直した＝`quickRetry`）と「理解不足の疑い」に分ける目安。`buildWeakNotes(..., ignoreCareless: true)` でケアレスの疑いの誤答を弱点に数えない（既定は従来どおり数える）。所要時間が未計測（0）や、基準になる正解が 5 件未満のときは速さでは判定しない。

実装済み追加: 自信度（`Attempt.confident`・`confidenceKindOf`・`summarizeConfidence`）。回答のとき「自信あり／なし」を任意で聞き、正誤と合わせて4つに分ける（自信ありで正解＝定着、自信なしで正解＝まぐれかも、自信ありで誤答＝思い込みの疑い、自信なしで誤答＝分からないと自覚）。単元別に「誤答のうち自信ありだった割合」「正解のうち自信なしだった割合」を出せる。間隔反復では、自信なしの正解は箱を上げず、自信ありで誤答した問題は同じ遅れなら先に出す。弱点ノートに `confidentWrongCount`。模試の `scoreMockExam(confident:)` でも残せる。SQLite は版 2（`confident` 列。旧版の DB は開くと列が足され、既存の回答は残る）。

実装済み追加: テスト後の振り返り（`buildPostTestReview`）。実際のテストの問題は問題集に無いので、単元ごとの失点と理由（理解不足／忘れ／ケアレス／時間切れ）を入れる。単元別・理由別の失点、「取り戻しやすい失点」（ケアレス・時間切れ）と「学び直しが要る失点」（理解不足・忘れ）、入力の食い違い（`consistent`）を返す。理解不足・忘れの単元だけ習熟度を下げた `adjustedMastery`（`buildPlan` にそのまま渡せる）と、履歴に残す `mode: 'real_test'` の回答を作る。ツリーを渡すと、存在しない単元・葉でない単元を `issues` で報告して外す。

実装済み追加: 誤解の型の傾向分析（`analyzeMisconceptions`）。誤答した選択肢に付いた誤解の型を単元をまたいで集計し、型ごとに回数・自信ありで誤答した回数・単元別の回数・直近 14 日とその前の 14 日の比較（新しく出た／増えた／同じ／減った／直近は出ていない）・克服済みかを返す。複数の単元に出ている型（`crossUnit`）は、単元をこえた共通のつまずきとして先に並び、さかのぼり診断や学び直しの入口になる。

実装済み追加: 学習時間の見積もり（`buildPace`・`estimateDayTimes`・`daysOverBudget`・`questionsWithinBudget`）。回答の所要時間（`elapsedMs`）から1問あたりの時間を中央値で求め（単元の記録が 5 件以上ならその単元、足りなければ全体、全体も足りなければ既定の 45 秒。未計測と 5 分超は除く）、`buildPlan` の日ごとの計画から1日の学習時間を見積もる（表示用に5分きざみの切り上げ）。1日に使える分を決めて、超える日を探したり、その分で解ける問題数を出したりできる。

実装済み追加: 目標点からの逆算（`buildGoalPlan`）。「この教科で80点」と決めると、今の習熟度から見込む点（範囲の単元を問題数の重みで平均）との差を出し、習熟度を上限（既定 0.9）まで上げたときの増分が大きい単元から、届くところまで「どの単元をどこまで伸ばすか」を返す（最後の単元は必要な分だけ）。上限まで伸ばしても届かない目標は `unreachable`。記録のない単元は未学習（0）として数える。到達レベルの下限点（`LevelThresholds.minOf`）を目標にもできる。伸ばす単元の ID は `unitIds`。

実装済み追加: 模試の履歴比較（`compareMockExams`）。模試の結果（`MockHistoryEntry`）を日付順に並べ、得点・アプリ内偏差値・1問あたりの時間・未回答・時間切れの推移、前回との差、自己ベスト、得点の傾き（1回ごとに平均で何点動くか）を出す。単元別には、直近の回と「前回」「最初の回」での正答率の変化（伸びた順）を返し、最も伸びた単元・最も下がった単元を取り出せる。問題数が少ない単元（既定 2 問未満）は、ぶれが大きいので比べない。

実装済み追加: 週次レポートの材料の強化（`WeeklyReport`）。先週の回答数・学習した日数（`previousAttemptCount`・`previousActiveDays`・`attemptDelta`）に加えて、`buildWeeklyReport(..., questions: ...)` で問題集を渡すと、その週に新しく克服できた弱点の数（`newlyOvercome`）と、先週は間違えたが今週は間違えなかった誤解の型（`easedMisconceptions`）も出す。いずれも「できるようになったところ」を伝える材料で、本文（`toText`）はこれまでどおり。新しい項目を本文に出す文言（全言語）と、13歳未満に見せてよい内容・範囲は、法務確認のあとに決める（見せる側のアプリが決める）。
実装済み追加: 問題集・単元ツリーの JSON 形式と検証（`parseQuestionBank`・`validateQuestionBank`・`validateUnitList`、`dart run tool/validate_bank.dart`）。形式は `docs/question_bank_format.md`。
実装済み追加: 成長機能 v1.1（G7 成長の年輪 `buildGrowthRings`・`GrowthRingsView`、G8 本番の点数の記録 `compareRealTests`、G9 アプリ内偏差値の表示ポリシー `deviationDisplay`・`formatDeviationRange`）。
実装済み追加: さかのぼり診断（`PrerequisiteGraph`・`diagnoseBacktrace`。他アプリの前提は誘導リンクだけ）。
実装済み追加: 直前プリント（`buildLastMinuteSheet`・`renderSheetHtml`。間違い理由別・未克服のみ。A4 印刷用の HTML で、端末のフォントを使うので言語を問わず印刷できる）。
実装済み追加: 当日チェック（持ち物チェックリスト `DayChecklist`・`DayChecklistView`、直前5分カード `buildFiveMinuteCard`）。うかラボとの共通化は app_common_kit 側で別途。
実装済み追加: 範囲カードの QR 共有（`encodeScope`・`decodeScope`・`ScopeQrView`）。
未実装: キャラ収集（キャラ案の確定待ち）、英語アプリとの結合。
中核ロジックは Flutter 非依存（`chukore_kit.dart`）。画面部品は別入口 `chukore_kit_ui.dart`（地図タップの描画 `RegionTapMap` など）。UI 連携時に app_common_kit を依存に加える。

```
flutter pub get && flutter analyze && flutter test
```

## 海外対応（i18n）

- 文言は `ChukoreStrings`（`JaStrings` / `EnStrings` / `PtStrings` / `EsStrings` / `FrStrings` / `KoStrings` / `IdStrings` / `ViStrings` / `DeStrings` / `ZhStrings`）に集約。`ChukoreStrings.forLocale('pt-BR')` のように選ぶ（未対応の言語は英語）。ポルトガル語は既定がブラジル式、`pt-PT` のときだけ欧州式の綴り（dezasseis など）。中国語は簡体（既定）・繁体（`zh-Hant`・`zh-TW`・`zh-HK`・`zh-MO`。スクリプト指定が地域に優先、`zh-Hans-TW` は簡体）で、数の読み上げは同じ字・文言は字体が別。韓国語の読み上げは漢字語の数詞。インドネシア語は `id`（Android の旧式のコード `in` も）で、複数形が無く、小数点はカンマ。ベトナム語は `vi` で、複数形が無く、小数点はカンマ。数の読み上げは mười・mốt・lăm・lẻ・nghìn の規則（北部式）。年は紀元前が `500 TCN`、西暦が `năm 1945`。ドイツ語は `de`（スイス・リヒテンシュタインの `de-CH`・`de-LI` は小数点が `.` で ß を使わず ss）。数の読み上げは一語に続ける形（`vierhundertzweiundachtzig`、一の位だけの 1 は `eins`、二十以上は `einundzwanzig`）。年は紀元前が `500 v. Chr.`、西暦は数字だけ。フランス語は `fr-BE`・`fr-CH` のとき septante/nonante（80 は quatre-vingts）。フランス語の約物（! ? : %）の前は改行されない空白（U+00A0）、複数形は 2 から（1,5 point）。スペイン語は小数点が地域で違い、`es-MX`・`es-US` など（ベストエフォート）は `.`、それ以外は `,`。小数点は `strings.decimalSeparator` で取れるので、数値入力の `checkAnswer(..., decimalSeparator: strings.decimalSeparator)` にそのまま渡す。成長カード・週次レポート・地図/年表の読み上げ・年の表記に渡す。言語を増やすときは `ChukoreStrings` を実装して `forLocale` に足す。
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
