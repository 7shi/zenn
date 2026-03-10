---
title: "LLM を制御するハーネスの初歩"
emoji: "🤖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["llm", "agent", "python", "ollama"]
published: true
---

本記事では、いわゆる「AI コーディングエージェント」の仕組みを解剖します。単なる「チャット」がどのようにして「一連の作業の自動実行」へと変わるのか、その背後にあるメカニズムを探ります。

学習用の実装を使用します。オリジナルは Anthropic SDK を使用していますが、Ollama に移植したフォークです。

- [s02_tool_use.py](https://github.com/7shi/learn-ollama-code/blob/feature/migrate-to-ollama/agents/s02_tool_use.py)（[ドキュメント](https://github.com/7shi/learn-ollama-code/blob/feature/migrate-to-ollama/docs/ja/s02-tool-use.md)）

:::message
本記事は Gemini CLI の生成結果をベースに編集しました。
:::

## コーディングエージェントとハーネス

ユーザーの入力を受けて自律的に作業を行うシステムは、一般に「コーディングエージェント」と呼ばれます。しかし、その技術的な実態は、強力だが制御が難しい LLM を、現実の作業環境で安全かつ確実に動作させるための枠組みにあります。

このような制御のための枠組みは「ハーネス」と呼ばれます。ハーネスは本来、馬具や幼児用の安全帯などを指し、力のある対象を目的の方向に正しく制御するための道具です。

コーディングエージェントを構成するハーネスとは、具体的には以下の要素を指します。

1.  LLM から呼び出すための「ツール（関数）」の定義
2.  操作範囲を限定する「安全策（サンドボックス）」
3.  それらを連続的に実行するための「ループ」

## ツールコール：LLMと外部を繋ぐインターフェース

LLM は本来、テキストを生成することしかできません。そこに外部操作を組み込むための仕組みが「ツールコール」です。

ハーネスの実装においては、まず「LLM から呼び出すための関数」を Python 側で定義します。そして、それらの関数の名前・目的・引数の情報を LLM に提示することで、LLM は「どのツールを、どんな引数で実行すべきか」を判断し、ツールの実行依頼を返せるようになります。

## ツールの実装

エージェントには、用途に応じた異なるタイプのツールが用意されています。`s02_tool_use.py` には基本となるツールが実装されています。

ツールの引数はすべて Python の型ヒントで定義されており、関数の冒頭には docstring で説明が書かれています。これらの情報は、LLM にツールの仕様を伝える際に重要な役割を果たします。また、LLM に文字列として情報を渡すため、すべてのツールは「文字列を返す」ことを前提に設計されています。

### コマンド実行

最も汎用的なツールは、シェル（bash）のコマンド実行です。`ls` でファイル一覧を見たり、`grep` で検索したりと、これだけで LLM が外部の環境を操作するための基本動作をカバーできます。

```python
def bash(command: str) -> str:
    """
    Run a shell command.

    Args:
        command (str): The shell command to execute

    Returns:
        str: The output of the command
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

LLM は "Run a shell command." という情報を踏まえて、プロンプトの内容から「このタスクを達成するためにはシェルコマンドを実行する必要がある」と判断した場合に、`bash` ツールを実行するよう依頼します。

```text:使用例
s02 >> カレントディレクトリにあるすべてのPythonファイルを一覧表示する
bash{'command': 'ls -la *.py'}
-rw-r--r-- 1 7shi 7shi 180  3月 10 20:01 greet.py
-rw-r--r-- 1 7shi 7shi  23  3月 10 19:18 hello.py
カレントディレクトリにあるPythonファイルは以下の通りです：

- `greet.py` (180 bytes)
- `hello.py` (23 bytes)
```

:::message
詳細なフローは後で説明しますが、ツールの呼び出しはコードで作り込む必要があります。LLM はツールの実行依頼を返して、コード側でツールを実行して結果を渡すことで、最終的な回答を生成します。
:::

### ファイル操作ツール

コマンド実行だけでは、複雑なファイルの書き換えなどは不安定になりがちです。そこで、より確実な操作のために専用のツールを用意します。

#### パスのサンドボックス化

ファイル操作ツールを実装する前に、エージェントが作業ディレクトリ外の重要なファイルを破壊しないように制限をかける必要があります。`safe_path` はファイルパスをチェックし、ワークスペース外へのアクセスを遮断する「ガードレール」の役割を果たします。

```python
def safe_path(p: str) -> Path:
    """
    Ensure the path is within the WORKDIR.
    """
    # WORKDIR からの相対パスを絶対パスに変換
    path = (WORKDIR / p).resolve()
    # 解決されたパスが WORKDIR 配下にあるかを確認
    if not path.is_relative_to(WORKDIR):
        raise ValueError(f"Path escapes workspace: {p}")
    return path
```

#### ファイルの読み取り

```python
def read_file(path: str, limit: int = None) -> str:
    """
    Read file contents.

    Args:
        path (str): Path to the file relative to workspace
        limit (int): Maximum number of lines to return

    Returns:
        str: The file contents
    """
    try:
        # パスの安全性を確認して内容を読み取る
        text = safe_path(path).read_text()
        lines = text.splitlines()
        # 表示制限がある場合は切り詰める
        if limit and limit < len(lines):
            lines = lines[:limit] + [f"... ({len(lines) - limit} more lines)"]
        return "\n".join(lines)[:50000]
    except Exception as e:
        return f"Error: {e}"
```
````text:使用例
s02 >> hello.pyはどのような処理を行っていますか？
read_file{'path': 'hello.py', 'limit': 10}
print("Hello, World!")
`hello.py` ファイルには、以下の1行のコードが含まれています。

```python
print("Hello, World!")
```

このプログラムは、コンソールに `"Hello, World!"` という文字列を出力する処理を行っています。
````

#### ファイルの作成

```python
def write_file(path: str, content: str) -> str:
    """
    Write content to file.

    Args:
        path (str): Path to the file relative to workspace
        content (str): Content to write

    Returns:
        str: Success or error message
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
````text:使用例
s02 >> greet(name)関数を持つgreet.pyというファイルを作成する
write_file{'path': 'greet.py', 'content': 'def greet(name):\n    return f"Hello, {name}!"\n'}
Wrote 46 bytes to greet.py
ファイル「greet.py」を英語で記述して作成しました。内容は以下の通りです：

```python
def greet(name):
    return f"Hello, {name}!"
```
````

#### ファイルの編集（ピンポイント置換）

大きなファイルを編集する際、ファイル全体を書き直すのは非効率であり、LLM が一部を書き間違えるリスクも高まります。`edit_file` は、特定の文字列を別の文字列に置換することで、変更箇所を最小限に抑えます。これにより、LLM による編集の確実性が向上し、API のトークン消費量（転送データ量）も節約できます。

```python
def edit_file(path: str, old_text: str, new_text: str) -> str:
    """
    Replace exact text in file.

    Args:
        path (str): Path to the file relative to workspace
        old_text (str): Exact text to find and replace
        new_text (str): Replacement text

    Returns:
        str: Success or error message
    """
    try:
        fp = safe_path(path)
        content = fp.read_text()
        # 置換対象の文字列 `old_text` がファイル内に存在するか確認
        if old_text not in content:
            return f"Error: Text not found in {path}"
        # 最初の 1 箇所だけを置換して保存
        fp.write_text(content.replace(old_text, new_text, 1))
        return f"Edited {path}"
    except Exception as e:
        return f"Error: {e}"
```
````text:使用例
s02 >> greet.pyを編集して関数にdocstringを追加する
edit_file{'path': 'greet.py', 'old_text': 'def greet(name):\n    return f"Hello, {name}!"', 'new_text': 'def greet(name):\n    """Greet the given name.\n\n    Args:\n        name (str): The name to greet.\n\n    Returns:\n        str: A greeting message.\n    """\n    return f"Hello, {name}!"'}
Edited greet.py
greet.py に docstring を追加しました。編集後のファイルの中身は以下の通りです：

```python
def greet(name):
    """Greet the given name.

    Args:
        name (str): The name to greet.

    Returns:
        str: A greeting message.
    """
    return f"Hello, {name}!"
```
````

## ツールのリスト化と自動変換

実装した関数を LLM がツールとして認識できるようにするには、ツール定義のリストを渡す必要があります。

```python:ツール定義のリスト
TOOLS = [bash, read_file, write_file, edit_file]
```

ここで、[Ollama Python ライブラリ](https://github.com/ollama/ollama-python)の強力な機能が働きます。通常、LLM にツールの仕様を伝えるには、複雑な JSON スキーマを書かなければなりませんが、このライブラリは Python の機能を活用して、この手間を自動化してくれます。

*   **Type Hints（型ヒント）**: `path: str` や `limit: int` から、引数のデータ型を特定
*   **docstring（ドキュメント文字列）**: 関数の冒頭にある説明文から、そのツールが「何をするものか」「それぞれの引数が何を意味するか」を抽出

普通の Python 関数を記述するだけで、ライブラリがそれを解析し、LLM が理解できる形式へと自動変換してくれるのです。

:::message
詳細は以下の記事を参照してください。
:::

https://zenn.dev/7shi/articles/20251231-ollama-tools

## 二重のループ構造

`s02_tool_use.py` は、「ユーザーとの対話」と「ツールの実行」がそれぞれネストしたループとして構成されています。

### メインループ：ユーザーとの対話

`if __name__ == "__main__":` ブロックにあるループは、ユーザーからの入力を受け取り、エージェントの結果を表示します。

```python
if __name__ == "__main__":
    # システムプロンプトを含む会話履歴の初期化
    history = [{"role": "system", "content": SYSTEM}]
    while True:
        try:
            # ユーザーからの入力を受け付ける（プロンプトは水色）
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

ここで重要なポイントがあります。LLM は状態を保持しません。つまり、推論のたびに毎回「過去の会話履歴」を送信する必要があります。具体的には、以下を含める必要があります。

1. システムプロンプト
2. ユーザーのプロンプト
3. ツール実行の結果
4. アシスタントの回答
5. ユーザーのプロンプト
6. （以降、すべてのターン）

この仕組みにより、LLM は「コンテキスト（これまでの文脈）」を理解した上で判断を下せるようになります。実装では、この履歴を `history` というリストで管理し、ツールの実行結果が返ってくるたびに `append()` でリストに追加していくことで、常に「最新の状態」を LLM に提示します。

:::message
OpenAI の API では、サーバー側での履歴の保持をサポートする [Responses API](https://developers.openai.com/api/reference/responses/overview) も提供されています。これを利用すれば毎回すべての履歴を送る必要はなく、キャッシュ効率も向上します。

ただし、Codex CLI では履歴を最適化しながら送ることが想定されているらしく、専用のエンドポイントでは履歴の保持がサポートされていません。👉[調査実装](https://github.com/7shi/codex-oauth)
:::

### エージェントループ：ツールの実行

メインループから呼び出される `agent_loop` は、LLM が「ツールを使う」と言い続ける限り回り続ける、エージェントの核となるループです。

LLM からの回答 `response.message` にツール実行の依頼が含まれている場合、それは `tool_calls` というリストに格納されます。ツール名から実際の実行コードを呼び出すための「ディスパッチマップ（名前引き用の辞書）」を用意しておきます。

```python:ディスパッチマップ
TOOL_HANDLERS = {
    "bash":       bash,
    "read_file":  read_file,
    "write_file": write_file,
    "edit_file":  edit_file,
}
```

:::message
分かりやすさを優先してキーと関数名を一致させています。ツールを追加する際、関数を直接指定せずにラムダ式を挟むケースなどがあるため、`TOOLS` から自動生成せずに列挙しています。
:::

`tool_calls` の中身があればツールを実行してループを継続し、空であれば「最終的なテキスト回答が来た」と判断してループを終了します。

```python
def agent_loop(messages: list):
    while True:
        # 推論：現在の履歴とツールの仕様を渡して LLM に判断させる
        response = client.chat(
            model=MODEL, messages=messages, tools=TOOLS, think=THINK,
        )
        # LLM の回答（アシスタントのターン）を履歴に追加
        messages.append(response.message)
        
        # 停止条件：ツール呼び出しが含まれていなければ終了
        if not response.message.tool_calls:
            return
            
        # 実行：指示されたツールを一つずつ呼び出す
        for tool in response.message.tool_calls:
            # ツールの名前と引数を表示（黄色）
            print(f"\033[33m{tool.function.name}{tool.function.arguments}\033[0m")
            # 関数を取得・実行して、実行結果を表示（黄色）
            handler = TOOL_HANDLERS.get(tool.function.name)
            output = handler(**tool.function.arguments) if handler else f"Unknown tool: {tool.function.name}"
            print(f"\033[33m{str(output)[:200]}\033[0m")
            # 実行結果を履歴に追加、これにより次のループで LLM は結果を確認できる
            messages.append({"role": "tool", "content": str(output), "tool_name": tool.function.name})
```

この二重構造により、以下のフローが実現されます。

1.  ユーザーが依頼を投げる（メインループ）
2.  ハーネスが「目的を達成するために必要なツール」を順次呼び出し、その結果を自己フィードバックしながら作業を進める（`agent_loop`）
3.  LLM が「もうツールを使う必要はない（回答の準備ができた）」と判断すると、`agent_loop` を抜けてメインループに戻る
4.  メインループで最終的なテキストメッセージをユーザーに表示し、次の入力を待つ

:::message
このフローの構成上、ツールコールの後に必ずテキストの回答で締め括ることになります。
:::

## まとめ

ここまで見てきたように、コーディングエージェントを実用的なものにしているのは、LLM の能力だけではなく、それを制御するハーネスの設計にあります。

1.  **安全なツール設計**：`safe_path` などによって保護された関数群
2.  **自律的な駆動**：実行結果を自己フィードバックし、目的達成まで止まらない二重ループ構造
3.  **疎結合な拡張性**：ディスパッチマップにより、ツールをいくつ追加してもメインループのコードが変わらない仕組み

単なるチャットは情報の生成で終わりますが、コーディングエージェントはこの堅牢な制御機構によって、実際のファイルシステム上で作業を完遂します。

以後のステップでは、「タスクの計画」や「複数のエージェントによる協調」といった高度な機能が、今回解説した構造をベースに追加されていきます。

https://github.com/7shi/learn-ollama-code

## 関連記事

実装に見られるように、過去の履歴を毎回送信することで LLM はコンテキストを認識しています。LLM がその都度学習して内容を記憶しているわけではありません。この点を踏まえて、LLM の推論と記憶の関係について解説した記事です。

https://note.com/7shi/n/n9b7839879be0

MCP はツールをユーザー側で追加できるように標準化した仕組みに相当します。MCP とツールコール（Function calling とも呼ばれる）を比較して解説した記事です。

https://qiita.com/7shi/items/e27866ce51c6b9a0f605

## 参考

各種コーディングエージェントについてのまとめ記事です。

https://blog.lai.so/agent/

コーディングエージェント作成についての書籍を執筆されています。

https://gihyo.jp/book/2026/978-4-297-15565-0

TypeScript と Gemini を使ってコーディングエージェントを自作する記事です。MCP をサポートしており、ファイルの読み書きも MCP 経由で行います。

https://azukiazusa.dev/blog/build-your-own-coding-ai-agent/

昨今、MCP はコンテキスト効率が悪いと言われることが多くなっていますが、コンテキスト消費量を抑える工夫も行われています。

https://azukiazusa.dev/blog/enable-claude-code-tool-search-to-reduce-mcp-token-usage/

コーディングエージェントの歴史をたどりつつ、サンプル実装も解説されています。

https://zenn.dev/sakasegawa/articles/af8ede2e4d7da4

ハーネスの効果的な利用方法が解説されています。特に、実装に至った判断を残しておくのは重要です。ハーネスの仕組みがイメージできていれば、より効果的に利用できそうです。

https://nyosegawa.github.io/posts/harness-engineering-best-practices-2026/

:::message
ここで紹介させていただいた [laiso](https://x.com/laiso) さん、[azukiazusa](https://x.com/azukiazusa9) さん、[逆瀬川](https://x.com/gyakuse)さんは、レベルの高い記事を書いておられるので要注目です。
:::
