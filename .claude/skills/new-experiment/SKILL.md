---
name: new-experiment
description: 新しい実験フォルダを作り、探索ループ(仮説→設定→計測→考察)を開始する。勝率・精度など指標で測る非決定的な作業に使う。
---

引数 $ARGUMENTS を実験名(kebab-case)として、探索ループを開始する。

手順:
1. experiments/ の最大連番+1 を NNNN(4桁)とする。
2. `experiments/NNNN-$ARGUMENTS/` に hypothesis.md / config.yaml / result.md を作る。中身と書式は
   @.claude/rules/experiment-rules.md「単位」とテンプレに従う(config は1実験1変数だけ変える。
   result.md は空で置き、計測後に記入)。
3. baseline が存在するか確認し、無ければ先に baseline を作るよう促す。
4. 強さ・精度を test で縛ろうとしないこと。決定的な制約(クラッシュしない/予算内/再現性)が必要なら、それは別途 tests/ にテストとして追加するよう提案する。
5. **この skill が作るのは文書(hypothesis / config / result の雛形)だけ。** 実験の実装・実行も
   「テストと実装」と同じ扱いで、人間の明確な許可が無い限り着手しない
   (@.claude/rules/test-rules.md「着手の許可」。探索ループも例外ではない)。
