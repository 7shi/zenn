---
title: "LLM を制御するハーネスの初歩"
emoji: "🤖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["llm", "agent", "python", "ollama"]
published: true
---

本記事では、いわゆる「AI コーディングエージェント」の仕組みを解剖します。単なる「チャット」がどのようにして「一連の作業の自動実行」へと変わるのか、その背後にあるメカニズムを探ります。

Ollama を対象とした学習用の実装を使用します。

- [s02_tool_use.py](https://github.com/7shi/learn-ollama-code/blob/feature/migrate-to-ollama/agents/s02_tool_use.py)

:::message
本記事は Gemini CLI の生成結果をベースに編集しました。
:::

## コーディングエージェントとハーネス

ユーザーの入力を受けて自律的に作業を行うシステムは、一般に「コーディングエージェント」と呼ばれます。しかし、その技術的な実態は、強力だが制御が難しい LLM を、現実の作業環境で安全かつ確実に動作させるための枠組みにあります。

このような制御のための枠組みは**ハーネス**と呼ばれます。ハーネスは本来、馬具や幼児用の安全帯などを指し、力のある対象を目的の方向に正しく「制御」するための道具です。

エージェントを構成するハーネスとは、具体的には以下の要素を指します。

1.  LLM から呼び出すための「ツール（関数）」の定義
2.  操作範囲を限定する「安全策（サンドボックス）」
3.  それらを連続的に実行するための「ループ」

## ツールコール：LLMと外部を繋ぐインターフェース

LLM は本来、テキストを生成することしかできません。そこに外部操作を組み込むための仕組みが**ツールコール**です。

ハーネスの実装においては、まず「LLM から呼び出すための関数」を Python 側で定義します。そして、それらの関数の名前・目的・引数の情報を LLM に提示することで、LLM は「どのツールを、どんな引数で実行すべきか」を判断し、ツールの実行依頼を返せるようになります。

## ツールの実装

エージェントには、用途に応じた異なるタイプのツールが用意されています。`s02_tool_use.py` には基本となるツールが実装されています。

### Bash コマンド

最も汎用的なツールは、シェル（Bash）の実行です。`ls` でファイル一覧を見たり、`pytest` でテストを走らせたりと、これ一発で「観測と試行」という基本動作をカバーできます。

```python
def bash(command: str) -> str:
    """
    Run a shell command.
    """
    # 危険な操作（ルートディレクトリの削除やシャットダウン等）を簡易的にブロック
    dangerous = ["rm -rf /", "sudo", "shutdown", "reboot", "> /dev/"]
    if any(d in command for d in dangerous):
        return "Error: Dangerous command blocked"
    try:
        # 指定されたコマンドをサブプロセスとして実行
        r = subprocess.run(command, shell=True, cwd=WORKDIR,
                           capture_output=True, text=True, timeout=120)
        # 標準出力と標準エラー出力を結合して返す
        out = (r.stdout + r.stderr).strip()
        return out[:50000] if out else "(no output)"
    except subprocess.TimeoutExpired:
        return "Error: Timeout (120s)"
```

### パスのサンドボックス化

ファイル操作ツールを実装する前に、エージェントが作業ディレクトリ外の重要なファイルを破壊しないように制限をかける必要があります。`safe_path` は、すべてのファイルパスをチェックし、ワークスペース外へのアクセスを遮断する「ガードレール」の役割を果たします。

```python
def safe_path(p: str) -> Path:
    """
    Ensure the path is within the WORKDIR.
    """
    # パスを作業ディレクトリ（WORKDIR）からの絶対パスに変換
    path = (WORKDIR / p).resolve()
    # 解決されたパスがWORKDIR配下にあるかを確認
    if not path.is_relative_to(WORKDIR):
        raise ValueError(f"Path escapes workspace: {p}")
    return path
```

### ファイル操作ツール

コマンド操作だけでは、複雑なファイルの書き換えなどは不安定になりがちです。そこで、より確実な操作のために専用のツールを用意します。これらのツールは、内部で必ず上記の `safe_path` を経由するように設計されています。

```python:ファイルの読み取り
def read_file(path: str, limit: int = None) -> str:
    """
    Read file contents.
    """
    try:
        # パスの安全性を確認して内容を読み取る
        text = safe_path(path).read_text()
        lines = text.splitlines()
        # 表示制限（limit）がある場合は切り詰める
        if limit and limit < len(lines):
            lines = lines[:limit] + [f"... ({len(lines) - limit} more lines)"]
        return "\n".join(lines)[:50000]
    except Exception as e:
        return f"Error: {e}"
```

```python:ファイルの作成
def write_file(path: str, content: str) -> str:
    """
    Write content to file.
    """
    try:
        # パスの安全性を確認
        fp = safe_path(path)
        # 必要に応じて親ディレクトリを作成
        fp.parent.mkdir(parents=True, exist_ok=True)
        # 内容を書き込む
        fp.write_text(content)
        return f"Wrote {len(content)} bytes to {path}"
    except Exception as e:
        return f"Error: {e}"
```

大きなファイルを編集する際、ファイル全体を書き直すのは非効率であり、LLM が一部を書き間違えるリスクも高まります。`edit_file` は、特定の文字列を別の文字列に置換することで、変更箇所を最小限に抑えます。これにより、LLM による編集の確実性が向上し、API のトークン消費量（転送データ量）も節約できます。

```python:ファイルの編集（ピンポイント置換）
def edit_file(path: str, old_text: str, new_text: str) -> str:
    """
    Replace exact text in file.
    """
    try:
        fp = safe_path(path)
        content = fp.read_text()
        # 置換対象の文字列（old_text）がファイル内に存在するか確認
        if old_text not in content:
            return f"Error: Text not found in {path}"
        # 最初の1箇所だけを置換して保存
        fp.write_text(content.replace(old_text, new_text, 1))
        return f"Edited {path}"
    except Exception as e:
        return f"Error: {e}"
```

## ツールのリスト化と自動変換

実装した関数を LLM が「ツール」として認識できるようにするには、2つの情報が必要です。

1.  **TOOL_HANDLERS**: LLM からの実行指示があった際、関数名から実際の実行コードを呼び出すための「ディスパッチマップ」
2.  **TOOLS**: LLM へ提示するための「関数の仕様」のリスト

```python
# 名前引き用の辞書：LLM が指定した関数名を実際の関数オブジェクトに紐付ける
TOOL_HANDLERS = {
    "bash":       bash,
    "read_file":  read_file,
    "write_file": write_file,
    "edit_file":  edit_file,
}

# LLM に渡すツール定義のリスト：ライブラリが解析してスキーマ化する
TOOLS = [bash, read_file, write_file, edit_file]
```

ここで、[Ollama Python ライブラリ](https://github.com/ollama/ollama-python)の強力な機能が働きます。通常、LLM に関数の仕様（ツール仕様）を伝えるには、複雑な JSON スキーマを書かなければなりませんが、このライブラリは Python の機能を活用して、この手間を自動化してくれます。

*   **Type Hints（型ヒント）**: `path: str` や `limit: int` から、引数のデータ型を特定
*   **docstring（ドキュメント文字列）**: 関数の冒頭にある説明文から、そのツールが「何をするものか」「それぞれの引数が何を意味するか」を抽出

開発者は、普通の Python 関数を記述するだけで、ライブラリがそれを解析し、LLM が理解できる形式へと自動変換してくれるのです。

## 二重のループ構造

`s02_tool_use.py` の最大の特徴は、「ユーザーとの対話」と「ツールの実行」がそれぞれ独立したループとして構成されている点にあります。

### メインループ：ユーザーとの対話

`if __name__ == "__main__":` ブロックにあるループは、ユーザーからの入力を受け取り、エージェントの結果を表示するためのものです。

```python
if __name__ == "__main__":
    # システムプロンプトを含む会話履歴の初期化
    history = [{"role": "system", "content": SYSTEM}]
    while True:
        try:
            # ユーザーからの入力を受け付ける
            query = input("\033[36ms02 >> \033[0m")
        except (EOFError, KeyboardInterrupt):
            break
        # 終了コマンドのチェック
        if query.strip().lower() in ("q", "exit", ""):
            break
        # ユーザーの発言を履歴に追加
        history.append({"role": "user", "content": query})
        # 内側のループ（エージェント作業）を開始
        agent_loop(history)
        
        # agent_loop が終わった後、最終的なテキスト回答（履歴の最後）を取得して表示
        last = history[-1]
        content = last.content if hasattr(last, "content") else last.get("content", "")
        if content:
            print(content)
        print()
```

### エージェントループ：ツールの自動実行

メインループから呼び出される `agent_loop` は、LLM が「ツールを使う」と言い続ける限り回り続ける、エージェントの核となるループです。

LLM からの回答 `response.message` にツール実行の指示が含まれている場合、それは `tool_calls` というリストに格納されます。プログラムはこのリストを確認し、中身があればツールを実行してループを継続し、空であれば「最終的なテキスト回答が来た」と判断してループを終了します。

```python
def agent_loop(messages: list):
    while True:
        # 推論：現在の履歴とツールの仕様を渡してLLMに判断させる
        response = client.chat(
            model=MODEL, messages=messages, tools=TOOLS, think=THINK,
        )
        # LLMの回答（アシスタントのターン）を履歴に追加
        messages.append(response.message)
        
        # 停止条件：ツール呼び出し（tool_calls）が含まれていなければ終了して main に戻る
        if not response.message.tool_calls:
            return
            
        # 実行：指示されたツールを一つずつ呼び出す
        for tool in response.message.tool_calls:
            # TOOL_HANDLERSから対応する関数を取得
            handler = TOOL_HANDLERS.get(tool.function.name)
            # 関数を実行し結果（output）を取得
            output = handler(**tool.function.arguments) if handler else f"Unknown tool: {tool.function.name}"
            # 実行中のツール名と出力をコンソールに表示
            print(f"> {tool.function.name}: {str(output)[:200]}")
            # 実行結果（ツールのターン）を履歴に追加。
            # これにより、次のループ（chat呼び出し）でLLMは結果を確認できる
            messages.append({"role": "tool", "content": str(output), "tool_name": tool.function.name})
```

この二重構造により、以下のフローが実現されます。

1.  **ユーザー**が依頼を投げる（メインループ）
2.  **エージェント**が「目的を達成するために必要なツール」を順次呼び出し、その結果を自己フィードバックしながら作業を進める（`agent_loop`）
3.  LLMが「もうツールを使う必要はない（回答の準備ができた）」と判断すると、`agent_loop` を抜けてメインループに戻る
4.  メインループで最終的なテキストメッセージをユーザーに表示し、次の入力を待つ

## まとめ

ここまで見てきたように、エージェントを実用的なものにしているのは、LLM の賢さだけではなく、それを制御する「ハーネス」の設計にあります。

1.  **安全なツール設計**：`safe_path` などによって物理的に保護された関数群
2.  **シームレスなインターフェース**：Ollama Python ライブラリによる、型ヒントと docstring からのツール仕様の自動生成
3.  **自律的な駆動**：実行結果を自己フィードバックし、目的達成まで止まらない二重ループ構造
4.  **疎結合な拡張性**：`TOOL_HANDLERS`（ディスパッチマップ）により、ツールをいくつ追加してもメインループのコードが一切変わらない仕組み

単なる「チャット」は情報の生成で終わりますが、「コーディングエージェント」はこの堅牢な制御機構によって、実際のファイルシステム上で作業を完遂します。

以後のステップでは、「タスクの計画」や「複数のエージェントによる協調」といった高度な機能が、今回解説した構造をベースに追加されていきます。

https://github.com/7shi/learn-ollama-code

## 関連記事

https://zenn.dev/7shi/articles/20251231-ollama-tools

https://zenn.dev/7shi/articles/20260102-toolcall-strout
