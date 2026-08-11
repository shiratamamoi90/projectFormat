# 技術スタックとコマンド(技術要素)

エージェントへのルールではなく、このプロジェクトの技術的な事実を置く。
バージョンは固定し、変えたらここを更新する。CLAUDE.md からはこのファイルを参照する。

> **`<...>` は不備ではなく、プロジェクト開始時に人間が埋める記入スロット**(リポジトリ直下の
> `TEMPLATE.md`「使い方」手順1)。空のままならまだ開始状態(未確定)であり、エージェントは自分で
> 埋めず、記入を人間に案内して確定を待つ。埋めるまで実装を始めない(CLAUDE.md「エージェントの制約」)。

## Stack

- 種別: <architecture.md「種別ごとの Adapt」の表から選ぶ(Web/業務アプリ・CLI/ツール・ライブラリ・
  MLコンペ・研究/PoC)。種別が決まると「正」と Adapt 層の中身が決まる>
- 言語/FW: <バージョンを明記。**このフォーマットは言語を限定しない。既定言語は無く、下の Commands も
  空のスロットで出荷される**(空のままなら hooks は何もせず NOTE を出す)。決めたら次の5つを
  **併せて**記入する — 1つでも空のままだと動かないか黙って素通りする>
  1. `.claude/settings.json` の permissions に、テスト・整形・依存管理のコマンドを
     `Bash(<コマンド>:*)` の形で追記する(例: `Bash(pytest:*)` / `Bash(go:*)` / `Bash(npm:*)` /
     `Bash(mvn:*)`)。既定では言語非依存のものしか許可していない
  2. 下の「Commands」の表と、`scripts/hooks.sh` 冒頭の `TEST_CMD` / `FORMAT_CMD` /
     `FORMAT_EXTENSIONS`(整形・テストの実コマンド。表が正本で、写し先はそこだけ)
  3. 下の「命名の記法」(準拠する規約・強制ツール)
  4. **テストの置き場** — `tests/core` `tests/app` `tests/integration` は一例で、
     Go は実装と同居、Java は `src/test/java/...` が標準。変えるなら
     `scripts/validate.sh` 冒頭の `SRC_DIRS` / `TEST_DIRS`・上の 2.・TEMPLATE.md のツリーを同時に直す
     (崩してはいけない条件は @test-rules.md「単体テストと総合テスト」の置き場が正本)
  5. `.gitignore` の区分2「生成物・キャッシュ」— **未追跡ファイルとして出るものは言語ごとに違う**
     (Python なら `__pycache__/` `.pytest_cache/`、Node なら `node_modules/` `dist/` など)。
     中身と言語別の代表例は `gitignore.template` の区分2 が正本(ここに書き写さない)
- 環境: <WSL2 / Docker / GPU passthrough など>
- 依存管理: <lockfile / requirements など。バージョン固定の方法>

## Commands

- テスト(全部): `<全テストを回すコマンド>`(Stop フック `scripts/hooks.sh test` が使用 = `TEST_CMD`。
  **記入すると停止時に自動実行される。** これは人間が有効化した機械実行で、エージェントが
  自分でテストを実行する許可とは別 — @test-rules.md「着手の許可」。自動実行を止めるなら空に戻す)
- 単体テスト: `<単体だけ回すコマンド>`(/run-loop のサイクル中に使用)
- 総合テスト: `<総合だけ回すコマンド>`(change を閉じる前に使用)
- フォーマット: `<1ファイルを整形するコマンド>`(PostToolUse フック `scripts/hooks.sh format` が
  使用 = `FORMAT_CMD`。対象拡張子は同スクリプトの `FORMAT_EXTENSIONS`)
- 検証: `scripts/validate.sh`(**言語非依存。記入不要**。/validate と Stop フック
  `scripts/hooks.sh validate` が使用)
- 計測: `<計測コマンド>`(非決定的な論点を測る種別 — MLコンペ・研究/PoC — のみ記入。
  Web/CLI/ライブラリでは不要のまま残してよい)

