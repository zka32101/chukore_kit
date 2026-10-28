# 機能の詳細

README の実装済み一覧の詳細。各項目の先頭は公開 API の名前。仕様は `chukore_kit_仕様_v0_2.md`。

**目次**: [土台（モデル・計画・判定）](#土台モデル計画判定) / [復習・弱点](#復習弱点) / [計画・目標](#計画目標) / [模試・テスト後の振り返り](#模試テスト後の振り返り) / [成長の見える化](#成長の見える化) / [問題タイプ・地図・年表](#問題タイプ地図年表) / [保護者・先生役](#保護者先生役) / [直前・当日・共有](#直前当日共有) / [出題・今日の画面](#出題今日の画面) / [問題集の品質](#問題集の品質) / [アクセシビリティ](#アクセシビリティ) / [保存・引き継ぎ](#保存引き継ぎ) / [未実装](#未実装)

## 土台（モデル・計画・判定）

- （仕様 §9 の 1・2・4 の一部）モデル、単元ツリー(JSON)、テスト日逆算、習熟度、到達レベル、アプリ内偏差値、弱点ノート(克服判定)。
- 問題タイプ判定（選択・数値・並べ替え）、回答履歴ストア契約＋メモリ実装。
- SQLite 保存: `package:chukore_kit/chukore_kit_sqlite.dart`（sqlite3。コード生成なし）。
- アプリ内偏差値 段階2の計算部（exam_stats 互換の3値集計。送受信はアプリがコールバックで注入）。
- 問題集・単元ツリーの JSON 形式と検証（`parseQuestionBank`・`validateQuestionBank`・`validateUnitList`、`dart run tool/validate_bank.dart`）。形式は `docs/question_bank_format.md`。
- ネイティブ確認の依頼の道具（`reviewPacketCsv`・`numberWordsTsv`・`reviewBoundaryNumbers`・`stringsKeyGroup`・`tool/export_review_packets.dart`）。言語ごとに、確認シート CSV（key・まとまり・日本語・English・この言語・長さ〔日本語に対する文字数の比〕・残すもの〔プレースホルダ〕・直した文言・理由）と、数の読み上げの境目の数 TSV を書き出す。`dart run tool/export_review_packets.dart [出力先] [言語タグ ...]`（既定 `build/native_review`、git の管理外）。依頼書は `docs/native_review_checklist.md`。

## 復習・弱点

- 間隔反復（`buildReviewStates`・`dueForReview`）。問題ごとに、正解で箱が上がり復習間隔が 1→3→7→14→30 日と伸び、不正解で箱 0 に戻って翌日に出す。テスト日を超えない。今日の復習は「遅れている順→箱が低い順」で、件数・単元で絞れる。固定の再出題日（`retryDates`）とは別に使える。
- ケアレスミス判定（`classifyMistakes`）。誤答を「ケアレスの疑い」（その単元で正解するときの中央値の 35% 未満で答えた＝`tooFast`、直後 10 分以内に同じ問題を正解し直した＝`quickRetry`）と「理解不足の疑い」に分ける目安。`buildWeakNotes(..., ignoreCareless: true)` でケアレスの疑いの誤答を弱点に数えない（既定は従来どおり数える）。所要時間が未計測（0）や、基準になる正解が 5 件未満のときは速さでは判定しない。
- 自信度（`Attempt.confident`・`confidenceKindOf`・`summarizeConfidence`）。回答のとき「自信あり／なし」を任意で聞き、正誤と合わせて4つに分ける（自信ありで正解＝定着、自信なしで正解＝まぐれかも、自信ありで誤答＝思い込みの疑い、自信なしで誤答＝分からないと自覚）。単元別に「誤答のうち自信ありだった割合」「正解のうち自信なしだった割合」を出せる。間隔反復では、自信なしの正解は箱を上げず、自信ありで誤答した問題は同じ遅れなら先に出す。弱点ノートに `confidentWrongCount`。模試の `scoreMockExam(confident:)` でも残せる。SQLite は版 2 で `confident` 列を追加（現在は版 3。旧版の DB は開くと列が足され、既存の回答は残る）。
- 誤解の型の傾向分析（`analyzeMisconceptions`）。誤答した選択肢に付いた誤解の型を単元をまたいで集計し、型ごとに回数・自信ありで誤答した回数・単元別の回数・直近 14 日とその前の 14 日の比較（新しく出た／増えた／同じ／減った／直近は出ていない）・克服済みかを返す。複数の単元に出ている型（`crossUnit`）は、単元をこえた共通のつまずきとして先に並び、さかのぼり診断や学び直しの入口になる。
- さかのぼり診断（`PrerequisiteGraph`・`diagnoseBacktrace`。他アプリの前提は誘導リンクだけ）。
- つまずき別の解き直しセット（`buildRetrySets`・`RetrySet`、共有の `prioritizeWeak`・`questionsForWeakEntry`）。弱点ノートの誤解の型ごと（型の無い選択肢の誤答は問題ごと）に、解き直す問題のセットを作る。セットの並びは、自信ありで誤答が多い型（思い込みの疑い）→ 最近間違えた型。中身は、同じ型の**まだ解いていない問題**を先にして（答えを覚えただけで通れないように）、次に間違えた問題（最近順）、最後に解いたことのある問題（古い順）。`perSet` 問まで（既定 5）。ケアレスミスの疑いの誤答は誤解として数えない（`ignoreCareless`）。克服済みは含めない（`includeOvercome` で後ろに付く）。`pickPractice` の弱点枠も、同じ優先順と候補の選び方を使う。
- 間違えた理由の自己申告（`Attempt.reason`・`LossReason`・`summarizeMistakeReasons`、文言 `reasonPrompt` / `reasonLabel`）。間違えたあとに子どもが理由を選べる（わからなかった／忘れていた／うっかり／時間が足りなかった。**答えなくてもよい**ので、聞くかどうかと「スキップ」はアプリ側）。`LossReason` はテスト後の振り返りと共通。申告は **ケアレス判定の推定より優先**する（`classifyMistakes`）: 「うっかり」`selfReported`・「時間が足りなかった」`timeShort` は知識の不足ではない誤答として弱点ノート（`ignoreCareless`）に数えず、「わからなかった」「忘れていた」は、速く答えた・すぐ正解し直したとしても理解不足の側。申告が無い誤答は、これまでどおり推定。`summarizeMistakeReasons` は理由ごとの数・未申告の数・いちばん多い理由・申告のあった分での割合（未申告は分母に入れず、申告の少なさから決めつけない）を返し、単元と期間で絞れる。保存: SQLite は版 3（理由の列。版 2 の DB は開くと列が足される。知らない値は読み飛ばして null）、バックアップは項目 `rs`（無い古いファイルもそのまま読める。知らない理由は拒否）。
- 段階ヒント（`Question.hintIds`・`Attempt.hintsUsed`・`hintCredit`・`summarizeHintUsage`）。問題に、浅いものから順のヒントの ID を持たせる（本文は問題データ側。1 つ目は考え方、2 つ目は途中の式、のように少しずつ答えに近づける）。答える前に見たヒントの数を回答に残し、**自力で解けた正解とヒントを使った正解を区別**する: 習熟度では、ヒントを使った正解は満点でなく 0 個 1.0・1 個 0.7・2 個 0.45・3 個以上 0.25（`defaultHintCredits`、仮決定。誤答は 0 のまま）。間隔反復ではヒントを使った正解は箱を上げず、弱点ノートの克服（連続正解）にも数えない。`summarizeHintUsage` は 正解のうち自力で解けた割合・回答のうちヒントを使った割合・見たヒントの延べ数を、単元・期間・出題の種類で絞って返す（模試ではヒントを出さない）。問題集の検証は `hint_id_empty`・`hint_duplicate`（エラー）、`hint_is_explanation`・`hints_too_many`（警告。3 段までが目安）。ヒントの追加は問題の内容の変更なので、差分更新では version を上げる。保存: SQLite は版 4（`hints_used` 列。版 3 の DB は開くと列が足され、古い行は 0）、バックアップは項目 `hu`（0 のときは付けない。無い古いファイルもそのまま読める。0〜20 以外は拒否）。
- 暗記カード学習（問題タイプ `card`・`CardRating`・`attemptFromCardRating`・`buildCardDeck`・`CardSession`、文言 `cardAgain` / `cardHard` / `cardGood` / `cardFlip` と `cardRatingLabel`）。社会・理科・英語の暗記向けに、表を見て思い出し、めくって裏を見たあと、自分で「わからない／あやしい／わかった」を選ぶ。自己採点は**既存の仕組みにそのまま乗る**: わかった＝正解（自信あり。箱が上がる）、あやしい＝正解だが自信なし（習熟度には正解として数え、間隔反復では箱を上げない）、わからない＝誤答（理由は「わからなかった」。同じセッションですぐ「わかった」と答え直しても、うっかり扱いにならない）。出題の種類は `card`。`buildCardDeck` は今日のカードを返す: 期限が来たカード（遅れている順、最大 30 枚）→ まだ見ていない新しいカード（ID 順、最大 10 枚。期限のカードが 30 枚以上たまっていたら 0 枚。復習が先）。`CardSession` は学習の進み方を管理する: 「わからない」のカードは 3 枚あとにもう一度出し（同じカードは最大 2 回まで繰り返し、それでも思い出せなければ今日は切り上げて間隔反復で明日また出す）、「あやしい」「わかった」はそのセッションで終わり。自己採点のたびに `Attempt` を返し、保存はアプリ側。`checkAnswer` の `card` は `good`・`hard` を正解（点は 1 と 0.5）、`again` を不正解。模試には出さない（自己採点で点数にできない）。問題集の検証は `card_answer_empty`（エラー）、`choices_ignored`・`hints_ignored`（警告）。
- 復習間隔の個別調整（`tuneReviewIntervals`・`ReviewTuning`・`BoxRetention`・`IntervalAction`）。箱 1 以降について、期日の日以降〜期日の `maxLateRatio`（既定 1.5）倍までに復習した練習の回答（ヒント付きは除く）の正答率とその 95% 信頼区間（Wilson）を出し、**区間の上端が 0.8 未満なら間隔を 25% 短く、下端が 0.9 より上なら 25% 長く**する提案を作る（1 回に 1 段だけ。回答が `minAttempts`（既定 30）件に満たない箱は判断しない）。間隔は常に前の箱より長く保つので、判断しない箱が押し上げられることもある。結果は提案で、`config` を設定に渡すか（子どもごとか全体か）はアプリが決める。**端末 1 台では箱ごとの回答が少ない**ので、匿名で集めた束か長期の履歴で使う想定。値は暫定（`docs/softlaunch_validation_plan.md` の復習間隔の項で検証）。Wilson の区間は `wilsonInterval` として公開した。
- 克服の戻りの分析（`analyzeRelapses`・`RelapseReport`・`OvercomeEvent`）。弱点ノートと同じ定義（誤答の型、無ければ問題単位）で履歴を時刻順にたどり、間違えたあとが `isOvercome`（連続 `streak`〔既定 3〕回正解・`minDays`〔既定 2〕日以上）を満たした時点を**克服**、そのあと同じ項目でまた間違えたら**再発**とする。再発した克服の数、克服から再発までの日数（`daysHeld`・中央値 `medianDaysHeld`）、**戻り率**（克服から `minAgeDays`〔既定 14〕日以上たった克服のうち再発した割合。たった今の克服を入れると「まだ再発していないだけ」で低く出るため）を返す。ケアレスミスの疑いの間違いは再発に数えない（`ignoreCareless`）。**克服の基準が甘くないか見直す根拠**（検証計画の「克服後の戻り率」）で、再発が多い・早いなら連続回数や日数を増やす。

## 計画・目標

- 学習時間の見積もり（`buildPace`・`estimateDayTimes`・`daysOverBudget`・`questionsWithinBudget`）。回答の所要時間（`elapsedMs`）から1問あたりの時間を中央値で求め（単元の記録が 5 件以上ならその単元、足りなければ全体、全体も足りなければ既定の 45 秒。未計測と 5 分超は除く）、`buildPlan` の日ごとの計画から1日の学習時間を見積もる（表示用に5分きざみの切り上げ）。1日に使える分を決めて、超える日を探したり、その分で解ける問題数を出したりできる。
- 目標点からの逆算（`buildGoalPlan`）。「この教科で80点」と決めると、今の習熟度から見込む点（範囲の単元を問題数の重みで平均）との差を出し、習熟度を上限（既定 0.9）まで上げたときの増分が大きい単元から、届くところまで「どの単元をどこまで伸ばすか」を返す（最後の単元は必要な分だけ）。上限まで伸ばしても届かない目標は `unreachable`。記録のない単元は未学習（0）として数える。到達レベルの下限点（`LevelThresholds.minOf`）を目標にもできる。伸ばす単元の ID は `unitIds`。
- 複数教科の同時計画（`buildMultiPlan`・`MultiPlanResult`・`MultiDayPlan`）。5 教科などの定期テストが同じ時期に来るとき、1 日に解ける問題数（`dailyQuestions`、既定 30）を、その日まだテストが残っている教科に割り振る。重みは「1 ÷ (テストまでの日数 + 1)」×「残りの学習量（(1 − 習熟度) × 想定問題数 の合計）」で、**テストが近い教科・習熟度が低く範囲が広い教科**ほど多い。どの教科にも予算の `minShare`（既定 10%、教科が多いときは均等割りまで）は残して止めない。忙しい日・お休みは全教科共通（`buildPlan` と同じ上乗せ）。教科ごとの内訳（重点・弱点・復習、重点の単元別、テスト 3 日前からは直前モード）は `buildPlan` と同じ決め方で、`byPlan[テストID]` の `DayPlan` をそのまま `pickPractice` に渡せる。テストが終わった翌日からはその教科に割り当てず、残りの教科に回る。過ぎたテストは `skippedPlanIds`、範囲が広すぎる教科は `overCapacityPlanIds` と `priorityUnitIds`。1 教科だけなら（`dailyQuestions` = `baseQuantity` で）`buildPlan` と同じ結果になる。
- 不具合の修正: `buildPlan` の 1 日の内訳（重点・弱点・復習）が、合計が奇数の直前モードで合計を超えることがあった（合計 5 で重点 3 + 弱点 3）。共通の `splitDay` で、合計に必ず一致するようにした（弱点を削る）。
- 学習の「山場」の予告（`findPeakAhead`・`PeakPreview`・文言 `ChukoreStrings.peakAhead`）。計画（`DayPlan` の並び）から、今日の後 `lookahead`（既定 3）日以内にある最初の山場を返す。山場 = 問題数が、ふだん（問題のある日・追い込み以外の中央値）の `ratio`（既定 1.5）倍以上で、かつ `minExtra`（既定 5）問以上多い日。今日そのものと、追い込み（`lastMinute`）の日は予告しない。文言は数字を含まない責めない一文（18言語。ネイティブ確認は未実施）。近づいたときに 1 度だけ出すなどの出し方は呼び出し側（不安をあおらないため）。
- 学習量の自動調整（`suggestCapacity`・`CapacitySuggestion`・`CapacityAction`）。直近 `windowDays`（既定 28）日に学習した日（練習の回答がある日）の 1 日の回答数の**中央値**を「ふだんの量」とし、今の 1 日の量（`PlannerConfig.baseQuantity`）と比べる。差が今の量の 10%（1 以上）以内なら変えず、外なら**1 回に今の量の 20%（1 以上）まで**だけ動かし、`minBase`〜`maxBase`（既定 5〜40）に収める。おやすみの日は数えない。学習した日が `minActiveDays`（既定 5）日に満たなければ判断しない。**「計画より少ない＝足りない」ではなく「計画が重い」と捉えて量を下げる**（責めない設計）。`applyTo` で 1 日の量だけを替えた `PlannerConfig` を作れる。反映するかはアプリが決める。値は暫定（`docs/softlaunch_validation_plan.md` で検証）。

## 模試・テスト後の振り返り

- 模試モード（`buildMockExam`・`scoreMockExam`）。範囲と問題数・制限時間を決めると、単元の重み（estimatedQuestions）に比例して出題する（同じ seed なら同じ出題）。採点は単元別の成績・未回答（不正解扱い）・時間切れ・アプリ内偏差値（段階1）を返し、回答履歴は `mode: 'mock'` で習熟度・間隔反復・弱点ノートにそのまま使える。正答率の低い単元は `weakUnits()`。
- 模試の履歴比較（`compareMockExams`）。模試の結果（`MockHistoryEntry`）を日付順に並べ、得点・アプリ内偏差値・1問あたりの時間・未回答・時間切れの推移、前回との差、自己ベスト、得点の傾き（1回ごとに平均で何点動くか）を出す。単元別には、直近の回と「前回」「最初の回」での正答率の変化（伸びた順）を返し、最も伸びた単元・最も下がった単元を取り出せる。問題数が少ない単元（既定 2 問未満）は、ぶれが大きいので比べない。
- テスト後の振り返り（`buildPostTestReview`）。実際のテストの問題は問題集に無いので、単元ごとの失点と理由（理解不足／忘れ／ケアレス／時間切れ）を入れる。単元別・理由別の失点、「取り戻しやすい失点」（ケアレス・時間切れ）と「学び直しが要る失点」（理解不足・忘れ）、入力の食い違い（`consistent`）を返す。理解不足・忘れの単元だけ習熟度を下げた `adjustedMastery`（`buildPlan` にそのまま渡せる）と、履歴に残す `mode: 'real_test'` の回答を作る。ツリーを渡すと、存在しない単元・葉でない単元を `issues` で報告して外す。
- 模試からの「次の一手」（`planNextSteps`・`NextStep`）。模試の結果（`MockExamResult`）で正答率が `below`（既定 0.6）未満の単元を、低い順に最大 `maxUnits`（既定 3）件取り上げ、各単元で前提をさかのぼる診断（`diagnoseBacktrace`）を行って、**つまずきの出発点 → その単元** の順に取り組むよう示す（前提が固まっていればその単元だけ）。取り組む単元の問題から解き直しセット（`buildRetrySets`）も作る。前提の先が他アプリの単元なら誘導先（`ExternalRef`）を引き継ぐ。落とした単元が無ければ空で、「来週の優先順位」を決める材料になる。
- つまずきの「根っこ」ランキング（`rankRootCauses`・`RootCause`）。習熟度が `weakBelow`（既定 0.6）未満の単元ごとに前提をさかのぼり（`diagnoseBacktrace`）、**同じ土台に行き着く弱い単元をまとめて**、多くの弱点を説明する土台の順（同数は習熟度の低い順〔記録なしが先〕→ 単元ID順）に並べる。「この数単元を固めれば弱点の多くがほどける」を示す。前提がすべて固まっている弱い単元は、自分自身が土台。記録の無い単元は `includeUnknown` が真のときだけ弱い単元に数える（前提の側の「記録なし」は、`diagnoseBacktrace` と同じく原因の候補になる）。`unitIds` で範囲（テスト範囲の葉など）を絞れ、前提の先が他アプリなら誘導先（`ExternalRef`）も付く。模試 1 回分の `planNextSteps` の全体版。
- 模試の時間配分の分析（`analyzeMockTiming`・`MockTiming`・`TimingPattern`・`SlowQuestion`・`UnitTime`・`MockTimingConfig`）。`scoreMockExam` の `perQuestionMs`（回答の `elapsedMs`）から、1 問あたりの目安時間（制限時間 ÷ 問題数。制限時間が無ければ所要時間の中央値）の `slowFactor`（既定 2.0）倍を**超えた**問題を、かかった時間の長い順に出す。そのうち間違えたものを「飛ばして戻る」練習の候補（`skipCandidates`）、単元ごとの 1 問あたりの時間と正答率（`units`）、余った時間（`spareMs`）、かけすぎた問題が全体に占めた割合（`slowShare`）も返す。全体の傾向は 時間切れ・未回答（`ranOutOfTime`）> 制限時間の 20% 以上を残した（`spareTime`、見直しに回せる）> 時間をかけて間違えた問題がある（`slowOnFew`）> `balanced`。所要時間の記録が `minTimed`（既定 5）件に満たなければ `unknown`（時間切れだけは分かる）。**責めない**: 時間配分の練習と見直しの材料にする。値は暫定。
- 次にやる単元の提案（`suggestNextUnits`・`NextUnit`・`NextUnitStatus`）。前提グラフと習熟度から、**前提がすべて固まっていて、いま取り組める単元**を取り組む順に返す。前提が `readyAt`（既定 0.6）以上で、自分が `doneAt`（既定 0.8）未満（仕上がり前）のものが対象。学習の記録が無い前提は固まっていない扱い（`readyAt` を 0 にしても）。前提を持たない単元と、前提グラフに無い単元はいつでも取り組める。他アプリの前提は止めない。並びは、続きから（記録あり）が先で習熟度の低い順 → 新しく始めるものは、その単元を前提にしている単元の数（`unlocks`）が多い順 → 単元ID順。`unitIds` で範囲を絞れ（範囲外の前提の習熟度も見る）、`maxUnits`（既定 3）で件数を絞る。`rankRootCauses`（弱い土台に戻る提案）と対で使う。

## 成長の見える化

- 成長機能の計算部（G2レーダー・G3自己ベスト・G4スタンプ・G5できるようになった数・G6進化）。
- 成長カード（`GrowthCardData`・`GrowthCardView`・`renderGrowthCardPng`。名前/ID/メール欄なし、13歳未満はゲート通過後のみ共有）。
- 成長機能 v1.1（G7 成長の年輪 `buildGrowthRings`・`GrowthRingsView`、G8 本番の点数の記録 `compareRealTests`、G9 アプリ内偏差値の表示ポリシー `deviationDisplay`・`formatDeviationRange`）。
- 本番の点の変化 `buildOutcomeSummary`・`OutcomeSummary`・`OutcomeChange`（設計は [`score_outcome_measurement.md`](score_outcome_measurement.md)）。本人が入力した本番の点（`RealTestRecord` は満点 `maxScore` と種類 `RealTestKind` を持ち、満点が違うテストは比 `ratio` で比べる）の変化を端末内で求める。前回との差が**ノイズ幅（既定 3 点）以内なら「ほぼ同じ」**で、超えたときだけ上がった／下がった。前回が無ければ使う前の点 `baseline` と比べ、それも無ければ最初の記録。種類（定期／模試）をまたがず、点が範囲外の記録は数えない（`skipped`）。テスト前 28 日間の学習日数・問題数（`StudyDay` の学習日）を添える。**本人にだけ見せるもので、基盤は集めない・送らない**。`compareRealTests` も満点が違う記録を 100 点換算で比べる（満点 100 なら従来どおり）。
- 本番の点まわりのしきい値の設定束 `KitTuning`（版つき）。変化のノイズ幅・大きい変化・使った量の区分と期間・点を聞く期間・集計の最小件数を1つにまとめ、`outcomeSummary` / `outcomeReports` / `tally` / `rates` / `scorePrompt` が同じ値で各関数を呼ぶ。JSON から読み（書き間違い・範囲外・矛盾は `FormatException`）、既定は `docs/kit_tuning/default.json`。**値を変えたら `version` を上げる**: 報告 `OutcomeReport.tuning` と `score_entered` イベントに版が入り、`tallyOutcomes` は版が違う報告を混ぜない。
- 匿名イベントの名前と許可項目（`FunnelEventName`・`FunnelEvent`・`funnelEventKeys`・`validateFunnelProps`・`funnelEventLabel`）と、点の入力率・振り返りの到達率 `funnelRates`（設計は [`score_outcome_measurement.md`](score_outcome_measurement.md) §8.5）。項目は許可リストだけで、点・日付・名前などは持てない（作ろうとすると `ArgumentError`。`subject` は英小文字、`region` は大文字2文字、`grade` は 1〜3）。`FunnelEvent.scoreEntered(OutcomeReport)` で点を持たない区分だけから作る。`funnelRates` の件数はイベントの数で人数ではなく、分母が 30 未満の割合は返さない。**送信の仕組みは無く、法務確認と保護者の同意が済むまでアプリは使わない。**
- 分で選ぶ今日の出題 `pickPracticeForMinutes`・`TimedPracticeSet`（「今日は 5 分」のように、量でなく時間で選ばせる）。計画どおりの出題が予算に収まれば `pickPractice` と同じ結果（**足りない分を埋めて増やさない**）。収まらなければ、復習・弱点・単元ごとの重点の比率を保って数を減らし（最大剰余法）、それでも見積もり（`PaceModel`＝本人の履歴の中央値）が超えるなら後ろ（補充・弱点）から外す。1 問も出ないことはなく、1 問でも予算を超えるときは 1 問を出して `fits` が偽。
- 点を聞くタイミングと入力の読み取り（`decideScorePrompt`・`ScorePromptState`・`ScorePrompt`、`parseScoreInput`・`ScoreInput`・`ScoreInputError`）。**聞くのは、テスト日の翌日から 14 日以内に 1 回だけ**（当日は聞かない。前後 3 日以内に記録があれば聞かない。聞いたら、入れても入れなくても同じテストは二度と聞かない。1 日に 1 回まで）。使う前の点は、記録も使う前の点も無く一度も聞いていないときだけ聞く（テスト後の質問が先）。入力は全角・各地の数字・桁区切りを読み、小数点がカンマの国に対応、`NaN`・指数表記・マイナス・満点超過は理由つきで拒否。聞いた履歴 `ScorePromptState` は不変で、保存はアプリ側。`normalizeNumberInput`（数値入力の正規化）を公開。
- 本番の点の入力と変化の文言（`outcomeAsk`・`outcomeSkip`・`outcomeBaselineAsk`・`outcomeFirst`/`Up`/`Same`/`Down`・`outcomeDisclaimer`、`outcomeMessage`）。入力は任意で、入れなくてよいと伝える。下がったときも責めず一緒に見る。上がったときも結果を保証しない（免責 `outcomeDisclaimer` を添える）。18言語、**ネイティブ確認は未実施**。
- 匿名の報告 `OutcomeReport`・`buildOutcomeReports`・集計 `tallyOutcomes`（設計は [`score_outcome_measurement.md`](score_outcome_measurement.md) §5・§6）。本番の点の変化を、**点・満点・日付を持たない粗い区分**（変化 5 段階 `OutcomeBand`・使った量 3 段階 `UsageBand`・教科・国・学年・種類・使う前の点の有無）に変換する。`toJson` のキーは 7 つに固定（点などを足したらテストが落ちる）。`tallyOutcomes` は**1 マスが 30 件に満たなければ返さず**、上がった割合（up＋bigUp）と 95% 信頼区間を求める。**送信の仕組みは無い。法務確認と保護者の同意が済むまで、アプリは使わない。**

- 成長の年輪の読み上げ（`GrowthRingsView.semanticsLabel`・`ChukoreStrings.ringsLatestMonth`）。合計の学習日数に加えて、最新の月の学習日数（月は `2026-10` の形）も伝える。休んだ月（0 日）もそのまま伝える。図の太さが見えない人にも、最近の学習の様子が分かるようにするため。全 12 言語・17 列。

## 問題タイプ・地図・年表

- 地図タップ問題の判定（小学コレ！社会の JapanRegionTapMap を参考。境界線データ・教科色はアプリ側。描画は `RegionTapMap`、CustomPainter で flutter_map 非依存）。
- 図タップ（`RegionTapMap` の background＋画像座標 flipY=false）、年表（timeline 判定・`TimelineOrderList`）。
- 記述問題の判定（`text`・`multi`、`normalizeText`、`AnswerResult.score`）。短い記述は別解を `|` で並べ、表記ゆれ（全角・大文字・空白・文末の句読点・かなの種類）を吸収して比べる。複数の語を答える問題は順不同で、合った項目の割合を部分点（`score`）として返す。余分な項目は減点、重ね書きは無視。カタカナ指定の問題は `foldKana: false`。形式と検証コードは `docs/question_bank_format.md`。

## 保護者・先生役

- 保護者ゲート(漢数字)・週次レポート文面。
- 週次レポートの材料の強化（`WeeklyReport`）。先週の回答数・学習した日数（`previousAttemptCount`・`previousActiveDays`・`attemptDelta`）に加えて、`buildWeeklyReport(..., questions: ...)` で問題集を渡すと、その週に新しく克服できた弱点の数（`newlyOvercome`）と、先週は間違えたが今週は間違えなかった誤解の型（`easedMisconceptions`）も出す。いずれも「できるようになったところ」を伝える材料で、本文（`toText`）はこれまでどおり。新しい項目を本文に出す文言（全言語）と、13歳未満に見せてよい内容・範囲は、法務確認のあとに決める（見せる側のアプリが決める）。
- 先生役モード（まちがいキャラ）の出題・進行（`MistakeLine`・`pickMistakeLines`・`TeacherSession`・`teacherAttempt`）。誤解の型と弱点ノートの克服判定につながる。セリフなどの中身は問題データ（アプリ側）。

- 国ごとの年齢条件（`AgePolicy`・`ChildFeature`・`Access`・`deviationDisplayFor`）。「子ども」の年齢の線（既定は 13 歳未満）と、子どもに対する機能ごとの扱い（そのまま使える／保護者ゲートのあと／出さない）を、地域コードで切り替える。対象の機能は、アプリ内偏差値・成長カードの共有・週次レポート・範囲カードの共有。既定の扱いは、偏差値と範囲カードの共有は出さない、成長カードの共有と週次レポートは保護者ゲートのあと。**国ごとの実際の年齢条件は法務確認のあとに `AgePolicy.forRegion(..., overrides: {...})` で与える（このパッケージは確認前の法的な年齢を決めない。上書きの無い地域は現行の方針）**。法務確認の結果は JSON で渡せる（`AgePolicyTable.parse(json)` → `table.forRegion('KR')`。形は `default` と `regions`、各地域に `childUnder` と `access`。`access` を書いたら書かれていない機能は出さない。機能名・扱い・地域コードの書き間違い、年齢の範囲外は `FormatException`で、誤字で制限がゆるくならない）。年齢は保存せず、確認画面などで一時的に `isChild(age)` を呼び、結果の「子どもか」だけをアプリが持つ。
- 子ども本人向けの週のふりかえり（`buildMyWeek`・`MyWeek`・`MyWeekKind`、文言 `myWeekGrew` / `myWeekOvercame` / `myWeekKept` / `myWeekStarted` / `myWeekRest`）。保護者向けの `WeeklyReport` と同じ材料から、**できたことだけ**を前に出す。見出しの種類は 伸びた単元がある（grew）> 新しく克服したつまずきがある（overcame）> 週 3 日以上続けた（kept）> 1〜2 日（started）> 学習なし（rest）の優先。rest は見出しだけで、日数・問題数などの数字は出さず、責めずにいつでも始められると伝える。先週より少なかったことは伝えない（`moreThanLastWeek` が偽になるだけ。多いときだけ UI で褒められる）。減った誤解の型は子ども向けには使わない。文面は 見出し → 日数と問題数（`reportHeader`）→ 克服した数（`statStamps`）→ 伸びた単元の名前（最大 3、パーセントは出さない）。見出しは数字を含まない短い文で全言語に用意。自分の記録を自分で見るだけで共有・送信しない。見せてよいかは `ChildFeature.selfReview`（既定は子どもでも使える。JSON の `access` を書くときは `selfReview` も書かないと出さない）。
- 保護者への声かけの提案（`suggestGuardianTalk`・`GuardianTalk`・文言 `talkGrew` / `talkOvercame` / `talkSteady` / `talkStarted` / `talkRest`）。週のレポートから、**結果よりも取り組みをほめる**一言を選ぶ。種類の優先は子ども本人向けのふりかえり（`buildMyWeek`）と同じ（伸びた > 克服 > 継続 > はじめの一歩 > おやすみ）。他の子や先週と比べない・責めない・点数や順位に触れない・数字を含まない（先週より少なくても文面は変わらない。テストで固定）。見せてよいかは `AgePolicy`（`ChildFeature.weeklyReport`）で決める。**18言語の文言のネイティブ確認は未実施**（`docs/translation_review.csv` に追加済み）。

## 直前・当日・共有

- 直前プリント（`buildLastMinuteSheet`・`renderSheetHtml`。間違い理由別・未克服のみ。A4 印刷用の HTML で、端末のフォントを使うので言語を問わず印刷できる）。
- 当日チェック（持ち物チェックリスト `DayChecklist`・`DayChecklistView`、直前5分カード `buildFiveMinuteCard`）。うかラボとの共通化は app_common_kit 側で別途。
- 範囲カードの QR 共有（`encodeScope`・`decodeScope`・`ScopeQrView`）。

## 出題・今日の画面

- 学習を促す通知の判定（`decideNudge`・`NudgeSettings`・`nudgeText`、文言 `nudgeTestSoon` / `nudgeReview` / `nudgeStreak`）。今日通知を出すか、何を出すか（出さないなら null、1 日 1 件まで）を決める。優先は テスト 7 日以内 > 復習 3 問以上 > 連続 3 日以上（昨日学習して今日まだのとき）。今日すでに学習した・忙しい日／お休み・テスト当日・前回の通知から 2 日未満（テスト 3 日前からは毎日）・2 週間以上離れている（テストが近い場合を除く）・一度も学習していない（テストが近い場合を除く）は出さない。連続記録がすでに途切れていたら連続の通知は出さず、責める言い方もしない。文言は数字を含まない短い文で、日数・件数は返り値（`daysToTest` など）を使って呼び出し側が添える。通知を出す時刻・OS の許可・13歳未満への通知の可否はアプリ側（法務確認のあと）。値は仮決定。
- 適応的な出題選び（`pickPractice`・`PracticeSet`・`PickerConfig`）。今日の計画（`DayPlan`）から、実際に出す問題を選ぶ。順は 復習 → 重点（単元ごとにやさしい順）→ 弱点 → 補充。
  - 重点枠: 習熟度が高いほど基準正答率の低い（難しい）問題を当てる（習熟度 0 で 0.85、1 で 0.5 に近い問題。仮決定）。同じ近さなら、最近正解していない・長く解いていない（未出題が先）問題。3 日以内に正解した問題は、他に選べるうちは出さない。
  - 復習枠: 期限が来た問題（遅れている順・自信ありで誤答が先）。弱点枠: 未克服の弱点（自信ありの誤答が多い・最近間違えた順）を、1 項目ずつ回して選ぶ。同じ問題を 2 つの枠で出さない。
  - 足りない枠は、習熟度の低い単元から順に補充（`extra`）。それでも足りなければ `shortfall` に残る。`scopeUnitIds` で範囲を絞れる。
  - 同じ入力なら同じ結果（乱数・現在時刻に依存しない）。`seed` は同じ近さの問題の中の選び方だけを変える。
- 通知を出す時間帯の提案（`suggestNudgeHour`・`NudgeHour`・`defaultNudgeHour`）。回答履歴から、その子がいつも学習する時間帯を求める（端末内だけで計算）。直近 28 日の学習日を数え、1 日に何問解いても 1 日として数える（問題数の多い日に偏らない）。前後 1 時間のゆれはならす。学習日が 5 日未満、またはどの時間帯にも偏りが無い（前後 1 時間に入る日の割合が 4 割未満）ときは null で、アプリは `defaultNudgeHour`（18 時）などを使う。提案は 7〜20 時に寄せる（夜遅く・早朝に通知しない。寄せたときは `clamped`）。`forDate` を渡すと平日／土日それぞれの習慣で求める（同じ種類の学習日が足りなければ全体）。`decideNudge` の「出すか」と組み合わせて「いつ出すか」を決める。値は仮決定。
- 疲れと休憩の提案（`suggestBreak`・`BreakSuggestion`・`BreakReason`・`BreakConfig`、文言 `breakLong` / `breakMistakes` / `breakSlowing` / `breakRushing`）。回答履歴から、いまの学習（回答の間が 30 分未満でつながる最後の区間）だけを見て、休憩を**勧める**（止めたり進めなくしたりしない。その扱いは画面側）。理由は優先順に、あてずっぽう（直近 5 問がすべて 2 秒未満の誤答。ゆっくり読み直すよう促す）→ 続けて間違えた（直近 4 問すべて誤答）→ 途中から遅くなった（直近 5 問の所要時間の中央値が最初の 5 問の 2 倍以上。10 問以上のとき）→ 長く続けている（休まず 40 分以上）。最後の回答から 30 分以上たっていれば（すでに休んでいる）勧めない。前に提案した時刻 `lastSuggestedAt` から 15 分以内は繰り返さない。模試・本番の記録は見ない（既定は練習のみ、`modes` で変えられる）。文言は責めない短い文で数字を含まず、全言語に用意。値は仮決定（ソフトローンチで検証）。
- 混ぜ練習（`interleaveByUnit`）。`pickPractice` の結果を、同じ単元が続かないように並べ直す。同じ型が続くと答えを覚えて通れてしまうため。先頭の復習枠（短い想起）はそのまま先頭に置き、残りは単元の最初に出てくる順で 1 問ずつ回す（単元の中の順＝やさしい順は変えない）。1 単元だけが残ったときは続けて出す。問題の集まり・枠・`shortfall` は変えない。使うかどうか（常に混ぜるか、重点の単元は続けるか）はアプリ側が決める。なお回答のバックアップの取り込み（`AttemptBackup.importInto`）は、同じ回答を二重に足さない仕様で既に実装済み。
- 前日・当日の「やらないこと」ガード（`guardLastDays`・`GuardedPractice`・`EveGuardConfig`・`EveNotice`・文言 `eveNotice` / `testDayNotice`）。テストまで 1 日（前日）と 0 日（当日）に限り、`pickPractice` の結果から**まだ一度も解いていない問題を外し**（別モードの回答でも「解いた」とみなす）、上限（前日 15 問・当日 8 問）を超える分は後ろ（弱点・補充）から減らす。復習は先頭なので残る。出せる問題が無くなったら**空のまま**返す（休むのも準備のうち。穴埋めしない）。`shortfall` は変えず、外した数・減らした数は別々に返す。それ以外の日は元の結果をそのまま返す。不安からの詰め込みを抑える方針。落ち着く一言は数字を含まない短い文で、18言語（ネイティブ確認は未実施）。値は暫定。
- 「今日」の画面の窓口（`buildTodayCard`・`TodayCard`・`TodayHeadline`）。休憩の提案（`suggestBreak`）・前日/当日（`eveNoticeOf`）・山場の予告（`findPeakAhead`）・復習の期限の数（`buildReviewStates` / `dueForReview`）・今日学習したか（暗記カードだけの日は数えない）を 1 回で求め、**見出し**を 1 つ選ぶ。優先は 休憩（`breakNow`）> テスト当日 > 前日 > 山場の予告 > 今日はここまで（`done`）> 復習の期限（`reviewDue`）> はじめよう（`start`）。`message(strings)` で見出しに添える一言（責めない短い文・数字を含まない）を返す（`done` と `start` は画面側の文言なので null）。今日の分が計画に無ければテスト日との差で前日/当日を求める。`guardsPractice` が真なら出題に `guardLastDays` をかける。通知の判断（`decideNudge`）は端末の外へ出す通知なので、この画面の窓口には含めない。

## 問題集の品質

- 問題集の差分更新（`BankDiff.between` / `check` / `apply` / `toJsonString` / `BankDiff.parse`、`tool/diff_bank.dart`）。月次などの差分配信用。内容を変えたのに version を上げ忘れた問題をエラーにし、差分は順番にしか当たらない（元と違う問題集には StateError で、途中まで当たらない）。配信はアプリ側。詳細は `docs/question_bank_format.md`。
- 問題の実測難易度と、基準値のずれの検出（`calibrateDifficulty`・`CalibrationReport`・`DifficultyDrift`・`recalibrate`）。問題の基準正答率（`difficulty`）は作った人の見積もりなので、回答履歴から実測の正答率を出し、**偶然とは言いにくいほど大きくずれた問題**を見つける。ずれ = 実測の 95% 信頼区間（Wilson）に基準値が入らず、しかも差が `minGap`（既定 0.15）以上。回答が `minAttempts`（既定 20）件に満たない問題は判定しない。数えるのは練習の回答だけ（模試は時間制限で正答率が下がるので別。`mode` で変えられる）で、ヒントを使った回答（正解が増えて易しい側にかたよる）と暗記カードは数えない。単元ごとの偏り（「実測 − 基準」の平均）も返す。提案値は実測を 0.05 刻みに丸めて 0.05〜0.95 に収めた値（0 と 1 は偏差値の換算で分散が 0 になるため避ける）で、`recalibrate` が問題集に反映する（**version を 1 上げる**ので、`BankDiff` の検査を通り、差分配信できる）。**端末 1 台の履歴では 1 問あたりの回答が少ない**ので、アプリが個人を特定しない形で集めた回答の束を渡す想定（基盤は集めない・送らない）。
- 誤答の選択肢の分析（`analyzeDistractors`・`QuestionDistractors`・`DistractorFlag`・`untaggedCandidatesByUnit`）。選択式（`choice`・`map`）の問題で、選択肢ごとの選ばれ方から3つの気になる点を見つける。**popularUntagged**: 型（`misconceptionTags`）の無い誤答が誤答の 25% 以上かつ 5 回以上選ばれている＝新しい誤解の型の候補（先生役のセリフの材料）。**neverChosen**: 1 回も選ばれない誤答＝差し替え候補。**beatsAnswer**: 誤答が正解より多く選ばれている＝問題文や正解の誤り・曖昧さの疑い。回答が `minAttempts`（既定 30）件に満たない問題は調べない。数えるのは練習の回答だけで、ヒントを使った回答や選択肢IDの無い回答は数えない。並びは旗の数 → 回答数 → 問題ID。`untaggedCandidatesByUnit` で単元ごとに型の候補をまとめる。`calibrateDifficulty` と同じく、アプリが個人を特定しない形で集めた回答の束を渡す想定（基盤は集めない・送らない）。
- 誤解の型の下書き（`suggestTagDrafts`・`TagDraft`・`applyTagDrafts`）。`analyzeDistractors` の「型の無い人気の誤答」から、型を付ける候補（問題・選択肢・仮の型名・選ばれた回数と割合）を多い順に作る。仮の型名は `t_<単元>_<問題>_<選択肢>`（小文字・数字・`_`）なので、**採用前に意味の分かる名前へ変え、先生役のセリフを付ける**。`applyTagDrafts` は採用した型を問題集に反映し、**version を 1 上げる**（正解の選択肢・存在しない選択肢・すでに型がある選択肢には付けない）。回答を集める仕様の案は `docs/anonymous_data_collection.md`（法務確認前は実装しない）。
- 問題集の品質レポート（`buildQualityReport`・`QualityReport`・`tool/quality_report.dart`）。匿名で集めた回答の束から、難易度のずれ（`calibrateDifficulty`）・誤答の選択肢の旗（`analyzeDistractors`）・誤解の型の候補（`suggestTagDrafts`）・復習間隔の提案（`tuneReviewIntervals`）を 1 つにまとめ、`toMarkdown({maxRows})` で Markdown にする（各表は上位 `maxRows` 行まで、残りは「ほか N 件」。変わらない箱は載せない）。**開発者が問題集を直すための材料**で、子どもや保護者には出さない。コマンド: `dart run tool/quality_report.dart <questions.json> <backup.json> [<backup2.json> ...] [--out report.md]`（`<backup.json>` は `AttemptBackup.export` の形式。複数ファイルは合わせて数える。読めないファイルは終了コード 66、壊れた JSON は 65）。各分析の閾値は各関数の既定値で、回答が足りなければ何も出ない（「実測できた問題」の数を見る）。回答を集める仕様は `docs/anonymous_data_collection.md`（法務確認前は実装しない）。

## アクセシビリティ

- アクセシビリティの追加。**コントラスト比**（`contrastRatio`・`relativeLuminance`・`meetsTextContrast`〔通常 4.5／大きな文字 3〕・`meetsGraphicContrast`〔3〕）で、アプリの配色を機械的に確かめられる。既定の教科色（`0xFF3B82F6`）は白地で約 3.68 なので、リング・図形には使えるが**小さな文字の色には使わない**（テストで固定）。**読みやすい長さに分ける**（`splitForReading`）: 解説・問題文を文末（。！？!?. と改行）で区切り、`maxChars`（既定 60）字までにまとめる。長い 1 文は読点、無ければ文字数で切り、小数点・閉じかっこ・絵文字は壊さない。1 画面に出す量を減らす、読み上げを区切る、1 文ずつ見せるための材料。**文字拡大 200%** で当日チェックが全言語でオーバーフローしないことをテストで確認している。**未実施**: 色覚多様性（P型・D型）のシミュレーションでの配色確認、実機の文字拡大での全画面の確認（色だけに頼らない表示は、正誤の ✓/✗・チェックボックスの形で対応済み）。
- 色覚シミュレーションと配色の検査（`ColorVision`・`simulateColorVision`・`colorDifference`・`confusablePairs`）。P型・D型・T型での見え方の近似（Machado 2009）と、見た目の違い（ΔE）で、配色のうち区別しにくい組を見つける。画面の正解（緑）・不正解（赤）はD型・P型で近く見えるため、✓/✗ の形と読み上げを必ず付ける（テストで固定）。**未実施**: 実機・当事者の確認。詳細は `docs/accessibility_colors.md`。暫定値をソフトローンチで確定する計画は `docs/softlaunch_validation_plan.md`。

## 保存・引き継ぎ

- 学習データの書き出しと取り込み（`AttemptBackup.export(attempts)` / `AttemptBackup.importInto(store, json)`）。機種変更やアプリの入れ直しの引き継ぎ用で、通信しない。入るのは回答履歴だけ（問題ID・単元ID・正誤・選んだ選択肢・時刻（UTC）・所要時間・モード・自信度）で、名前・ID・メール・生年月日は入らない。テスト日の予定・範囲はアプリが持つので含めない。取り込みは store に無い回答だけを足すので、同じファイルを何度入れても二重にならない（同じ問題・時刻・答え・モードは同一とみなす）。件数とチェック値を持ち、途中で切れた・書き換わったファイル、新しい版のファイル、1 件でも不正な行があるファイルは `FormatException` で、一部だけ戻る状態を作らない。ファイルの保存・共有はアプリ側。
- 回答履歴の全削除（`AttemptStore.deleteAll()`）と言語名（`ChukoreStrings.languageName`）。`deleteAll` はデータ削除の流れ（`app_common_kit` の `DataEraser`）から呼ぶ想定で、SQLite は `VACUUM` まで行う（端末の外に書き出した `AttemptBackup` は消せない）。`languageName` は設定画面の言語リスト用（例: `日本語`・`Deutsch (Schweiz)`）で、全言語・全地域つきに名前がある（テストで固定）。

## 未実装

- キャラ収集（キャラ案の確定待ち）、英語アプリとの結合。
