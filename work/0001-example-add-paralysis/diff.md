# 差分 0001: まひ状態(記入例)

反映元:要件 S0001_01〜05 / 基本設計「構成要素と責務」(場所は `docs/index.md` から引く)

## ADDED
- src/core/status_condition.py
- tests/core/test_status_condition.py(単体・5シナリオ)
- tests/integration/test_paralysis_flow.py(総合・付与から回復までの1経路)

## MODIFIED
- src/core: compute_legal_actions(行動制限)、apply_turn_end(回復)

## 完了条件
- [ ] tasks.md のチェックリストが全て埋まっている(ここに再掲しない)
- [ ] `docs/` のシナリオ ID がすべて `tests/` と対応している(`scripts/validate.sh`)
- [ ] まひ付与 → 攻撃・逃げが合法手から消える → ターン終了で回復、の経路が総合テストで緑
      (この行を実行可能にしたものが総合テスト — test-rules.md「総合テスト」)

> 決定的な作業なので、完了条件に計測(勝率・baseline 比較)を入れない。強さへの影響を見たいなら
> 非決定的な論点を別に開いて `result.md` で測る(二系統を混ぜない — CLAUDE.md「最重要ルール」)。
