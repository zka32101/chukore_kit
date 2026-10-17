# 機能の詳細

README の実装済み一覧の詳細。各項目の先頭は公開 API の名前。仕様は `chukore_kit_仕様_v0_2.md`。

## 土台（モデル・計画・判定）

- （仕様 §9 の 1・2・4 の一部）モデル、単元ツリー(JSON)、テスト日逆算、習熟度、到達レベル、アプリ内偏差値、弱点ノート(克服判定)。
- 問題タイプ判定（選択・数値・並べ替え）、回答履歴ストア契約＋メモリ実装。
- SQLite 保存: `package:chukore_kit/chukore_kit_sqlite.dart`（sqlite3。コード生成なし）。
- アプリ内偏差値 段階2の計算部（exam_stats 互換の3値集計。送受信はアプリがコールバックで注入）。
- 問題集・単元ツリーの JSON 形式と検証（`parseQuestionBank`・`validateQuestionBank`・`validateUnitList`、`dart run tool/validate_bank.dart`）。形式は `docs/question_bank_format.md`。

## 復習・弱点

- 間隔反復（`buildReviewStates`・`dueForReview`）。問題ごとに、正解で箱が上がり復習間隔が 1→3→7→14→30 日と伸び、不正解で箱 0 に戻って翌日に出す。テスト日を超えない。今日の復習は「遅れている順→箱が低い順」で、件数・単元で絞れる。固定の再出題日（`retryDates`）とは別に使える。
- ケアレスミス判定（`classifyMistakes`）。誤答を「ケアレスの疑い」（その単元で正解するときの中央値の 35% 未満で答えた＝`tooFast`、直後 10 分以内に同じ問題を正解し直した＝`quickRetry`）と「理解不足の疑い」に分ける目安。`buildWeakNotes(..., ignoreCareless: true)` でケアレスの疑いの誤答を弱点に数えない（既定は従来どおり数える）。所要時間が未計測（0）や、基準になる正解が 5 件未満のときは速さでは判定しない。
- 自信度（`Attempt.confident`・`confidenceKindOf`・`summarizeConfidence`）。回答のとき「自信あり／なし」を任意で聞き、正誤と合わせて4つに分ける（自信ありで正解＝定着、自信なしで正解＝まぐれかも、自信ありで誤答＝思い込みの疑い、自信なしで誤答＝分からないと自覚）。単元別に「誤答のうち自信ありだった割合」「正解のうち自信なしだった割合」を出せる。間隔反復では、自信なしの正解は箱を上げず、自信ありで誤答した問題は同じ遅れなら先に出す。弱点ノートに `confidentWrongCount`。模試の `scoreMockExam(confident:)` でも残せる。SQLite は版 2（`confident` 列。旧版の DB は開くと列が足され、既存の回答は残る）。
- 誤解の型の傾向分析（`analyzeMisconceptions`）。誤答した選択肢に付いた誤解の型を単元をまたいで集計し、型ごとに回数・自信ありで誤答した回数・単元別の回数・直近 14 日とその前の 14 日の比較（新しく出た／増えた／同じ／減った／直近は出ていない）・克服済みかを返す。複数の単元に出ている型（`crossUnit`）は、単元をこえた共通のつまずきとして先に並び、さかのぼり診断や学び直しの入口になる。
- さかのぼり診断（`PrerequisiteGraph`・`diagnoseBacktrace`。他アプリの前提は誘導リンクだけ）。

## 計画・目標

- 学習時間の見積もり（`buildPace`・`estimateDayTimes`・`daysOverBudget`・`questionsWithinBudget`）。回答の所要時間（`elapsedMs`）から1問あたりの時間を中央値で求め（単元の記録が 5 件以上ならその単元、足りなければ全体、全体も足りなければ既定の 45 秒。未計測と 5 分超は除く）、`buildPlan` の日ごとの計画から1日の学習時間を見積もる（表示用に5分きざみの切り上げ）。1日に使える分を決めて、超える日を探したり、その分で解ける問題数を出したりできる。
- 目標点からの逆算（`buildGoalPlan`）。「この教科で80点」と決めると、今の習熟度から見込む点（範囲の単元を問題数の重みで平均）との差を出し、習熟度を上限（既定 0.9）まで上げたときの増分が大きい単元から、届くところまで「どの単元をどこまで伸ばすか」を返す（最後の単元は必要な分だけ）。上限まで伸ばしても届かない目標は `unreachable`。記録のない単元は未学習（0）として数える。到達レベルの下限点（`LevelThresholds.minOf`）を目標にもできる。伸ばす単元の ID は `unitIds`。

## 模試・テスト後の振り返り

