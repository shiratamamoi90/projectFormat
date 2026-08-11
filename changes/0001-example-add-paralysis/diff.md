# 差分 0001: まひ状態

## ADDED
- specs/rule-engine.md に「状態異常」セクション
- src/engine/status.py
- tests/engine/test_paralysis.py(単体・5シナリオ)
- tests/integration/test_paralysis_flow.py(総合・付与から回復までの1経路)

## MODIFIED
- src/engine: get_legal_actions(行動制限)、apply_turn_end(回復)

## 完了条件
- [ ] tasks.md のチェックリストが全て埋まっている(ここに再掲しない)
- [ ] baseline 対戦が壊れていないことを eval で確認
