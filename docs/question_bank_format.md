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
| `type` | `choice`（選択）／`map`（地図タップ。選択肢は領域ID）／`numeric`（数値。`choices` は空でよい）／`order`・`timeline`（並べ替え・年表。`answer` は正解順のIDをカンマ区切り、`choices` は同じID集合） |
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
`unit_missing` / `duplicate_mistake_line_id` / `mistake_*`（元の問題・型・選択肢のつながり、セリフ・説明が空など）

警告（品質上の注意）:
`unit_no_estimate` / `difficulty_extreme` / `tags_ignored` / `unit_not_leaf` / `unit_empty`

## 教科別の検算

数学の SymPy による検算や、英語の語彙リスト照合は Dart ではなく別ツールで行う（設計書 §12-4 の 8）。
このツールが見るのは、形式とつながり（上の検証コード）まで。
