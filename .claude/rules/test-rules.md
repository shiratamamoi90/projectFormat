# テストのルール(テストはコード前提 = 先に書く)

## 着手の許可(このループに入る前の関門)

**テストと実装は、人間の明確な許可が無い限り作成も実行もしない。許可が出れば作成・実行してよい。**
CLAUDE.md「エージェントの制約」の同項がこのルールの宣言で、ここはその運用を書く。

- **どの場合でも有効。** 仕様ループ・探索ループ、バグ修正・リファクタ・「1行だけ」の修正、
  緊急対応 — どれも例外にしない。例外を1つ作ると、次からそれが根拠として使われる。
- **許可は作業ごと。** 前の作業(`work/NNNN-*`)でもらった許可を次の作業に流用しない。
  「テストを書いてよい」と「実装を書いてよい」も別の許可として扱う(Red の確認を挟むため)。
- **許可が無い間に進めてよいもの**:論点(`topic.md`)・要件(`docs/`)・
  作業計画(`tasks.md` / `diff.md`)などの文書、
  および「何をどう書くつもりか」の提案。**書かないだけでなく、実行もしない**
  (テスト・評価コマンドを走らせるのも「実施」にあたる)。
- **許可の求め方**:何を作るか(対象ファイルとシナリオ ID)と、実行するコマンドを示して確認を取る。
  黙って着手して事後承認を求めない。
- **担保**:/run-loop は許可の確認を経ないとサイクルに入らない(@.claude/skills/run-loop/SKILL.md)。
  Stop フックのテスト実行は人間が `TEST_CMD` を記入して有効化する機械実行で、
  **エージェントが自分でテストを実行してよいという意味ではない**(@stack.md「Commands」)。

## ループ厳守:仕様 → テスト → 実装 → テスト

0. **着手の許可を得る**(上の節。許可が無ければここで止まる)。
1. `docs/` の各シナリオに対し、**失敗する単体テストを先に書く**(Red)。
2. テストが赤になることを確認する(緑のテストは検証になっていない)。
3. テストを通す**最小実装**(Green)。
4. リファクタ。全テスト緑を維持。
5. 全シナリオが緑になったら**総合テストを書いて緑にする**。ここまでで作業を閉じられる
   (閉じ方は @architecture.md「終わり方」)。

> ループ名「仕様 → テスト → 実装 → テスト」の**前半のテストが単体(手順1)、後半のテストが総合(手順5)**。
> 単体だけで閉じない(なぜ両方書くかは下の「単体テストと総合テスト」)。

> **赤確認の担保**は「実行(skill)」が持つ:/run-loop が赤の確認・報告を経ないと実装に進めない手順にしている。
> hooks では意図的にブロックしない(Stop フックは通知のみ — Red フェーズの意図的な赤を妨げないため)。

## 対応関係

- 要件の1シナリオ = test の1メソッド。例: `test_S0001_02_paralyzed_actor_cannot_attack`
- **テスト名の付け方は @impl-rules.md N-2 が正本**(ID を一字も改変せず含める / ID だけの名前は禁止 /
  ID を書くのはテスト関数名だけ / 総合テストには付けない)。理由込みで N-2 にあるので書き写さない。
- 要件ごとに class / describe でグループ化し、`docs/` の見出しと一致させる。

## 何をテストするか / しないか

- **する(肯定側)**:core の全シナリオ、状態遷移、境界、エラー処理、勝敗/判定 —
  **その機能が満たすべき動作を満たしていること**。
- **する(否定側)**:**その機能が「してはいけない動作」をしていないこと。**
  禁止された操作・遷移が起きない / 対象外に波及しない / 意図しない副作用が無い
  (3種の中身と書き分けは @doc-rules.md「必須カバレッジ」が正本。ここに書き写さない)。
  肯定側だけのテストは「動くこと」しか守らないので、実装が余計なことをしても緑のまま通る。
  否定側も `docs/` のシナリオなので **1シナリオ = 1テスト**で書き、肯定側のテストに相乗りさせない
  (相乗りさせると、どちらが壊れて落ちたのか名前から分からない)。
- **する(非決定側でも)**:「クラッシュせず合法な出力を返す」「時間/メモリ予算を超えない」「再現性(同シードで同結果)」— これらは決定的なのでテスト対象。
- **しない**:強さ・精度・勝率(→ 非決定的な論点の result.md で測る。@experiment-rules.md)。

## 単体テストと総合テスト(どちらも書く)

一方だけでは不足。単体は「部品が仕様どおりか」、総合は「繋いだ経路が動くか」を守る。
どちらも決定的であること(強さ・精度は縛らない ← 上の「何をテストするか」)。

| | 単体テスト | 総合テスト |
|---|---|---|
| 置き場 | `tests/core/`(全シナリオ)、`tests/app/`(スモーク) | `tests/integration/` |
| 単位 | 1シナリオ = 1メソッド | 1要件(見出し)= 1経路 |
| 範囲 | 1関数・1状態遷移。外部 I/O を含めない | 複数コンポーネントの結合。実際の入出力・設定読み込みを通す |
| 速さ | 速い。Red→Green のサイクルで毎回回す | 遅くてよい。作業を閉じる前に回す |
| 落ちた意味 | その部品が仕様と違う | 部品は正しいが繋ぎ方・前提が違う |

