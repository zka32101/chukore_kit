# リリース手順

各アプリは chukore_kit をタグで固定して参照する（`main` は参照しない。戻せなくなるため）。

```yaml
dependencies:
  chukore_kit:
    git:
      url: https://github.com/zka32101/chukore_kit
      ref: v0.2.0
```

## 版を上げる前のチェック

1. `flutter analyze` が問題なし。
2. `flutter test` と `TZ=Asia/Tokyo flutter test` がどちらも通る（日付・時差の不具合を拾う）。
3. 文言を足したときは `dart run tool/export_strings.dart` で `docs/translation_review.csv` を更新済み（更新を忘れるとテストが落ちる）。
4. 保存の形（SQLite のスキーマ版・`AttemptBackup` の版・問題集の形式）を変えたときは、**版を上げて移行を書き**、`CHANGELOG.md` の「移行時の注意」に書く。
5. 公開 API を壊す変更がなければ補修版/副版、あれば副版（`0.x` の間）を上げる。

## 手順

1. `pubspec.yaml` の `version` を上げる。
2. `CHANGELOG.md` の先頭に新しい版の節を足す（日付つき）。`git log --format='%s'` の PR 番号から、テーマ別にまとめる。
3. PR を出して main にマージ（ブランチは main に合わせる）。
4. **タグを打つ**（人が確認して実行）:
   ```bash
   git checkout main && git pull
   git tag -a vX.Y.Z -m "chukore_kit vX.Y.Z"
   git push origin vX.Y.Z
   ```
5. 各アプリの `pubspec.yaml` の `ref:` を新しいタグにして、`flutter pub get` → そのアプリのテストを流す。

## 戻すとき

アプリ側の `ref:` を前のタグに戻す。ただし **SQLite のスキーマ版が上がっている版からは戻せない**（新しい版の DB を古い版は開かない）。スキーマ版を上げた版では、アプリの更新前にバックアップ（`AttemptBackup`）を取る案内を出すこと。

## 版の一覧と保存形式

| 版 | SQLite スキーマ | バックアップ形式 | 備考 |
|---|---|---|---|
| 0.2.0 | 4 | 1 | 最初の配布対象 |
