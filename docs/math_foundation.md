# 数学の基盤設計（覚えるだけにしない・体験型）

> ステータス: 設計 + 第1段（`expr` 実装済み）。数学は日本の2教科目、海外（ブラジル等）の1教科目の候補。
> 方針は `docs/design_principles.md`（責めない・結果を保証しない）に従う。

## 1. 目的
- 数学は**答えの形式**（式・分数・平方根）と**考え方**（なぜそうなるか）が弱点の源。暗記と反復だけでは伸びない。
- 基盤が持つのは**判定・生成・検証・体験の仕様**まで。画面（スライダー・グラフ）はアプリ側。

## 2. 段階

| 段 | 内容 | 状態 |
|---|---|---|
| 1 | 数式の判定 `type: expr`（`MathExpr`）: 展開・因数分解・約分・分数と小数を同じ値として判定。全角・×÷−・² も読む | **実装済み** |
| 2 | 形の指定（`form`: 展開済み／因数分解済み／既約分数／最簡の根号）。`2(x+3)` を「展開しなさい」で通さない。`judgeExpr` が値は合うが形が違う（`wrongForm`）を区別 | **実装済み** |
| 3 | 問題の変種生成 `MathTemplate`（係数を種で変える。同じ種なら同じ問題。答えは式から機械計算）。暗記でなく型を解く。設計は [`math_variants_design.md`](math_variants_design.md) | **実装済み**（`MathTemplate`・`TemplateSet`・`validateTemplates`・`tool/expand_templates.dart`。見本は `docs/samples/templates.sample.json`） |
| 4 | 検算ツール: **画面に出る問題文の数字だけ**から、問題の意味どおりに答えを解き直して、型の答えと照合する（型の答えの式は隠れた値から書くので、書き間違えても自分自身とは合ってしまうため）。`test/answer_oracle_test.dart`。わざと壊した型を見つけることも確認 | **実装済み**（中2・中3の 66 型。図の中の点・長さが唯一の手がかりの 5 型は対象外。中1は未） |
| 5 | 体験の仕様 `Exploration`（下記 §4）。スライダーで式のパラメータを動かすグラフ教材（`slider_graph`）。グラフの点の計算・予想の答え合わせ・目標の達成判定・目標に届くかの検証。見本は `docs/samples/explorations.sample.json` | **実装済み**（画面はアプリ側） |
| 6 | 途中式の1行ずつ判定（直前の行と同値か。最初に崩れた行を示す＝「どこで間違えたか」）。誤解の型も当てる（§10） | **実装済み** |

## 3. 暗記にしない工夫（問題の設計）
1. **誤解の型を答えに結ぶ**: 既存の `misconceptionTags` / まちがいキャラを数学でも使う。例: `(x+3)^2 → x^2+9`（`square_of_sum`）、符号（`sign_flip`）、分数の足し算で分母も足す（`fraction_add_denominator`）。
2. **変種**: 係数だけ変えた問題を出し、答えを覚えても通れなくする（段3）。
3. **なぜ**を問う: 「正しい式はどれ」でなく「間違いの理由はどれ」（まちがいキャラの `fixChoices`）。
4. **見積もり・確かめ**: 解いた後に「代入して確かめる」を1問に含める（`expr` で式に値を入れる問題）。
5. **逆向き**: 答えから問題を作る・式から文章題を選ぶ。
6. **混ぜ練習**: 既存の `interleaveByUnit`（同じ型が続かない）。
7. **間隔反復**: 既存の復習（型ごとに復習の期限）。

## 4. 体験型（Exploration）
基盤は**仕様（データ）と判定**だけ持ち、操作（スライダー・グラフの描画）は画面側が実装する。実装済みの種類は `slider_graph`（式のパラメータを動かして、グラフの変化を確かめる）。天秤などは種類を足して対応する。

