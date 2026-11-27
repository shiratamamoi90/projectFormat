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

# hook の結果は JSON で返す。exit 0 で素の stdout に書いても、PostToolUse / Stop では
# **エージェントにも人間にも表示されない**(Claude Code 公式ドキュメント「hooks」)。
# 素の echo に戻すと「知らせているつもりで誰にも届かない」状態になる。
# stdout は JSON オブジェクト1つだけでないと解釈されないので、1回の起動で1回だけ呼ぶ。
MESSAGE_CHAR_LIMIT=9000   # 公式の上限 10,000 文字に余裕を持たせる
emit_json() {   # $1 = 種類(agent | user)、$2 = 本文
  python3 -c 'import json, sys
kind, text, limit = sys.argv[1], sys.argv[2][:int(sys.argv[3])], sys.argv[3]
if kind == "agent":   # PostToolUse: ツール結果と一緒にエージェントの文脈へ足す(ブロックしない)
    body = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}
else:                 # Stop: 人間に表示する
    body = {"systemMessage": text}
print(json.dumps(body, ensure_ascii=False))' "$1" "$2" "$MESSAGE_CHAR_LIMIT"
}
# Stop で人間向け(systemMessage)にするのは、Stop の additionalContext / decision:block は
# 停止を取り消して会話を続けさせるため。テスト結果のたびに続行すると Red フェーズの赤で
# 止まれなくなる(テストの実行・修正はエージェントが勝手にしない — test-rules.md「着手の許可」)。
notify_agent() { emit_json agent "$1"; }
notify_user()  { emit_json user "$1"; }

# ---------------------------------------------------------------------------
# 記入スロット:**このフォーマットは対象プロジェクトの言語を限定しない。**
# 言語が決まったら埋める(DEVELOPMENT.md「プロジェクト開始の手順」手順1)。値の正本は
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
# 書式は**拡張正規表現**(bash の `=~`)。コマンド行全体に対して照合する。
#   例: 'manage\.py[[:space:]]+migrate.*--database[= ]prod'  'DROP[[:space:]]+TABLE'
# `rm -rf` と force push はここに書かない — 下の veto が字句解析で判定する
# (文字列照合だと `rm -fr` / `rm -r -f` / `git push origin main --force` が素通りする)。
DANGEROUS_PATTERNS=()

