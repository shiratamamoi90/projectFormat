---
name: new-topic
description: 新しい論点フォルダを decisions/undecided/ に作り、案を出して議論を始める。決定的・非決定的どちらの決めごとにも使う。
---

引数 $ARGUMENTS を論点名(kebab-case)として、`decisions/undecided/` に論点を1つ開く。

手順:
1. `decisions/undecided/` と `decisions/decided/` の既存連番を**両方**調べ、最大+1 を 4桁ゼロ詰めで
   NNNN とする(無ければ 0001)。**decided 側も見る** — 番号は払い出したら不変で、
   決定済みに移った番号を再利用してはいけない(@.claude/rules/impl-rules.md N-2)。
2. **決定的か非決定的かを判定して報告する。** 出力が一意に決まり受け入れ条件を書けるなら決定的、
   指標でしか良し悪しを測れないなら非決定的。**両方の性質があるなら論点を分ける**
   (混ぜない。@.claude/rules/architecture.md「二系統の対応表」)。
3. `decisions/undecided/NNNN-$ARGUMENTS/topic.md` を作る。書式は
   @.claude/rules/requirement-rules.md「topic.md テンプレ」(切り方と粒度は
   @.claude/rules/decision-rules.md)。**冒頭の種別タグを必ず埋める**
   (/validate が欠落を NG にする)。
4. **非決定的と判定した場合のみ** `config.yaml` と `result.md` を追加し、`topic.md` に
   「測り方」と「中止条件」を書く(@.claude/rules/experiment-rules.md)。
   baseline が無ければ、先に baseline を作るよう促す。
5. 案は複数出してよいが、**決定は書かない。** 「決定」以下は空のまま人間に渡す。
   決めるのは人間で、確定は /decide で行う。
