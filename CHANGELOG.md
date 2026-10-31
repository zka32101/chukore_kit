# 変更履歴

版の付け方: `0.x` の間は、機能の追加で副版（0.**N**.0）、修正だけなら補修版（0.N.**P**）を上げる。**公開 API を壊す変更は副版を上げ、下の「移行時の注意」に書く。** 各アプリは `ref: vX.Y.Z` のタグで固定して参照する（手順は [`docs/release.md`](docs/release.md)）。

## [未リリース]

- 円周率 π: 式に `π`/`pi`、形 `in_terms_of_pi`（π で答える。小数の近似は不可）、型の書式 `{$e}`（係数に π を付けて出す）。数学（中1）の型に円・おうぎ形・円柱・円錐・球の 9 型を追加（計 40 型）

- 変種生成にデータの活用を追加: 数列のパラメータ（英大文字 1 字、`Variant.lists`）、集計 `stats`（sum・mean・median・mode・range・min・max・count）、数列の差し込み `{L}`・`{~L}`。数学（中1）の型にデータの 6 型（平均・中央値・最頻値・範囲・度数・相対度数）を追加（計 31 型）

- docs: 図・グラフ・データの扱いの設計（`docs/math_figures_design.md`。図の仕様 `FigureSpec`、core が SVG を作る案、データの数列パラメータと集計関数、円周率 π の扱い。未実装）

- 体験型の教材 `Exploration`・`ExplorationSet`・`ExplorationParam`・`validateExplorations`（`slider_graph`: 式のパラメータを動かすグラフ教材。グラフの点 `sample`、予想の答え合わせ、目標の達成判定 `goalReached`、目標に届くかの検証）と `MathExpr.bind`。見本 `docs/samples/explorations.sample.json`

- docs/test: 数学の部品のパッケージ境界の方針（分けない・分ける条件）と、境界テスト `test/package_boundaries_test.dart`（`lib/src/math` が Flutter・他の core に依存しないこと）

- docs: 数学（中1）の問題の型 25 個（`docs/content_drafts/suugaku_chu1/templates.json`: 正負の数・同類項・かっこ・式の値・数量の関係・等式の性質・一次方程式・座標・比例・反比例）。全変種の判定をテストで確認

- docs: ちゅうコレ！数学（中1）の単元ツリー・前提の草案（`docs/content_drafts/suugaku_chu1/`: 7分野・21単元、誤解の型の候補）。検証テスト付き

- 数学の問題の型 `MathTemplate`・`TemplateSet`・`Variant`・`parseVariantId`・`validateTemplates` と `tool/expand_templates.dart`。係数を種で変えた変種を作り、答えと誤答（誤解の型つき）を式から計算する。検証 `template_unsatisfiable`・`template_expression_invalid`・`template_answer_dup`。見本 `docs/samples/templates.sample.json`

- 変種生成の部品: `SeededRandom`（xorshift32。端末・Web で同じ列）、`renderTemplateString`（`{e}`・`{+e}`・`{&e}` の差し込み）・`evalConstraint`・`formatExact`（整数・既約分数）。`expr` の誤答の誤解の型（`misconceptionTags` のキーに誤答の式を書く。検証 `tag_expr_invalid`・`tag_expr_duplicate`）

- docs: 数学の問題の変種生成 `MathTemplate` の設計（`docs/math_variants_design.md`。未実装）

- 数式の答えの形の指定 `Question.form`（`expanded`・`factored`・`reduced_fraction`・`simplest_radical`）と `judgeExpr`・`ExprVerdict`・`MathExpr.hasForm`。値は合うが形が違う答えを区別。検証 `unknown_form`・`answer_form_mismatch`・`form_ignored`

- 数式の問題タイプ `expr` と `MathExpr`（数式の読み取り・同値判定）。`2x+6` と `2(x+3)`、`1/2` と `0.5` を同じ値として判定。検証 `expr_answer_invalid`。設計は `docs/math_foundation.md`

- docs: ちゅうコレ！英語（日本）中1前半のコンテンツ草案（`docs/content_drafts/eigo_jp_chu1/`: 単元・前提・見本問題16問・誤解の型）。検証テスト付き

- 英語（日本）のコンセプト案・競合・評価（レビュー）調査・差別化 `docs/eigo_concept_jp.md`（App Store 日本の競合 10 本の評価と、レビュー 2,452 件の集計。直接競合の不満は課金画面・広告・誤植・落ちる。弱点克服の有料化と煽るキャラは嫌われる。差別化 8 点を根拠つきで）
- 最初の教科の再確認 `docs/first_subject_decision.md`（日本。競合・需要・作りやすさを英語と数学で比較。英語を最初にする判断は維持、同価格帯の直接競合があるため設計で差をつける。未確認の項目と見直しの条件つき）
## [0.4.0] - 2026-10-28

