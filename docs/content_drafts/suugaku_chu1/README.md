# ちゅうコレ！数学（中1）単元ツリー・前提の草案

数学基盤（`docs/math_foundation.md`）の上に載せる、中1の単元と前提の草案。問題の型は `docs/samples/templates.sample.json`（`m1_expr`・`m1_linear`）が最初の見本。
内容は日本の学習指導要領（中1）に沿った暫定。教科書会社ごとの並びの違い・最新の指導要領との照合は未実施（公開前にコンテンツ担当が確認する）。

- `units.json`: 7 分野・21 単元（葉）。`estimatedQuestions` は目安（計 約 380 問）。
- `prerequisites.json`: 前提関係。小学の前提は誘導リンクだけ（コードは共有しない）。
- `templates.json`: 問題の型 9 つ（`docs/math_variants_design.md`）。問題文の文章はコンテンツ側で持つ（`display` の数式を差し込む）。選択肢の日本語は型に直接書いてある（国別コンテンツのため）。

## 前提の流れ
正負の数（大小 → 加減 → 乗除 → 混合）→ 文字式（表し方 → 計算・数量の関係）→ 方程式（等式の性質 + 計算 → 解き方 → 文章題）。比例・反比例は文字式の表し方 → 変数 → 比例／反比例 → グラフ。図形は作図 → 移動／おうぎ形 → 空間図形・体積。

## 誤解の型の候補（型の `wrong` のタグ）
| 単元 | タグ | 内容 |
|---|---|---|
| 正負の数 | `sign_flip` | 符号を逆にする |
| | `sub_negative_sign` | 負の数をひく操作で符号を誤る |
| | `neg_square_sign` | `(-3)^2` と `-3^2` の混同 |
| 文字式 | `distribute_first_only` | かっこの先頭だけにかける |
| | `add_instead_of_multiply` | かけるところを足す |
| | `like_terms_mixup` | 同類項でない項をまとめる（`2x+3` を `5x`） |
| 方程式 | `forgot_to_divide` | 両辺を割り忘れる |
| | `move_term_sign` | 移項で符号を変えない |
| | `multiply_one_side` | 片方の辺だけにかける |
| 比例・反比例 | `prop_inv_mixup` | 比例と反比例の式の取り違え |
| | `coordinate_swap` | x 座標と y 座標の取り違え |
| 図形 | `arc_area_mixup` | 弧の長さと面積の公式の取り違え |
| | `volume_missing_third` | 錐体の体積の 1/3 を忘れる |

## 次にやること
1. 型を増やす。`templates.json` に 9 型（文字式の計算・式の値・数量の関係・等式の性質・一次方程式）を書いた（各 40 変種）。次は正負の数（符号の誤解）、比例・反比例の式。
   展開: `dart run tool/expand_templates.dart units.json templates.json questions.json`
2. 選択式・記述式の見本問題（図が要る単元は図の方針を決めてから）。
3. 体験型（`Exploration`）の見本: 一次関数の傾きと切片、方程式の天秤。
