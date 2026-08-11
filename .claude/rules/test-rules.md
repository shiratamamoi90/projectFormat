# テストのルール(テストはコード前提 = 先に書く)

## ループ厳守:仕様 → テスト → 実装 → テスト

1. spec.md の各シナリオに対し、**失敗する単体テストを先に書く**(Red)。
2. テストが赤になることを確認する(緑のテストは検証になっていない)。
3. テストを通す**最小実装**(Green)。
4. リファクタ。全テスト緑を維持。
5. 全シナリオが緑になったら**総合テストを書いて緑にする**。ここまでで change を閉じられる。

> ループ名「仕様 → テスト → 実装 → テスト」の**前半のテストが単体(手順1)、後半のテストが総合(手順5)**。
> 単体だけで閉じない(なぜ両方書くかは下の「単体テストと総合テスト」)。

> **赤確認の担保は「実行(skill)」**:/run-loop が赤の確認・報告を経ないと実装に進めない手順にしている。
> hooks では意図的にブロックしない(Stop フックは通知のみ — Red フェーズの意図的な赤を妨げないため)。

## 対応関係

- spec の1シナリオ = test の1メソッド。例: `test_S0001_02_paralyzed_actor_cannot_attack`
- **テスト名の付け方は @impl-rules.md N-2 が正本**(ID を一字も改変せず含める / ID だけの名前は禁止 /
  ID を書くのはテスト関数名だけ / 総合テストには付けない)。理由込みで N-2 にあるので書き写さない。
- 要件ごとに class / describe でグループ化し、spec の見出しと一致させる。

## 何をテストするか / しないか

- **する**:engine の全シナリオ、状態遷移、境界、エラー処理、勝敗/判定。
- **する(非決定側でも)**:「クラッシュせず合法な出力を返す」「時間/メモリ予算を超えない」「再現性(同シードで同結果)」— これらは決定的なのでテスト対象。
- **しない**:強さ・精度・勝率(→ experiments/ の result.md で測る)。

## 単体テストと総合テスト(どちらも書く)

一方だけでは不足。単体は「部品が仕様どおりか」、総合は「繋いだ経路が動くか」を守る。
どちらも決定的であること(強さ・精度は縛らない ← 上の「何をテストするか」)。

| | 単体テスト | 総合テスト |
|---|---|---|
| 置き場 | `tests/engine/`(全シナリオ)、`tests/agent/`(スモーク) | `tests/integration/` |
| 単位 | spec の1シナリオ = 1メソッド | spec の1要件(見出し)= 1経路 |
| 範囲 | 1関数・1状態遷移。外部 I/O を含めない | 複数コンポーネントの結合。実際の入出力・設定読み込みを通す |
| 速さ | 速い。Red→Green のサイクルで毎回回す | 遅くてよい。change を閉じる前に回す |
| 落ちた意味 | その部品が仕様と違う | 部品は正しいが繋ぎ方・前提が違う |

### 単体テスト

- spec の各シナリオに1対1(上の「対応関係」に従う)。境界・異常系を網羅する。
- engine は副作用を閉じ込めた純粋関数なので、状態を組み立てて `apply(state, action)` を直接呼ぶ。
- 外部依存(ファイル・ネットワーク・時刻・乱数)は引数か fake で渡す。実物を呼ばない。

### 総合テスト

- **代表的な正常系を最初から最後まで通す経路を必ず1本用意する**(例:初期状態から決着まで1試合、
  入力ファイルを読んで出力を書くまで)。これが赤のまま change を閉じない。
- 縛るのは**結合部の前提**:依存方向(engine←agent←eval)を通した呼び出し、設定・シードの読み込み、
  エラーの伝播、外部入力の検証(@security-rules.md「入力と信頼境界」)。
- 非決定的要素は**シードを固定して決定的にする**。固定できないもの(実ネットワーク等)は fake に
  置き換える。再現できない総合テストは残さない(@impl-rules.md「不変条件」)。
- 単体で既に縛った分岐を総合で再検査しない(遅くなるだけ)。経路が通ることの確認に絞る。
- 総合テストは diff.md の「完了条件」を実行可能にしたもの。先に赤で置いてから実装を進めてもよい。

## 回帰

- バグ修正時は、再現する**失敗テストを先に追加**してから直す。
- 単体で再現するなら単体に、結合部でしか再現しないなら総合に置く(バグの居場所と同じ層に置く)。

## 例(実装より先に書く)

単体(`tests/engine/test_paralysis.py`)— spec の1シナリオ = 1メソッド:

```python
class TestParalysis:
    def test_S0001_02_paralyzed_actor_cannot_attack(self):
        state = make_battle_state(active_status="paralyzed")  # GIVEN
        actions = engine.get_legal_actions(state)             # WHEN
        assert not any(a.kind == "attack" for a in actions)   # THEN

    def test_S0001_03_paralysis_is_cleared_at_turn_end(self):
        state = make_battle_state(active_status="paralyzed")
        assert engine.apply_turn_end(state).active_status is None
```

総合(`tests/integration/test_paralysis_flow.py`)— 付与から回復までを1経路で通す:

```python
def test_paralysis_flow_through_one_turn():   # 総合テストに ID は付けない(N-2)
    # 単体で縛った分岐は再検査しない。結合して経路が通ることだけを見る。
    state = build_battle_state(seed=42)                   # シード固定 = 再現可能
    state = engine.apply_status_condition(state, PARALYSIS)
    assert not any(a.kind == "attack" for a in engine.get_legal_actions(state))
    state = engine.apply_turn_end(state)
    assert engine.get_legal_actions(state)                # 回復し行動可能に戻る
```
