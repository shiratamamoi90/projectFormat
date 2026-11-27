#!/usr/bin/env bash
# 自前 validate(OpenSpec の validate --strict 相当の最小版)。
# 検査項目の正本は @.claude/rules/impl-rules.md「命名規則」N-8。項目を増やしたら N-8 も直す。
# 依存: bash(comm のプロセス置換)/ python3(要件・用語集の解析)。sh では動かない。
#
# なぜ cd するか:hook・CI・任意の cwd から呼ばれても同じ結果にするため
# (相対パスのまま呼ばれると docs/ が見つからず「NG が無い」と誤報告する)。
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

GLOSSARY="docs/glossary.md"
# 検査対象のパス。**言語慣習に合わせてテストの置き場を変えたらここだけ直す**
# (Go は実装と同居、Java は src/test/java など。@.claude/rules/test-rules.md
# 「単体テストと総合テスト」の置き場)。下の3つの grep が共有するので、直書きすると
# 1箇所直し忘れて「テストを探せないまま OK」になる(@.claude/rules/impl-rules.md「ハードコード禁止」)。
SRC_DIRS=(src)
TEST_DIRS=(tests)
# 決定済みの正本と、議論の記録。要件シナリオは DOC_DIRS にだけ書く
# (decisions 側に重複させない — @.claude/rules/doc-rules.md「確定の流れ」)。
DOC_DIRS=(docs)
DECISION_DIR="decisions"
SCENARIO_ID='S[0-9]{4}_[0-9]{2}'
EXAMPLE_MARK='-example-'   # 記入例(CLAUDE.md「このリポジトリの現在の状態」)。実作業ではない
MAX_SHOW=10
fail=0

# docs/ は LLM Wiki として運用する(@.claude/rules/doc-rules.md「wiki の構成」)。
# 構成を変えたらここだけ直す — 下の検査と --normative-diff が同じ設定を共有する。
WIKI_INDEX="docs/index.md"     # 全ページの目録。孤立ページを出さないための入口
WIKI_LOG="docs/log.md"         # 追記専用の作業記録
# 規範ページ = 何を満たすか(要件定義・基本設計・用語)。中身の変更は /decide 経由だけ。
# これ以外の docs/ は説明ページで、LLM が /ingest・/tidy で自由に整理してよい。
NORMATIVE_PATHS=(docs/requirements docs/design "$GLOSSARY")
SUMMARY_DIR="docs/summaries"   # 一次資料の要約。出典(sources:)が必須
SOURCE_DIR="sources"           # 一次資料の原本。不変・既定で git 追跡外
# 不可視文字の検査対象 = エージェントが読む文書すべて(間接プロンプトインジェクション対策。
# @.claude/rules/security-rules.md「エージェントの防御」)。
AGENT_READ_PATHS=(CLAUDE.md README.md DEVELOPMENT.md .claude docs decisions "$SOURCE_DIR" src tests)

# python 側で共有する解析。シナリオ見出し・frontmatter・規範の行の取り出し方を検査ごとに
# 書くと、片方だけ直して検査と --normative-diff の判定がずれる(@impl-rules.md「共通化」)。
read -r -d '' PY_LIB <<'PYLIB'
import os, re, subprocess, sys
from collections import Counter

