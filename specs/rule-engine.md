# 確定仕様(source of truth)

**決定済み論点を統合した結果だけを置く。** 議論の途中は `decisions/undecided/` にあり、
決まったものを `decisions/decided/` から**ここへ書き起こす**(手順は
`.claude/rules/spec-rules.md`「確定の流れ」、実行は `/decide`)。

- 書くのは**何を満たすか**だけ。どう分けて満たすかは `design/` 側。
- シナリオ ID の先頭4桁は**論点番号**と一致させる(`.claude/rules/impl-rules.md` N-2)。
- ここに書いたシナリオは `scripts/validate.sh` が `tests/` と双方向で照合する。
  ID があって対応するテストが無ければ「未実装」として NG になる。
- ファイル分割は自由。機能のまとまりごとに分けてよい(このファイル名も変えてよい)。

記入例は `specs/0001-example-status-condition.md`(参考にしたら削除する)。
