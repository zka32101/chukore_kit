# ちゅうコレ！社会（日本）中1 コンテンツ草案

`chukore_jp_shakai` ができたら、このディレクトリごと移す（`content/` へ）。基盤の設計は `docs/shakai_foundation.md`。

- `units.json`: 単元ツリー。地理（世界の姿・日本の姿・世界各地の生活と環境）と歴史（歴史の学び方・古代）。subject は `social`
- `prerequisites.json`: 前提関係（座標 → 時差、国土の端 → 都道府県、気候帯 → 雨温図、年代 → 縄文弥生 → 古墳 → 飛鳥奈良 → 平安。外部の前提は小学社会）
- `questions.json`: 見本の問題 18 問（choice・multi・numeric・match・map・timeline・text の全タイプ）
- `charts.json`: 雨温図の見本 4 つ（`ChartSpec`）。**実在の地点の値ではないパターン**。実データは出典（気象庁・理科年表など）で置き換える

検証: `dart run tool/validate_bank.dart units.json questions.json prerequisites.json`（エラー・警告 0。`test/shakai_draft_test.dart` が確認。`charts.json` は `ChartSpec` で読めること）

## 誤解の型（misconceptionTags）
| 型 | 内容 |
|---|---|
| continent_size_mixup | 大陸の大きさの取り違え |
| equator_pole_mixup / latitude_longitude_mixup | 赤道と極の取り違え／緯度と経度の取り違え |
| time_diff_direction_reversed / time_diff_ignored | 時差の足し引きの向き違い／時差を考えない |
| extreme_point_mixup / name_direction_trap | 国土の端の島の取り違え／島の名前の字面にひかれた誤り（南鳥島を最南端とする） |
| neighbor_region | 隣の地方・県との取り違え |
| climate_zone_mixup | 気候帯・雨温図の取り違え |
| era_mixup / artifact_mixup | 時代の取り違え／遺跡・遺物の取り違え |
| name_mixup | 人物名の取り違え（聖徳太子／中大兄皇子、桓武天皇／聖武天皇／天智天皇） |

## 問題文（見本）
| ID | 問題文 |
|---|---|
| soc1_land_001〜002 | 「世界で最も大きい大陸は」／「三海洋をすべて答えなさい」 |
| soc1_coord_001 | 「赤道は緯度何度か」 |
| soc1_time_001〜002 | 「日本（東経135度）と経度0度の時差は何時間」／「日本が正午のとき、経度0度の地点は何時」 |
| soc1_area_001〜002 | 「日本の最北端の島は」／「島と、国土の端の方角を結びなさい」 |
| soc1_pref_001〜002 | 「東北地方をタップしなさい」（地図は `MapPack`）／「中部地方の県は」 |
| soc1_zone_001 | 「一年中気温が高く雨が多い気候帯は」 |
| soc1_chart_001 | 「降水量が最も少ない地域の雨温図は」（選択肢は `charts.json` の ID） |
| soc1_era_001〜002 | 「西暦1868年は何世紀か」（`ceil(y/100)`）／「時代を古い順に並べなさい」 |
| soc1_yayoi_001 | 「稲作が広まった時代は」 |
| soc1_kofun_001 | 「大王の墓として造られた大型の墓は」 |
| soc1_asuka_001〜002 | 「人物と事柄を結びなさい」／「710 年につくられた都は」 |
| soc1_heian_001 | 「平安京に都を移した天皇は」 |

## 次にやること
- 量の拡充（目標 約 190 問。各葉の `estimatedQuestions` の合計）。中世・近世以降は次の範囲
- 世界・日本の地図（`MapPack`。世界は小学コレ！社会の Natural Earth から変換済みの手順あり。都道府県は国土地理院の利用条件の確認後）
- 雨温図・円グラフなど資料の実データ（出典の確認）、解説本文、まちがいキャラ
- 国境・国名・領土の表記（コソボ・台湾・北方領土ほか）はコンテンツ側で方針を決める
