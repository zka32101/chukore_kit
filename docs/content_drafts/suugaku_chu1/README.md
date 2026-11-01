# ちゅうコレ！数学（中1）単元ツリー・前提の草案

数学基盤（`docs/math_foundation.md`）の上に載せる、中1の単元と前提の草案。問題の型は `docs/samples/templates.sample.json`（`m1_expr`・`m1_linear`）が最初の見本。
内容は日本の学習指導要領（中1）に沿った暫定。教科書会社ごとの並びの違い・最新の指導要領との照合は未実施（公開前にコンテンツ担当が確認する）。

- `units.json`: 7 分野・21 単元（葉）。`estimatedQuestions` は目安（計 約 380 問）。
- `prerequisites.json`: 前提関係。小学の前提は誘導リンクだけ（コードは共有しない）。
- `experiences.json` / `explorations.json` / `constructions.json`: 体験（天秤・一次関数・作図の見本）。レッスンから参照する
- `texts.json`: 文言 222（レッスンの説明文 40 に加えて、**81 の型すべての問題文 `prompt_<型ID>` と解説**、図の説明）。目録の `textsCover` は省略（全部）。レッスンの説明文（等式の性質＝天秤、一次方程式＝みかんの代金、同類項＝えんぴつと消しゴム、三角形の内角の和＝切り取って並べる）。実例から入り、例題の行ごとの説明は例題の値を差し込んで読める。解説は、その型の値を差し込んで読める（テストが全変種で確認。式の問題は解説が答えを含む）
- `templates.json`: 問題の型 81 個（`docs/math_variants_design.md`）。問題文の文章はコンテンツ側で持つ（`display` の数式を差し込む）。選択肢の日本語は型に直接書いてある（国別コンテンツのため）。

続き: 中2 `../suugaku_chu2/`、中3 `../suugaku_chu3/`（単元・前提の草案）。

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

## 追加した型（文章題・移動・平行線・角柱角錐）の問題文
| ID | 問題文 |
|---|---|
| m1_eq_word_001 | 「1個 {a} 円のみかんを x 個買い、{b} 円の箱に入れてもらったら、代金は {c} 円。x は」 |
| m1_eq_word_002 | 「みかんを子どもに {a} 個ずつ配ると {b} 個余り、{c} 個ずつ配ると {d} 個足りない。子どもの人数は」 |
| m1_eq_word_003 | 「いま子が {b} 歳、親が {a} 歳。親の年齢が子の {n} 倍になるのは何年後」 |
| m1_geo_move_001〜002 | 「点 A({p}, {q}) を右へ {s}、上へ {t} 平行移動した点の x 座標（002 は y 座標）」 |
| m1_geo_move_003〜005 | 「点 ({p}, {q}) を x 軸について対称移動した点の y 座標」／「原点について対称移動した点の x 座標」／「原点を中心に反時計回りに 90° 回転した点の x 座標」 |
| m1_geo_parallel_001〜003 | 「l // m のとき、x は」（図: 平行な 2 直線と交わる直線。001 錯角・002 同位角・003 同側内角） |
| m1_space_prism_001〜pyramid_001 | 「底面積 {S} cm²、高さ {h} cm の角柱（角錐）の体積」 |
| m1_space_solid_face_002〜vertex_003（図つき） | 「図の{kind}（角柱・角錐）の面の数／辺の数／頂点の数」（n は図から読み取る。角柱・角錐の図は `solid` の `prism`・`pyramid`） |
| m1_space_prism_002・pyramid_002（図つき） | 「底面積 {S} cm²、高さ {h} cm の{kind}の体積」（図の n は何角形でもよい） |
| m1_space_solid_face_001〜edge_002 | 「{n} 角柱の面の数／辺の数」「{n} 角錐の頂点の数／辺の数」 |

## 次にやること
1. 型を増やす。`templates.json` に 81 型（正負の数・文字式の計算・式の値・数量の関係・等式の性質・一次方程式・座標・比例・反比例・データの活用・円とおうぎ形・円柱と球・角と二等辺三角形、図つき・立体と展開図・図が選択肢）を書いた（各 40 変種）。次は平行線と角、角柱・角錐（`docs/math_figures_design.md`）。作図の見本は `docs/samples/constructions.sample.json`。
   展開: `dart run tool/expand_templates.dart units.json templates.json questions.json`
2. 選択式・記述式の見本問題（図が要る単元は図の方針を決めてから）。
3. 体験型（`Exploration`）の見本: 一次関数の傾きと切片（`explorations.json`）。方程式の天秤は `experiences.json`（`balance` の 3 つ。`les_m1_eq_prop_01` が参照）。