SCENARIO_HEADING = re.compile(r'^### (S\d{4}_\d{2}) +(\S.*)$')
MD_LINK = re.compile(r'\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
FENCE = re.compile(r'^\s*(```|~~~)')
TABLE_SEPARATOR = re.compile(r'^\|?[\s:|-]+\|?$')

def read_text(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()

def split_frontmatter(lines):
    """先頭の `---` で囲んだ YAML を (dict, 本文の行, 本文の開始行番号) で返す。"""
    if not lines or lines[0].strip() != '---':
        return {}, lines, 1
    for end in range(1, len(lines)):
        if lines[end].strip() == '---':
            meta = {}
            for line in lines[1:end]:
                key, sep, value = line.partition(':')
                if sep:
                    meta[key.strip()] = value.strip()
            return meta, lines[end + 1:], end + 2
    return {}, lines, 1

def meta_numbers(meta, key):
    return re.findall(r'\d{4}', meta.get(key, ''))

def outside_code(lines, first_no=1):
    """コードブロックの外の (行番号, 行) だけを返す。例示のコードを規範として数えないため。"""
    in_code = False
    for offset, line in enumerate(lines):
        if FENCE.match(line):
            in_code = not in_code
            continue
        if not in_code:
            yield first_no + offset, line

def normalize(line):
    """リンクの付け外しと空白の揺れでは意味が変わらないので、比較の前に落とす。"""
    text = MD_LINK.sub(lambda m: m.group(1), line)
    return ' '.join(text.split())

def normative_items(lines):
    """規範の記述 = 箇条書きと表の行(散文は説明扱い — doc-rules.md「規範ページの書き方」)。"""
    items = []
    for _, line in outside_code(lines):
        stripped = line.strip()
        if stripped.startswith('- ') or (stripped.startswith('|') and not TABLE_SEPARATOR.match(stripped)):
            items.append(normalize(stripped))
    return items

def scenarios(lines):
    """シナリオ ID -> (名前, 本文の箇条書き)。ID と THEN の結びつきまで比べるため。"""
    found, current = {}, None
    for _, line in outside_code(lines):
        match = SCENARIO_HEADING.match(line)
        if match:
            current = match.group(1)
            found[current] = [normalize(match.group(2))]
        elif line.startswith('#'):
            current = None
        elif current and line.strip().startswith('- '):
            found[current].append(normalize(line.strip()))
    return {key: tuple(value) for key, value in found.items()}
PYLIB
run_py() {   # $1 = プログラム本体、残り = 引数(argv で渡す。stdin は使わない)
  local program=$1; shift
  python3 -c "$PY_LIB"$'\n'"$program" "$@"
}

# ---------------------------------------------------------------------------
# --normative-diff [git-ref]: 規範ページの中身が ref(既定 HEAD)から変わったかだけを見る。
# /tidy(意味を変えない整理)は差分 0 を示して初めて完了できる。/decide では、変わった
# シナリオがその論点の ID だけであることを確かめる(@.claude/rules/doc-rules.md「wiki の運用」)。
if [ "${1:-}" = "--normative-diff" ]; then
  read -r -d '' DIFF_PY <<'PYDIFF'
ref, paths = sys.argv[1], sys.argv[2:]

def files_now():
    for path in paths:
        if os.path.isfile(path):
            yield path
        for base, _, names in os.walk(path):
            for name in names:
                if name.endswith('.md'):
                    yield os.path.join(base, name)

def files_at_ref():
    out = subprocess.run(['git', 'ls-tree', '-r', '--name-only', ref, '--', *paths],
                         capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line.endswith('.md')]

def read_ref(path):
    return subprocess.run(['git', 'show', f'{ref}:{path}'],
                          capture_output=True, text=True, check=True).stdout

def collect(read, files):
    items, found = Counter(), {}
    for path in files:
        _, body, _ = split_frontmatter(read(path).splitlines())
        items.update(normative_items(body))
        found.update(scenarios(body))
    return items, found

before_items, before_ids = collect(read_ref, files_at_ref())
after_items, after_ids = collect(read_text, sorted(set(files_now())))
changed = 0
for scenario_id in sorted(set(before_ids) | set(after_ids)):
    if scenario_id not in after_ids:
        print(f"消えたシナリオ: {scenario_id}"); changed += 1
    elif scenario_id not in before_ids:
        print(f"増えたシナリオ: {scenario_id}"); changed += 1
    elif before_ids[scenario_id] != after_ids[scenario_id]:
        print(f"名前か本文が変わったシナリオ: {scenario_id}"); changed += 1
for item, count in sorted((before_items - after_items).items()):
    print(f"消えた規範の行(×{count}): {item}"); changed += 1
for item, count in sorted((after_items - before_items).items()):
    print(f"増えた規範の行(×{count}): {item}"); changed += 1
print("規範の差分なし" if changed == 0 else f"規範の差分 {changed} 件")
sys.exit(1 if changed else 0)
PYDIFF
  run_py "$DIFF_PY" "${2:-HEAD}" "${NORMATIVE_PATHS[@]}"
  exit $?
fi

# 見出しは impl-rules.md N-8 の項目名と一字一句同じにする(/validate がこの名前で N-8 と対応づける)。
section() { echo "== validate: $1 =="; }
report_ok() { echo "  OK"; }

# NG を1行出し、該当箇所を最大 MAX_SHOW 件インデント表示する。
report_ng() {
  fail=1
  echo "  NG: $1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | head -n "$MAX_SHOW" | sed 's/^/    /'; fi
}

# comm / sort に空行を渡さないための整形。
nonempty() { printf '%s\n' "${1:-}" | grep -v '^$' || true; }

# python 側の出力から種類タグ($1 = ERR / ID / WORD)の行だけを取り出す。タグの剥がし方を
# 呼び出しごとに書くと、出力形式を変えたとき直し漏れた側が黙って空になる。
pick() { printf '%s\n' "${2:-}" | awk -F'\t' -v tag="$1" '$1 == tag { sub(/^[^\t]*\t/, ""); print }'; }

# ---------------------------------------------------------------------------
# 上の設定が指すパスが実在するかを最初に見る。**存在しないパスを黙って素通りさせない。**
# ディレクトリを改名して設定を直し忘れると、検査対象が0件のまま全項目 OK になり、
# 「検査しているつもりで何も見ていない」状態になる(実際にこれで要件↔test 照合が
# 空振りした)。ここで落とせば、改名の直し漏れが必ず表面化する。
section "検査対象パスの実在"
missing_paths=""
for path in "${SRC_DIRS[@]}" "${TEST_DIRS[@]}" "${DOC_DIRS[@]}" "$DECISION_DIR"; do
  [ -d "$path" ] || missing_paths="${missing_paths}${path}(ディレクトリが無い)"$'\n'
done
for path in "$GLOSSARY" "$WIKI_INDEX" "$WIKI_LOG"; do
  [ -f "$path" ] || missing_paths="${missing_paths}${path}(ファイルが無い)"$'\n'
done
for path in "${NORMATIVE_PATHS[@]}" "$SUMMARY_DIR" "$SOURCE_DIR"; do
  [ -e "$path" ] || missing_paths="${missing_paths}${path}(無い)"$'\n'
done
missing_paths=$(nonempty "$missing_paths")
if [ -n "$missing_paths" ]; then
  report_ng "scripts/validate.sh 冒頭の設定が実在しないパスを指している(改名の直し漏れ)" "$missing_paths"
else
  report_ok
fi

# ---------------------------------------------------------------------------
# 要件文書の解析はここ1箇所だけで行う。シナリオ見出しの書式を bash 側にも書くと
# 同じ知識が2箇所になり、片方だけ直して検査がすり抜ける(@impl-rules.md「共通化」)。
# 出力は ERR(書式NG)と ID(ファイルとシナリオ ID の対)の2種類。
#
# 対象ファイルは引数で渡す(パイプ + xargs にすると heredoc と stdin を取り合い、
# python がプログラムを読めずに黙って何も検査しなくなる)。
mapfile -t doc_files < <(find "${DOC_DIRS[@]}" -name '*.md' 2>/dev/null | sort)
doc_out=""
if [ "${#doc_files[@]}" -gt 0 ]; then
  read -r -d '' DOC_PY <<'PYDOC'
HEADING = SCENARIO_HEADING
NEAR_MISS = re.compile(r'^### S[-\d]')   # `S-0001-01` 等のハイフン形も拾う(N-2 はハイフン禁止)
KEYWORDS = ('GIVEN', 'WHEN', 'THEN')

for path in sys.argv[1:]:
    lines = open(path, encoding='utf-8').read().splitlines()
    headings = [(no, m.group(1))
                for no, line in enumerate(lines, 1)
                if (m := HEADING.match(line))]
    # 用語集・目次などシナリオを持たない文書は検査対象外。
    # シナリオ見出しを持つものだけを仕様文書として扱う。
    if not headings:
        continue

    for no, line in enumerate(lines, 1):
        if NEAR_MISS.match(line) and not HEADING.match(line):
            print(f"ERR\t{path}:{no} 見出しが `### S<4桁>_<2桁> <名前>` の形式でない: {line}")
    # 見出しごとの本文(次の見出しまで)に GIVEN/WHEN/THEN が揃っているか。
    # 本文の切れ目は `### ` で始まる行すべて。書式 NG の見出しを切れ目に含めないと、
    # その下の GIVEN/WHEN/THEN を直前のシナリオの本文として数えて欠落を見逃す。
    breaks = [no for no, line in enumerate(lines, 1) if line.startswith('### ')] + [len(lines) + 1]
    for no, scenario_id in headings:
        body = "\n".join(lines[no:next(b for b in breaks if b > no) - 1])
        for keyword in KEYWORDS:
            if keyword not in body:
                print(f"ERR\t{path}:{no} {scenario_id} に {keyword} がない")
        print(f"ID\t{path}\t{scenario_id}")
PYDOC
  doc_out=$(run_py "$DOC_PY" "${doc_files[@]}")
fi
doc_err=$(pick ERR "$doc_out")
# 記入例は実作業ではないため ID 照合から外す(消すまで未実装 NG が出続けるのを防ぐ)。
id_pairs=$(pick ID "$doc_out" | grep -v -- "$EXAMPLE_MARK" || true)
# 払い出し済み ID の一覧。重複検査と要件↔test 照合の両方が使うので1回だけ作る。
doc_id_hits=$(nonempty "$(printf '%s\n' "$id_pairs" | cut -f2)")

section "要件の書式"
if [ -n "$doc_err" ]; then report_ng "要件の書式が仕様どおりでない" "$doc_err"; else report_ok; fi

# ---------------------------------------------------------------------------
section "ID の払い出し"
# 同じ ID を2つの見出しが持つ = 払い出しの重複。ID は不変・再利用禁止。
dup_doc_ids=$(printf '%s\n' "$doc_id_hits" | sort | uniq -d)
# ID の先頭4桁は論点番号。**決定済み**の論点に対応していなければならない。
# 未決定(undecided)の番号で要件が書かれていたら「決まっていないものを先に書いた」合図で、
# このフォルダの核になる規律(@.claude/rules/doc-rules.md「確定の流れ」)が破れている。
folder_numbers() {   # $1 = undecided | decided
  find "$DECISION_DIR/$1" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's|.*/||; s|^\([0-9]\{4\}\).*|\1|' | grep -E '^[0-9]{4}$' | sort -u
}
decided_numbers=$(folder_numbers decided)
undecided_numbers=$(folder_numbers undecided)
number_mismatch=$(nonempty "$id_pairs" | awk -F'\t' -v decided="$decided_numbers" -v undecided="$undecided_numbers" '
  BEGIN {
    n = split(decided, a, "\n");   for (i = 1; i <= n; i++) if (a[i] != "") ok[a[i]] = 1
    m = split(undecided, b, "\n"); for (i = 1; i <= m; i++) if (b[i] != "") pending[b[i]] = 1
  }
  $2 != "" {                       # 記入例だけの状態では id_pairs が空になる
    id_number = substr($2, 2, 4)
    if (id_number in ok) next
    if (id_number in pending)
      print $1 ": " $2 " (論点 " id_number " はまだ undecided。決まる前に要件を書いている)"
    else
      print $1 ": " $2 " (decisions/ に論点 " id_number " が無い)"
  }' | sort -u)
if [ -n "$dup_doc_ids" ] || [ -n "$number_mismatch" ]; then
  [ -n "$dup_doc_ids" ] && report_ng "同じシナリオ ID が複数の見出しで払い出されている" "$dup_doc_ids"
  [ -n "$number_mismatch" ] && report_ng "シナリオ ID の先頭4桁に対応する論点が decisions/ に無い" "$number_mismatch"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "用語集の書式"
# 「使ってはいけない表記」を列位置で読むため、先に表の形を検査する。
# 出力は ERR(書式NG)と WORD(禁止表記)の2種類。
glossary_out=$(python3 - "$GLOSSARY" <<'PY'
import re, sys

path = sys.argv[1]
TERMS_HEADING = '## 用語'
COLUMN_COUNT = 5        # 仕様 | 名詞形 | 形容詞形 | 使ってはいけない表記 | 定義
BANNED_COLUMN = 4       # 1始まり

try:
    lines = open(path, encoding='utf-8').read().splitlines()
except OSError:
    print(f"ERR\t{path} が無い(ドメイン用語の正が未定義)")
    sys.exit(0)

in_terms = False
row_count = 0
for lineno, line in enumerate(lines, 1):
    if line.startswith('## '):
        in_terms = line.strip() == TERMS_HEADING
        continue
    if not in_terms or not line.lstrip().startswith('|'):
        continue
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if all(set(c) <= set('-: ') for c in cells):   # 区切り行
        continue
    if len(cells) != COLUMN_COUNT:
        print(f"ERR\t{path}:{lineno} 用語テーブルの列数が {len(cells)}(5列固定)")
        continue
    row_count += 1
    if row_count == 1:                             # ヘッダ行
        continue
    for word in re.findall(r'`([A-Za-z0-9_]+)`', cells[BANNED_COLUMN - 1]):
        print(f"WORD\t{word}")

if row_count < 2:
    print(f"ERR\t{path} の `{TERMS_HEADING}` に用語行が無い")
PY
)
glossary_err=$(pick ERR "$glossary_out")
banned=$(pick WORD "$glossary_out" | sort -u)
if [ -n "$glossary_err" ]; then
  report_ng "用語集の書式が崩れている(検査が列位置に依存している)" "$glossary_err"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "用語の揺れ"
hits=""
for word in $banned; do
  # 要件文書こそ用語の正本なので docs/ も見る。**用語集自身は除外**する
  # (「使ってはいけない表記」列にその語が並んでいるため、必ず自己ヒットする)。
  hit=$(grep -rnw -- "$word" "${SRC_DIRS[@]}" "${TEST_DIRS[@]}" "${DOC_DIRS[@]}" 2>/dev/null \
        | grep -v "^${GLOSSARY}:")
  [ -n "$hit" ] && hits="${hits}${hit}"$'\n'
done
hits=$(nonempty "$hits")
if [ -n "$hits" ]; then
  report_ng "用語集の「使ってはいけない表記」が使われている" "$hits"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "要件 ↔ test 対応"
test_id_hits=$(grep -rhoE "$SCENARIO_ID" "${TEST_DIRS[@]}" 2>/dev/null || true)   # 下の重複検査も使う
doc_ids=$(printf '%s\n' "$doc_id_hits" | sort -u)
test_ids=$(nonempty "$test_id_hits" | sort -u)
missing=$(comm -23 <(nonempty "$doc_ids") <(nonempty "$test_ids"))
ghost=$(comm -13 <(nonempty "$doc_ids") <(nonempty "$test_ids"))
if [ -n "$missing" ] || [ -n "$ghost" ]; then
  [ -n "$missing" ] && report_ng "要件にあって test が無い(未実装)" "$missing"
  [ -n "$ghost" ] && report_ng "test にあって要件に無い(幽霊テスト)" "$ghost"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "1シナリオ1テスト"
dup_test_ids=$(nonempty "$test_id_hits" | sort | uniq -d)
if [ -n "$dup_test_ids" ]; then
  report_ng "同じシナリオ ID のテストが複数ある(1シナリオ = 1テスト関数)" "$dup_test_ids"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "否定形ブール"
# `is_not_x` / `shouldNotX` / `not` で終わる `should_not` まで拾う。
neg=$(grep -rnE '\b(is|has|can|should)(_not_|_not\b|Not[A-Z])' "${SRC_DIRS[@]}" "${TEST_DIRS[@]}" 2>/dev/null)
if [ -n "$neg" ]; then
  report_ng "否定形のブール名がある(肯定形を定義し呼び出し側で否定する)" "$neg"
else
  report_ok
fi

# ---------------------------------------------------------------------------
# 論点の検査。二系統をフォルダで分けるのをやめた代わりに、種別タグを機械で担保する
# (@.claude/rules/architecture.md「二系統の対応表」)。出力は TAG / LINK の2種類。
topic_out=$(python3 - "$DECISION_DIR" <<'PY'
import os, re, sys

root = sys.argv[1]
# タグ行を1行だけ取り出し、選択肢が**1つに絞られているか**を見る。
# `種別: 決定的 / 非決定的` のようにテンプレの選択肢が残った状態を「記入済み」と
# 扱ってはいけない(雛形のまま素通りする)。`非決定的` は `決定的` を部分文字列に含むので、
# 数えるときは長い方を先に並べた交替で拾う。
KIND_LINE = re.compile(r'^.*種別:.*$', re.M)
KIND_WORDS = re.compile(r'非決定的|決定的')
STATE_LINE = re.compile(r'^.*状態:.*$', re.M)
STATE_WORDS = re.compile(r'未決定|決定済み')
STATE_FOR = {'undecided': '未決定', 'decided': '決定済み'}

def sole(line_re, word_re, text):
    """タグ行から選択肢を1つだけ読む。行が無い / 2つ以上並ぶなら None。"""
    line = line_re.search(text)
    if not line:
        return None
    found = word_re.findall(line.group(0))
    return found[0] if len(found) == 1 else None
LINK = re.compile(r'反映先')
# 反映先に S-ID・要件・基本設計・用語集(または docs/)が書かれていれば「docs/ に統合した」と宣言している。`—` だけなら
# 要件にも基本設計にも及ばない決定(詳細設計の決定など)。どちらとも読めないものは書き損じとして NG にする。
NEEDS_REFLECTION = re.compile(r'S\d{4}_\d{2}|docs/|要件|基本設計|用語集')
MEASURE_FILE = 'result.md'

for state in ('undecided', 'decided'):
    base = os.path.join(root, state)
    if not os.path.isdir(base):
        continue
    for name in sorted(os.listdir(base)):
        folder = os.path.join(base, name)
        topic = os.path.join(folder, 'topic.md')
        if not os.path.isdir(folder):
            continue
        if not os.path.isfile(topic):
            print(f"TAG\t{folder} に topic.md が無い")
            continue
        text = open(topic, encoding='utf-8').read()
        kind = sole(KIND_LINE, KIND_WORDS, text)
        if not kind:
            print(f"TAG\t{topic} の `種別:` が決定的 / 非決定的のどちらか1つに絞られていない(雛形のまま)")
        elif kind == '決定的' and os.path.isfile(os.path.join(folder, MEASURE_FILE)):
            # 決定的な論点に計測ファイルがある = 2つのループを混ぜた合図。
            print(f"TAG\t{topic} は種別が決定的なのに {MEASURE_FILE} が同居している")
        elif (kind == '非決定的' and state == 'decided'
              and not os.path.isfile(os.path.join(folder, MEASURE_FILE))):
            # 非決定的な論点は計測で決める。実測値なしで決定済みにしたら根拠が無い。
            print(f"TAG\t{topic} は種別が非決定的なのに {MEASURE_FILE} が無い(計測せずに決めている)")
        # 状態はフォルダの位置が正。書いてある状態がずれていたら、移動時の直し忘れか
        # 雛形のまま(@.claude/rules/doc-rules.md「確定の流れ」)。
        written_state = sole(STATE_LINE, STATE_WORDS, text)
        if written_state is None:
            print(f"TAG\t{topic} の `状態:` が未決定 / 決定済みのどちらか1つに絞られていない(雛形のまま)")
        elif written_state != STATE_FOR[state]:
            print(f"TAG\t{topic} は {state}/ にあるのに `状態: {written_state}` と書かれている")
        if state != 'decided':
            continue
        # 決定済みは反映先が書かれていないと、決めたまま docs/ に反映し忘れる。
        link = LINK.search(text)
        if not link:
            print(f"LINK\t{topic} に `反映先:` が無い(未統合の疑い)")
            continue
        # 反映先をファイルのパスで照合しない — /tidy がページを移すたびに、書き換え禁止の
        # decided/ 側が壊れるため。代わりに「docs/ のどこかがこの論点を参照しているか」を
        # 下の wiki 検査の結果と突き合わせる(シナリオ ID の先頭4桁か、frontmatter の decisions:)。
        link_line = text[link.start():].splitlines()[0]
        if NEEDS_REFLECTION.search(link_line):
            print(f"NEEDS\t{name[:4]}\t{topic}")
        elif '—' not in link_line:
            print(f"LINK\t{topic} の `反映先:` が S-ID・docs/・`—` のどれとも読めない")
PY
)
section "論点のタグ"
topic_tag=$(pick TAG "$topic_out")
if [ -n "$topic_tag" ]; then report_ng "論点の種別・状態のタグが雛形のまま・位置とずれている、または二系統が混ざっている" "$topic_tag"; else report_ok; fi

# ---------------------------------------------------------------------------
# wiki の検査(docs/ 全体)。出力は REF(参照されている論点番号)/ IDX(目録に無い孤立ページ)/
# LNK(切れたリンク)/ ORG(規範ページの由来・要約の出典)/ LOG(作業記録の書式)。
read -r -d '' WIKI_PY <<'PYWIKI'
index_path, log_path, summary_dir, source_dir = sys.argv[1:5]
decided = set(sys.argv[5].split())
normative = [p.rstrip('/') for p in sys.argv[6].split('\n') if p]
files = sys.argv[7:]
LOG_HEADING = re.compile(r'^## \[(\d{4}-\d{2}-\d{2})\] (ingest|decide|tidy|lint|query) \| \S')

def is_under(path, base):
    return path == base or path.startswith(base + '/')

linked_from_index = set()
for path in files:
    lines = read_text(path).splitlines()
    meta, body, first_no = split_frontmatter(lines)
    ids = scenarios(body)
    decisions = meta_numbers(meta, 'decisions')
    for number in {i[1:5] for i in ids} | set(decisions):
        print(f"REF\t{number}")
    if any(is_under(path, base) for base in normative):
        # 規範の記述(箇条書き・表)があるのに由来が無い = 決定を経ずに書いた疑い。
        if normative_items(body) and not decisions:
            print(f"ORG\t{path}: 規範の記述があるのに frontmatter の decisions: が無い")
        for number in decisions:
            if number not in decided:
                print(f"ORG\t{path}: decisions: の論点 {number} が decisions/decided/ に無い")
        for number in sorted({i[1:5] for i in ids} - set(decisions)):
            print(f"ORG\t{path}: シナリオの論点 {number} が decisions: に無い")
    if is_under(path, summary_dir) and not meta.get('sources'):
        print(f"ORG\t{path}: 要約ページに出典(frontmatter の sources:)が無い")
    for no, line in outside_code(body, first_no):
        for _, target in MD_LINK.findall(line):
            target = target.split('#')[0]
            if not target or re.match(r'^[a-z]+:', target):
                continue                      # URL・アンカーだけのリンクは対象外
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if path == index_path:
                linked_from_index.add(resolved)
            # 一次資料は既定で git 追跡外なので、他の人の手元には無いのが正しい。
            if is_under(resolved, source_dir):
                continue
            if not os.path.exists(resolved):
                print(f"LNK\t{path}:{no} リンク先が無い: {target}")

for path in files:
    if path not in (index_path, log_path) and path not in linked_from_index:
        print(f"IDX\t{path} が {index_path} から辿れない(孤立ページ)")

# 作業記録は時系列の追記専用。書式が揃っていれば grep で直近を引ける(LLM Wiki の log.md)。
previous = ''
for no, line in enumerate(read_text(log_path).splitlines() if os.path.isfile(log_path) else [], 1):
    if not line.startswith('## '):
        continue
    match = LOG_HEADING.match(line)
    if not match:
        print(f"LOG\t{log_path}:{no} 見出しが `## [YYYY-MM-DD] <ingest|decide|tidy|lint|query> | <題>` でない")
    elif match.group(1) < previous:
        print(f"LOG\t{log_path}:{no} 日付が前の記録より古い(追記専用。途中に挿入しない)")
    else:
        previous = match.group(1)
PYWIKI
wiki_out=""
[ "${#doc_files[@]}" -gt 0 ] && wiki_out=$(run_py "$WIKI_PY" "$WIKI_INDEX" "$WIKI_LOG" "$SUMMARY_DIR" \
  "$SOURCE_DIR" "$(printf '%s ' $decided_numbers)" "$(printf '%s\n' "${NORMATIVE_PATHS[@]}")" "${doc_files[@]}")

section "未統合の決定"
topic_link=$(pick LINK "$topic_out")
referenced_numbers=$(pick REF "$wiki_out" | sort -u)
unreflected=$(pick NEEDS "$topic_out" | awk -F'\t' -v refs="$referenced_numbers" '
  BEGIN { n = split(refs, a, "\n"); for (i = 1; i <= n; i++) seen[a[i]] = 1 }
  !($1 in seen) { print $2 " (docs/ のどのページも論点 " $1 " を参照していない)" }')
if [ -n "$topic_link" ] || [ -n "$unreflected" ]; then
  [ -n "$topic_link" ] && report_ng "決定済みなのに反映先が無い・読めない" "$topic_link"
  [ -n "$unreflected" ] && report_ng "反映先を宣言しているのに docs/ に統合されていない" "$unreflected"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "不可視文字"
# 人間には見えずエージェントだけが読む文字(タグ文字によるスマグリング、ゼロ幅、双方向制御)。
# 取り込んだ資料や skill に仕込まれると、レビューを素通りして指示として働く
# (@.claude/rules/security-rules.md「エージェントの防御」)。バイナリ(PDF 等)は読めないので
# 対象外 — 取り込む前にテキストへ変換する。
read -r -d '' INVISIBLE_PY <<'PYINV'
SUSPICIOUS = [(0xE0000, 0xE007F), (0x200B, 0x200F), (0x202A, 0x202E),
              (0x2060, 0x2064), (0x2066, 0x2069), (0xFEFF, 0xFEFF), (0x180E, 0x180E)]
MAX_BYTES = 5_000_000

def walk(paths):
    for path in paths:
        if os.path.isfile(path):
            yield path
        for base, dirs, names in os.walk(path):
            dirs[:] = [d for d in dirs if d != '.git']
            for name in names:
                yield os.path.join(base, name)

for path in walk(sys.argv[1:]):
    try:
        if os.path.getsize(path) > MAX_BYTES:
            continue
        text = read_text(path)
    except (OSError, UnicodeDecodeError):
        continue
    for no, line in enumerate(text.splitlines(), 1):
        for col, char in enumerate(line, 1):
            code = ord(char)
            if no == 1 and col == 1 and code == 0xFEFF:
                continue                      # 先頭の BOM は符号化の印で、指示を運ばない
            if any(low <= code <= high for low, high in SUSPICIOUS):
                print(f"{path}:{no}:{col} U+{code:04X}")
PYINV
invisible=$(run_py "$INVISIBLE_PY" "${AGENT_READ_PATHS[@]}")
if [ -n "$invisible" ]; then
  report_ng "エージェントが読む文書に不可視文字がある(意図しない指示が隠れていないか確認する)" "$invisible"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "索引とリンク"
wiki_idx=$(pick IDX "$wiki_out"); wiki_lnk=$(pick LNK "$wiki_out")
if [ -n "$wiki_idx" ] || [ -n "$wiki_lnk" ]; then
  [ -n "$wiki_idx" ] && report_ng "目録に載っていないページがある" "$wiki_idx"
  [ -n "$wiki_lnk" ] && report_ng "docs/ 内のリンクが切れている" "$wiki_lnk"
else
  report_ok
fi

section "規範ページの由来"
wiki_org=$(pick ORG "$wiki_out")
if [ -n "$wiki_org" ]; then report_ng "規範ページの由来、または要約の出典が無い・誤っている" "$wiki_org"; else report_ok; fi

section "作業記録の書式"
wiki_log=$(pick LOG "$wiki_out")
if [ -n "$wiki_log" ]; then report_ng "作業記録(log.md)の書式が崩れている" "$wiki_log"; else report_ok; fi

# ---------------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then echo "整合OK"; else echo "整合NG(上記を修正)"; fi
exit "$fail"
