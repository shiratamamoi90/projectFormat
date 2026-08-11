# 用語集(ドメイン語彙の「正」)

> **下の「## 用語」と「## 却下した語」の行はすべて記入例**(まひ・状態異常 等)。
> プロジェクト開始時に自分のドメインの語へ**置き換える**(TEMPLATE.md 手順3)。
> **表ごと消さない** — `scripts/validate.sh` は用語行が1つも無いと NG を出す。
> 用語が固まっていないうちは、確実に使う語を1つだけ書いて始める。

仕様に登場する概念の正本。**ここに登録されていない語をコードのドメイン語彙として使わない。**
このファイルが持つのは**語そのものだけ**で、語の選び方(名詞形が正・述語は `is_<形容詞形>` /
`has_<名詞形>`・同義語を作らない・追加や変更は論点(`decisions/`)を通す仕様変更)は
@.claude/rules/impl-rules.md「命名規則」N-1 が正本。ここに書き写さない(2箇所あると片方が古くなる)。

## 書き方(検査対象なので形式を崩さない)

- テーブルは**5列固定**。列位置を `scripts/validate.sh` が参照するため増減させない。
- 形容詞形が作れない語は空欄にせず `—` を入れる(空セルは列位置をずらす)。
- 「使ってはいけない表記」はバッククォート付きのカンマ区切りで書く(`` `para`, `plz` ``)。
  この列の識別子が `src/` `tests/` に出現すると検査が NG を出す。
- **汎用語(`state`, `count`, `data`, `status` 等)を禁止表記に登録しない。**
  単語境界の grep が無関係な箇所まで拾い、検査が使い物にならなくなる。
  汎用語の扱いは impl-rules.md N-6(中身のない名前)で縛る。

## 用語

| 仕様(日本語) | 名詞形(正) | 形容詞形 | 使ってはいけない表記 | 定義 |
|---|---|---|---|---|
| まひ | `paralysis` | `paralyzed` | `para`, `plz`, `is_paralysis`, `paralyze_flag` | 行動を制限する状態異常のひとつ。ターン終了時に解除される |
| 状態異常 | `status_condition` | — | `ailment`, `status_ailment`, `cond` | 行動や解決の結果を変更する効果の総称 |
| 命中判定 | `accuracy_check` | — | `hit_check`, `check_hit`, `acc` | 技が命中したかを決める判定 |
| バトル場の状態 | `battle_state` | — | `bstate`, `game_state`, `battle_ctx` | 1試合の進行に必要な全情報を持つ不変データ |
| 行動 | `action` | — | `act`, `cmd`, `move` | プレイヤーが選択できる操作の単位 |
| 残りターン数 | `remaining_turns` | — | `turns_left`, `remain_turns`, `left_turns` | 効果が持続する残りターン数 |
| 合法手 | `legal_action` | — | `valid_action`, `legal_move`, `allowed_action` | その局面で選択できる行動の全体 |
| 攻撃 | `attack` | — | `atk`, `attack_cmd` | 相手にダメージを与える行動 |
| 逃げ | `retreat` | — | `escape`, `flee`, `run_away` | バトル場のポケモンをベンチに下げる行動 |
| ターン終了 | `turn_end` | — | `end_turn`, `eot`, `turn_finish` | 1ターンの解決が終わる時点。持続効果の解除を判定する |
| ベンチ | `bench` | — | `bnc`, `benched_area`, `reserve` | バトル場以外に控えているポケモンの置き場 |

> 名詞形は**概念・データ・型の名前**。関数名にするときは N-3 の接頭辞を付ける(例と理由は N-3)。

## 却下した語

同義語の再提案を防ぐための記録。ここにある語は再検討しない(覆すなら新しい論点を通す)。

| 却下した語 | 採用した語 | 却下理由 | 決定した論点 |
|---|---|---|---|
| game_state | `battle_state` | 「正」が「バトル場」と呼ぶ範囲より広く読める | 0001-example-paralysis |
| ailment | `status_condition` | 「正」の表記が「状態異常」。訳語を2つ持たない | 0001-example-paralysis |
| move | `action` | 技(technique)と紛らわしい。操作単位は action に統一 | 0001-example-paralysis |