> この表が hooks / skill の呼ぶコマンドの正本。hooks 側を変えたらこの表も一致させる。
> settings.json / settings.team.json には**イベント名と `scripts/hooks.sh <引数>` だけ**を書き、
> コマンドを JSON 文字列に直書きしない(引用が壊れやすく、hook の stdin JSON も扱えない)。
> 記入例(言語ごと。**どれも既定ではない。採用したものを書く**):
>
> | | テスト(全部) | フォーマット | 拡張子 |
> |---|---|---|---|
> | Python | `pytest tests/ -q` | `ruff format` | `py` |
> | Go | `go test ./...` | `gofmt -w` | `go` |
> | TypeScript | `npm test` | `npx prettier --write` | `ts tsx` |
> | Java | `mvn -q test` | `mvn spotless:apply` | `java` |
> | Rust | `cargo test` | `rustfmt` | `rs` |
>
> 言語を決めたときの記入箇所は、上の「Stack」の言語/FW に5つまとめてある
> (この表と `scripts/hooks.sh` はそのうちの2番目)。

## 命名の記法(言語確定時に埋める)

原則:**その言語の公式スタイルガイドに従う。独自ルールを作らない**(『リーダブルコード』4章)。
記法違反は**フォーマッタ/リンタで機械的に落とす。レビューで指摘しない**(人手で守らせない)。

言語そのものは上の「Stack」の言語/FW が正本(同じ事実を2箇所に書かない)。

- 準拠する規約: `<未定>`(例:PEP 8 / Google Java Style / typescript-eslint recommended)
- 強制ツール: `<未定>`(例:ruff / spotless / eslint + prettier)

「このプロジェクト」列を埋めるのが記入作業。右3列は記入例なので、採用した言語の列をそのまま写す
(対象の一覧を2つの表に分けて持たない — 片方に行を足し忘れる)。

| 対象 | このプロジェクト | 記入例: Python | Java | TypeScript |
|---|---|---|---|---|
| 関数 | `<未定>` | `snake_case` | `camelCase` | `camelCase` |
| 変数 | `<未定>` | `snake_case` | `camelCase` | `camelCase` |
| 定数 | `<未定>` | `UPPER_SNAKE_CASE` | `UPPER_SNAKE_CASE` | `UPPER_SNAKE_CASE` |
| 型・クラス | `<未定>` | `PascalCase` | `PascalCase` | `PascalCase` |
| enum 型名 | `<未定>` | `PascalCase` | `PascalCase` | `PascalCase` |
| enum 値 | `<未定>` | `UPPER_SNAKE_CASE` | `UPPER_SNAKE_CASE` | `UPPER_SNAKE_CASE` |
| モジュール | `<未定>` | `snake_case` | `lowercase`(パッケージ) | `kebab-case` |
| ソースファイル名 | `<未定>` | `snake_case.py` | `PascalCase.java` | `kebab-case.ts` |
| テストファイル名 | `<未定>` | `test_<対象>.py` | `<対象>Test.java` | `<対象>.test.ts` |
| テスト関数名 | `<未定>` | `test_S0001_01_<英語>` | `S0001_01_<英語>` | `it('S0001_01 <英語>')` |
| 非公開識別子 | `<未定>` | 先頭 `_` | `private` | `#` または `private` |

### 記法に優先する制約

記法より @impl-rules.md「命名規則」が優先する。次の3点は言語規約に合わせて崩さない。

1. **テスト関数名にシナリオ ID を一字も改変せず含める**(N-2)。camelCase の言語でも
   `S0001_01` の `S` と `_` を保つ(`s000101` / `S000101` に変換しない)。崩すと機械照合が壊れる。
2. **ソースファイル名は用語集の名詞形から作る**(N-1 / N-7)。ケース変換だけ言語規約に合わせ、
   **語そのものを変えない**(`paralysis` → `Paralysis.java` は可、`Para.java` は不可)。
3. **N-3 の接頭辞と契約が言語慣習より優先する。** 例:Java の Bean 規約(`getX()`)より
   N-3 の「`get_*` は保持値をそのまま返す」契約を守る。計算するなら `computeX()` にする。

## このプロジェクトの「正」(source of truth)

<何を最終的な正とするか。例:公式仕様 / 要件定義書 / データ契約 / 評価指標とコンペルール>

- ここに無い挙動を自己解釈で足さない(制約は CLAUDE.md「エージェントの制約」)。
- 曖昧な点は `[要確認]` として人間に確認する。勝手に決めない。
- 種別による差し替え(Adapt 層)は @architecture.md の「種別ごとの Adapt」を参照。
