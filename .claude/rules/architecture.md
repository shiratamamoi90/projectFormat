# アーキテクチャ:分離軸 × 実装手段

この設計は2つの直交する軸でできている。規模が変わっても **Core は書き換えず、行・列・セル単位で足し引きする**だけで拡張できる。

## 分離軸(縦):規模に応じたレイヤー

| レイヤー | いつ使うか | 内容 |
|---|---|---|
| **Core** | 常時(個人開発から) | 二系統原則、基本 skill、format+test フック |
| **Scale** | 規模が上がったら足す | ADR、危険操作veto、CI連携、sub-agent 並列化 |
| **Adapt** | プロジェクト種別で差替 | 「正」の定義、ドメイン別 skill、`baselines/` や `migrations/` 等 |

## 実装手段(横):担保の強さ

| 手段 | 置き場 | 強制力 | 役割 |
|---|---|---|---|
| **方針** | CLAUDE.md / .claude/rules/ | なし(影響のみ) | 守ってほしいこと |
| **実行** | .claude/skills/ | コマンドで呼ぶ | 繰り返す工程の自動化 |
| **強制** | .claude/settings.json (hooks) | あり(機械実行) | 絶対に守らせること |

> 右へ行くほど強い。**絶対則は方針列に置いたままにせず、強制列(hooks)か実行列(skill)の停止条件へ
> 移す**(理由は CLAUDE.md「参照先」冒頭)。

## マトリクス

| | 方針 | 実行 | 強制 |
|---|---|---|---|
| **Core** | 二系統原則・Don't | /new-change, /new-experiment, /validate, /run-loop | format on edit, test on stop |
| **Scale** | チーム規約・ロール | /eval, /team-onboarding | 危険操作veto, 時間予算, CI |
| **Adapt** | 「正」の定義・不変条件 | ドメイン別コマンド | ドメイン別検査 |

各セルは独立。1セルの変更が他に波及しない。

実体の所在(このテンプレートに収録済みのもの):
- Core・実行の skill 4つ → `.claude/skills/{new-change,new-experiment,run-loop,validate}/SKILL.md`
- Core・強制の hooks(format on edit / test on stop)→ 配線は `.claude/settings.json`、
  実体は `scripts/hooks.sh format` / `scripts/hooks.sh test`
- Scale・強制のうち veto と validate → 配線は `.claude/settings.team.json`(settings.json にマージで
  有効化)、実体は `scripts/hooks.sh veto` / `scripts/hooks.sh validate`
- Scale・実行の /eval /team-onboarding、Scale・強制の時間予算・CI → **未収録**。規模が上がった時に追加する。
- Adapt 行 → 種別確定後に追加する(下の「種別ごとの Adapt」)。テンプレートには baselines/ の雛形のみ収録。

## 二系統の対応表

| | 仕様ループ(決定的) | 探索ループ(非決定的) |
|---|---|---|
| 単位フォルダ | changes/NNNN-xxx/ | experiments/NNNN-xxx/ |
| 中身 | proposal / spec / tasks / diff | hypothesis / config / result |
| 完了先 | specs/ に反映しアーカイブ | result を残しアーカイブ |
| テスト | 単体で全シナリオ + 総合で経路(主役) | 強さは縛らない。クラッシュ/予算のみ決定的にテスト |
| 対応コード | src/engine(安定・決定的) | src/agent, src/eval(探索) |

## 依存方向(不変条件)

```
src/engine  ← src/agent  ← src/eval
(決定的・安定)   (探索)       (評価)
```
矢印の向きにのみ依存してよい。この図は地図で、規範と崩したときに何が壊れるかは
@impl-rules.md「不変条件」が正本。

## 整合性の優先順位(不変条件)

食い違いを見つけたら、**必ずこの順で上位を正とする**。下位に合わせて上位を書き換えない。

```
ドキュメント  ←  テスト  ←  ソースコード
(仕様が正)      (仕様の写し)   (テストを通すもの)
```

| 順位 | 層 | 実体 | 食い違ったときの扱い |
|---|---|---|---|
| 1 | ドキュメント | `specs/`, `changes/*/spec.md`, `.claude/rules/`, 「正」(@stack.md) | これが正。直すのは人間の承認を経たときだけ |
| 2 | テスト | `tests/`(単体・総合) | ドキュメントと違えばテストが誤り。仕様に合わせて直す |
| 3 | ソースコード | `src/`, `scripts/` | テストと違えばコードが誤り。テストに合わせて直す |

- **実装に合わせて spec やテストを書き換えない**(最頻出の罠)。コードのほうが正しいと判明した場合も
  順序は変えない:先に spec を人間の承認で直し、次にテスト、最後にコード。
- **確認も同じ順で行う**:ドキュメント同士 → ドキュメント↔テスト → テスト↔コード。
  上位が崩れたまま下位を直しても、直した先がまた誤りになる。
- ドキュメント同士の食い違いは「**正本はどれか**」で解く(コマンドの正本は @stack.md、リポジトリの
  状態の正本は `TEMPLATE.md` 冒頭)。正本が決まっていない事実は、正本を決めてから直す。
- この検査を実行するのが `/validate`(実行列)。

## 種別ごとの Adapt(差し替え表)

| 種別 | 「正」 | 仕様ループ | 探索ループ | 固有物 |
|---|---|---|---|---|
| Web/業務アプリ | 要件定義 | 主役 | ほぼ無し | migrations/ |
| CLI/ツール | コマンド仕様 | 主役 | 無し | fixtures/ |
| ライブラリ | 公開API契約 | 主役 | 無し | 後方互換テスト |
| MLコンペ | 評価指標+ルール | engine部のみ | 主役 | baselines/, eval/ |
| 研究/PoC | 検証仮説 | 補助 | 主役 | data versioning |

種別が変わったら Adapt 行だけ差し替える。Core/Scale は不変。
