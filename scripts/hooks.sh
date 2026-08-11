#!/usr/bin/env bash
# hooks の実体(4イベントを1本に集約)。settings.json / settings.team.json には
# 「イベント名 + このスクリプト + 引数」だけを書き、処理はここに置く
# (JSON 文字列にコマンドを直書きすると引用が壊れ、hook の stdin JSON も扱えない)。
# 使い方: scripts/hooks.sh <format|test|veto|validate>
# 実行するコマンドの正本は @.claude/rules/stack.md「Commands」(下の記入スロットに写す)。
#
# このスクリプト自体の動作要件は bash と python3(hook の stdin JSON を読むため)で、
# **対象プロジェクトの実装言語とは無関係**。Go でも Java でも TS でも同じものが動く。
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

# ---------------------------------------------------------------------------
# 記入スロット:**このフォーマットは対象プロジェクトの言語を限定しない。**
# 言語が決まったら埋める(TEMPLATE.md「使い方」手順1)。値の正本は
# @.claude/rules/stack.md「Commands」で、ここはその唯一の写し先。
#
# 空のままなら該当 hook は何もせず素通りし、NOTE で未記入を知らせる
# (黙って素通りすると「強制しているつもりで何も強制していない」状態になるため)。
TEST_CMD=""             # 例: pytest tests/ -q │ go test ./... │ npm test │ mvn -q test
FORMAT_CMD=""           # 例: ruff format │ gofmt -w │ npx prettier --write │ rustfmt
FORMAT_EXTENSIONS=""    # 整形対象の拡張子(空白区切り)。例: py │ go │ ts tsx js │ java rs
# ---------------------------------------------------------------------------

# プロジェクト固有の危険コマンド(本番マイグレーション・削除など)はここに追記する。
# 方針(rules)に書くだけでは強制にならない。言語に依らず共通。
DANGEROUS_PATTERNS=('rm -rf' 'git push --force' 'git push -f')

case "${1:-}" in
  format)
    # PostToolUse(Edit|Write): 編集したファイルだけ整形する(Core)。
    # 拡張子で絞るのは、整形ツールにドキュメント等を渡すと毎回パースエラーになるため。
    path=$(read_tool_input file_path)
    [ -n "$path" ] && [ -f "$path" ] || exit 0
    if [ -z "$FORMAT_CMD" ] || [ -z "$FORMAT_EXTENSIONS" ]; then
      echo "NOTE: FORMAT_CMD / FORMAT_EXTENSIONS が未記入(scripts/hooks.sh 冒頭。stack.md「Commands」を写す)"
      exit 0
    fi
    for ext in $FORMAT_EXTENSIONS; do          # 空白区切りを分割するため意図的に非クォート
      case "$path" in
        *."$ext")
          # $FORMAT_CMD も引数付き(`npx prettier --write` 等)を許すため非クォート。
          $FORMAT_CMD "$path" >/dev/null 2>&1 \
            || echo "NOTE: 整形に失敗($path)。stack.md の環境構築を確認"
          break ;;
      esac
    done
    ;;
  test)
    # Stop: 全テストを回して通知する(Core)。落ちてもブロックしないのは Red フェーズ
    # (実装前の意図的な赤)を妨げないため。赤確認の担保は /run-loop が持つ
    # (@.claude/rules/test-rules.md「赤確認の担保は『実行(skill)』」)。
    #
    # これは**人間が TEST_CMD を記入して有効化した機械実行**であって、
    # 「エージェントが自分でテストを実行してよい」という意味ではない
    # (@.claude/rules/test-rules.md「着手の許可」)。エージェント側の実行には都度の許可が要る。
    # 自動実行そのものを止めたいときは TEST_CMD を空に戻す(空なら NOTE だけ出して何もしない)。
    if [ -z "$TEST_CMD" ]; then
      echo "NOTE: TEST_CMD が未記入(scripts/hooks.sh 冒頭。stack.md「Commands」を写す)"
      exit 0
    fi
    out=$($TEST_CMD 2>&1); code=$?           # 引数付きコマンドを許すため非クォート
    printf '%s\n' "$out" | tail -5
    case "$code" in
      0) ;;
      127) echo "NOTE: テストコマンドが見つからない($TEST_CMD)。stack.md の環境構築を先に行う" ;;
      # 「テストが1件も無い」ときの終了コードはツールごとに違う(pytest は 5、go test は 0)。
      # 言語を限定しないため個別に分岐せず、まとめてこの1本で知らせる。
      *)   echo "TESTS FAILING — Red フェーズ(実装前の赤)か、まだテストが無い段階なら想定どおり。そうでなければ停止前に直すこと" ;;
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
    # Stop: 整合検査を回して通知する(Scale)。NG でもブロックしないのは、要件を書いた直後や
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
