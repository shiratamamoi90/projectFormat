#!/usr/bin/env bash
# 自前 validate(OpenSpec の validate --strict 相当の最小版)。
# 検査項目の正本は @.claude/rules/impl-rules.md「命名規則」N-8。項目を増やしたら N-8 も直す。
# 依存: bash(comm のプロセス置換)/ python3(spec・用語集の解析)。sh では動かない。
#
# なぜ cd するか:hook・CI・任意の cwd から呼ばれても同じ結果にするため
# (相対パスのまま呼ばれると specs/ が見つからず「NG が無い」と誤報告する)。
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

GLOSSARY="specs/glossary.md"
SCENARIO_ID='S[0-9]{4}_[0-9]{2}'
EXAMPLE_MARK='-example-'   # 記入例(TEMPLATE.md「このリポジトリの現在の状態」)。実作業ではない
MAX_SHOW=10
fail=0

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
# spec 文書の解析はここ1箇所だけで行う。シナリオ見出しの書式を bash 側にも書くと
# 同じ知識が2箇所になり、片方だけ直して検査がすり抜ける(@impl-rules.md「共通化」)。
# 出力は ERR(書式NG)と ID(ファイルとシナリオ ID の対)の2種類。
#
# 対象ファイルは引数で渡す(パイプ + xargs にすると heredoc と stdin を取り合い、
# python がプログラムを読めずに黙って何も検査しなくなる)。
mapfile -t spec_docs < <(find specs changes -name '*.md' 2>/dev/null | sort)
spec_out=""
if [ "${#spec_docs[@]}" -gt 0 ]; then
  spec_out=$(python3 - "${spec_docs[@]}" <<'PY'
import re, sys

HEADING = re.compile(r'^### (S\d{4}_\d{2}) +\S')
NEAR_MISS = re.compile(r'^### S[-\d]')   # `S-0001-01` 等のハイフン形も拾う(N-2 はハイフン禁止)
KEYWORDS = ('GIVEN', 'WHEN', 'THEN')

for path in sys.argv[1:]:
    lines = open(path, encoding='utf-8').read().splitlines()
    headings = [(no, m.group(1))
                for no, line in enumerate(lines, 1)
                if (m := HEADING.match(line))]
    # spec.md は必ずシナリオを持つ。それ以外(用語集・確定仕様の目次など)は
    # シナリオ見出しを持つときだけ仕様文書として検査する。
    if not headings and not path.endswith('/spec.md'):
        continue

    for no, line in enumerate(lines, 1):
        if NEAR_MISS.match(line) and not HEADING.match(line):
            print(f"ERR\t{path}:{no} 見出しが `### S<4桁>_<2桁> <名前>` の形式でない: {line}")
    if not headings:
        print(f"ERR\t{path} に `### S<4桁>_<2桁> <名前>` のシナリオ見出しが無い")
        continue

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
PY
  )
fi
spec_err=$(pick ERR "$spec_out")
# 記入例は実作業ではないため ID 照合から外す(消すまで未実装 NG が出続けるのを防ぐ)。
id_pairs=$(pick ID "$spec_out" | grep -v -- "$EXAMPLE_MARK" || true)
# 払い出し済み ID の一覧。重複検査と spec↔test 照合の両方が使うので1回だけ作る。
spec_id_hits=$(nonempty "$(printf '%s\n' "$id_pairs" | cut -f2)")

section "spec の書式(見出し・GIVEN/WHEN/THEN)"
if [ -n "$spec_err" ]; then report_ng "spec の書式が仕様どおりでない" "$spec_err"; else report_ok; fi

# ---------------------------------------------------------------------------
section "シナリオ ID の払い出し(N-2)"
# 同じ ID を2つの見出しが持つ = 払い出しの重複。ID は不変・再利用禁止。
dup_spec_ids=$(printf '%s\n' "$spec_id_hits" | sort | uniq -d)
# ID の先頭4桁は change 番号。フォルダ番号とずれると spec とテストの追跡が壊れる。
number_mismatch=$(printf '%s\n' "$id_pairs" | awk -F'\t' '
  $1 ~ /^changes\// {
    split($1, parts, "/")
    folder_number = substr(parts[2], 1, 4)
    id_number = substr($2, 2, 4)
    if (id_number != folder_number)
      print $1 ": " $2 " (フォルダ番号 " folder_number " と不一致)"
  }' | sort -u)
if [ -n "$dup_spec_ids" ] || [ -n "$number_mismatch" ]; then
  [ -n "$dup_spec_ids" ] && report_ng "同じシナリオ ID が複数の見出しで払い出されている" "$dup_spec_ids"
  [ -n "$number_mismatch" ] && report_ng "シナリオ ID の change 番号がフォルダ番号と一致しない" "$number_mismatch"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "用語集の書式(N-1)"
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
section "用語の揺れ(N-1)"
hits=""
for word in $banned; do
  hit=$(grep -rnw -- "$word" src tests 2>/dev/null)
  [ -n "$hit" ] && hits="${hits}${hit}"$'\n'
done
hits=$(nonempty "$hits")
if [ -n "$hits" ]; then
  report_ng "用語集の「使ってはいけない表記」が使われている" "$hits"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "spec ↔ test のシナリオ ID 照合(N-2)"
test_id_hits=$(grep -rhoE "$SCENARIO_ID" tests 2>/dev/null || true)   # 下の重複検査も使う
spec_ids=$(printf '%s\n' "$spec_id_hits" | sort -u)
test_ids=$(nonempty "$test_id_hits" | sort -u)
missing=$(comm -23 <(nonempty "$spec_ids") <(nonempty "$test_ids"))
ghost=$(comm -13 <(nonempty "$spec_ids") <(nonempty "$test_ids"))
if [ -n "$missing" ] || [ -n "$ghost" ]; then
  [ -n "$missing" ] && report_ng "spec にあって test が無い(未実装)" "$missing"
  [ -n "$ghost" ] && report_ng "test にあって spec に無い(幽霊テスト)" "$ghost"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "1シナリオ1テスト(N-2)"
dup_test_ids=$(nonempty "$test_id_hits" | sort | uniq -d)
if [ -n "$dup_test_ids" ]; then
  report_ng "同じシナリオ ID のテストが複数ある(1シナリオ = 1テスト関数)" "$dup_test_ids"
else
  report_ok
fi

# ---------------------------------------------------------------------------
section "否定形ブール(N-4)"
# `is_not_x` / `shouldNotX` / `not` で終わる `should_not` まで拾う。
neg=$(grep -rnE '\b(is|has|can|should)(_not_|_not\b|Not[A-Z])' src tests 2>/dev/null)
if [ -n "$neg" ]; then
  report_ng "否定形のブール名がある(肯定形を定義し呼び出し側で否定する)" "$neg"
else
  report_ok
fi

# ---------------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then echo "整合OK"; else echo "整合NG(上記を修正)"; fi
exit "$fail"