```json
{"id": "ex_linear_ab", "version": 1, "unitId": "m1_func_graph", "kind": "slider_graph", "promptId": "ex_linear_ab_prompt",
 "expr": "a*x+b",
 "params": [{"name": "a", "min": -3, "max": 3, "step": 0.5, "initial": 0}, {"name": "b", "min": -5, "max": 5, "step": 1, "initial": 0}],
 "predict": {"promptId": "…", "choices": ["steeper", "shift_up", "same"], "answer": "steeper"},
 "goal": {"expr": "2*x+1"}, "explanationId": "exp_ex_linear_ab"}
```
- **予想 → 動かして確かめる → 言葉にする**の順（予想が外れた時こそ学ぶ。責めない）。`predict` の選択肢は ID で、文言はコンテンツ側。`checkPrediction(id)`。
- **ゴール型**: 「このグラフに合わせよう」。`goalReached(values)` は、パラメータを格子に合わせた式が目標と同じ関数かを `MathExpr.equivalent` で判定する（書き方によらない）。
- 画面向け: `initialValues`、`normalize`（スライダーの値を格子に合わせる）、`sample`（グラフの点。定義できない点・桁あふれは y が NaN で、描かない点として扱う）。
- 検証 `validateExplorations`: `exploration_unit_missing`・`exploration_goal_unreachable`（格子のどの組でも目標にならない）・`exploration_initial_is_goal`（最初から達成）。`goalSolutions` は目標を満たす組を返し、ヒントにも使える。
- 例: 比例・一次関数（傾きと切片）、反比例。今後: 正負の数（数直線）、方程式（天秤）、図形（角度・面積）、確率（コインを何回も振る）。
- 体験は**習熟度に直接加点しない**（遊びで水増ししない。回答履歴 `Attempt` にも残さない）。体験後の確認問題（`expr`／選択）で測る。

## 5. 海外展開での違い
- 数式の記号と式の判定はそのまま（`expr`）。小数点がカンマの国は `decimalSeparator`（数値入力）に対応済み。
- 国で違うのは単元の並びと用語（`CurriculumPack`）。BNCC 等は未取得（`docs/curriculum_packs/example_BR.json` は暫定）。

## 6. 次にやること
段3（変種生成）→ 数学中1の単元ツリー草案（正負の数・文字式・一次方程式・比例反比例・平面図形）を `docs/content_drafts/` に。

## 7. パッケージの境界（数学専用の基盤は今は分けない）
決定: 数学の部品は `chukore_kit`（`lib/src/math`）に置く。`expr` は問題の判定と問題集の検証に組み込まれ、理科の計算問題にも使える共通部品で、純粋な Dart で小さく（使わない教科ではビルドから外れる）、パッケージを増やすとタグ・CI・リリースが倍になるため。
- 境界を守る（`test/package_boundaries_test.dart` が確認）: `lib/src/math` は Flutter に依存せず、core では `models`・`bank`・`scope/unit_tree` だけに依存する。core から `math` を使うのは、問題の判定（`answer.dart`）と問題集の検証（`question_bank.dart`）だけ。
- 体験型（`Exploration`）の画面部品は `chukore_kit_ui.dart` ではなく、別の入り口（将来 `chukore_math_ui` に切り出せる形）に置く。仕様と達成判定（純粋な Dart）は core に置く。
- 国別の単元・問題・型は基盤ではなく `chukore_<国>_<教科>` に置く。
- **分ける条件**（どれかが出たら再判断）: ① 数学専用の重い依存（記号計算・グラフ描画・図形レンダリング）② 体験型の画面部品が大きくなる ③ 数学だけ更新頻度が大きく違う ④ 数学が core のモデルから独立して扱える形になる。

## 8. 図・グラフ・データ（平面図形／空間図形／データの活用）
未着手の3分野の方針は [`math_figures_design.md`](math_figures_design.md)（設計のみ。着手順の案: データ → π → 平面図形 → 空間図形）。

## 9. 作図（体験型 `construction`、実装済み）
定規とコンパスの作図を、**手順を 1 つずつ実行して、最後に目標の直線が引けたか**で判定する（描いた絵を採点しない）。見本は `docs/samples/constructions.sample.json`。
- 教材 `Construction`: 最初の点（`givens`）、見せる図形（`show`: 線分 `seg`・直線 `line`・半直線 `ray`）、目標 `goal`、模範の手順 `solution`、手順の上限 `maxSteps`、`promptId`・`explanationId`・`altId`（文言はコンテンツ側）。目標は `perpendicularBisector`（線分の垂直二等分線）・`angleBisector`（角の二等分線）・`perpendicular`（点を通る垂線。点は直線の上でも外でもよい）。
- 状態 `ConstructionState`: **点は最初の点と交点だけ**を選べる（自由な位置に点は打てない）ので、手順そのものが作図として正しい。操作は `addCircle(中心, 点)`（その点を通る円）・`addCircle(中心, 点a, 点b)`（半径は線分 ab の長さ＝コンパスを移す）・`addLine(点, 点)`（定規）・`intersect(図形, 図形)`（円と円・直線と円・直線と直線。すでにある点と同じ位置なら使い回す）。ID は円 `c1…`・直線 `l1…`・交点 `X1…`（新しい点だけ順に）。成り立たない操作は `ArgumentError`。
- 判定 `isSolved`: 引いた直線のどれかが目標の直線と**同じ直線**（向きは問わない）か。通る点が合っていても向きが違えば不可、平行でも重ならなければ不可。
- 表示 `figure(state)`: 見せる図形・作った直線（枠で切る）・円・点と名前を `Figure`（`toSvg` で SVG）にする。体験は習熟度に加点せず、回答履歴にも残さない（確認問題で測る）。
- 検証 `validateConstructions`: `construction_unit_missing`・`construction_solution_missing`・`construction_solution_fails`（模範の手順が成り立たない・目標に届かない）・`construction_solution_too_long`。**模範の手順を実際に実行して確かめる**ので、教材を書き間違えても、解けない作図は出ない。
- 見本 4 つ: 垂直二等分線、角の二等分線、点から直線への垂線（外の点）、直線上の点での垂線。

