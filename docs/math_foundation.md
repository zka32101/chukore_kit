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
| 4 | 検算ツール（別ツールで SymPy 等。`tool/` ではなくコンテンツ側のテスト） | 未 |
| 5 | 体験の仕様 `Exploration`（下記 §4）。スライダーで式のパラメータを動かすグラフ教材（`slider_graph`）。グラフの点の計算・予想の答え合わせ・目標の達成判定・目標に届くかの検証。見本は `docs/samples/explorations.sample.json` | **実装済み**（画面はアプリ側） |
| 6 | 途中式の1行ずつ判定（直前の行と同値か。最初に崩れた行を示す＝「どこで間違えたか」） | 未 |

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
