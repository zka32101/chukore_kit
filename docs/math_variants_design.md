# 問題の変種生成 `MathTemplate` の設計

> ステータス: 設計のみ（未実装）。`docs/math_foundation.md` の段3。先に決めたいことは §9。

## 1. 目的
- 「答えを覚えて通る」を防ぐ。同じ**型**で数だけ違う問題を、**同じ種なら同じ問題**として出す。
- 毎月の問題追加を「問題を書く」から「型（テンプレート）を書く」に変える。1 つの型から数十問を機械で作り、答えも**式から機械計算**するので、答えの書き間違いが無くなる。
- 間違い方（誤解の型）も、型の中で**式として**書く。間違った選択肢・答えに、自動で誤解のタグが付く。

## 2. 作るもの（全部 core、純粋な Dart）
| 部品 | 役割 |
|---|---|
| `SeededRandom` | 種から決まった乱数列を返す。**自前の 32bit 実装**（`dart:math` の `Random(seed)` は実装・版で列が変わりうる。Web でも同じ結果にする） |
| `ParamSpec` | パラメータの範囲（整数 `int:[lo,hi]`、候補 `oneOf:[…]`） |
| `MathTemplate` | 型の定義。JSON から読む（書き間違いは `FormatException`）。`generate(seed)` で `Question` と表示用の値を返す |
| `Variant` | `generate` の結果: `question`（`Question`）、`display`（画面に出す数式の文字列）、`params`（値） |
| `expandTemplates` | 型の集まりから、種 1..N の問題集（`questions.json` と同じ形）を作る。検証ツール `tool/expand_templates.dart` |

問題文の**文章**（「次の式を展開しなさい」）は core に持たない。`questions.json` が問題文を持たないのと同じで、コンテンツ側が `templateId` ごとの文章を持ち、`display` の数式を差し込む。

## 3. テンプレートの形（案）
```json
{
  "version": 1,
  "templates": [
    {
      "id": "m1_expand_001", "templateVersion": 1, "unitId": "m1_expr",
      "type": "expr", "form": "expanded", "difficulty": 0.7,
      "params": {"a": {"int": [2, 9]}, "b": {"int": [-9, 9]}},
      "constraints": ["b != 0"],
      "display": {"expr": "{a}(x{+b})"},
      "answer": "{a}x{+a*b}",
      "wrong": [
        {"expr": "{a}x{+b}", "tag": "distribute_first_only"},
        {"expr": "{a}x{+a+b}", "tag": "add_instead_of_multiply"}
      ],
      "explanationId": "exp_m1_expand_001"
    }
  ]
}
```
- `{e}`: 式 `e`（パラメータの四則・かっこ）の値を整数または既約分数で差し込む。`{+e}`: 符号をつける（`+12`・`-12`）。`{&e}`: 負ならかっこで囲む（`(-3)`）。
- `derived`: パラメータから計算する値（例 `"c": "a*k+b"`）。`display`・`answer`・`wrong`・`constraints` で使える。
- `constraints`: `式 比較 式`（`== != < <= > >=`）。満たす値が出るまで引き直す（上限 50 回、無理なら `template_unsatisfiable`）。
- 割り算の結果が整数にも既約分数にも書けない（循環小数など）なら引き直す。
- `choice` の型は `choices`（式で書く）と `answer` を同じ書式で持つ。`wrong` の `tag` は選択肢の誤解のタグになる。

## 4. 誤答に誤解のタグを付ける（`expr` の拡張）
`expr` の問題は選択肢が無いので、今は誤答にタグが付けられない。**`misconceptionTags` のキーに式を書く**ことにする。
- `checkAnswer` は、不正解のとき、入力が `misconceptionTags` のどの式と**同値か**を見て、最初に同値なもののタグを返す（`AnswerResult.misconceptionTag`）。
- 手書きの `expr` 問題でも使える。型の `wrong` は、この `misconceptionTags` に展開される。
- 検証: キーが式として読めない（`tag_expr_invalid`）、キーが正解と同値（`tag_on_answer`、既存）、キー同士が同値（`tag_expr_duplicate`）。

