# 問題データの形式と検証

教科アプリは、**単元ツリー**（`units.json`）と**問題集**（`questions.json`）を持つ。
形式を確かめるには、次のコマンドを使う（エラーがあれば終了コード 1）。

```
dart run tool/validate_bank.dart units.json questions.json
```

サンプル: `docs/samples/units.sample.json`・`docs/samples/questions.sample.json`
（テストで検証しているので、この説明とずれない）。

## 単元ツリー `units.json`

```json
{
  "version": 1,
  "units": [
    {"id": "en1_grammar", "subject": "en", "grade": 1, "title": "Grammar", "order": 1},
    {"id": "en1_verbs", "subject": "en", "grade": 1, "parentId": "en1_grammar",
     "title": "General verbs", "order": 2, "estimatedQuestions": 30}
  ]
}
```

- `parentId` が無い単元がルート。親を選ぶと配下の**葉**がすべて範囲になる。
- `estimatedQuestions` はテスト日逆算の重み（葉に付ける）。`order` は同じ親の中の並び順。
- 問題は**葉の単元**に付ける（葉でないと範囲選択・習熟度が正しく働かない）。

## 単元の前提 `prerequisites.json`（さかのぼり診断用・省略可）

つまずいた単元の前提をたどって、どこでつまずき始めたかを特定するための依存関係。

```json
{
  "version": 1,
  "prerequisites": [
    {"unitId": "en1_verbs", "requires": ["en1_be"]},
    {"unitId": "en1_be", "external": [
      {"id": "shogaku_english_basic", "title": "小学英語: あいさつと自己紹介", "link": "https://example.com/shogaku-kore"}
    ]}
  ]
}
```

- `requires`: 同じ単元ツリーの中の前提の単元。
- `external`: 他アプリ（小学コレ！など）にある前提。**コードは共有せず、誘導（リンク）だけ**を持つ。`link` はストアのリンクやアプリ間リンクで、開くのはアプリ側。
- 診断は `diagnoseBacktrace`。習熟度が基準（既定 0.6）未満の前提を weak、学習の記録が無い前提を unknown とし、「前提がすべて ok なのに自分は weak／unknown」の単元を出発点の候補にする。出発点が持つ `external` が誘導先になる。
- 検証: `dart run tool/validate_bank.dart units.json questions.json prerequisites.json`
  - エラー: 単元が無い・自分自身が前提・循環（`a → b → c → a` と道筋を表示。同じ循環は 1 回）・重複・`external` の空欄。
  - 警告（直すと分かりやすいが、動作には影響しない）: 冗長な前提（`prereq_redundant`: 別の前提の先でも辿れる）、学年の逆転（`prereq_grade_inversion`: 前提が上の学年）、別の教科の前提（`prereq_cross_subject`）、前提の重複（`prereq_requires_duplicate`）。
  - 作成の進み具合: 「前提の定義: 12/40 末端単元（未定義: …）」と表示する。前提が本当に無い単元は定義しなくてよいので、これはエラーにしない。コードからは `PrerequisiteGraph.uncoveredLeaves(tree)`。

## 問題集 `questions.json`

```json
{
  "version": 1,
  "questions": [
    {"id": "en1_verbs_001", "unitId": "en1_verbs", "type": "choice", "difficulty": 0.62,
     "choices": ["goes", "go", "going"], "answer": "goes", "explanationId": "exp_en1_verbs_001",
     "misconceptionTags": {"go": "third_person_s"}, "version": 1}
  ],
  "mistakeLines": [ ... ]
}
```

| 項目 | 内容 |
|---|---|
| `type` | `choice`（選択）／`map`（地図タップ。選択肢は領域ID）／`numeric`（数値。`choices` は空でよい）／`order`・`timeline`（並べ替え・年表。`answer` は正解順のIDをカンマ区切り、`choices` は同じID集合）／`text`（短い記述。`answer` は別解を `\|` で区切る。例 `東京\|とうきょう\|Tokyo`。`choices` は空）／`multi`（複数の語を答える。`answer` は項目を `;`、各項目の別解を `\|` で区切る。例 `織田信長\|のぶなが;豊臣秀吉\|ひでよし;徳川家康`。順不同・部分点あり。`choices` は空） |
| `difficulty` | 基準正答率 0〜1（アプリ内偏差値の換算に使う）。0 と 1 は警告 |
| `misconceptionTags` | 誤答の選択肢ID → 誤解の型（小文字・数字・`_`）。**正解の選択肢には付けない** |
| `explanationId` | 解説の ID（解説の本文は別データ） |

### まちがいキャラ `mistakeLines`（先生役モード）

