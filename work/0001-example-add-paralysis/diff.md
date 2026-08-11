# 差分 0001: まひ状態(記入例)

反映元:`docs/0001-example-status-condition.md`

## ADDED
- src/core/status.py
- tests/core/test_paralysis.py(単体・5シナリオ)
- tests/integration/test_paralysis_flow.py(総合・付与から回復までの1経路)

## MODIFIED
- src/core: get_legal_actions(行動制限)、apply_turn_end(回復)

## 完了条件
- [ ] tasks.md のチェックリストが全て埋まっている(ここに再掲しない)
- [ ] `docs/` のシナリオ ID がすべて `tests/` と対応している(`scripts/validate.sh`)
- [ ] baseline との比較が壊れていないことを計測で確認
