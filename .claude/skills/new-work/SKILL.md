---
name: new-work
description: 統合済みの specs/ と design/ をもとに、反映作業の単位を work/ に作る。テストと実装の前段。
---

引数 $ARGUMENTS を作業名(kebab-case)として、`work/` に作業単位を1つ作る。

前提確認(**欠けたら停止する。この skill の停止条件**):
- 反映元が **`specs/` と `design/` に統合済み**であること。`decisions/decided/` に
  未統合のまま残っているなら、先に `/decide` で統合する。**論点から直接作業を作らない。**
- 反映元が `decisions/undecided/` にしか無いなら停止する。**決まっていないものを作業にしない。**

手順:
1. `work/` の既存連番を調べ、最大+1 を 4桁ゼロ詰めで NNNN とする(無ければ 0001)。
   **この番号はシナリオ ID とは無関係**(ID の先頭4桁は論点番号。@.claude/rules/impl-rules.md N-2)。
2. `work/NNNN-$ARGUMENTS/` に2ファイルを作る。**先頭に反映元(`specs/` `design/` の該当箇所)を書く。**
   - `tasks.md` … テスト先行のチェックリスト(下記の形)
   - `diff.md` … ADDED / MODIFIED / 完了条件
3. 対象シナリオ ID を `specs/` から拾って列挙し、作業範囲を報告する。
4. **テストと実装は書かない。** 着手には人間の明確な許可が要る
   (@.claude/rules/test-rules.md「着手の許可」)。許可が出たら `/run-loop` へ。

tasks.md の形:
```markdown
- [ ] spec の各シナリオに対応する失敗**単体**テストを書く(Red)
- [ ] テストが赤になることを確認
- [ ] 最小実装で緑にする(Green)
- [ ] リファクタ(全緑維持)
- [ ] **総合**テスト(tests/integration/)で経路を通し緑にする
- [ ] diff.md を更新し、この作業フォルダを閉じる
```

> `work/` は **git 追跡外**(手元の作業管理)。共有すべき決定は `decisions/`、
> 正本は `specs/` `design/` にある。作業フォルダに仕様や設計を書き足さない。
