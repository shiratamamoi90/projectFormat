# プロジェクトテンプレート(仕様ループ + 探索ループ / Claude Code 前提)

決定的な部分は **仕様ループ**(仕様→テスト→実装→テスト)、非決定的な部分は **探索ループ**
(仮説→設定→計測→考察)で開発する、二系統 × 3レイヤー(Core/Scale/Adapt)の雛形。
規律は **方針(CLAUDE.md)/ 実行(skill)/ 強制(hooks)** の3手段で担保する。

## このリポジトリの現在の状態(初見の人へ)

- **これはテンプレート本体であり、実プロジェクトではない(開始状態)。** プロジェクト種別・言語・
  依存管理・「正」は**意図的に未確定**で、`.claude/rules/stack.md` の `<...>` スロットは**現時点ですべて
  未記入**(コピーした先で下の手順1により人間が確定する)。`<...>` は不備ではなく記入スロット。
- **進行中・予定中の作業は無い。** `0001-example-*` は書き方を示す記入例であり、実作業ではない
  (どれが記入例かは下のツリー、削除は手順3)。
- **仕組み(hooks / skill / validate)は収録済みで、この状態のまま動く。** 所在と役割は下の
  「ディレクトリ構造」が正本(ここに重ねて書かない)。
- **このリポジトリは同梱物ごと GitHub で管理する。** そのため `.gitignore` は**空が正**で、
  除外リストは `gitignore.template` に置いてある(コピー先で手順1により `.gitignore` になる)。
  空の `.gitignore` に除外を書き戻さない — フォーマット自身が git に上がらなくなる。

## 使い方(最小5ステップ)

1. **`gitignore.template` を `.gitignore` にリネームする**(`mv gitignore.template .gitignore`)。
   **コピー直後・最初のコミット前に必ず行う。** 除外はこのリネームで初めて効き、
   **機密情報(`.env`)・生成物(`__pycache__` `.pytest_cache` `.ruff_cache`)・テンプレート同梱物
   ・ローカルの記録(`decisions/` `experiments/` `baselines/`)** の4区分が追跡対象から外れる
   (区分ごとの中身と理由は `gitignore.template` 自身が正本。ここに一覧を書き写さない)。
   続けて `CLAUDE.md` のプロジェクト名、`.claude/rules/stack.md` の `<...>`(**種別**・Stack・「正」・Commands)、`security-rules.md` の「このプロジェクト固有」、そして **`README.md`(作るシステムの紹介 — clone した人が最初に読むファイル)** を埋める。種別を決めると Adapt 層が決まる(`architecture.md` の種別表)。
2. `.claude/rules/` の各ルールを必要に応じて調整(基本そのままで可)。
3. `changes/0001-example-*` と `experiments/0001-example-*` を参考にしたら削除。
4. Claude Code を起動。`/new-change <名前>` で最初の変更を作り、spec を自分で書いて承認。
5. `/run-loop <change名>` で Red→Green→Refactor を回す。完了したら `/validate`。

> **コピー先で git に上げる範囲の正本は `gitignore.template`**(手順1で `.gitignore` になる)。
> テンプレート同梱物(このファイル・CLAUDE.md・`.claude/`・`scripts/` のフック・雛形と記入例)は
> 追跡せず、`src/` `tests/` `specs/`・実作業の `changes/NNNN-*/`・`README.md` だけをコミットする。
> **フォーマットの説明(このファイル)は上げず、作ったシステムの説明(`README.md`)を上げる**という
> 切り分け。フォーマット本体のリポジトリだけは例外で、同梱物ごと管理するため `.gitignore` が空
> (冒頭「このリポジトリの現在の状態」)。

## ディレクトリ構造

パスの役割とレイヤー(Core/Scale/Adapt)はこのツリーが正本。**同じ一覧を別の表で持たない**
(2箇所あると片方が古いまま残る — @.claude/rules/impl-rules.md「共通化」)。

```
.
├── CLAUDE.md                       # エージェントへのルール/制約のみ(薄く保つ・詳細は rules/ を参照 / Core)
├── TEMPLATE.md                     # このファイル。フォーマットの説明 + リポジトリの現在の状態の正本(冒頭 / コピー先では git 非追跡)
├── README.md                       # 作ったシステムの紹介(何か・使い方)。**git に上げる**雛形
├── .gitignore                      # フォーマット本体では**空が正**(同梱物ごと GitHub 管理するため)
├── gitignore.template              # コピー先の除外リストの正本。手順1で `.gitignore` にリネームする
├── .claude/
│   ├── settings.json               # hooks の配線: format on edit, test on stop(Core)
│   ├── settings.team.json          # チーム用 hooks の配線: veto, validate(Scale, マージで有効化)
│   ├── rules/                      # ルールの正本7本(どれを見るかは CLAUDE.md の参照先表 / Core)
│   └── skills/                     # スラッシュコマンド(実行 / Core)
│                                   #   new-change / new-experiment / run-loop / validate の SKILL.md
├── specs/                          # 決定的部分の source of truth(Core)
│   ├── rule-engine.md              #   確定仕様(承認・実装済みのものだけ置く)
│   └── glossary.md                 #   用語集:ドメイン語彙の「正」(N-1。validate.sh が参照)
├── changes/                        # 仕様ループの作業単位(Core)
│   └── 0001-example-add-paralysis/ #   記入例:proposal / spec / tasks / diff(中身は spec-rules.md)
├── experiments/                    # 探索ループの作業単位(Core)
│   └── 0001-example-mcts-depth/    #   記入例:hypothesis / config / result(中身は experiment-rules.md)
├── src/                            # 依存方向 engine←agent←eval(Core/Adapt)
│   ├── engine/                     #   決定的・安定(仕様ループ対象)
│   ├── agent/                      #   探索(実験で評価)
│   └── eval/                       #   自己対戦・評価
├── tests/                          # 単体 + 総合の両方を書く(Core)
│   ├── engine/                     #   単体:spec の全シナリオ
│   ├── agent/                      #   単体:スモーク(クラッシュ/予算/再現性)
│   └── integration/                #   総合:繋いだ経路を最初から最後まで通す
├── decisions/                      # ADR:判断の記録(Scale)
│   └── 0001-example-language.md
├── scripts/
│   ├── validate.sh                 # 機械検査(項目の正本は impl-rules.md N-8)。/validate が呼ぶ(Core)
│   └── hooks.sh                    # hooks の実体。format|test(Core)/ veto|validate(Scale)を引数で切替
└── baselines/                      # 実験の比較基準(Adapt / ML系)
    └── README.md
```

## 規模に応じた拡張

- **個人**: Core のみ。experiments/ を使わないなら無視してよい。
- **コンペ**: + Adapt(`baselines/` と `src/eval/`)。
- **チーム**: + Scale(decisions/ 必須・settings.team.json を settings.json にマージ・CI から validate)。
  既定では `decisions/` `experiments/` `baselines/` を追跡しない(個人前提)。
  チームで共有するものから該当行を消す(範囲の正本は `gitignore.template` — 上の「使い方」の注記)。

各レイヤーの中身・未収録のもの・設計思想は `.claude/rules/architecture.md`。