**置き場のパスは一例であって、言語慣習に合わせて差し替えてよい**(このフォーマットは言語を
限定しない)。Go は実装と同居する `foo_test.go`、Java は `src/test/java/...` が標準。
差し替えるときは**次の3つを崩さない**(崩すと表の左右が混ざるか、機械検査が素通りする)。

1. **単体と総合を別の場所に分ける。** 速さと落ちた意味が違うため、まとめて回す単位を分離できなくなる。
2. **単体は core / app の別を保つ**(全シナリオ側とスモーク側)。
3. **パスを指す4箇所を同時に直す** — @stack.md「Commands」・`scripts/hooks.sh`・
   `scripts/validate.sh` 冒頭の `SRC_DIRS` / `TEST_DIRS`・TEMPLATE.md のツリー。
   1つでも残すと、テストを探せないまま「NG が無い」と誤報告する
   (差し替え箇所の一覧は @stack.md「Stack」の言語/FW)。

### 単体テスト

- `docs/` の各シナリオに1対1(上の「対応関係」に従う)。境界・異常系・**否定側**を網羅する。
- core は副作用を閉じ込めた純粋関数なので、状態を組み立てて `apply(state, action)` を直接呼ぶ。
- **副作用が無いことは「呼び出しの前後で入力が等しい」ことを検証して確かめる。** 戻り値だけを
  見ていると、引数を書き換える実装(N-3 違反)がテストを素通りする。
- 外部依存(ファイル・ネットワーク・時刻・乱数)は引数か fake で渡す。実物を呼ばない。

### 総合テスト

- **代表的な正常系を最初から最後まで通す経路を必ず1本用意する**(例:初期状態から決着まで1試合、
  入力ファイルを読んで出力を書くまで)。これが赤のまま作業を閉じない。
- 縛るのは**結合部の前提**:依存方向(core←app)を通した呼び出し、設定・シードの読み込み、
  エラーの伝播、外部入力の検証(@security-rules.md「入力と信頼境界」)。
- 非決定的要素は**シードを固定して決定的にする**。固定できないもの(実ネットワーク等)は fake に
  置き換える。再現できない総合テストは残さない(@impl-rules.md「不変条件」)。
- 単体で既に縛った分岐を総合で再検査しない(遅くなるだけ)。経路が通ることの確認に絞る。
- 総合テストは `work/NNNN-*/diff.md` の「完了条件」を実行可能にしたもの。先に赤で置いてから
  実装を進めてもよい。

## 回帰

- バグ修正時は、再現する**失敗テストを先に追加**してから直す。
- 単体で再現するなら単体に、結合部でしか再現しないなら総合に置く(バグの居場所と同じ層に置く)。

## 例(実装より先に書く)

**例は Python 記法で書いてあるが、フォーマットは言語を限定しない。** 他の言語では記法だけ
置き換える(対応は @impl-rules.md N-2 と @stack.md「命名の記法」)。**置き換えても崩さないのは
次の3つ** — シナリオ ID を一字も改変せず関数名に含める / 1シナリオ = 1テスト関数 /
GIVEN・WHEN・THEN の3段で書き、総合テストには ID を付けない。

単体(`tests/core/test_paralysis.py`)— 1シナリオ = 1メソッド:

```python
class TestParalysis:
    def test_S0001_02_paralyzed_actor_cannot_attack(self):
        state = make_battle_state(active_status="paralyzed")  # GIVEN
        actions = core.get_legal_actions(state)             # WHEN
        assert not any(a.kind == "attack" for a in actions)   # THEN

    def test_S0001_03_paralysis_is_cleared_at_turn_end(self):
        state = make_battle_state(active_status="paralyzed")
        assert core.apply_turn_end(state).active_status is None
```

総合(`tests/integration/test_paralysis_flow.py`)— 付与から回復までを1経路で通す:

```python
def test_paralysis_flow_through_one_turn():   # 総合テストに ID は付けない(N-2)
    # 単体で縛った分岐は再検査しない。結合して経路が通ることだけを見る。
    state = build_battle_state(seed=42)                   # シード固定 = 再現可能
    state = core.apply_status_condition(state, PARALYSIS)
    assert not any(a.kind == "attack" for a in core.get_legal_actions(state))
    state = core.apply_turn_end(state)
    assert core.get_legal_actions(state)                # 回復し行動可能に戻る
```

同じ S0001_02 を他の言語で書いた場合。**変わるのは記法だけで、上の3つは同じ**:

```java
// src/test/java/core/ParalysisTest.java — Java の標準配置に合わせて置き場を変えた場合
@Test
void S0001_02_paralyzedActorCannotAttack() {
    BattleState state = makeBattleState(Status.PARALYZED);        // GIVEN
    List<Action> actions = Engine.getLegalActions(state);         // WHEN
    assertTrue(actions.stream().noneMatch(Action::isAttack));     // THEN
}
```

```typescript
// tests/core/paralysis.test.ts
it('S0001_02 paralyzed actor cannot attack', () => {
  const state = makeBattleState({ activeStatus: 'paralyzed' });   // GIVEN
  const actions = core.getLegalActions(state);                  // WHEN
  expect(actions.some((a) => a.kind === 'attack')).toBe(false);   // THEN
});
```

`S0001_02` の綴りが3言語で一字も変わらない点に注意する。ここが崩れると `scripts/validate.sh` の
要件 ↔ test 照合が言語依存になり、機械検査が成立しない(理由は @impl-rules.md N-2)。