## 10. 途中式の判定（`checkSolutionSteps`、実装済み）
子どもが書いた途中式を **1 行ずつ前の行と比べ**、最初に壊れた行と、**その行で何を間違えたか（誤解の型）**を返す。「答えが違う」でなく「どの行のどこで」を伝えるための部品。
```dart
final r = checkSolutionSteps(['2x+3=11', '2x=11+3', 'x=7'], target: 'x=4');
r.firstProblem; // 1（2 行目で解が変わった）
r.tag;          // 'move_term_sign'（移項で符号を変えていない）
r.reachedTarget; // false
```
- **式の変形**（`2(x+3)` → `2x+6` → …、数の計算 `(-3)*4+5` → `-12+5` → `-7`）: 各行が前の行と同じ値（`MathExpr.equivalent`）。
- **方程式**（`2x+3=11` → `2x=8` → `x=4`）: 各行が前の行と**同じ解**（`MathEquation.equivalent`）。左辺 − 右辺が 0 でない定数倍で一致するとき同じ解。移項・両辺に同じ数をたす・ひく・同じ 0 でない数でかける・わる・かっこをはずす、は同じ。両辺に変数をかける・2 乗を外して片方の解だけにする、は**解が変わる**のでエラー。全角の `＝`・空白・左右入れ替え（`4=x`）も読む。
- 結果 `SolutionCheck`: 行ごとの `LineVerdict`（`ok`／`broken`／`unreadable`／`kindMismatch` と誤解の型 `tag`）、`firstProblem`（最初に ok でなかった行。なければ null）、`reachedTarget`（全行 ok で最後が目標に着いた）、`finalNotSolved`（方程式で解の形 `x=数` まで整理していない）、`finalWrongForm`（式で `form` に合わない）。壊れた行のあとの行は、**その行（書かれたとおり）との比較**になる（誤りが元に戻れば ok）。
- **誤解の型の当て方**: 前の行から、よくある誤りで書き換えた式を作り（`MathExpr.commonMistakes`）、今の行と同じになるものを探す。式: `distribute_first_only`（`2(x+3)`→`2x+3`）・`minus_paren_first_only`（`5-(x+3)`→`5-x+3`）・`square_of_sum`・`fraction_add_denominator`・`like_terms_mixup`（`2x+3`→`5x`）・`order_of_operations`・`fraction_numerator_partial`・`sub_negative_sign`・`sign_rule_product`・`neg_square_sign`。**一次方程式**はさらに、`move_term_sign`（移項で符号を変えない）と割り算の誤り（`forgot_to_divide`・`multiplied_instead_of_divide`・`divide_reversed`・`sign_flip`）を係数から当てる。`a x = e` の形からの 1 手は割り算の誤りを先に、それ以外は移項の誤りを先に疑う。当たらない誤りは `tag` が null（壊れたことだけ伝える）。
- 使い方: 画面は行を足すたびに呼び、`firstProblem` の行に「ここで式が変わっているよ」と責めずに示す。`tag` があれば、その誤解の型の解説（レッスンの `pitfall`、まちがいキャラ）へつなぐ。レッスンの例題の途中式の検証（`docs/learning_model.md` §3.3）にも使う。
- 限界: 不等式・連立方程式・2 次以上の方程式の誤解の型、行の途中の書き間違いの位置（行の中のどこか）は未対応。