0.3.0 のあとに、**子どもへの既定を基盤で守る**ことと、アプリの結線を短くする入口のまとめを足した版。コンセプト「気づいたら、点が上がっている。」の続き。**SQLite のスキーマ版（4）・バックアップ形式（1）は 0.2.0 から変更なし**（移行は不要）。PR 番号は `zka32101/chukore_kit` のもの。

### 移行時の注意
- **公開 API を壊す変更はない**（追加のみ）。ただし、**アプリは次の 2 つに切り替えること**。これまで基盤は子どもの年齢を見ておらず、方針の表（`AgePolicy`）にあるだけで何も守っていなかった。
  - 通知の判定: `decideNudge` → **`decideNudgeFor`**（子どもには方針が許さない限り出さない。既定は出さない）
  - 範囲カードの符号: `encodeScope` → **`encodeScopeFor`**（子どもには方針が許さない限り作らない。既定は作らない）
- `ChildFeature` に `nudge` を追加。`AgePolicyTable` の JSON の `access` を書いている場合、`nudge` を書かなければ子どもには通知を出さない（`scopeShare` と同じ安全側）。

### 子どもへの既定を基盤で守る
- 子どもへの通知: `ChildFeature.nudge`（既定は子どもには非表示）と `decideNudgeFor`。保護者ゲートのあとの方針なら、承認があるときだけ (#121)
- 子どもへの範囲カード（QR）: `encodeScopeFor`（同じ形）(#123)

### 入口と声かけ
- 「今日」の入口のまとめ `buildDailyHome`（見出し・今日の出題・時間の見積もり・前日/当日の制限・点を聞くかを 1 回で。時間の予算に収め、混ぜ、制限をかける。個別に呼んでも同じ結果）(#122)
- 保護者への声かけ（点の変化）`suggestOutcomeTalk` / `suggestOutcomeTalkFor`（数字を含めず、取り組みを話題にし、責めない。保護者向けレポートと同じ年齢の方針）と、文言 `talkOutcomeFirst` / `Up` / `Same` / `Down`（18言語。**ネイティブ確認は未実施**）(#122)
- `example/day_flow.dart` に、時間で選ぶ出題・本番の点の一連・入口のまとめ・保護者への声かけ・通知の既定を追加。通しのテストで固定 (#119, #122)

### 方針の記録
- 運営者の判断で法務確認は行わない（2026-10-28）。確認が要る機能（匿名の送信・集計、範囲カードの共有、13歳未満への通知、結果を示す訴求、海外展開）は有効にしない。範囲は `docs/legal_review_questions.md` §0、方針は `docs/design_principles.md` §2-9 (#120)
- リポジトリは公開のまま。README と `pubspec.yaml` の「非公開」を訂正し、文書中の個人名を「運営者」に置き換えた (#119)

## [0.3.0] - 2026-10-28

中学専用の基盤として、**本番の点の変化を測る一式**と、**海外対応の土台**（地域プロファイル・カリキュラムパック・試験カレンダー）を足した版。コンセプトは「気づいたら、点が上がっている。」。**公開 API を壊す変更はなく、SQLite のスキーマ版（4）・バックアップ形式（1）は 0.2.0 のまま**（移行は不要）。PR 番号は `zka32101/chukore_kit` のもの。

### 本番の点の変化（設計: `docs/score_outcome_measurement.md`）
- 本番の点の変化 `buildOutcomeSummary`（端末内。ノイズ幅・使う前の点との比較・使った量）。`RealTestRecord` に満点 `maxScore` と種類 `RealTestKind` を追加（既存の呼び出しは変わらない）(#110)
- 点を聞くタイミング `decideScorePrompt`（テスト日の翌日から14日以内に1回だけ・1日1回まで・聞いたら二度と聞かない）と入力の読み取り `parseScoreInput`。数値入力の正規化 `normalizeNumberInput` を公開 (#113)
- 点まわりの文言 8 つ（18言語。責めず、結果を保証しない）と `outcomeMessage`。**ネイティブ確認は未実施** (#112)
- 匿名の報告 `buildOutcomeReports`（点・日付を持たない粗い区分）と集計 `tallyOutcomes`（30 件未満のマスは返さない）(#111)
- 匿名イベントの名前と許可項目 `FunnelEvent`（点・日付・名前を持てない）と、点の入力率・振り返りの到達率 `funnelRates` (#115)
- しきい値の設定束 `KitTuning`（版つき。報告とイベントに版が入り、版が違う報告は集計で混ぜない）(#116)
- ※ 匿名の報告・イベント・集計は**送信の仕組みが無く、法務確認と保護者の同意が済むまでアプリは使わない**

### 出題・計画
- 分で選ぶ今日の出題 `pickPracticeForMinutes`（予算に収まるよう、比率を保って数を減らす。増やさない）(#114)
- 次にやる単元の提案 `suggestNextUnits`、克服の戻りの分析 `analyzeRelapses` (#99)
- `StudyDay.shift`/`shiftAttempts`: 回答の時刻と「今」を境界の分だけ戻して渡すと、既存の全関数が学習日で数える (#102)
- 国ごとの試験の時期のカレンダー `ExamCalendar`（中身は現地の学校暦の確認のあと）(#117)

### 海外対応の土台
- 地域プロファイル `RegionProfile` / `RegionProfileTable`（年齢の線・保護者同意・利用時間上限・広告/トラッキング・課金手段・保持日数・必須の通知。既定は最も厳しい側。数値は法務確認後）(#100)
- 国別カリキュラムパック `CurriculumPack`（単元の木に学習基準の項目コードを対応づけ、`validate` で整合・網羅を検査。BNCC の実データは現地の確認後）(#102)
- 差し替え用の入口 `Clock`/`ConsentStore`（既定は同意なし）/`NotificationScheduler`/`EntitlementReader`、学習日の境界 `StudyDay` (#101)
- L10n 品質ゲート: UI に日本語の直書きがないことと、年輪の図・年表の並べ替えの全言語 200% 文字拡大を、テストで見張る (#102)

### 品質
- 速度の修正: 回答が 10 万件の履歴で、`classifyMistakes`（約 13 秒 → 0.2 秒）と `buildRetrySets`（約 16 秒 → 0.4 秒）が履歴の件数の 2 乗に比例して遅くなっていたのを直した（結果は同じ）。`tool/bench.dart` と `test/scale_test.dart` で見張る
- 互換性の固定: 旧版の SQLite（版 1〜3）の移行と、バックアップ形式 v1 の固定ファイルをテストで守る

### ドキュメント
- 設計方針 `design_principles.md`（中学専用・小学と共通にしない）、海外展開の基準 `global_rollout_criteria.md`、海外版との対応表 `global_alignment.md`、中学数学の海外競合調査 `competitive_research_middle_school.md`、本番の点を測る設計 `score_outcome_measurement.md` (#103〜#109)

## [0.2.0] - 2026-10-20

最初のまとまった版（0.1.0 はタグを打たずに開発していたため、これが最初の配布対象）。PR 番号は `zka32101/chukore_kit` のもの。

### 計画・出題
- 範囲（単元ツリー）・テスト日逆算・評価の初期実装 (#1)、複数教科の同時計画 (#66)、目標点からの逆算 (#40)
- 適応的な出題選び `pickPractice` (#62)、混ぜ練習 `interleaveByUnit` (#81)、前日・当日のガード `guardLastDays` (#87)
- 間隔反復 (#32)、復習間隔の個別調整 `tuneReviewIntervals` (#82)、学習量の自動調整 `suggestCapacity` (#85)、山場の予告 `findPeakAhead` (#75)
- 学習時間の見積もり (#39)、暗記カード学習 (#70)、段階ヒント (#68)、疲れと休憩の提案 (#69)
- 「今日」の画面の窓口 `buildTodayCard`、前日/当日の区分 `eveNoticeOf` (#89)

### 診断・振り返り
- 弱点ノートと克服判定 (#2)、つまずき別の解き直しセット (#64)、ケアレスミス判定 (#35)、自信度 (#36)、間違えた理由の自己申告 (#67)
- さかのぼり診断 (#24)、つまずきの根っこランキング `rankRootCauses` (#84)、前提の作成支援 (#55)
- 模試モード (#33)、模試の履歴比較 (#41)、模試からの次の一手 `planNextSteps` (#74)、模試の時間配分の分析 `analyzeMockTiming` (#86)
- テスト後の振り返り (#37)、誤解の型の傾向分析 (#38)
- アプリ内偏差値（段階 1・2）(#8, #23)

### 問題集の品質
- 問題集・単元ツリーの JSON 形式と検証 (#20)、差分更新 (#57)
- 実測難易度とずれの検出 (#72)、誤答の選択肢の分析 (#73)、誤解の型の下書き `suggestTagDrafts` (#77)
- 問題集の品質レポート `buildQualityReport` と `tool/quality_report.dart` (#90)
- 記述問題の判定（別解・表記ゆれ・部分点）(#56)、問題タイプの判定 (#4)

### 子ども・保護者
- 保護者ゲートの出題・判定と週次レポート (#3, #42)、週次レポートの強化 (#42)、子ども本人向けの週のふりかえり (#65)
- 保護者への声かけの提案 `suggestGuardianTalk` (#83)、学習を促す通知の判定・時間帯の提案 (#58, #63)
- 国ごとの年齢条件 `AgePolicy` と、地域ごとの上書き表 (#48, #53)
- 成長機能（成長カード・年輪・本番の点数・偏差値の表示ポリシー）(#5, #12, #21)
- 先生役モード (#19)、直前プリント (#25)、当日チェック (#26)、範囲カードの QR 共有 (#27)

### 画面部品・アクセシビリティ
- 地図タップ・図タップ・年表 (#9, #10, #11)、色だけに頼らない表示 (#22)
- コントラスト比・読みやすい長さへの分割 (#76)、色覚シミュレーションと配色の検査 (#78)

### 保存・引き継ぎ
- 回答履歴ストア契約と SQLite 実装（別入口 `chukore_kit_sqlite.dart`）(#4, #6)
- 学習データの書き出しと取り込み `AttemptBackup` (#54)
- 回答履歴の全削除 `AttemptStore.deleteAll()` (#80)

### 海外対応（18 言語・23 種）
- 日本語・英語・ポルトガル語（pt-BR / pt-PT）・スペイン語・フランス語・韓国語・中国語（簡体・繁体）・インドネシア語・ベトナム語・ドイツ語・トルコ語・タイ語・ヒンディー語・アラビア語（右から左）・ロシア語・イタリア語・オランダ語・ポーランド語 (#13〜#18, #28, #34, #43, #44, #46, #50, #51, #52, #59, #60, #61)
- 翻訳確認の書き出し `docs/translation_review.csv`、数の読み上げの一覧ツール、言語名 `languageName` (#17, #71, #80)

### 修正
- 循環前提で出発点が空になる問題、指紋の Web 精度 (#29)
- 基準正答率の範囲検査をリリースビルドでも有効に、SQLite のスキーマ版を記録 (#30)
- UI の再描画判定・QR の再計算・TextPainter の破棄・幅 0 の図 (#31)
- 点数の表示（`3.0`・`-0.0`）と年輪の等価性 (#47)
- 1 日の内訳が合計を超える不具合（複数教科の計画）(#66)

### 例・整理
- 1 日の流れの例 `example/day_flow.dart`（結線の手本。テストで見張る）(#91)
- ネイティブ確認の依頼の道具: 言語ごとの確認シート `reviewPacketCsv`・数の読み上げ `numberWordsTsv` と、書き出すコマンド `tool/export_review_packets.dart`（#95）
- 法務確認の問い合わせ資料 `docs/legal_review_questions.md`（確認したい点・基盤の現状の挙動・確認後に進められる作業）
- 内部の整理: 中央値の計算 6 か所を 1 つ（`lib/src/util/median.dart`、非公開）にまとめた（挙動は変わらない）。直接のテストが無かった `allocateByWeight`・`wilsonInterval`・`eveNoticeOf`・`overcomeStampCount` にテストを追加 (#92)
- ドキュメント: `docs/features.md` を分野ごとの節に整理し、目次を付けた (#93)

### 移行時の注意
- **SQLite のスキーマ版は 4**（列の追加は自動で移行する）。**新しい版で作った DB を古い版のアプリで開くと `StateError`**（新しい版のデータベースです）になる。アプリを戻すときは注意。
- `AttemptBackup` のファイル形式は版 1。新しい版のファイルは古いアプリが拒否する。
- `AttemptStore.deleteAll()` は既定で `UnsupportedError`（自作のストアを持つアプリは実装すること）。
- `wilsonInterval` が公開 API になった（`calibrateDifficulty` と `tuneReviewIntervals` が使う）。
- 暫定値（閾値・上限など）は [`docs/softlaunch_validation_plan.md`](docs/softlaunch_validation_plan.md) の検証で見直す。変えたときは副版を上げ、ここに書く。
- 18 言語の文言のネイティブ確認、実機のフォント確認は未実施（[`docs/native_review_checklist.md`](docs/native_review_checklist.md)）。
