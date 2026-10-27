# 海外版（shoukore_core_global）との対応表

海外版の設計（「言語・地域はデータ、コードは中立」）に対して、chukore_kit に何があり、何が残っているか。

| 海外版の部品 | chukore_kit | 状態 |
|---|---|---|
| 言語（文言） | `ChukoreStrings`（18言語・RTL）、`docs/translation_review.csv` | ✅ ネイティブ確認は人手待ち（[`native_review_checklist.md`](native_review_checklist.md)） |
| 地域コンプライアンス | `RegionProfileTable`（年齢・保護者同意・利用時間・広告/トラッキング・課金手段・保持・必須通知）、`AgePolicyTable` | ✅ 数値は法務確認後（[`legal_review_questions.md`](legal_review_questions.md)） |
| 国別カリキュラム | `CurriculumPack`（単元の木 ↔ 学習基準コード、`validate`） | ✅ 仕組み。BNCC の実データは現地確認後 |
| question | `QuestionBank`・`pickQuestions`・`interleaveByUnit` | ✅ |
| progress | `AttemptStore`（SQLite・バックアップ・互換テスト） | ✅ |
| adaptive | `calibrateDifficulty`・`tuneReviewIntervals`・`suggestNextUnits` | ✅ |
| guardian | `buildWeeklyReport`・`suggestGuardianTalk`・`AgePolicy` | ✅ |
| growth | `GrowthRings`・成長カード | ✅ |
| privacy | `ConsentStore`（既定は同意なし）、匿名集計は設計のみ | 🟡 匿名集計は法務待ち（[`anonymous_data_collection.md`](anonymous_data_collection.md)） |
| notify | `NotificationScheduler`（契約）、`nudge` | ✅ 実装はアプリ側 |
| Clock / EntitlementReader | `Clock`・`EntitlementReader` | ✅ 実装はアプリ側 |
| 日の境界・タイムゾーン | `StudyDay.shift` / `shiftAttempts` | ✅ |
| L10n 品質ゲート | UI 直書き検出、全言語 200% 文字拡大テスト | ✅ |

## 小学コレ！・海外版コアとの関係

- chukore_kit は**中学（ちゅうコレ！）専用**で、小学コレ！とは共通にしない。小学の海外版（`shoukore_core_global`）は別の基盤で、ここは参考にした設計の考え方（言語・地域はデータ、コードは中立）だけを取り入れている。
- 国ごとに変わるものは、コードに書かず `RegionProfile` / `CurriculumPack` / 文言に置く。
- アプリが実装するのは、`ConsentStore`・`NotificationScheduler`・`EntitlementReader`・`Clock` の4つと、課金・通知・保存の実体だけ。
- 他アプリの単元（小学コレ！の前提など）は、コードを共有せず誘導（`ExternalRef`）だけを持つ。

## 残り（人手が必要）

1. 18言語のネイティブ確認、実機の文字拡大・RTL・色覚の確認。
2. 法務確認（子どもの年齢、通知、匿名集計、各国の数値）。
3. ブラジルの BNCC 対応表（現地の教育者の確認）。
4. 次のタグ（v0.2.1 か v0.3.0）。