```json
{"id": "ml_third_person_s_001", "tag": "third_person_s", "questionId": "en1_verbs_001",
 "sourceChoiceId": "go", "statement": "He go to school every day.",
 "fixChoices": ["He goes to school every day.", "He going to school every day."],
 "correctChoice": "He goes to school every day.", "explanation": "he / she / it の動詞には s をつけます。"}
```

`questionId` の問題の誤答選択肢 `sourceChoiceId` に、同じ `tag` が付いていること。
間違えると、その誤答の型として弱点ノートに載り、続けて直すと克服判定される。

## 検証コード

エラー（出題・判定・克服判定が壊れる）:
`malformed` / `duplicate_unit_id` / `unit_parent_missing` / `unit_cycle` / `unit_negative_count` /
`duplicate_question_id` / `unknown_type` / `explanation_missing` / `bad_version` / `choices_duplicate` /
`choices_too_few` / `answer_not_in_choices` / `numeric_answer_invalid` / `order_too_few` /
`order_duplicate` / `order_choices_mismatch` / `tag_choice_missing` / `tag_on_answer` / `tag_format` /
`unit_missing` / `prereq_unit_missing` / `prereq_requires_missing` / `prereq_self` / `prereq_cycle` / `prereq_duplicate` / `prereq_external_empty` / `prereq_redundant` / `prereq_grade_inversion` / `prereq_cross_subject` / `prereq_requires_duplicate` / `duplicate_mistake_line_id` / `mistake_*`（元の問題・型・選択肢のつながり、セリフ・説明が空など）

警告（品質上の注意）:
`unit_no_estimate` / `difficulty_extreme` / `tags_ignored` / `unit_not_leaf` / `unit_empty`

## 教科別の検算

数学の SymPy による検算や、英語の語彙リスト照合は Dart ではなく別ツールで行う（設計書 §12-4 の 8）。
このツールが見るのは、形式とつながり（上の検証コード）まで。

## 記述問題（`text`・`multi`）の判定
- 比べる前に表記ゆれをそろえる（`normalizeText`）: 全角の英数記号→半角、英字は小文字、空白の並びは 1 つ、文末の句読点（`。.、,!?`）は除く、カタカナ→ひらがな、各地の数字→0〜9、引用符・ハイフン類の違い。語順や途中の記号は変えない（`a lot` と `alot` は別）。
- カタカナで書く指定の問題は、`checkAnswer(..., foldKana: false)` でカタカナとひらがなを区別する。
- `multi`: 入力の区切りは `;`・`；`・`、`・`,`・`，`・改行。正解の項目には、これらの区切り文字を入れない（`multi_item_separator`）。
- 得点は `AnswerResult.score`（0〜1）。`multi` は 合った項目数 ÷ 全項目数。正解に無い項目が混じると、その数だけ減る（思いつく語を全部書く当て推量を避ける。0 を下回らない）。同じ項目の重ね書き（別解を両方書く、同じ語を 2 回書く）は加点も減点もしない。全項目が合い、余分が無いときだけ `correct`。`text` ほかは正解 1・不正解 0。
- 模試の採点は `correct`（○×）で数える。部分点を模試の得点に使うかは、運用で決める。
- 検証コード: `text_answer_empty` / `text_alt_duplicate` / `multi_too_few` / `multi_item_empty` / `multi_item_separator` / `multi_ambiguous` / `choices_ignored`（警告）。

## 問題集の差分更新（月次の配信用）
全体を送り直さず、差分だけで更新できる。配信・保存はアプリ側で、基盤は「差分を作る・検査する・適用する」を持つ。
- 作る: `BankDiff.between(今の問題, 新しい問題)`（追加・削除・変更）。コマンドは `dart run tool/diff_bank.dart <今の questions.json> <新しい questions.json> [<diff.json>]`。エラーがあれば差分ファイルを書かず終了コード 1。
- 検査（`diff.check(今の問題)`）: 内容を変えたのに `version` が同じ（`changed_without_version_bump`、エラー）、`version` が下がった（`version_decreased`、エラー）、内容は同じなのに `version` だけ上がった（`version_bumped_without_change`、警告）。**内容を変えた問題は version を上げる**決まり（回答履歴は問題ID・版に結びつくため、古い内容の集計と混ざらないようにする）。
- 適用: `diff.apply(手元の問題)`。変更は元の位置、追加は最後、削除は除く。手元が差分の元と違う（削除・変更する問題が無い、変更前の版が合わない、追加する問題がすでにある）と `StateError` で、途中まで当たった状態は返さない。差分は**順番に**当てる（1 か月飛ばすと版が合わず止まる）。適用後の問題集は、通常どおり `validateQuestionBank` で検証する。
- ファイル: `diff.toJsonString()` / `BankDiff.parse(json)`。形式名 `chukore_kit.bank_diff`、版 1。別のファイル・壊れたファイル・新しい版は `FormatException`。

