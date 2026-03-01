---
title: "uv エコシステムの勘所"
emoji: "🚀"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["uv", "python"]
published: true
---

Python プロジェクトで uv を使い始めるときに最低限必要な知識として、ビルドバックエンドの役割、3種類の実行方法の違い、ディレクトリ構成の使い分けを解説します。

:::message
本記事は Gemini CLI / Codex CLI / Claude Code の生成結果をベースに編集しました。
:::

## pyproject.toml とは

`uv init` を実行すると `pyproject.toml` が生成されるため、最初のうちは uv の設定ファイルのように見えます。しかし実際には Python の標準仕様で定められた設定ファイルであり、複数の独立したツールから利用されます。（uv / Rye / Poetry / hatchling / taskipy など）

:::message
`pyproject.toml` に関わる主な標準仕様:

- [PEP 517](https://peps.python.org/pep-0517/): ビルドシステムのインターフェース（`build-backend` キー）
- [PEP 518](https://peps.python.org/pep-0518/): `[build-system]` テーブル
- [PEP 621](https://peps.python.org/pep-0621/): `[project]` テーブル（`[project.scripts]` などのメタデータ）
:::

uv が担うのは仮想環境の管理・依存関係の解決・パッケージのインストールといった基本的なプロジェクト管理機能です。ソースコードから配布物（wheel / sdist）を作成するビルド処理本体は外部のビルドバックエンド（hatchling 等）に委譲され、uv は `uv build` でそのフロントエンドとして振る舞います。hatchling は uv と組み合わせて使われることが多いですが、uv とは独立したツールです。

## ビルドバックエンドの役割

かつて Python のビルドは `setup.py` というスクリプトを実行して行われていましたが、現在は `pyproject.toml` による宣言的な管理が標準となっています。

hatchling は `pyproject.toml` の指示を解釈し、ビルド済み配布物（wheel）やソース配布物（sdist）を作成するビルドバックエンドです。

使用するビルドバックエンドは `pyproject.toml` の `[build-system]` テーブルで指定します。ただし、`uv init`（デフォルト）で生成されるのはアプリケーション向けの構成であり、`[build-system]` は含まれません。追加するには `uv init --lib`（または `--package`）として初期化するか、後から手動で追記します。

```toml:設定例
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

### ビルドとインストールの分離

ビルドとインストールは別の工程であり、それぞれ担当が異なります。

- **ビルド**（`uv build`）: `[build-system.requires]` に指定された外部パッケージ（`hatchling`、`setuptools` 等）を取得し、wheel / sdist を作成します。uv はビルドのフロントエンドとして動作し、ビルド処理本体はビルドバックエンドに委譲します。この段階では `site-packages` や `bin` への配置は行いません。
- **インストール**（`uv sync` / `uv add`）: uv 自身が wheel の内容を `site-packages` へ展開し、`[project.scripts]` に基づくラッパーを `bin` へ生成します。ビルドバックエンドは関与しません。

## 3種類の実行方法の違い

パッケージをインストールすると実体が `site-packages` に配置され、`[project.scripts]` の設定があればラッパーが `bin`（Windows では `Scripts/`）にも配置されます。この配置に応じて、以下の3種類の実行方法があります。

:::message
`uv run` はいずれの場合も、必要に応じてビルド・インストールを自動で行ってから実行します。そのため、手順を意識せずシームレスに呼び出すことができます。
:::

1. **直接実行** (`uv run example_tool.py`): インストール不要。Python インタープリタがファイルを直接読み込みます。開発中にコードの変更をすぐ確認したい場合に使います。

2. **モジュール実行** (`uv run -m example_tool`): Python のモジュール検索システムが `sys.path` から探索して実行します。環境や配置によっては未インストールでも動作しますが、wheel ターゲット設定（`packages` または `include`）を行ってインストール後のモジュール解決を確認する用途として有効です。

3. **コマンド実行** (`uv run example_tool`): `[project.scripts]` の設定が前提。ラッパーが `bin` に配置され、ラッパーは内部で対象モジュールを `import` するため `site-packages` への実体の配置も必要です。利用者がファイル構成を意識せず呼び出すための標準的な方法です。

```toml:設定例
[project.scripts]
example-tool = "example_tool:main"
```

左辺がコマンド名、右辺が `モジュール名:関数名` です。Makefile のターゲットのようなタスク定義に見えますが、実際の仕組みは異なります。インストール時に `bin/example-tool`（Windows では `Scripts/example-tool.exe`）という実行ファイル（ラッパー）が生成され、`uv run example-tool` はそのラッパーを呼び出します。ラッパーの内部では `example_tool` モジュールを import して `main()` を実行するコードが書かれています。

ここで注意が必要なのは、`[project.scripts]` を機能させるには `[build-system]` でビルドバックエンドを指定する必要がある一方で、実行ラッパーを生成するのはビルドバックエンドではないという点です。処理は「ビルド時」と「インストール時」で分かれており、ビルド時には hatchling などのビルドバックエンドが `[project.scripts]` を wheel のメタデータ（entry points）へ書き込みます。一方、インストール時には uv がそのメタデータを読み取り、`bin/`（Windows では `Scripts/`）に実行ラッパーを生成します。ビルドバックエンドがメタデータを作らないと uv もラッパーを生成できませんが、ラッパー本体を生成するのは uv です。

### タスクランナー

`[project.scripts]` はタスクランナーのように見えますが、Python モジュールのエントリーポイントに対してラッパーを生成する仕組みであり、任意のシェルコマンドを登録できる汎用的なタスクランナーではありません。uv にはタスクランナー機能がないため、taskipy などの外部ツールを導入する必要があります。

taskipy は以下のコマンドで依存関係に追加します。

```sh
uv add taskipy
```

導入すると、`[tool.taskipy.tasks]` セクションにタスクを定義できます。

```toml:設定例
[tool.taskipy.tasks]
test = "pytest"
lint = "ruff check ."
```

定義したタスクは `uv run task <タスク名>` で呼び出します。`[project.scripts]` に似た定義に見えますが、仕組みは異なります。taskipy は `bin/task` という実行ファイルとしてインストールされるパッケージです。`uv run task test` は `bin/task` を `test` という引数で呼び出しているに過ぎず、uv run から直接実行できるターゲットを生成しているわけではありません。

:::message
hatchling / taskipy はそれぞれ uv とは別々に `pyproject.toml` を読み込んで自分の担当セクションを処理しており、uv のプラグインとして動作しているわけではありません。
:::

## ディレクトリ構成の使い分け

Python プロジェクトのディレクトリ構成には、大規模・ライブラリ公開向けの `src` レイアウトと、小規模ツール向けのフラット構成という2つの選択肢があります。

:::message
以下の設定例で示すように、ディレクトリ構成によって使うキーが異なります。パッケージディレクトリ（`src` レイアウト等）には `packages`、単一ファイルには `include` を使います。
:::

### src レイアウト

多くのプロジェクトで採用される `src` レイアウトには、技術的理由があります。

1. **テストの整合性**: ルートにソースがあると、インポート時に「インストールされた物」ではなく「カレントのファイル」を直接参照してしまいます。`src` に隠すことで、ビルド・インストール手順の不整合を検知しやすくなります。
2. **管理の分離**: 設定ファイル（`.gitignore`, `README`, `toml` 等）と、プログラム本体（コード）をディレクトリレベルで分離し、見通しを良くします。

```toml:設定例
[tool.hatch.build.targets.wheel]
# src/ 以下のパッケージをインストール対象として指定
packages = ["src/example_tool"]
```

`packages` に指定したパスの最後の要素（`example_tool`）がインストール後のパッケージ名になります。

### 単一ファイル構成での制御

小規模なツールでは、`src` ディレクトリを作ると構造が複雑になりすぎることがあります。フラットなディレクトリ構造のまま、ビルド成果物に含めたいファイルを明示して管理することもできます。

```toml:設定例
[tool.hatch.build.targets.wheel]
# インストール対象（製品）に含めるファイルを指定
include = ["example_tool.py"]
```

## あとがき

この記事は、uv を使い始めたときに感じた「見通しの悪さ」を解消するために書きました。

まず感じたのは、`pyproject.toml` に謎の設定が並び、スクリプトをどう実行するべきなのかが分かりにくいということです。hatchling や taskipy は uv のプラグインのように見えますが、実際にはそれぞれが独立して `pyproject.toml` を参照するツールだということが、最初のうちは認識できませんでした。また、`pyproject.toml` の書き方を調べると Rye / Poetry など類似のツール向けの情報も混在して出て来たため、混乱に拍車が掛かりました。

「こんなのどうやって理解すれば良いのか、使っているうちに分かるものなのか」と不安になりましたが、とりあえず細部の理解は後回しにして使うことを優先しました。`pyproject.toml` を AI で生成したりしながら使い続けるうちに uv の挙動が少しずつ見えてきて、ようやく記事にまとめることができました。

## 関連記事

私は uv を触る以前には activate を必要とする virtualenv を使っていました。uv を使ってみると、npm のように activate のステップを挟まないシームレスな仮想環境を提供するものだと理解しました。

https://qiita.com/7shi/items/0f9c9ff7cf2fcb9597c5
