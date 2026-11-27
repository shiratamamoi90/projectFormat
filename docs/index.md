# 目録(index)

> **docs/ の入口。** 全ページを1行要約付きで載せる。LLM が `/ingest`・`/decide`・`/tidy` の
> たびに更新し、載っていないページは `scripts/validate.sh` が孤立ページとして NG にする。
> 読む人はまずここから入る。運用の正本は `.claude/rules/doc-rules.md`「wiki の運用」。

## 全体

- [全体像](overview.md) — 何を作るか・どこまで決まったか
- [用語集](glossary.md) — ドメイン語彙の正(規範)
- [作業記録](log.md) — 取り込み・決定・整理の時系列

## 要件定義(規範)

- [要件:状態異常](requirements/0001-example-status-condition.md) — まひの付与・行動制限・回復(S0001_01〜05)(記入例)

## 基本設計(規範)

- [基本設計:対戦エンジン](design/0001-example-basic-design.md) — 合法手の責務・行動の契約・概念データ(記入例)

## 一次資料の要約

- [要約:架空ルールブック v1.0](summaries/rulebook-example-v1.md) — 状態異常とベンチ上限の規定(記入例)

## 概念・横断

- まだ無い
