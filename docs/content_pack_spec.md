# コンテンツパックの仕様

ちゅうコレ！は、国（10 か国以上の予定）× 教科 × 学年の範囲ごとに、**中身を 1 つのまとまり（コンテンツパック）**で持つ。
中身は国ごとのリポジトリ（`chukore_<国>_<教科>`）が持ち、`chukore_kit` は**形式と検証**だけを持つ（基盤は何も集めず・送らない）。国ごとの設定は、すでにある `RegionProfile`・`ExamCalendar`・`CurriculumPack`・`ChukoreStrings`（`docs/global_alignment.md`）に置く。

## 1. ディレクトリ

```
pack/
├── manifest.json        目録（必須）
├── units.json           単元ツリー（必須）
├── prerequisites.json   単元の前提（さかのぼり診断）
├── questions.json       問題集と、まちがいキャラ
├── templates.json       変種を作る型（数学など。`docs/math_variants_design.md`）
├── lessons.json         レッスン（`docs/learning_model.md` §3）
├── explorations.json    式を動かす体験（数学）
├── constructions.json   作図（数学）
├── experiences.json     教科共通の体験（sort・link・dial・balance・timeline）
├── charts.json          資料のグラフ（`{"version":1,"charts":{ID: グラフ}}`）
└── map_packs/*.json     地図データ（`MapPack`。出典必須）
```

`units.json` 以外は省略できる（教科によって必要なものが違う）。ファイルの置き場所・名前は `manifest.json` の `files` で決める。

## 2. 目録 `manifest.json`

```json
{
  "version": 1,
  "id": "chukore_jp_shakai_chu1",
  "country": "JP",
  "locale": "ja",
  "subject": "social",
  "grades": [1],
  "curriculum": "文部科学省 学習指導要領（中学校 社会）",
  "contentVersion": "0.1.0",
  "attribution": ["出典の表示（原典・利用条件）"],
  "files": {
    "units": "units.json",
    "prerequisites": "prerequisites.json",
    "questions": "questions.json",
    "charts": "charts.json",
    "maps": ["map_packs/world.json"]
  }
}
```

| キー | 内容 |
|---|---|
| `id` | パックの ID（小文字・数字・`_`、先頭は英字） |
| `country` | 国コード（ISO 3166-1 の大文字 2 文字: `JP`・`BR`） |
| `locale` | 言語（`ja`・`pt-BR`・`en` など） |
| `subject` | 教科（`math`・`en`・`social`・`science`・…）。**すべての単元の `subject` と同じ** |
| `grades` | 範囲の学年（1〜12）。単元の `grade` はこの中に入れる |
| `curriculum` | 準拠する教育課程の名前 |
| `contentVersion` | 中身の版（`1.2.3`）。問題の `version` とは別（パック全体の版） |
| `attribution` | 出典の表示（地図・統計・画像の原典。空でもよい） |
| `files` | ファイルの場所（目録からの相対パス。`..` と絶対パスは不可） |

## 3. 検証

```
dart run tool/validate_pack.dart <パックのディレクトリ>
```

エラーがあれば終了コード 1（警告だけなら 0）。ライブラリでは `validateContentPack(manifestSource, read)`（入出力に依らない。`read` は相対パスの本文を返す関数）。

1. **個別の検証**（従来どおり）: 単元（`validateUnitList`）・前提（`PrerequisiteGraph.validate`）・問題（`parseQuestionBank`＋`validateQuestionBank`）・型（`validateTemplates`）・体験型・作図・体験（`validate*`）・グラフ（`ChartSpec`）・地図（`validateMapPack`）・レッスン（`validateLessons`）。メッセージには `[ファイル名]` が付く。
2. **ファイルをまたぐ検査**:

| コード | 内容 |
|---|---|
| `pack_manifest_invalid` | 目録が読めない（形式の誤り） |
| `pack_file_missing` / `pack_file_path_invalid` / `pack_file_malformed` | ファイルがない／パスが不正／中身を読めない |
| `pack_unit_subject_mismatch`（エラー） | 単元の教科が目録の `subject` と違う |
| `pack_unit_grade_outside`（警告） | 単元の学年が `grades` にない |
| `pack_prereq_uncovered`（警告） | 前提の定義がない末端の単元 |
| `pack_experience_id_clash`（エラー） | 体験（`experiences`）の ID が体験型（`explorations`）と重複（レッスンは両方を同じ名前空間で参照するため） |

3. **レッスンの参照**は同じパックの中身で確かめる: 問題 ID（`questions`）・型 ID（`templates`）・体験 ID（`explorations` と `experiences`）・作図 ID（`constructions`）・誤解の型（問題の `misconceptionTags` と型の `wrong`）。型があるパックでは、例題の途中式も `MathLessonChecker` で検査する。

## 4. 国ごとの違いはどこに置くか
国ごとに変わるものは、パックの中身ではなく**国の設定**（すでにある仕組み。`docs/global_alignment.md`）に置く。部品の中に国ごとの分岐は書かない。

| 変わるもの | 置き場所 |
|---|---|
| 年齢・保護者同意・利用時間・広告・課金手段・保持・必須通知 | `RegionProfileTable`（`docs/region_profiles/`） |
| 定期テストなどの時期（学校暦） | `ExamCalendar`（`docs/exam_calendars/`） |
| 学習基準（学習指導要領・BNCC など）と単元の対応 | `CurriculumPack`（`docs/curriculum_packs/`） |
| 文言 | `ChukoreStrings`（18 言語）。パックの文言は ID だけで、本文は言語ごとのテキスト（`locale`） |
| 小数点・桁区切り・文字の正規化 | 回答の判定の引数（`decimalSeparator` など）と、記述問題の別解 |

今後の課題: パックの目録から `CurriculumPack` を参照し、単元と学習基準の対応を一括検証で確かめる（BNCC など現地確認ができてから）。

## 5. 同梱の草案
`docs/content_drafts/{shakai_chu1,eigo_jp_chu1,suugaku_chu1}/manifest.json`（`test/content_pack_test.dart` が検証）。リポジトリ（`chukore_jp_shakai` など）ができたら、ディレクトリごと移す。