- 模試モード（`buildMockExam`・`scoreMockExam`）。範囲と問題数・制限時間を決めると、単元の重み（estimatedQuestions）に比例して出題する（同じ seed なら同じ出題）。採点は単元別の成績・未回答（不正解扱い）・時間切れ・アプリ内偏差値（段階1）を返し、回答履歴は `mode: 'mock'` で習熟度・間隔反復・弱点ノートにそのまま使える。正答率の低い単元は `weakUnits()`。
- 模試の履歴比較（`compareMockExams`）。模試の結果（`MockHistoryEntry`）を日付順に並べ、得点・アプリ内偏差値・1問あたりの時間・未回答・時間切れの推移、前回との差、自己ベスト、得点の傾き（1回ごとに平均で何点動くか）を出す。単元別には、直近の回と「前回」「最初の回」での正答率の変化（伸びた順）を返し、最も伸びた単元・最も下がった単元を取り出せる。問題数が少ない単元（既定 2 問未満）は、ぶれが大きいので比べない。
- テスト後の振り返り（`buildPostTestReview`）。実際のテストの問題は問題集に無いので、単元ごとの失点と理由（理解不足／忘れ／ケアレス／時間切れ）を入れる。単元別・理由別の失点、「取り戻しやすい失点」（ケアレス・時間切れ）と「学び直しが要る失点」（理解不足・忘れ）、入力の食い違い（`consistent`）を返す。理解不足・忘れの単元だけ習熟度を下げた `adjustedMastery`（`buildPlan` にそのまま渡せる）と、履歴に残す `mode: 'real_test'` の回答を作る。ツリーを渡すと、存在しない単元・葉でない単元を `issues` で報告して外す。

## 成長の見える化

- 成長機能の計算部（G2レーダー・G3自己ベスト・G4スタンプ・G5できるようになった数・G6進化）。
- 成長カード（`GrowthCardData`・`GrowthCardView`・`renderGrowthCardPng`。名前/ID/メール欄なし、13歳未満はゲート通過後のみ共有）。
- 成長機能 v1.1（G7 成長の年輪 `buildGrowthRings`・`GrowthRingsView`、G8 本番の点数の記録 `compareRealTests`、G9 アプリ内偏差値の表示ポリシー `deviationDisplay`・`formatDeviationRange`）。

## 問題タイプ・地図・年表

- 地図タップ問題の判定（小学コレ！社会の JapanRegionTapMap を参考。境界線データ・教科色はアプリ側。描画は `RegionTapMap`、CustomPainter で flutter_map 非依存）。
- 図タップ（`RegionTapMap` の background＋画像座標 flipY=false）、年表（timeline 判定・`TimelineOrderList`）。

## 保護者・先生役

- 保護者ゲート(漢数字)・週次レポート文面。
- 週次レポートの材料の強化（`WeeklyReport`）。先週の回答数・学習した日数（`previousAttemptCount`・`previousActiveDays`・`attemptDelta`）に加えて、`buildWeeklyReport(..., questions: ...)` で問題集を渡すと、その週に新しく克服できた弱点の数（`newlyOvercome`）と、先週は間違えたが今週は間違えなかった誤解の型（`easedMisconceptions`）も出す。いずれも「できるようになったところ」を伝える材料で、本文（`toText`）はこれまでどおり。新しい項目を本文に出す文言（全言語）と、13歳未満に見せてよい内容・範囲は、法務確認のあとに決める（見せる側のアプリが決める）。
- 先生役モード（まちがいキャラ）の出題・進行（`MistakeLine`・`pickMistakeLines`・`TeacherSession`・`teacherAttempt`）。誤解の型と弱点ノートの克服判定につながる。セリフなどの中身は問題データ（アプリ側）。

- 国ごとの年齢条件（`AgePolicy`・`ChildFeature`・`Access`・`deviationDisplayFor`）。「子ども」の年齢の線（既定は 13 歳未満）と、子どもに対する機能ごとの扱い（そのまま使える／保護者ゲートのあと／出さない）を、地域コードで切り替える。対象の機能は、アプリ内偏差値・成長カードの共有・週次レポート・範囲カードの共有。既定の扱いは、偏差値と範囲カードの共有は出さない、成長カードの共有と週次レポートは保護者ゲートのあと。**国ごとの実際の年齢条件は法務確認のあとに `AgePolicy.forRegion(..., overrides: {...})` で与える（このパッケージは確認前の法的な年齢を決めない。上書きの無い地域は現行の方針）**。年齢は保存せず、確認画面などで一時的に `isChild(age)` を呼び、結果の「子どもか」だけをアプリが持つ。

## 直前・当日・共有

- 直前プリント（`buildLastMinuteSheet`・`renderSheetHtml`。間違い理由別・未克服のみ。A4 印刷用の HTML で、端末のフォントを使うので言語を問わず印刷できる）。
- 当日チェック（持ち物チェックリスト `DayChecklist`・`DayChecklistView`、直前5分カード `buildFiveMinuteCard`）。うかラボとの共通化は app_common_kit 側で別途。
- 範囲カードの QR 共有（`encodeScope`・`decodeScope`・`ScopeQrView`）。

## 未実装

- キャラ収集（キャラ案の確定待ち）、英語アプリとの結合。