## 5. 問題 ID・版・履歴
- 変種の問題 ID は `{templateId}~{seed}`（例 `m1_expand_001~17`）。回答の履歴は問題 ID に結びつくので、**同じ種は永久に同じ問題**でなければならない。
- 型の内容（パラメータの範囲・式・制約・`wrong`）を変えたら `templateVersion` を上げる。変種の `Question.version` は `templateVersion`。版が変われば古い回答と混ざらない（既存の差分更新の決まりと同じ）。
- 毎月の配信は、問題ではなく**型の差分**だけ送ればよい。変種は端末で再現できる。
- 習熟度・基準正答率の補正は**型ごと**にも集計できるようにする（変種ごとだと 1 問あたりの回答が少なすぎる）。`difficulty` は型で 1 つ。

## 6. 出題との接続
- 出題器は今まで通り `Question` の一覧から選ぶ。アプリが型から種 1..N を展開して**プールに入れる**（N は既定 40。§9）。
- 同じ型を続けて出さない: `interleaveByUnit` の考え方を型にも使う案（`interleaveByTemplate`）。まず単元で混ぜるだけで足りるかを見る。
- 直近に解いた種は避ける（既存の「3 日以内に正解した問題は出さない」が、問題 ID が違うので自然に効く）。

## 7. 検証（`validateTemplates`・`tool/expand_templates.dart`）
各型を種 1..N（既定 40）で展開し、展開した問題集に通常の `validateQuestionBank` もかける（`answer_form_mismatch`・`unit_missing` など）。
| コード | 内容 | 重さ |
|---|---|---|
| `template_unsatisfiable` | 50 回引き直しても決まらない（制約が厳しい・値が分数で書けない・誤答が正解と同値になり続ける・選択肢が重複し続ける・表示の式がすでに目標の形） | エラー |
| `template_expression_invalid` | `{…}` の式が読めない、宣言のない文字、答えが選択肢にない、誤答が選択肢にない | エラー |
| `template_answer_dup` | N 個の変種で答えが半分以下の種類しかない（範囲が狭すぎる） | 警告 |

- 読み込み（`TemplateSet.parse`）で、未知のキー・型違い・範囲外・`{` `}` の対応違い・式の宣言のない文字・id の重複を `FormatException` で止める。
- **正解と同値になる誤答、誤答どうしの重複、選択肢の重複は、その種を引き直す**（その組み合わせのパラメータは出ない）。例: 見本の展開の型で `a=2,b=2` のとき `a+b==a*b` なので、誤答 2 が正解と同値になり、その組は引かれない。
- 変種の `explanationId` は型で 1 つ。解説の本文は、`display` の数式を差し込むコンテンツ側で持つ。

## 8. やらないこと
- 実行時に AI で問題を作らない（検証できないため）。
- 文章題の文章の自動生成（コンテンツ側で複数の言い回しを持つ）。
- 図形（作図・角度の図）の生成。数式の型を先に固め、図は体験型（`Exploration`）の段で考える。
- 記号計算による解答の自動導出（答えは型の作者が式で与える。検算は別ツール）。

## 9. 先に決めたいこと
1. **プールの大きさ**: 1 つの型から何問展開するか（案: 40）。大きいほど覚えにくいが、検証が重い。
2. **難しさのずらし方**: 型の `difficulty` は 1 つで足りるか。数が大きいほど難しい型は、パラメータの範囲で 2 つの型に分ける（案）か、`difficultyBy` を足すか。
3. **履歴の集計単位**: 習熟度は単元ごとのままでよいか。弱点ノートの誤解のタグは型をまたいで集計する（案: 型をまたぐ。同じ誤解は同じタグ名）。
4. **対象の最初の単元**: 数学中 1 の「正負の数」「文字式」「一次方程式」のうち、型にしやすいのは文字式の展開・計算と方程式。正負の数は符号の誤解（`sign_flip`）の診断に向く。

## 10. 実装の順（1〜4 は実装済み）
1. `SeededRandom`・式の差し込み（`{e}`・`{+e}`・`{(e)}`）・制約・分数の書式（テスト: 同じ種で同じ結果、桁、符号、分数、Web 相当の 32bit 範囲）
2. `expr` の誤答タグ（§4。既存の `checkAnswer` の拡張）
3. `MathTemplate` の読み込みと `generate`
4. `expandTemplates` と検証、`tool/expand_templates.dart`
5. 出題器との結線の例（`example/`）、ドキュメント

## 11. 数列とデータの集計（追加）
`params` に英大文字 1 字の数列、`stats` に集計を書ける。詳細は [`math_figures_design.md`](math_figures_design.md) §5C。引き直しの条件に「最頻値が複数」も入る。