case "${1:-}" in
  format)
    # PostToolUse(Edit|Write): 編集したファイルだけ整形する(Core)。
    # 拡張子で絞るのは、整形ツールにドキュメント等を渡すと毎回パースエラーになるため。
    path=$(read_tool_input file_path)
    [ -n "$path" ] && [ -f "$path" ] || exit 0
    if [ -z "$FORMAT_CMD" ] || [ -z "$FORMAT_EXTENSIONS" ]; then
      notify_agent "NOTE: FORMAT_CMD / FORMAT_EXTENSIONS が未記入のため整形していない(scripts/hooks.sh 冒頭。stack.md「Commands」を写す)"
      exit 0
    fi
    for ext in $FORMAT_EXTENSIONS; do          # 空白区切りを分割するため意図的に非クォート
      case "$path" in
        *."$ext")
          # $FORMAT_CMD も引数付き(`npx prettier --write` 等)を許すため非クォート。
          $FORMAT_CMD "$path" >/dev/null 2>&1 \
            || notify_agent "NOTE: 整形に失敗($path)。stack.md の環境構築を確認"
          break ;;
      esac
    done
    ;;
  test)
    # Stop: 全テストを回して通知する(Core)。落ちてもブロックしないのは Red フェーズ
    # (実装前の意図的な赤)を妨げないため。赤確認の担保は /run-loop が持つ
    # (@.claude/rules/test-rules.md「ループ厳守」末尾の注記)。
    #
    # これは**人間が TEST_CMD を記入して有効化した機械実行**であって、
    # 「エージェントが自分でテストを実行してよい」という意味ではない
    # (@.claude/rules/test-rules.md「着手の許可」)。エージェント側の実行には都度の許可が要る。
    # 自動実行そのものを止めたいときは TEST_CMD を空に戻す(空なら NOTE だけ出して何もしない)。
    if [ -z "$TEST_CMD" ]; then
      notify_user "NOTE: TEST_CMD が未記入のため停止時テストは動いていない(scripts/hooks.sh 冒頭。stack.md「Commands」を写す)"
      exit 0
    fi
    out=$($TEST_CMD 2>&1); code=$?           # 引数付きコマンドを許すため非クォート
    tail_lines=$(printf '%s\n' "$out" | tail -5)
    case "$code" in
      0)   verdict="TESTS PASSING" ;;
      127) verdict="NOTE: テストコマンドが見つからない($TEST_CMD)。stack.md の環境構築を先に行う" ;;
      # 「テストが1件も無い」ときの終了コードはツールごとに違う(pytest は 5、go test は 0)。
      # 言語を限定しないため個別に分岐せず、まとめてこの1本で知らせる。
      *)   verdict="TESTS FAILING — Red フェーズ(実装前の赤)か、まだテストが無い段階なら想定どおり。そうでなければ停止前に直すこと" ;;
    esac
    notify_user "$verdict${tail_lines:+$'\n'$tail_lines}"
    ;;
  veto)
    # PreToolUse(Bash): 破壊的・不可逆な操作を拒否する(Scale)。
    # exit 2 だけがツール実行をブロックし stderr がエージェントに返る(exit 1 では止まらない)。
    command_line=$(read_tool_input command)
    [ -n "$command_line" ] || exit 0
    # rm -rf と force push は字句解析で判定する。文字列の部分一致にしない理由:
    # フラグの順序(-fr)・分割(-r -f)・位置(push origin main --force)・refspec の `+`
    # で同じ操作を書けるため、部分一致では「止めているつもりで素通り」になる。
    # コマンドは argv で渡す(heredoc がプログラム側の stdin を使うため)。
    blocked=$(python3 - "$command_line" <<'PY'
import os, shlex, sys

SEPARATORS = set(';&|()')
# 実コマンドの前に付く語。これらを剥がしてから判定する(`sudo rm -rf` 等)。
WRAPPERS = {'sudo', 'env', 'command', 'exec', 'nohup', 'time', 'xargs', 'nice'}
SHELLS = {'sh', 'bash', 'zsh', 'dash'}
# 値を1つ取る git のグローバルオプション(サブコマンド名と取り違えないため)。
GIT_OPTIONS_WITH_VALUE = {'-C', '-c', '--git-dir', '--work-tree', '--namespace'}

def split_segments(command):
    """`;` `&&` `|` 等で区切った単純コマンドごとの語の並び。"""
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:          # 引用符の閉じ忘れ等。粗く分けてでも判定は続ける
        tokens = command.split()
    segment = []
    for token in tokens:
        if token and set(token) <= SEPARATORS:
            if segment:
                yield segment
            segment = []
        else:
            segment.append(token)
    if segment:
        yield segment

def strip_wrappers(words):
    while words:
        head = words[0]
        if '=' in head and not head.startswith('-'):      # FOO=1 rm ...
            words = words[1:]
        elif os.path.basename(head) in WRAPPERS:
            words = words[1:]
            while words and words[0].startswith('-'):      # sudo -E / xargs -0
                words = words[1:]
        else:
            break
    return words

def is_forced_recursive_rm(args):
    recursive = force = False
    for arg in args:
        if arg == '--':
            break
        if arg == '--recursive':
            recursive = True
        elif arg == '--force':
            force = True
        elif arg.startswith('-') and not arg.startswith('--'):
            recursive = recursive or 'r' in arg or 'R' in arg
            force = force or 'f' in arg
    return recursive and force

def is_force_push(args):
    words = iter(args)
    for arg in words:
        if arg in GIT_OPTIONS_WITH_VALUE:
            next(words, None)
        elif arg.startswith('-'):
            continue
        elif arg != 'push':
            return False
        else:
            break
    else:
        return False
    for arg in words:
        if arg == '--force' or arg.startswith('--force-with-lease'):
            return True
        if arg.startswith('-') and not arg.startswith('--') and 'f' in arg:
            return True
        if arg.startswith('+'):                            # +main は強制更新の refspec
            return True
    return False

def find_danger(command):
    for segment in split_segments(command):
        words = strip_wrappers(segment)
        if not words:
            continue
        name, args = os.path.basename(words[0]), words[1:]
        if name == 'rm' and is_forced_recursive_rm(args):
            return 'rm -rf'
        if name == 'git' and is_force_push(args):
            return 'git push --force'
        # `bash -c "..."` / `eval "..."` の中身も同じ規則で見る。それ以外の引数
        # (コミットメッセージ等)は中を見ない — 文言に rm -rf を含むだけで止めないため。
        if name in SHELLS and '-c' in args and args.index('-c') + 1 < len(args):
            inner = find_danger(args[args.index('-c') + 1])
        elif name == 'eval':
            inner = find_danger(' '.join(args))
        else:
            inner = None
        if inner:
            return inner
    return None

print(find_danger(sys.argv[1]) or '')
PY
)
    if [ -z "$blocked" ]; then
      for pattern in ${DANGEROUS_PATTERNS[@]+"${DANGEROUS_PATTERNS[@]}"}; do
        if [[ $command_line =~ $pattern ]]; then blocked=$pattern; break; fi
      done
    fi
    if [ -n "$blocked" ]; then
      echo "BLOCKED: 危険操作「$blocked」は人間の承認なしに実行しない(security-rules.md「危険操作」)" >&2
      exit 2
    fi
    ;;
  validate)
    # Stop: 整合検査を回して通知する(Scale)。NG でもブロックしないのは、要件を書いた直後や
    # Red フェーズでは未実装 NG が正常な状態で、止めると作業が進まないため。CI では
    # scripts/validate.sh を直接呼び exit code で落とす。
    # 結果は人間に表示する。OK のセクションは省き、NG の行と最終判定だけを渡す(上限内に収めるため)。
    #
    # NG で停止させたいチームは、notify_user の代わりに `printf '%s\n' "$out" >&2; exit 2` にする
    # (exit 2 の stderr がエージェントに「止まらず直せ」として返る)。ただし未実装 NG が正常な
    # Red フェーズでも止まれなくなる。Claude Code は連続8回で打ち切るが、それまで同じ NG で回り続ける。
    out=$(scripts/validate.sh 2>&1); code=$?
    if [ "$code" -eq 0 ]; then
      notify_user "validate: 整合OK"
    else
      # 見出しは NG のセクションだけ残す(どの N-8 項目の NG かを失わないため)。
      notify_user "$(printf '%s\n' "$out" | awk '
        /^== validate: / { header = $0; next }
        /^  OK$/         { header = ""; next }
        header != ""     { print header; header = "" }
                         { print }')"
    fi
    ;;
  *)
    echo "usage: scripts/hooks.sh <format|test|veto|validate>" >&2
    exit 1 ;;
esac
exit 0
