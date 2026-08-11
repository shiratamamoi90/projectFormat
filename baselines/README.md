# Baselines

**非決定的な論点を測るときの比較基準**(@.claude/rules/experiment-rules.md)。
最初にここを実装し、`requirements/` で仕様化する(baseline 自体は決定的なので TDD 対象)。
以下は記入例なので、プロジェクトに合わせて置き換える。

- `random` … 合法手から一様ランダムに選ぶ
- `greedy` … 1手先の評価値が最大の手を選ぶ

計測は「baseline をどれだけ上回ったか」でのみ評価する。結果は論点の `result.md` に残す。
