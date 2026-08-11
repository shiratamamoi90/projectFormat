---
name: decide
description: 決まった論点を decisions/undecided/ から decided/ へ移し、その場で requirements/ に統合する。
---

引数 $ARGUMENTS で指定された論点(例: 0002-search-depth)を確定させる。

前提確認(**欠けたら停止する。この skill の停止条件**):
- **人間がその決定を承認していること。** 承認が無ければ、決定案と理由を示して停止し、承認を求める。
  エージェントが自分で決めない(@.claude/rules/decision-rules.md「承認点」)。
- `topic.md` に `[要確認]` が残っていないこと。残っていれば、それを先に人間に確認する。
- 非決定的な論点なら `result.md` に**シードと依存を固定した実測値**があること。
  数値が無いまま決めない(@.claude/rules/experiment-rules.md)。

手順:
1. `topic.md` の「決定 / 理由 / 却下した案 / 反映先」を埋める。**却下した案とその理由を必ず残す**
   (無いと同じ案が再提案され、同じ議論を繰り返す)。
2. フォルダごと `decisions/decided/` へ移す。**フォルダの位置が状態**なので、
   `状態:` の行も決定済みに直す。
3. **その場で統合する。未統合の decided を残さない。**
   - **満たすべきこと** → `requirements/` に GIVEN/WHEN/THEN で書く。シナリオ ID の先頭4桁は
     **論点番号**(@.claude/rules/impl-rules.md N-2)。正常系・異常系・境界・否定を網羅する
     (@.claude/rules/requirement-rules.md「必須カバレッジ」)。
   - **構造の決定(どのファイル・どの層に置くか)は文書に書かない。** 結果はコードに現れ、
     理由は `topic.md` に残る。要件に及ばない論点なら `反映先: —` として統合を終える。
   - **シナリオ本文を `decided/` 側に重複させない。** `topic.md` には反映先だけを記す。
4. 「決まらなかったこと」があれば、`/new-topic` で別の論点として `undecided/` に切り出す。
5. `scripts/validate.sh` を実行し、統合結果が検査を通ることを確認して報告する。
   この時点では要件にあって test が無い(未実装)NG が出るのが正常。
6. 次は `/new-work` で作業単位を切る。**この skill はテストも実装も書かない**
   (@.claude/rules/test-rules.md「着手の許可」)。
