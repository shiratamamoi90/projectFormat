# 作業記録(log)

> **追記専用の時系列。** 書き換えず、末尾に足すだけ。見出しは
> `## [YYYY-MM-DD] <種類> | <題>`(種類は ingest / decide / tidy / lint / query)に揃え、
> `scripts/validate.sh` が書式と日付順を検査する。直近の記録は次で引ける:
> `grep "^## \[" docs/log.md | tail -5`。下の2件は記入例(片づけるときに消す)。

## [2026-11-27] ingest | 架空ルールブック v1.0(記入例)

- 追加:summaries/rulebook-example-v1.md
- 規範との食い違い:なし。ベンチの上限は次に開く論点の候補として残した

## [2026-11-27] decide | 論点 0001 まひ状態の扱い(記入例)

- 統合:requirements/0001-example-status-condition.md(S0001_01〜05)、design/0001-example-basic-design.md
- 規範の差分(`--normative-diff`):増えたのは論点 0001 のシナリオと設計の行だけ
