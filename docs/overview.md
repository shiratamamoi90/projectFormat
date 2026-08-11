# 確定仕様(source of truth)

**決定済み論点を統合した結果だけを置く。** 議論の途中は `decisions/undecided/` にあり、
決まったものを `decisions/decided/` から**ここへ書き起こす**(手順は
`.claude/rules/doc-rules.md`「確定の流れ」、実行は `/decide`)。

- 書くのは**何を満たすか**だけ。**どう作ったか(層・ファイル分割・関数名)は書かない** —
  ソースツリーを見れば分かる。なぜそう作ったかは `decisions/` にある
  (判定基準は `.claude/rules/doc-rules.md`「どこに何を書くか」)。
- シナリオ ID の先頭4桁は**論点番号**と一致させる(`.claude/rules/impl-rules.md` N-2)。
- ここに書いたシナリオは `scripts/validate.sh` が `tests/` と双方向で照合する。
  ID があって対応するテストが無ければ「未実装」として NG になる。
- ファイル分割は自由。機能のまとまりごとに分けてよい(このファイル名も変えてよい)。

記入例は `docs/0001-example-status-condition.md`(参考にしたら削除する)。

