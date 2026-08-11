---
name: run-loop
description: 仕様ループの1サイクル(Red→Green→Refactor)を回す。承認済み spec がある change に対して使う。
---

引数 $ARGUMENTS で指定された change フォルダ(例: 0003-add-paralysis)に対し、TDD を1周回す。

前提確認:
- 対象 change の spec.md が人間に承認済みであること。未承認なら停止して確認を促す。

サイクル:
1. spec の未実装シナリオを1つ選ぶ。
2. そのシナリオに対応する**失敗する単体テスト**を tests/engine/(または tests/agent/)に書く。
3. テストを実行し、**赤であることを確認**して報告(緑なら検証になっていないので作り直す)。
4. テストを通す**最小実装**を src/ に書く。engine の依存方向(engine←agent←eval)を崩さない。
5. テストを実行し緑を確認。リファクタし全緑維持。このとき**共通化できる重複が無いか確認**する
   (@.claude/rules/impl-rules.md「共通化」。寄せる先は依存方向で決まる)。
6. tasks.md の該当項目にチェック。残シナリオがあれば次へ。
7. 全シナリオが緑になったら、**総合テスト**を tests/integration/ に書いて緑にする
   (@.claude/rules/test-rules.md「単体テストと総合テスト」)。単体だけで閉じない。
8. 総合テストが緑になってから specs/ 反映とアーカイブを提案。

各ステップで赤→緑の遷移を必ず示すこと。
