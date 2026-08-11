#!/usr/bin/env bash
# hooks の実体(4イベントを1本に集約)。settings.json / settings.team.json には
# 「イベント名 + このスクリプト + 引数」だけを書き、処理はここに置く
# (JSON 文字列にコマンドを直書きすると引用が壊れ、hook の stdin JSON も扱えない)。
# 使い方: scripts/hooks.sh <format|test|veto|validate>
# 実行するコマンドの正本は @.claude/rules/stack.md「Commands」。
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 0

# hook の入力は stdin の JSON。編集先パスや実行されようとしているコマンドを環境変数で
# 受け取ることはできない($CLAUDE_FILE_PATH / $CLAUDE_TOOL_INPUT は存在せず、参照すると
# 空になり「動いているつもりで何もしていない」状態になる)。
read_tool_input() {   # $1 = tool_input のキー名
  python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input", {}).get(sys.argv[1], ""))
except Exception: pass' "$1" 2>/dev/null
}

# プロジェクト固有の危険コマンド(本番マイグレーション・削除など)はここに追記する。
# 方針(rules)に書くだけでは強制にならない。
DANGEROUS_PATTERNS=('rm -rf' 'git push --force' 'git push -f')

case "${1:-}" in
  format)
    # PostToolUse(Edit|Write): 編集したファイルだけ整形する(Core)。
    # .py に絞るのは、ruff にドキュメントを渡すと毎回パースエラーになるため。
    path=$(read_tool_input file_path)
    [ -n "$path" ] && [ -f "$path" ] || exit 0
    case "$path" in
      *.py) ruff format "$path" >/dev/null 2>&1 \
              || echo "NOTE: ruff format に失敗($path)。stack.md の環境構築を確認" ;;
    esac
    ;;
  test)
    # Stop: 全テストを回して通知する(Core)。落ちてもブロックしないのは Red フェーズ
    # (実装前の意図的な赤)を妨げないため。赤確認の担保は /run-loop が持つ
    # (@.claude/rules/test-rules.md「赤確認の担保は『実行(skill)』」)。
    out=$(pytest tests/ -q 2>&1); code=$?
    printf '%s\n' "$out" | tail -5
    case "$code" in
      0) ;;
      5)   echo "NOTE: テスト未作成(pytest: no tests collected)" ;;
      127) echo "NOTE: pytest 未インストール(stack.md の環境構築を先に行う)" ;;
      *)   echo "TESTS FAILING — Red フェーズ(実装前の赤)なら想定どおり。そうでなければ停止前に直すこと" ;;
    esac
    ;;
  veto)
    # PreToolUse(Bash): 破壊的・不可逆な操作を拒否する(Scale)。
    # exit 2 だけがツール実行をブロックし stderr がエージェントに返る(exit 1 では止まらない)。
    command_line=$(read_tool_input command)
    for pattern in "${DANGEROUS_PATTERNS[@]}"; do
      case "$command_line" in
        *"$pattern"*)
          echo "BLOCKED: 危険操作「$pattern」は人間の承認なしに実行しない(security-rules.md「危険操作」)" >&2
          exit 2 ;;
      esac
    done
    ;;
  validate)
    # Stop: 整合検査を回して通知する(Scale)。NG でもブロックしないのは、spec を書いた直後や
    # Red フェーズでは未実装 NG が正常な状態で、止めると作業が進まないため。CI では
    # scripts/validate.sh を直接呼び exit code で落とす。NG で停止させたいチームは
    # 次の行を `scripts/validate.sh || exit 2` に変える(exit 2 だけが Stop をブロックする)。
    scripts/validate.sh || true
    ;;
  *)
    echo "usage: scripts/hooks.sh <format|test|veto|validate>" >&2
    exit 1 ;;
esac
exit 0
