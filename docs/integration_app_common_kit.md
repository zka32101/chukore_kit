# app_common_kit / cross_promo_kit とのつなぎ方（設計案）

chukore_kit は**画面を持たない基盤**（ロジック・18言語の文言・一部の画面部品）。設定・同意・保護者ゲート・削除・クロスプロモは、ちゅうコレの各アプリが `app_common_kit`（v3.3.0）と `cross_promo_kit`（v0.3.0）を使って作る。ここは、その**つなぎ目**の案。

> ステータス: 案（コードは未実装）。2つのキットは別リポジトリで、変更が要る箇所は「相手側の変更」に分けて書く。法務確認が済むまで、データ収集に関わる部分は実装しない。

## 1. 役割分担

| 領域 | 担当 | 使うもの |
|---|---|---|
| 学習ロジック・文言（18言語）・年齢ポリシー・回答の保存 | **chukore_kit** | `AgePolicyTable`・`ChukoreStrings`・`AttemptStore` / `SqliteAttemptStore`・`AttemptBackup` |
| 設定画面（受験日・言語・表示モード・フィードバック） | app_common_kit | `SettingsScreen` |
| 同意（分析・クラッシュ・広告） | app_common_kit | `ConsentController` / `showConsentPrompt` |
| 保護者ゲート | app_common_kit | `requireParentalGate`（`package:app_common_kit/parental_gate.dart`） |
| データ削除 | app_common_kit | `DataDeletion` + `DataEraser` |
| 他アプリ紹介 | cross_promo_kit | `CrossPromoSection`（`isChildDirected: true` + `beforeOpenStore`） |
| 課金・広告 | app_common_kit | `entitlement`・`ads` |

## 2. つなぎ目 ①: 年齢ポリシー × 保護者ゲート

`AgePolicyTable` は「この年齢の子に、この機能を出してよいか」を返す。保護者ゲートは「大人がやっているか」の確認。

- **子ども本人が使う画面**で `AgePolicy` が不許可の機能（`ChildFeature.*`）は、そもそも出さない。
- **保護者向けの画面**（週次レポート、データ共有の同意、削除）に入る前に `requireParentalGate`。
- **外部リンク・ストア**（クロスプロモ、ご意見）の前にも `requireParentalGate`（`cross_promo_kit` は `isChildDirected: true` のとき必須で、渡し忘れはデバッグで assert）。

```dart
// アプリ側のイメージ（chukore_kit にアダプタは置かない。2つのキットを直接つなぐ）
Future<bool> openGuardianArea(BuildContext c) => requireParentalGate(c);
final allowed = policyTable.allows(age, ChildFeature.weeklyReport);
```

→ **基盤に足すもの（案）**: なし。`app_common_kit` に依存すると chukore_kit の中核（Flutter 非依存）が重くなるので、つなぎはアプリ側に置く。

## 3. つなぎ目 ②: 回答の匿名集計の同意

[`anonymous_data_collection.md`](anonymous_data_collection.md) の同意は、既存の同意の仕組みに載せるのが自然。

- **相手側の変更**: `app_common_kit` の `ConsentCategory` に `learningStats`（回答の匿名集計）を足す。**既定は不許可**（未回答 = 送らない）。13歳未満の同意の扱いは法務確認後。
- `ConsentStrings`（同意画面の文言）に、対応する説明を足す。**18言語は chukore_kit の `ChukoreStrings` が持っているが、同意画面は app_common_kit 側の言語対応に従う**ので、言語の差（どの言語が両方にあるか）を先に棚卸しする。
- 送る前に `ConsentController` で同意を確認し、不許可なら束を作らない。
- **chukore_kit に足すもの（案・法務後）**: `ChildFeature.dataSharing`（既定不許可）と、送る束を作る関数（日時・所要時間・理由を落とす。テストで固定）。

## 4. つなぎ目 ③: データ削除

`DataDeletion` に、種類ごとの `DataEraser` を渡す。ちゅうコレで消す対象:

| 対象 | 消し方 |
|---|---|
| 回答の履歴（SQLite） | `SqliteAttemptStore` のデータベースを削除（`CallbackEraser('attempts', …)`）。**`AttemptBackup` で書き出した端末外のファイルは消せない**ので、削除の説明で伝える |
| 学習計画・設定・同意 | `SharedPreferencesEraser` と `ConsentStore.clear()` |
| 匿名集計に送った分 | **端末側からは特定できない**（個人を結びつけない設計のため）。説明に「すでに送った統計は取り消せない」を書く |

→ **基盤に足すもの（案）**: `SqliteAttemptStore` に、データベースを閉じて消す `deleteAll()` があるか確認し、無ければ足す（実装は小さい。テストで「削除後に空」を固定）。

## 5. つなぎ目 ④: 設定画面と言語

- `SettingsScreen` の `languages` には、chukore_kit の `ChukoreStrings.supported`（18言語）から作る。`SettingsLanguage(code, 自分の言語での名前)` の一覧を、基盤が返せると楽（**案**: `ChukoreStrings.supported` に言語名のゲッターを足す。ネイティブ確認の対象に含める）。
- 受験日は `TestPlan.testDate` に保存する（保存はアプリ側）。
- アラビア語（RTL）は `textDirectionOf`（chukore_kit）と、`SettingsScreen` の RTL 対応を合わせて確認する（実機未確認）。

## 6. つなぎ目 ⑤: クロスプロモ

- `CrossPromoSection(currentAppId: …, currentCategory: 'ちゅうコレ', isChildDirected: true, beforeOpenStore: requireParentalGate)`。
- **掲載する他アプリは、年齢・内容の面で子どもに適切なものだけ**にする（`docs/cross_promo_apps.json` の `category` で絞る）。
- `onOpenStore`（タップ計測）は、子ども向けでは収集内容に注意（ストア規約）。**ちゅうコレでは使わない**のを既定にする。
- 「他の教科のちゅうコレ」への誘導（5教科）は、このセクションでできる。前提の単元が他アプリにあるとき（`ExternalRef`）の誘導先も、同じ掲載リストから引ける（**案**: `ExternalRef.id` を掲載リストの appId と合わせる）。

## 7. 依存の向き

```
各アプリ ──▶ chukore_kit   （ロジック・文言。Flutter 非依存の中核）
        ├──▶ app_common_kit （設定・同意・ゲート・削除・課金・広告）
        └──▶ cross_promo_kit（他アプリ紹介）
chukore_kit ─✕─▶ app_common_kit / cross_promo_kit
```

chukore_kit は2つのキットに**依存しない**（中核を軽く保つ。UI 部品 `chukore_kit_ui.dart` も、必要になるまで依存を足さない）。つなぎはアプリ側。2つのキットの変更が要る点（`ConsentCategory.learningStats`、同意文言）は、それぞれのリポジトリで別途。

## 8. 次の作業（優先順）

1. [ ] `SqliteAttemptStore` の全削除（`deleteAll()` の有無の確認と追加）— chukore_kit、小さい。
2. [ ] `ChukoreStrings` の言語名（設定画面の言語リスト用）— chukore_kit、18言語+CSV。
3. [ ] `app_common_kit` の `ConsentCategory.learningStats` と同意文言 — **法務確認後**。
4. [ ] `ChildFeature.dataSharing` と送る束の関数 — **法務確認後**。
5. [ ] アプリ側の結線例（サンプルアプリ）で、保護者ゲート → 同意 → 削除の流れを実機で確認。
