# ちゅうコレ！英語（日本）中1前半 コンテンツ草案

`chukore_jp_eigo` ができたら、このディレクトリごと移す（`content/` へ）。方針は `docs/eigo_concept_jp.md`。

- `units.json`: 単元ツリー（be動詞／一般動詞／複数形／命令文／疑問詞）
- `prerequisites.json`: 前提関係（be動詞 → 一般動詞 → 命令文・疑問詞、be動詞 → 複数形。be動詞の外部前提は小学英語）
- `questions.json`: 見本の問題 16 問と、まちがいキャラ 4 件（問題文の本文は問題データ側で持つ。下表）

検証: `dart run tool/validate_bank.dart units.json questions.json prerequisites.json`（エラー・警告 0。`test/eigo_jp_draft_test.dart` が確認）

## 誤解の型（misconceptionTags）
| 型 | 内容 |
|---|---|
| be_agreement | 主語と am/is/are の組み合わせ違い |
| be_negative_order / be_with_do | be動詞の否定の語順／be動詞に do を使う |
| third_person_s / third_person_es_rule | 三単現の s 忘れ／es・ies の規則 |
| do_does_mixup / verb_ing_misuse | Do と Does の混同／ing の誤用 |
| plural_missing / plural_es_overuse / plural_es_rule / plural_ies_overuse / plural_irregular | 複数形の各つまずき |
| imperative_s / imperative_be / imperative_negative | 命令文の s／be の付加／否定の作り方 |
| wh_choice / wh_order | 疑問詞の選択／疑問詞の後の語順 |

## 問題文（見本）
| ID | 問題文 |
|---|---|
| en1_be_001 | I ___ a student. |
| en1_be_002 | You ___ my friend. |
| en1_be_003 | She ___ a singer.（否定文に） |
| en1_be_004 | 「彼は先生ですか」 |
| en1_verbs_001 | He ___ to school every day. |
| en1_verbs_002 | She ___ English. |
| en1_verbs_003 | ___ you play tennis? |
| en1_verbs_004 | He ___ apples.（否定） |
| en1_plural_001〜003 | 「本が2冊」「箱が3つ」「子どもたち」を表す語 |
| en1_imperative_001〜002 | 「ドアを開けなさい」「走ってはいけません」 |
| en1_wh_001〜003 | ___ is this?（It's a pen.）／___ do you live?／「彼女はだれですか」 |

## 次にやること
語彙リスト照合（validateEnglishBank 案）、量の拡充（目標 約 95 問）、音声（TTS のみ）、解説本文。
