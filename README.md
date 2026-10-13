# chukore_kit

ちゅうコレ！専用の共通部品（非公開）。仕様: `chukore_kit_仕様_v0_2.md`。

実装済み（§9 の 1・2・4 の一部）: モデル、単元ツリー(JSON)、テスト日逆算、習熟度、到達レベル、目安偏差値、弱点ノート(克服判定)。
未実装: SQLite 保存、問題タイプ部品、保護者機能、成長・キャラ。
中核ロジックは純Dart（Flutter非依存）。UI連携時に app_common_kit を依存に加える。

```
dart pub get && dart test
```
