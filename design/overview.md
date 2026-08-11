# 確定設計(source of truth)

**決定済み論点を統合した結果だけを置く。** 議論の途中は `decisions/undecided/` にあり、
決まったものを `decisions/decided/` から**ここへ書き起こす**(手順・承認点の正本は
`.claude/rules/design-rules.md`)。

- 書くのは**どう分けて満たすか**:層の割り当て、部品の境界、公開する契約、外部との境界、技術の採用。
  **何を満たすか**は `specs/` 側に置き、ここに書き写さない。
- 崩してはいけない制約(依存方向・命名・共通化)は `.claude/rules/` が正本。ここでは
  「この制約のもとで何をどこに置いたか」だけを書く。
- ファイル分割は自由。大きくなったら層ごと・機能ごとに分けてよい(このファイル名も変えてよい)。

## 層の割り当て

```
src/engine  ←  src/agent  ←  src/eval
(決定的・安定)    (探索)        (評価)
```

| 層 | 置くもの | 置かないもの |
|---|---|---|
| `engine` | <決定的なコアロジック。純関数> | I/O、乱数、外部サービス |
| `agent` | <探索・方策> | 合法手の定義(engine が持つ) |
| `eval` | <評価・自己対戦> | — |

## engine の構成(記入例 — 論点 0001 を統合したもの)

- 状態異常は `src/engine/status.py` に置き、`get_legal_actions` から参照する。
  状態は `battle_state` が持ち、engine 内の純関数で受け渡す。
- **合法手の定義は engine だけが持つ。** 非合法手は生成側で落とし、実行時に弾く形にしない
  (理由と却下案は `decisions/decided/0001-example-paralysis/topic.md`)。

## agent の探索設定

<未決定。論点 0002 の計測結果を待つ(`decisions/undecided/0002-example-search-depth/`)。>

## 外部との境界

- <I/O・永続化・外部サービスをどこで行うか。engine の外側に置く>
