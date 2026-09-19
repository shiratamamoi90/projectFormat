---
name: where
description: いまどこにいるかを読み取り専用で報告する。効いている関門・発足の到達度・途中の作業・以降の宿題を集め、次の一手を1つ示す。
---

**読み取り専用。1バイトも書き換えない**(この skill の停止条件)。不足を見つけても直さず、
どの skill に渡すかだけを示す。着手もしない(@.claude/rules/test-rules.md「着手の許可」)。

`/validate` との違い:`/validate` は**整合が取れているか**(NG を出す検査)、`/where` は
**どこまで進んだか・次は何か**(現在地)。**整合の判定を再実装しない** — `scripts/validate.sh` を
1回実行し、その出力から残作業に当たるセクションだけを引く。目視判定を含む詳しい検査は `/validate`。

## 集めるもの

### 1. いま効いている関門

二系統の判定 / 決定の承認と着手の許可(**2つとも要る**)/ 整合性の優先順位。
**rules の本文を要約して貼らない**(写すと古くなる)。いまの作業に効くものだけを3〜5行で。

### 2. 現状

**開始状態か確定済みかの正本は `CLAUDE.md`「このリポジトリの現在の状態」。** まずこれを読む。
続けて発足の到達度を見る(未記入のまま作業に入るのを防ぐ):

```bash
grep -n '<[^<>]\{2,\}>' .claude/rules/stack.md | head   # 未記入スロット
grep -n '^TEST_CMD=\|^FORMAT_CMD=\|^FORMAT_EXTENSIONS=' scripts/hooks.sh
ls -d gitignore.template 2>/dev/null                     # 残っていれば未リネーム(除外が効いていない)
ls -d decisions/*/*-example-* docs/*-example-*.md work/*-example-* 2>/dev/null
grep -l PreToolUse .claude/settings.json                 # veto がマージ済みか(Scale)
grep -c 記入スロット README.md DEVELOPMENT.md            # 雛形の引用ブロックの残り
```

### 3. 途中の作業

- `decisions/undecided/` の各論点。**「現在の考え」から何を待っているかを抜き**、議論中と
  止まっているものを区別する(@.claude/rules/decision-rules.md「決まらないまま止めるとき」)。
- `work/NNNN-*/tasks.md` の未チェック項目。どの段(Red / Green / 総合)で止まっているか。
- `[要確認]` の残り。
- `validate.sh` の「要件 ↔ test」「未統合の決定」セクションの NG(= 未実装 / 未統合の残作業)。

### 4. 以降の宿題

`decisions/decided/*/topic.md` の**「決まらなかったこと(次の論点へ)」**を全部集め、まだ
`undecided/` にも `docs/` にも現れていないものを出す。**ここを読む口が無いと、発足や過去の決定で
仕分けた検討事項が誰にも拾われずに消える。**

### 5. 順序の警告

- 前提の論点が `undecided/` のまま後続が進んでいないか(@.claude/rules/decision-rules.md
  「前提が決まる前に先の論点を決めない」)。
- `work/` があるのに、その反映元の論点が未決定のまま残っていないか
  (@.claude/rules/architecture.md「終わり方」— 削除対象)。
- `decisions/undecided/` の結論が `docs/` や実装に先回りして現れていないか。

## 報告

1〜5 をこの順(上位から)で出し、最後に**次の一手を1つだけ**示す
(`/start-project` `/new-topic` `/decide` `/new-work` `/run-loop` `/validate` のどれか)。
**複数並べない** — 並べると選ぶ手間が人間に戻る。何も残っていなければ「進行中の作業なし」と報告する。
